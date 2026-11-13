-- Smoke tests for TrackerBuddy UI against WoW stubs (plain Lua 5.1)
local function hunter()
  return {
    { name = "Track Beasts",    type = "spell", spellID = 1494,  active = false },
    { name = "Auctioneer",      type = "other", active = true },
    { name = "Track Humanoids", type = "spell", spellID = 19883, active = true },
    { name = "Find Minerals",   type = "spell", spellID = 2580,  active = false },
  }
end

-- Fresh stubs + fresh addon load for every test.
local function setup(infos, db)
  dofile("tests/wow_stubs.lua")
  C_Minimap.infos = infos
  TrackerBuddyDB = db
  local ns = {}
  assert(loadfile("TrackerBuddy/Core.lua"))("TrackerBuddy", ns)
  assert(loadfile("TrackerBuddy/UI.lua"))("TrackerBuddy", ns)
  return ns
end

local function visible(ns)
  local out = {}
  for _, e in ipairs(ns.UI.entries) do
    if e:IsShown() then out[#out + 1] = e end
  end
  return out
end

local function entryFor(ns, spellID)
  for _, e in ipairs(visible(ns)) do
    if e.spellID == spellID then return e end
  end
end

local function setActive(spellID)
  for _, info in ipairs(C_Minimap.infos) do
    if info.type == "spell" then info.active = (info.spellID == spellID) end
  end
end

local tests = {}
local order = {}
local function test(name, fn) tests[name] = fn; order[#order + 1] = name end

test("smoke_login_builds", function()
  local ns = setup(hunter())
  STUB.fire("PLAYER_LOGIN")
  assert(#visible(ns) == 3, "visible " .. #visible(ns))
  local hum, beasts = entryFor(ns, 19883), entryFor(ns, 1494)
  assert(hum.attrs.type == nil, "active entry must not cast")
  assert(hum.highlight:IsShown() and not beasts.highlight:IsShown())
  assert(beasts.attrs.type == "spell")
  assert(beasts.attrs.spell == 1494)
  assert(beasts.icon.texture == 1494)
  assert(TrackerBuddyButton.icon.texture == 19883)
  assert(not TrackerBuddyList:IsShown(), "list starts hidden")
  assert(TrackerBuddyButton:GetAttribute("_onclick"), "toggle snippet set")
end)

test("smoke_no_spells", function()
  local ns = setup({})
  STUB.fire("PLAYER_LOGIN")
  assert(#visible(ns) == 0)
  assert(TrackerBuddyButton.icon.texture == 134400)
end)

test("smoke_rebuild_deferred_in_combat", function()
  local ns = setup(hunter())
  STUB.fire("PLAYER_LOGIN")
  STUB.combat = true
  table.insert(C_Minimap.infos, { name = "Find Herbs", type = "spell", spellID = 2383, active = false })
  STUB.fire("SPELLS_CHANGED")
  assert(#visible(ns) == 3, "visible " .. #visible(ns))
  assert(ns.UI.pendingRebuild == true)
  STUB.combat = false
  STUB.fire("PLAYER_REGEN_ENABLED")
  assert(#visible(ns) == 4, "visible " .. #visible(ns))
  assert(not ns.UI.pendingRebuild)
  assert(entryFor(ns, 2383).attrs.spell == 2383)
end)

test("smoke_refresh_in_combat_no_attrs", function()
  local ns = setup(hunter())
  STUB.fire("PLAYER_LOGIN")
  STUB.combat = true
  setActive(1494)
  STUB.fire("MINIMAP_UPDATE_TRACKING")
  assert(TrackerBuddyButton.icon.texture == 1494)
  assert(entryFor(ns, 1494).highlight:IsShown())
  assert(not entryFor(ns, 19883).highlight:IsShown())
  for _, c in ipairs(STUB.attrCalls) do
    assert(not c.combat, "SetAttribute in combat: " .. tostring(c.key))
  end
  assert(TrackerBuddyDB.lastSpellID == 1494)
end)

test("smoke_revive_restores", function()
  setup(hunter(), { lastSpellID = 2580 })
  setActive(nil)
  STUB.fire("PLAYER_LOGIN")
  STUB.dead = false
  STUB.fire("PLAYER_ALIVE")
  local calls = C_Minimap.setTrackingCalls
  assert(#calls == 1, "calls " .. #calls)
  assert(calls[1][1] == 4 and calls[1][2] == true)
end)

test("smoke_revive_in_combat_deferred", function()
  setup(hunter(), { lastSpellID = 2580 })
  setActive(nil)
  STUB.fire("PLAYER_LOGIN")
  STUB.combat = true
  STUB.fire("PLAYER_ALIVE")
  assert(#C_Minimap.setTrackingCalls == 0)
  STUB.combat = false
  STUB.fire("PLAYER_REGEN_ENABLED")
  local calls = C_Minimap.setTrackingCalls
  assert(#calls == 1, "calls " .. #calls)
  assert(calls[1][1] == 4 and calls[1][2] == true)
end)

test("smoke_restore_skipped_when_dead", function()
  setup(hunter(), { lastSpellID = 2580 })
  setActive(nil)
  STUB.fire("PLAYER_LOGIN")
  STUB.dead = true
  STUB.fire("PLAYER_UNGHOST")
  assert(#C_Minimap.setTrackingCalls == 0)
end)

test("smoke_login_in_combat_deferred", function()
  local ns = setup(hunter())
  STUB.combat = true
  STUB.fire("PLAYER_LOGIN")
  assert(#TrackerBuddyButton.points == 0, "no SetPoint in combat")
  assert(#visible(ns) == 0 and ns.UI.pendingRebuild == true)
  STUB.combat = false
  STUB.fire("PLAYER_REGEN_ENABLED")
  assert(select(1, TrackerBuddyButton:GetPoint()) == "CENTER")
  assert(select(5, TrackerBuddyButton:GetPoint()) == -150)
  assert(#visible(ns) == 3)
end)

test("smoke_regen_disabled_arms_all_entries", function()
  local ns = setup(hunter())
  STUB.fire("PLAYER_LOGIN")
  assert(entryFor(ns, 19883).attrs.type == nil)
  STUB.fire("PLAYER_REGEN_DISABLED")
  for _, e in ipairs(visible(ns)) do
    assert(e.attrs.type == "spell", "entry " .. e.spellID)
  end
  STUB.combat = true
  STUB.fire("MINIMAP_UPDATE_TRACKING")
  assert(entryFor(ns, 19883).attrs.type == "spell")
  STUB.combat = false
  STUB.fire("PLAYER_REGEN_ENABLED")
  assert(entryFor(ns, 19883).attrs.type == nil)
  assert(entryFor(ns, 1494).attrs.type == "spell")
end)

local failed = 0
for _, name in ipairs(order) do
  local ok, err = pcall(tests[name])
  if ok then print("PASS " .. name)
  else print("FAIL " .. name .. ": " .. tostring(err)); failed = failed + 1 end
end
if failed > 0 then os.exit(1) end

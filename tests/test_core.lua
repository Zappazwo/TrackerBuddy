-- Minimal test runner for TrackerBuddy Core (plain Lua 5.1)
local ns = {}
local chunk = assert(loadfile("TrackerBuddy/Core.lua"))
chunk("TrackerBuddy", ns)
local Core = ns.Core

local function makeApi(infos)
  return {
    GetNumTrackingTypes = function() return #infos end,
    GetTrackingInfo = function(i) return infos[i] end,
  }
end

local HUNTER = {
  { name = "Track Beasts",    type = "spell", spellID = 1494,  active = false },
  { name = "Auctioneer",      type = "other", active = true },
  { name = "Track Humanoids", type = "spell", spellID = 19883, active = true },
  { name = "Find Minerals",   type = "spell", spellID = 2580,  active = false },
}

local tests = {}
local order = {}
local function test(name, fn) tests[name] = fn; order[#order + 1] = name end

test("test_filters_spells", function()
  local list = Core.GetTrackingSpells(makeApi(HUNTER))
  assert(#list == 3, "count " .. #list)
  assert(list[1].index == 1)
  assert(list[2].index == 3)
  assert(list[3].spellID == 2580)
  assert(list[1].name == "Track Beasts")
  assert(list[2].active == true and list[1].active == false)
end)

test("test_active", function()
  local list = Core.GetTrackingSpells(makeApi(HUNTER))
  assert(Core.GetActive(list).spellID == 19883)
end)

test("test_empty_list", function()
  assert(#Core.GetTrackingSpells(makeApi({})) == 0)
  assert(Core.GetActive({}) == nil)
end)

test("test_nil_info_skipped", function()
  local api = {
    GetNumTrackingTypes = function() return 2 end,
    GetTrackingInfo = function(i)
      if i == 2 then return HUNTER[4] end
      return nil
    end,
  }
  local list = Core.GetTrackingSpells(api)
  assert(#list == 1)
  assert(list[1].index == 2)
end)

test("test_find_index", function()
  local list = Core.GetTrackingSpells(makeApi(HUNTER))
  assert(Core.FindIndexBySpell(list, 2580) == 4)
end)

test("test_find_index_unknown", function()
  local list = Core.GetTrackingSpells(makeApi(HUNTER))
  assert(Core.FindIndexBySpell(list, 2383) == nil)
  assert(Core.FindIndexBySpell(list, nil) == nil)
end)

test("test_cast_type_for_active", function()
  assert(Core.CastTypeFor({ active = true }) == nil)
  assert(Core.CastTypeFor({ active = false }) == "spell")
end)

local failed = 0
for _, name in ipairs(order) do
  local ok, err = pcall(tests[name])
  if ok then print("PASS " .. name)
  else print("FAIL " .. name .. ": " .. tostring(err)); failed = failed + 1 end
end
if failed > 0 then os.exit(1) end

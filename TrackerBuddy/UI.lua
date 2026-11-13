local _, ns = ...
ns = ns or {}

local Core = ns.Core
local UI = { entries = {}, pendingRebuild = false, pendingRestore = false, pendingPosition = false }
ns.UI = UI

local FALLBACK_ICON = 134400
local ENTRY_SIZE, ENTRY_GAP = 32, 4
local HINT = "Shift + Ziehen: verschieben"

local function GetDB()
  TrackerBuddyDB = TrackerBuddyDB or {}
  return TrackerBuddyDB
end

local function ReadList()
  return Core.GetTrackingSpells(C_Minimap)
end

local function AddHint()
  GameTooltip:AddLine(HINT, 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

-- Main button: secure toggle for the list.
local button = CreateFrame("Button", "TrackerBuddyButton", UIParent, "SecureHandlerClickTemplate")
button:SetSize(36, 36)
button:RegisterForClicks("AnyUp")
button.icon = button:CreateTexture(nil, "ARTWORK")
button.icon:SetAllPoints()
button.icon:SetTexture(FALLBACK_ICON)

local list = CreateFrame("Frame", "TrackerBuddyList", button, "SecureHandlerBaseTemplate")
list:SetPoint("BOTTOM", button, "TOP", 0, 4)
list:SetSize(ENTRY_SIZE, ENTRY_SIZE)
list:Hide()

button:SetFrameRef("list", list)
button:SetAttribute("_onclick", [[local l = self:GetFrameRef("list"); if l:IsShown() then l:Hide() else l:Show() end]])

button:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(UI.activeName or "TrackerBuddy – keine Fährte aktiv")
  AddHint()
end)
button:SetScript("OnLeave", function() GameTooltip:Hide() end)

button:SetMovable(true)
button:SetClampedToScreen(true)
button:RegisterForDrag("LeftButton")
button:SetScript("OnDragStart", function(self)
  if IsShiftKeyDown() and not InCombatLockdown() then
    self.isMoving = true
    self:StartMoving()
  end
end)
button:SetScript("OnDragStop", function(self)
  if not self.isMoving then return end
  self.isMoving = nil
  self:StopMovingOrSizing()
  local point, _, relPoint, x, y = self:GetPoint()
  GetDB().point = { point, relPoint, x, y }
end)

local function ApplyPosition()
  if InCombatLockdown() then
    UI.pendingPosition = true
    return
  end
  UI.pendingPosition = false
  local p = GetDB().point
  button:ClearAllPoints()
  if p then
    button:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  else
    button:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
  end
end

local function EntryOnEnter(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetSpellByID(self.spellID)
  AddHint()
end

local function CreateEntry(i)
  local entry = CreateFrame("Button", "TrackerBuddyEntry" .. i, list, "SecureActionButtonTemplate")
  entry:SetSize(ENTRY_SIZE, ENTRY_SIZE)
  entry:RegisterForClicks("AnyUp")
  entry:SetAttribute("useOnKeyDown", false)
  entry.icon = entry:CreateTexture(nil, "ARTWORK")
  entry.icon:SetAllPoints()
  entry.highlight = entry:CreateTexture(nil, "OVERLAY")
  entry.highlight:SetAllPoints()
  entry.highlight:SetTexture("Interface\\Buttons\\CheckButtonHilight")
  entry.highlight:SetBlendMode("ADD")
  entry.highlight:Hide()
  entry:SetScript("OnEnter", EntryOnEnter)
  entry:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- Post-body runs in the list's restricted environment: close after the cast.
  list:WrapScript(entry, "OnClick", "", "owner:Hide()")
  return entry
end

-- Texture-only updates are combat-safe; attributes only change out of combat.
function UI.Refresh()
  local spells = ReadList()
  local active = Core.GetActive(spells)
  UI.activeName = active and active.name or nil
  button.icon:SetTexture(active and C_Spell.GetSpellTexture(active.spellID) or FALLBACK_ICON)

  local bySpell = {}
  for _, s in ipairs(spells) do bySpell[s.spellID] = s end
  local inCombat = InCombatLockdown()
  for _, entry in ipairs(UI.entries) do
    local s = entry.spellID and bySpell[entry.spellID]
    entry.highlight:SetShown(s and s.active or false)
    if s and not inCombat then
      entry:SetAttribute("type", Core.CastTypeFor(s))
    end
  end
  return active
end

function UI.Rebuild()
  if InCombatLockdown() then
    UI.pendingRebuild = true
    return
  end
  UI.pendingRebuild = false
  local spells = ReadList()
  for i, s in ipairs(spells) do
    local entry = UI.entries[i] or CreateEntry(i)
    UI.entries[i] = entry
    entry.spellID = s.spellID
    entry:SetAttribute("spell", s.spellID)
    entry.icon:SetTexture(C_Spell.GetSpellTexture(s.spellID) or FALLBACK_ICON)
    entry:ClearAllPoints()
    entry:SetPoint("BOTTOM", list, "BOTTOM", 0, (i - 1) * (ENTRY_SIZE + ENTRY_GAP))
    entry:Show()
  end
  for i = #spells + 1, #UI.entries do
    local entry = UI.entries[i]
    entry.spellID = nil
    entry:SetAttribute("type", nil)
    entry:Hide()
  end
  list:SetHeight(math.max(1, #spells * (ENTRY_SIZE + ENTRY_GAP) - ENTRY_GAP))
  UI.Refresh()
end

function UI.Restore()
  if UnitIsDeadOrGhost("player") then return end
  if InCombatLockdown() then
    UI.pendingRestore = true
    return
  end
  UI.pendingRestore = false
  local spells = ReadList()
  if Core.GetActive(spells) then return end
  local index = Core.FindIndexBySpell(spells, GetDB().lastSpellID)
  if index then C_Minimap.SetTracking(index, true) end
end

function UI.OnEvent(event, ...)
  if event == "PLAYER_LOGIN" then
    GetDB()
    ApplyPosition()
    UI.Rebuild()
  elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_SKILL_LINE" then
    UI.Rebuild()
  elseif event == "MINIMAP_UPDATE_TRACKING" then
    local active = UI.Refresh()
    if active then GetDB().lastSpellID = active.spellID end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if UI.pendingPosition then ApplyPosition() end
    if UI.pendingRebuild then UI.Rebuild() else UI.Refresh() end
    if UI.pendingRestore then UI.Restore() end
  elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
    UI.Restore()
  end
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE",
                     "MINIMAP_UPDATE_TRACKING", "PLAYER_REGEN_ENABLED",
                     "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
  events:RegisterEvent(e)
end
events:SetScript("OnEvent", function(_, event, ...) UI.OnEvent(event, ...) end)

return ns

-- Minimal WoW API fakes for the UI smoke tests (plain Lua 5.1).
-- Loading this file resets all fake state.
STUB = { combat = false, dead = false, shift = false, frames = {}, attrCalls = {} }

local NOOPS = {
  "SetSize", "SetWidth", "SetHeight", "SetAllPoints", "ClearAllPoints",
  "RegisterForClicks", "RegisterForDrag", "SetMovable", "SetClampedToScreen",
  "StartMoving", "StopMovingOrSizing", "SetFrameRef", "WrapScript",
  "SetBlendMode", "SetDrawLayer", "SetTexCoord", "SetVertexColor",
}

local function makeObject(kind, name, parent)
  local obj = { kind = kind, name = name, parent = parent, shown = true,
                attrs = {}, scripts = {}, events = {}, points = {} }
  for _, m in ipairs(NOOPS) do obj[m] = function() end end
  function obj:Show() self.shown = true end
  function obj:Hide() self.shown = false end
  function obj:IsShown() return self.shown end
  function obj:SetShown(v) self.shown = v and true or false end
  function obj:SetAttribute(k, v)
    self.attrs[k] = v
    STUB.attrCalls[#STUB.attrCalls + 1] = { obj = self, key = k, value = v, combat = STUB.combat }
  end
  function obj:GetAttribute(k) return self.attrs[k] end
  function obj:SetScript(n, fn) self.scripts[n] = fn end
  function obj:GetScript(n) return self.scripts[n] end
  function obj:RegisterEvent(e) self.events[e] = true end
  function obj:SetPoint(...) self.points[#self.points + 1] = { ... } end
  function obj:GetPoint()
    local p = self.points[#self.points]
    if p then return unpack(p) end
  end
  function obj:CreateTexture()
    local tex = makeObject("Texture", nil, obj)
    function tex:SetTexture(t) self.texture = t end
    return tex
  end
  return obj
end

function CreateFrame(kind, name, parent, template)
  local f = makeObject(kind, name, parent)
  f.template = template
  STUB.frames[#STUB.frames + 1] = f
  if name then _G[name] = f end
  return f
end

-- Delivers an event to every fake frame that registered it.
function STUB.fire(event, ...)
  for _, f in ipairs(STUB.frames) do
    if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
  end
end

UIParent = makeObject("Frame", "UIParent")
GameTooltip = makeObject("GameTooltip", "GameTooltip")
GameTooltip.SetOwner = function() end
GameTooltip.SetText = function() end
GameTooltip.AddLine = function() end
GameTooltip.SetSpellByID = function() end

C_Minimap = { infos = {}, setTrackingCalls = {} }
function C_Minimap.GetNumTrackingTypes() return #C_Minimap.infos end
function C_Minimap.GetTrackingInfo(i) return C_Minimap.infos[i] end
function C_Minimap.SetTracking(i, on)
  C_Minimap.setTrackingCalls[#C_Minimap.setTrackingCalls + 1] = { i, on }
end

C_Spell = { GetSpellTexture = function(id) return id end }

function InCombatLockdown() return STUB.combat end
function UnitIsDeadOrGhost() return STUB.dead end
function IsShiftKeyDown() return STUB.shift end

TrackerBuddyDB = nil

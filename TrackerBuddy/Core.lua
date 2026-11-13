local _, ns = ...
ns = ns or {}

local Core = {}
ns.Core = Core

-- api = { GetNumTrackingTypes = fn, GetTrackingInfo = fn(i) -> info|nil }
-- Returns spell-type tracking entries in C_Minimap order.
function Core.GetTrackingSpells(api)
  local list = {}
  for i = 1, api.GetNumTrackingTypes() do
    local info = api.GetTrackingInfo(i)
    if info and info.type == "spell" and info.spellID then
      list[#list + 1] = {
        index = i,
        name = info.name,
        spellID = info.spellID,
        active = info.active and true or false,
      }
    end
  end
  return list
end

function Core.GetActive(list)
  for _, entry in ipairs(list) do
    if entry.active then return entry end
  end
  return nil
end

function Core.FindIndexBySpell(list, spellID)
  if not spellID then return nil end
  for _, entry in ipairs(list) do
    if entry.spellID == spellID then return entry.index end
  end
  return nil
end

-- Active tracking is already on, so no cast is needed.
function Core.CastTypeFor(entry)
  if entry.active then return nil end
  return "spell"
end

return ns

# TrackerBuddy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A WoW: Forever addon with one button that shows the active tracking ability and opens a list of all known tracking spells. Switching works in combat too.

**Architecture:** `Core.lua` holds pure logic with no frames and gets the WoW API injected, so it can be tested with plain Lua. `UI.lua` builds the secure frames: a `SecureHandlerClickTemplate` main button that toggles the list, plus one `SecureActionButtonTemplate` entry per spell. It reads state via `C_Minimap` and casts by spell ID.

**Tech Stack:** Lua 5.1 (WoW dialect), WoW: Forever 1.60.1 API (`C_Minimap`, `C_Spell`, Secure templates); tests with `lua5.1` and stubs.

**Spec:** `docs/superpowers/specs/2026-11-13-trackerbuddy-design.md`

## Global Constraints

- `## Interface: 16001`; addon folder and name `TrackerBuddy`.
- SavedVariablesPerCharacter: `TrackerBuddyDB` = `{ point = {point, relPoint, x, y}, lastSpellID = number|nil }`.
- Only `C_Minimap` entries with `type == "spell"` go in the list.
- No calls to protected functions (`Show/Hide/SetAttribute/SetPoint` on secure frames) while `InCombatLockdown()` is true. In combat only `_onclick` snippets and textures change.
- No modern globals that might be missing without fallback: icons via `C_Spell.GetSpellTexture(spellID)`, fallback icon `134400` (question mark).
- Code-Struktur: The spec says "TrackerBuddy.lua". Claude's call: split into `Core.lua` (testable) and `UI.lua`. Allowed by the spec ("Code-Struktur … dem Builder überlassen").

## Review Focus

1. **Character knows no tracking spell** (e.g. low-level non-hunter): button shows fallback icon, click opens an empty list, no error. → Task 1 test `test_empty_list`, Task 2 smoke `smoke_no_spells`.
2. **Clicking the already active tracking out of combat** must not turn it off → active entry gets `type` attribute `nil` on rebuild/update out of combat. Task 1 test `test_cast_type_for_active`.
3. **`SPELLS_CHANGED` / tracking update arrives in combat**: no rebuild of secure frames, rebuild deferred to `PLAYER_REGEN_ENABLED`. Task 2 smoke `smoke_rebuild_deferred_in_combat`.
4. **Saved last spell no longer known** (e.g. profession dropped): revive restore does nothing, no error. Task 1 test `test_find_index_unknown`.
5. **`C_Minimap.GetTrackingInfo` returns nil for an index** (list changed between calls): skipped, no error. Task 1 test `test_nil_info_skipped`.

---

### Task 1: Core logic, TOC, and test runner

**Files:**
- Create: `TrackerBuddy/TrackerBuddy.toc`
- Create: `TrackerBuddy/Core.lua`
- Create: `tests/test_core.lua`
- Create: `tests/run.sh`

**Interfaces:**
- Produces (on the addon namespace `ns`, second vararg of each file):
  - `ns.Core.GetTrackingSpells(api) -> list` where `api = { GetNumTrackingTypes = fn, GetTrackingInfo = fn(i) -> info|nil }` and `list` is an array of `{ index = number, name = string, spellID = number, active = boolean }` in `C_Minimap` order, only `type == "spell"` entries with a `spellID`.
  - `ns.Core.GetActive(list) -> entry|nil`
  - `ns.Core.FindIndexBySpell(list, spellID) -> number|nil` (returns the `C_Minimap` index)
  - `ns.Core.CastTypeFor(entry) -> "spell"|nil` (nil when `entry.active`)
- `Core.lua` must also load in plain Lua: `local _, ns = ...; ns = ns or {}` and `return ns` at the end so tests can `dofile`-style load via `loadfile(path)("TrackerBuddy", ns)`.

- [ ] **Step 1: Write the failing tests in `tests/test_core.lua`**

Minimal runner (no framework): each test is a function in a table, run with `pcall`, prints `PASS name`/`FAIL name: err`, exits `os.exit(1)` on any failure. Stub helper `makeApi(infos)` returns `GetNumTrackingTypes = #infos` and `GetTrackingInfo(i) = infos[i]`.

```lua
-- infos used by several tests
local HUNTER = {
  { name = "Track Beasts",    type = "spell", spellID = 1494,  active = false },
  { name = "Auctioneer",      type = "other", active = true },
  { name = "Track Humanoids", type = "spell", spellID = 19883, active = true },
  { name = "Find Minerals",   type = "spell", spellID = 2580,  active = false },
}
test_filters_spells:      #list == 3; list[1].index == 1; list[2].index == 3; list[3].spellID == 2580
test_active:              Core.GetActive(list).spellID == 19883
test_empty_list:          #Core.GetTrackingSpells(makeApi({})) == 0; Core.GetActive({}) == nil
test_nil_info_skipped:    api with GetNumTrackingTypes=2, GetTrackingInfo(1)=nil, (2)=Find Minerals -> #list == 1, list[1].index == 2
test_find_index:          Core.FindIndexBySpell(list, 2580) == 4
test_find_index_unknown:  Core.FindIndexBySpell(list, 2383) == nil; Core.FindIndexBySpell(list, nil) == nil
test_cast_type_for_active: Core.CastTypeFor({active=true}) == nil; Core.CastTypeFor({active=false}) == "spell"
```

- [ ] **Step 2: Create `tests/run.sh`**

Runs `luac5.1 -p` on every `TrackerBuddy/*.lua`, then `lua5.1 tests/test_core.lua` (and later `tests/test_ui_smoke.lua` if present). Exit non-zero on any failure. Run from repo root.

- [ ] **Step 3: Run to verify it fails**

Run: `bash tests/run.sh`
Expected: FAIL (Core.lua missing).

- [ ] **Step 4: Create `TrackerBuddy/TrackerBuddy.toc`**

```
## Interface: 16001
## Title: TrackerBuddy
## Notes: One button for all tracking abilities
## Author: Patrick
## Version: 0.1.0
## SavedVariablesPerCharacter: TrackerBuddyDB

Core.lua
UI.lua
```

- [ ] **Step 5: Implement the four functions in `TrackerBuddy/Core.lua`**

- [ ] **Step 6: Run to verify it passes**

Run: `bash tests/run.sh`
Expected: all `PASS`, exit 0. (UI.lua is not there yet; `run.sh` only checks files that exist.)

- [ ] **Step 7: Commit**

```bash
git add TrackerBuddy tests
git commit -m "feat: core tracking logic with tests"
```

---

### Task 2: UI with secure button, list, events, revive restore

**Files:**
- Create: `TrackerBuddy/UI.lua`
- Create: `tests/wow_stubs.lua`
- Create: `tests/test_ui_smoke.lua`
- Modify: `tests/run.sh` (run smoke test)

**Interfaces:**
- Consumes: `ns.Core.*` from Task 1.
- Produces: global frame `TrackerBuddyButton` (main button) and `TrackerBuddyList` (list frame). Internal functions on `ns.UI`, so the smoke test can call them:
  - `ns.UI.Rebuild()` – out of combat: reads list, creates/reuses entry buttons, sets `type`/`spell` attributes, lays them out; in combat: sets `ns.UI.pendingRebuild = true` and returns.
  - `ns.UI.Refresh()` – updates main icon and highlights (texture-only, combat-safe); out of combat also refreshes the `type` attribute per entry via `Core.CastTypeFor`.
  - `ns.UI.OnEvent(event, ...)` – dispatcher.

Behavior to build (values from the spec):
- Main button 36×36, `SecureHandlerClickTemplate`, `RegisterForClicks("AnyUp")`. `SetFrameRef("list", list)`; `_onclick` snippet: `local l = self:GetFrameRef("list"); if l:IsShown() then l:Hide() else l:Show() end`.
- List frame: `SecureHandlerBaseTemplate`, hidden at start, anchored `BOTTOM` to main button `TOP`, offset y 4. Entries 32×32, stacked upwards with 4 px gap.
- Entries: `SecureActionButtonTemplate`, `RegisterForClicks("AnyUp", "AnyDown")`, attribute `spell = spellID`, `type = Core.CastTypeFor(entry)`. Close after click: `list:WrapScript(entry, "OnClick", "", "owner:Hide()")` with the list as the wrapping handler (post-body hides it).
- Highlight active entry: a gold border texture (`Interface\\Buttons\\CheckButtonHilight`, ADD blend) shown only when active.
- Tooltips: `OnEnter` → `GameTooltip:SetOwner(self, "ANCHOR_RIGHT")`; `GameTooltip:SetSpellByID(spellID)` for entries; main button shows active name or "TrackerBuddy – keine Fährte aktiv"; plus a grey line "Shift + Ziehen: verschieben".
- Move: `SetMovable(true)`, `RegisterForDrag("LeftButton")`; `OnDragStart` only if `IsShiftKeyDown()` and not `InCombatLockdown()`; `OnDragStop` saves `GetPoint()` into `TrackerBuddyDB.point`. Default position: `CENTER, UIParent, CENTER, 0, -150`.
- Events: `PLAYER_LOGIN` (init DB, position, Rebuild), `SPELLS_CHANGED` and `LEARNED_SPELL_IN_SKILL_LINE` (Rebuild), `MINIMAP_UPDATE_TRACKING` (Refresh; also store `TrackerBuddyDB.lastSpellID` = active spellID when one is active), `PLAYER_REGEN_ENABLED` (Rebuild if pending, restore if pending), `PLAYER_ALIVE` and `PLAYER_UNGHOST` (restore).
- Restore: if `UnitIsDeadOrGhost("player")` → do nothing; if in combat → `pendingRestore = true`; else if no tracking is active and `FindIndexBySpell(list, db.lastSpellID)` gives an index → `C_Minimap.SetTracking(index, true)`.

- [ ] **Step 1: Write `tests/wow_stubs.lua`**

Global fakes: `CreateFrame(type, name, parent, template)` returns a mock object whose unknown methods are no-ops (metatable `__index` returning a no-op function) but records `SetAttribute(k, v)` into `obj.attrs`, `Show/Hide/IsShown`, `SetScript(name, fn)` into `obj.scripts`, `CreateTexture()` returning a mock with `SetTexture` recording `obj.texture`; register named frames in `_G`. Also `UIParent`, `GameTooltip`, `C_Minimap` (with a mutable `infos` table and `SetTracking` that records calls), `C_Spell.GetSpellTexture = function(id) return id end`, `InCombatLockdown` reading a mutable `STUB.combat`, `UnitIsDeadOrGhost` reading `STUB.dead`, `IsShiftKeyDown`.

- [ ] **Step 2: Write `tests/test_ui_smoke.lua` with these tests (runner like Task 1; loads stubs, then Core.lua and UI.lua with the same `ns`)**

```lua
smoke_login_builds:             infos=HUNTER; fire PLAYER_LOGIN -> 3 entries, entry for 19883 has attrs.type == nil, entry for 1494 attrs.type == "spell", attrs.spell == 1494; TrackerBuddyButton icon texture == 19883
smoke_no_spells:                infos={}; fire PLAYER_LOGIN -> no error, main icon == 134400
smoke_rebuild_deferred_in_combat: STUB.combat=true; add Find Herbs; fire SPELLS_CHANGED -> still 3 visible entries, ns.UI.pendingRebuild == true; STUB.combat=false; fire PLAYER_REGEN_ENABLED -> 4 entries
smoke_refresh_in_combat_no_attrs: STUB.combat=true; switch active to 1494; fire MINIMAP_UPDATE_TRACKING -> main icon == 1494, no SetAttribute call recorded during combat
smoke_revive_restores:          db.lastSpellID=2580; all infos inactive; STUB.dead=false; fire PLAYER_ALIVE -> C_Minimap.SetTracking called with (4, true)
smoke_revive_in_combat_deferred: same, STUB.combat=true -> no SetTracking; combat ends, PLAYER_REGEN_ENABLED -> SetTracking(4, true)
```

- [ ] **Step 3: Add the smoke test to `tests/run.sh` and run it**

Run: `bash tests/run.sh`
Expected: FAIL (UI.lua missing).

- [ ] **Step 4: Implement `TrackerBuddy/UI.lua` as specified above**

- [ ] **Step 5: Run to verify it passes**

Run: `bash tests/run.sh`
Expected: all PASS, exit 0.

- [ ] **Step 6: Commit**

```bash
git add TrackerBuddy tests
git commit -m "feat: secure tracking button and list"
```

---

### Task 3: README and in-game test checklist

**Files:**
- Create: `README.md` (German)

- [ ] **Step 1: Write `README.md`**

Sections: what it does (2–3 sentences), installation (copy the `TrackerBuddy` folder into `World of Warcraft\_forever_\Interface\AddOns\`; note: check the folder name of the Forever install, it is the one next to `_classic_era_`), usage (click, choose, Shift-drag), known limits (clicking the active tracking in combat may turn it off), in-game test checklist from the spec as checkboxes:
- List opens/closes out of combat and in combat
- Switch tracking out of combat and in combat
- Icon updates after switching
- Find Minerals / Find Herbs appear if learned
- Clicking the active entry out of combat keeps it on
- Position stays after `/reload`
- After death + resurrection, the last tracking comes back
- No Lua errors (`/console scriptErrors 1`)

- [ ] **Step 2: Run `bash tests/run.sh` once more**

Expected: all PASS.

- [ ] **Step 3: Commit and push**

```bash
git add README.md
git commit -m "docs: README with install and test checklist"
git push origin dev
```

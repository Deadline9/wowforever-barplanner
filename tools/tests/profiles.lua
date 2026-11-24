-- Exercise the saved database, game event handler and Check/Apply/Revert entry points.
local w, BP, P
local unpack = table.unpack or unpack
local passed, failed = 0, 0
local function char() return w.players[w.guid] end
local ids = { Thorns = 1, Barkskin = 2, Dash = 3, Prowl = 4, Wrath = 5 }
local function spell(slot, id) char().slots[slot] = { "spell", id } end
local function idAt(slot) return char().slots[slot] and char().slots[slot][2] end

UnitGUID = function() return w.guid end
UnitName = function() return "Seren" end -- even the readable names can match
GetRealmName = function() return char().realm end
UnitClass = function() return char().class, char().class end
InCombatLockdown = function() return w.combat end
IsPlayerSpell = function(id) return char().known[id] end
GetSpellInfo = function(value)
    if ids[value] then return value, nil, nil, nil, nil, nil, ids[value] end
    for name, id in pairs(ids) do if id == value then return name end end
end

local function macroList(character)
    local list = {}
    for name, m in pairs(w.macros) do if m.perChar == character then table.insert(list, name) end end
    table.sort(list)
    return list
end
GetNumMacros = function() return #macroList(false), #macroList(true) end
GetMacroIndexByName = function(name)
    for _, perChar in ipairs({ false, true }) do
        for i, n in ipairs(macroList(perChar)) do if n == name then return (perChar and 120 or 0) + i end end
    end
    return 0
end
GetMacroInfo = function(i)
    local name = macroList(i > 120)[i > 120 and i - 120 or i]
    if name then return name, w.macros[name].icon, w.macros[name].body end
end
CreateMacro = function(n, icon, body, perChar)
    w.macros[n] = { icon = tonumber(icon) or 134400, body = body, perChar = perChar }
    return GetMacroIndexByName(n)
end
EditMacro = function(i, n, icon, body)
    assert(GetMacroInfo(i) == n)
    w.macros[n].icon, w.macros[n].body = icon, body
end
DeleteMacro = function(i) w.macros[GetMacroInfo(i)] = nil end
GetActionInfo = function(s)
    local a = char().slots[s]
    if a and a[1] == "macro" then
        if w.macroActionID then return "macro", w.macroActionID, "item" end
        return "macro", GetMacroIndexByName(a[2])
    end
    if a then return a[1], a[2] end
end
GetActionText = function(slot)
    local a = char().slots[slot]
    if a and a[1] == "macro" then return a[2] end
end
HasAction = function(s) return char().slots[s] ~= nil end
GetCursorInfo = function()
    if w.cursor then
        if w.cursor[1] == "macro" then return "macro", GetMacroIndexByName(w.cursor[2]) end
        return unpack(w.cursor)
    end
end
ClearCursor = function() w.cursor = nil end
PickupAction = function(s) w.cursor, char().slots[s] = char().slots[s], nil end
PickupSpell = function(id) if IsPlayerSpell(id) then w.cursor = { "spell", id } end end
PickupMacro = function(i) w.cursor = { "macro", assert(GetMacroInfo(i)) } end
PlaceAction = function(s)
    if w.rejectSlot ~= s then char().slots[s], w.cursor = w.cursor, char().slots[s] end
end
GetCurrentBindingSet = function() return w.scope end
local registry = { "RUN", "PACK", "BUTTON" }
GetNumBindings = function() return #registry end
GetBindingKey = function(cmd)
    local list = {}
    for k, v in pairs(w.keys) do if v == cmd then table.insert(list, k) end end
    table.sort(list)
    return unpack(list)
end
GetBinding = function(i) return registry[i], "Tests", GetBindingKey(registry[i]) end
GetBindingAction = function(k, override) return (override and w.overrides[k]) or w.keys[k] or "" end
SetBinding = function(k, cmd) w.keys[k] = cmd; return true end
SaveBindings = function(set) assert(set == w.scope); w.saves = w.saves + 1 end
LoadBindings = function() error("Unexpected binding-set change") end
CreateFrame = function()
    local f = { RegisterEvent = function() end }
    function f:SetScript(_, fn) w.event = function(event, arg) fn(self, event, arg) end end
    return f
end
C_Timer = { After = function(_, fn) w.timer = fn end }
StaticPopupDialogs, SlashCmdList = {}, {}
StaticPopup_Show = function(key, msg) assert(key == "BARSMITH_LEVEL_UPDATES"); table.insert(w.prompts, msg) end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) table.insert(w.chat, msg) end }
local function reload()
    Barsmith = {}
    for _, file in ipairs({ "Bindings", "Profiles", "Changes", "Barsmith" }) do
        dofile("addon/Barsmith/" .. file .. ".lua")
    end
    BP, P = Barsmith, Barsmith.profiles
    w.event("ADDON_LOADED", "Barsmith")
end
local function event(e)
    w.event(e or "SPELLS_CHANGED")
    if w.timer then local fn = w.timer; w.timer = nil; fn() end
end
local function test(name, fn)
    w = { guid = "Player-A", scope = 2, keys = { R = "RUN", NUMLOCK = "RUN", B = "PACK" },
        overrides = {}, saves = 0, macros = {}, players = {}, chat = {}, prompts = {} }
    for _, guid in ipairs({ "Player-A", "Player-B", "Player-C" }) do
        w.players[guid] = { realm = guid, class = guid == "Player-C" and "PRIEST" or "DRUID",
            slots = {}, known = { [1] = true, [5] = true } }
    end
    BarsmithDB = nil
    reload()
    local ok, err = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1; print(name, err) end
end
local function plan(records)
    return "BP2:" .. BP.b64encode("BARPLAN\t2\n" .. records)
end
local function has(lines, msg)
    local text = table.concat(lines, "\n")
    assert(text:find(msg, 1, true), text .. " (expected " .. msg .. ")")
end
local function apply(text)
    has(BP.run(text, true), "Check OK")
    has(BP.run(text, false), "Done:")
end
local function revert()
    has(BP.revert(false), "Revert last Apply?")
    has(BP.revert(true), "Reverted the last Apply")
end

test("GUID isolation across login and reload", function()
    local text = plan("SLOT\t1\tspell\tDash")
    apply(text)
    assert(P.active().pending[1])
    for _, guid in ipairs({ "Player-B", "Player-C" }) do
        w.guid = guid
        reload()
        char().known[3] = true
        event("PLAYER_ENTERING_WORLD")
        local p, c = P.active()
        assert(not p.lastApplied and not p.text and not idAt(1) and c.realm == guid and c.name == "Seren")
    end
    w.guid = "Player-A"
    reload()
    char().known[3] = true
    event("PLAYER_ENTERING_WORLD")
    assert(idAt(1) == 3 and not idAt(109) and P.active().text == text)
end)

test("migration is unclaimed even on a matching class", function()
    local text = plan("CLASS\tDRUID\nSLOT\t1\tspell\tThorns")
    BarsmithDB = { last = text, auto = false }
    reload()
    assert(not BarsmithDB.last and BarsmithDB.legacyPlan == text and not BarsmithDB.auto)
    BarsmithDB.auto = true
    for _, guid in ipairs({ "Player-A", "Player-B" }) do
        w.guid = guid
        event("PLAYER_ENTERING_WORLD")
        assert(not P.active().text and not idAt(1))
    end
    local legacy = BarsmithDB.legacyPlan
    has(BP.run(legacy, false), "Run Check")
    assert(BarsmithDB.legacyPlan == text)
    apply(legacy)
    assert(P.active().lastApplied == legacy and P.active().text == text and not BarsmithDB.legacyPlan and idAt(1) == 1)
    w.guid = "Player-A"
    reload()
    assert(not P.active().text)
end)

test("named drafts, selection, duplication, deletion and invalidated checks", function()
    local text = plan("SLOT\t1\tspell\tThorns\nENSURE\tR\tBUTTON")
    assert(P.manage("create", "Solo", text))
    local solo, c = P.active()
    event()
    assert(not idAt(1) and c.active == "Solo" and not solo.pending and w.keys.R == "RUN")
    assert(P.manage("duplicate", "Healing"))
    assert(P.active() ~= solo and P.active().text == text)
    assert(P.manage("rename", "Healing party"))
    assert(not P.manage("rename", "Solo"))
    BP.run(text, true)
    assert(P.manage("select", "Solo"))
    has(BP.run(text, false), "Run Check")
    apply(text)
    assert(solo.undo and solo.pending)
    assert(P.manage("duplicate", "Copy") and not P.active().undo and not P.active().pending)
    assert(P.manage("select", "Healing party") and P.manage("delete"))
    assert(not c.profiles["Healing party"] and w.keys.NUMLOCK == "RUN")
    reload()
    assert(P.active() == c.profiles[c.active] and w.scope == 2 and w.saves == 1)
end)

test("applied input is independent of draft, profile name and character", function()
    local a = " " .. plan("SLOT\t1\tspell\tWrath") .. "\n"
    local b = plan("SLOT\t2\tspell\tThorns")
    assert(P.manage("create", "A", a) and not P.active().lastApplied)
    apply(a)
    assert(P.manage("duplicate", "B") and not P.active().lastApplied)
    apply(b)
    assert(P.manage("rename", "Renamed") and P.active().lastApplied == b)
    assert(P.manage("select", "A") and P.active().lastApplied == a)
    w.guid = "Player-B"
    reload()
    assert(not P.active().lastApplied)
    assert(P.copyFrom("Player-A", "A") and not P.active().lastApplied)
    apply(b)
    w.guid = "Player-A"
    reload()
    assert(P.active().lastApplied == a)
    has(BP.run(b, false), "Run Check")
    assert(P.active().lastApplied == a)
    local change = plan("SLOT\t2\tspell\tWrath")
    has(BP.run(change, true), "Check OK")
    w.rejectSlot = 2
    has(BP.run(change, false), "Previous state restored")
    assert(P.active().lastApplied == a)
end)

test("no-op records verbatim input and Revert leaves application history accessible", function()
    local text = plan("SLOT\t1\tspell\tWrath")
    apply(text)
    local undo = P.active().undo
    local exact = "  " .. text .. "\n"
    apply(exact)
    assert(P.active().undo == undo and P.active().lastApplied == exact)
    revert()
    assert(not P.active().text and not idAt(1) and P.active().lastApplied == exact)
end)

test("interrupted legacy migration preserves both distinct unowned strings", function()
    local older, newer = plan("NAME\tOlder"), plan("NAME\tNewer")
    BarsmithDB = { legacyPlan = older, last = newer }
    reload()
    assert(BarsmithDB.legacyPlan == older and BarsmithDB.last == newer and not P.active().lastApplied)
    apply(older)
    reload()
    assert(BarsmithDB.legacyPlan == newer and not BarsmithDB.last and P.active().lastApplied == older)
end)

test("future empty fill and colliding batch, postpone and approve", function()
    spell(1, 1); spell(3, 5); spell(109, 5)
    local text = plan("SLOT\t1\tspell\tBarkskin\nSLOT\t2\tspell\tDash\nSLOT\t3\tspell\tProwl")
    local summary, _, details = BP.run(text, true)
    has(summary, "2 occupied slots have future replacements")
    has(details, "Thorns (spell 1) -> Barkskin")
    has(BP.run(text, false), "Done:")
    for _, id in ipairs({ 2, 3, 4 }) do char().known[id] = true end
    event()
    assert(idAt(1) == 1 and idAt(2) == 3 and idAt(3) == 5 and idAt(109) == 5)
    has(w.prompts, "2 newly available")
    event(); event()
    assert(#w.prompts == 1)
    BP.levelUpdates("review")
    assert(idAt(1) == 1 and idAt(3) == 5)
    BP.levelUpdates("confirm")
    assert(idAt(1) == 2 and idAt(3) == 4 and not next(P.active().pending))
    spell(1, 5); P.active().overwrite = true; event()
    assert(idAt(1) == 5 and idAt(109) == 5)
end)

test("overwrite policy survives reload, combat and same-class alt", function()
    spell(1, 1); spell(2, 1); spell(109, 1)
    apply(plan("SLOT\t1\tspell\tDash\nSLOT\t2\tspell\tBarkskin"))
    P.active().overwrite = true
    char().known[2], char().known[3], w.combat = true, true, true
    reload()
    event()
    assert(idAt(1) == 1 and idAt(2) == 1 and #w.prompts == 0)
    w.combat = false
    event("PLAYER_REGEN_ENABLED")
    assert(idAt(1) == 3 and idAt(2) == 2 and idAt(109) == 1 and #w.prompts == 0)
    w.guid = "Player-B"
    assert(not P.active().overwrite and not P.active().text)
end)

test("40 replacements get one prompt and one approval", function()
    local records = {}
    for slot = 1, 40 do
        spell(slot, 1)
        records[slot] = "SLOT\t" .. slot .. "\tspell\tDash"
    end
    apply(plan(table.concat(records, "\n")))
    char().known[3] = true
    event()
    assert(#w.prompts == 1)
    has(w.prompts, "40 newly available")
    BP.levelUpdates("review"); BP.levelUpdates("confirm")
    for slot = 1, 40 do assert(idAt(slot) == 3) end
end)

test("stale leveling batches never partially execute", function()
    spell(1, 1); spell(2, 1)
    apply(plan("SLOT\t1\tspell\tDash\nSLOT\t2\tspell\tDash"))
    char().known[3] = true
    event(); BP.levelUpdates("review"); spell(2, 5); BP.levelUpdates("confirm")
    assert(idAt(1) == 1 and idAt(2) == 5)
    has(w.chat, "replacements changed")
    BP.levelUpdates("review")
    assert(P.manage("duplicate", "Other"))
    BP.levelUpdates("confirm")
    assert(idAt(1) == 1 and idAt(2) == 5)
end)

test("manual overwrite counts, details and stale slot preflight", function()
    spell(1, 1); spell(2, 1)
    local text = plan("SLOT\t1\tspell\tWrath\nSLOT\t2\tclear\t\nENSURE\tB\tBUTTON")
    local summary, _, details = BP.run(text, true)
    has(summary, "2 occupied slots will be replaced now")
    has(details, "Thorns (spell 1) -> spell Wrath")
    spell(2, 5)
    has(BP.run(text, false), "Run Check again")
    assert(idAt(1) == 1 and idAt(2) == 5 and w.keys.B == "PACK" and w.saves == 0)
    apply(text)
    assert(idAt(1) == 5 and not idAt(2) and w.keys.B == "BUTTON")
end)

test("a character macro placed on slot 54 survives immediate Check, Apply and Revert", function()
    local body = "#showtooltip\n/use 13"
    local text = BP.serialize({ macros = {{name = "Seren T13", perChar = true, body = body}},
        slots = {{ slot = 54, kind = "macro", value = "Seren T13" }} })
    -- Even an action ID that coincides with a real, unrelated account macro is unsafe.
    w.macroActionID = CreateMacro("Shared", 42, "/dance", false)
    apply(text)
    local undo = P.active().undo
    local summary, full = BP.run(text, true)
    has(summary, "Check OK")
    has(full, "0 to fill, 0 to clear, 1 already right")
    has(BP.run(text, false), "Done: 0 slots filled, 1 already right")
    assert(idAt(54) == "Seren T13" and P.active().undo == undo)
    local exported = assert(BP.parse(BP.exportCurrent()))
    local m = exported.macros[1]
    assert(#exported.macros == 1 and m.name == "Seren T13" and m.perChar and m.body == body)
    reload()
    char().slots[55] = { "macro", "Seren T13" }
    has(BP.revert(false), "is now used on")
    char().slots[55] = nil
    revert()
    assert(not idAt(54) and not w.macros["Seren T13"] and w.macros.Shared)
end)

test("unresolved and ambiguous slot macros block Check even when the action ID looks valid", function()
    w.macroActionID = CreateMacro("Shared", 42, "/dance", false)
    local text = plan("SLOT\t54\tclear\t")
    char().slots[54] = { "macro" }
    has(BP.run(text, true), "Cannot identify macro on slot 54")
    char().slots[54] = { "macro", "Unknown" }
    has(BP.run(text, true), "Cannot identify macro on slot 54")
    char().slots[54] = { "macro", "Shared" }
    CreateMacro("SHARED", 43, "/wave", true)
    has(BP.run(text, true), "Ambiguous macro name")
    has(BP.run(text, false), "Run Check")
    assert(idAt(54) == "Shared" and not P.active().undo)
end)

test("changing a macro slot after Check is detected even if the action ID stays the same", function()
    CreateMacro("Shared", 42, "/dance", false)
    w.macroActionID = CreateMacro("Local", 43, "/wave", true)
    char().slots[54] = { "macro", "Shared" }
    local text = plan("SLOT\t54\tclear\t")
    local before = BP.changes.slot(54)
    assert(before.name == "Shared" and before.perChar == false)
    has(BP.run(text, true), "Check OK")
    char().slots[54] = { "macro", "Local" }
    has(BP.run(text, false), "Run Check again.")
    assert(idAt(54) == "Local" and not P.active().undo)
end)

local mixed = "MACRO\tAAA\t\t1\t/cast Dash\nMACRO\tZZZ\t15\t1\t/cast Wrath\n"
    .. "SLOT\t1\tmacro\tAAA\nSLOT\t2\tclear\t\nENSURE\tR\tBUTTON\nREMOVE\tB\tPACK"
local function mixedApply()
    CreateMacro("ZZZ", 9, "/cast Thorns", true)
    spell(1, 1); char().slots[2] = { "macro", "ZZZ" }
    local prev = plan("SLOT\t3\tspell\tProwl")
    apply(prev)
    apply(plan(mixed))
    return prev
end

test("Revert after reload restores slots, macro contents/scope, keys and previous pending plan", function()
    local prev = mixedApply()
    assert(w.macros.AAA.perChar and w.macros.ZZZ.icon == 15 and idAt(1) == "AAA" and not idAt(2))
    assert(w.keys.R == "BUTTON" and not w.keys.B)
    w.keys.F13 = "OTHER"; spell(6, 1)
    reload()
    has(BP.revert(true), "Preview Revert again")
    revert()
    assert(not w.macros.AAA and w.macros.ZZZ.icon == 9 and w.macros.ZZZ.body == "/cast Thorns")
    assert(idAt(1) == 1 and idAt(2) == "ZZZ" and idAt(6) == 1)
    assert(w.keys.R == "RUN" and w.keys.NUMLOCK == "RUN" and w.keys.B == "PACK" and w.keys.F13 == "OTHER")
    assert(P.active().text == prev and P.active().pending[3] and not P.active().undo)
end)

for _, case in ipairs({
    { "slot", function() spell(2, 5) end },
    { "macro edited", function() w.macros.AAA.body = "/dance" end },
    { "macro acquired an unmanaged slot", function() char().slots[109] = { "macro", "AAA" } end },
    { "macro acquired a direct key", function() w.keys.Z = "MACRO AAA" end },
    { "formerly removed key assigned", function() w.keys.B = "OTHER" end },
    { "command acquired a secondary", function() w.keys.Z = "BUTTON" end },
    { "binding scope changed", function() w.scope = 1 end },
    { "binding override changed", function() w.overrides.R = "TEMP" end },
    { "prior spell no longer available", function() char().known[1] = nil end },
}) do
    test("Revert refuses drift: " .. case[1], function()
        mixedApply()
        has(BP.revert(false), "Revert last Apply?")
        case[2]()
        local saves = w.saves
        has(BP.revert(true), "Revert stopped")
        assert(w.saves == saves and w.keys.R == "BUTTON" and idAt(1) == "AAA" and P.active().undo)
    end)
end

test("game rejecting a late slot write rolls back macros, bindings and earlier slots", function()
    w.macroActionID = 53
    spell(1, 1); spell(2, 1)
    local text = plan("MACRO\tABC\t\t1\t/dance\nSLOT\t1\tmacro\tABC\nSLOT\t2\tspell\tWrath\nENSURE\tB\tBUTTON")
    has(BP.run(text, true), "Check OK")
    w.rejectSlot = 2
    has(BP.run(text, false), "Previous state restored")
    assert(w.keys.B == "PACK" and not w.macros.ABC and idAt(1) == 1 and idAt(2) == 1)
    assert(not P.active().text and not P.active().undo)
end)

test("failed Revert rolls back and is retryable", function()
    spell(1, 1); spell(2, 1)
    apply(plan("SLOT\t1\tspell\tWrath\nSLOT\t2\tspell\tWrath\nENSURE\tB\tBUTTON"))
    BP.revert(false)
    w.rejectSlot = 1
    has(BP.revert(true), "Previous state restored")
    assert(idAt(1) == 5 and idAt(2) == 5 and w.keys.B == "BUTTON" and P.active().undo)
    w.rejectSlot = nil
    revert()
    assert(idAt(1) == 1 and idAt(2) == 1 and w.keys.B == "PACK")
end)

test("unrestorable action blocks before any write; untouched slots do not block", function()
    char().slots[1] = { "flyout", 99 }
    has(BP.run(plan("SLOT\t1\tclear\t\nENSURE\tR\tBUTTON"), true), "cannot restore")
    assert(w.keys.R == "RUN" and idAt(1) == 99)
    apply(plan("SLOT\t2\tspell\tWrath"))
    assert(idAt(2) == 5 and idAt(1) == 99)
end)

test("no-op Apply preserves the useful snapshot", function()
    local text = plan("SLOT\t1\tspell\tWrath")
    apply(text)
    local snapshot = P.active().undo
    apply(text)
    assert(P.active().undo == snapshot)
    revert()
    assert(not idAt(1) and not P.active().text and not P.active().pending)
end)

test("clear then reserve a future slot in an older hand-authored plan", function()
    spell(1, 1)
    local text = plan("SLOT\t1\tclear\t\nSLOT\t1\tspell\tDash")
    local summary, _, details = BP.run(text, true)
    has(summary, "1 occupied slot will be replaced now")
    has(details, "reserved for Dash")
    has(BP.run(text, false), "Done:")
    assert(not idAt(1) and P.active().pending[1])
    revert()
    assert(idAt(1) == 1 and not P.active().pending)
    apply(text); char().known[3] = true; event()
    assert(idAt(1) == 3 and not idAt(109))
end)

test("future item, disabled auto-fill and cursor recheck", function()
    local count = 0
    GetItemCount = function() return count end
    PickupItem = function(id) w.cursor = { "item", id } end
    apply(plan("SLOT\t1\titem\titem:6948"))
    BarsmithDB.auto, count = false, 1
    event("BAG_UPDATE_DELAYED")
    assert(not idAt(1))
    BarsmithDB.auto, w.cursor = true, { "spell", 1 }
    event("BAG_UPDATE_DELAYED")
    assert(not idAt(1) and w.cursor[2] == 1)
    w.cursor = nil
    event("CURSOR_CHANGED")
    assert(idAt(1) == 6948)
    GetItemCount, PickupItem = nil, nil
end)

test("a character switch blocks deletion of a new shared macro", function()
    apply(plan("MACRO\tShared\t\t0\t/dance\nSLOT\t1\tmacro\tShared"))
    w.guid = "Player-B"; event("PLAYER_ENTERING_WORLD")
    char().slots[7] = { "macro", "Shared" }
    w.guid = "Player-A"; event("PLAYER_ENTERING_WORLD")
    has(BP.revert(false), "other characters' uses")
    assert(w.macros.Shared and idAt(1) == "Shared")
end)

test("account macro created in this visit can be reverted after reload", function()
    apply(plan("MACRO\tShared\t\t0\t/dance\nSLOT\t1\tmacro\tShared"))
    reload()
    revert()
    assert(not w.macros.Shared and not idAt(1))
end)

test("prior action macro drift blocks restoring that reference", function()
    CreateMacro("Former", 42, "/dance", true)
    char().slots[1] = { "macro", "Former" }
    apply(plan("SLOT\t1\tspell\tWrath"))
    w.macros.Former.body = "/wave"
    has(BP.revert(false), "Previous slot macro changed")
    assert(idAt(1) == 5)
end)

test("no ownership is inferred before a GUID is available", function()
    w.guid = nil
    has(BP.run(plan("SLOT\t1\tspell\tWrath"), true), "identity unavailable")
    assert(not next(BarsmithDB.characters))
end)

test("Revert handles an override masked by its new persistent owner", function()
    w.overrides.B = "BUTTON"
    apply(plan("ENSURE\tB\tBUTTON"))
    revert()
    assert(w.keys.B == "PACK" and w.overrides.B == "BUTTON")
end)

test("a pending Check cannot be reused across character changes", function()
    local text = plan("SLOT\t1\tspell\tWrath\nENSURE\tB\tBUTTON")
    BP.run(text, true)
    w.guid = "Player-B"
    has(BP.run(text, false), "Run Check before Apply")
    assert(not idAt(1) and w.keys.B == "PACK")
end)

test("an existing placed macro changed after Apply blocks Revert", function()
    CreateMacro("Shared", 91, "/cast Thorns", true)
    apply(plan("SLOT\t1\tmacro\tShared"))
    w.macros.Shared.body = "/wave"
    has(BP.revert(false), "Placed slot macro changed")
    assert(idAt(1) == "Shared")
end)

test("macro body change while a leveling batch is open requires fresh review", function()
    CreateMacro("Old", 91, "/dance", true)
    char().slots[1] = { "macro", "Old" }
    apply(plan("SLOT\t1\tspell\tDash"))
    char().known[3] = true
    BP.levelUpdates("review")
    w.macros.Old.body = "/wave"
    BP.levelUpdates("confirm")
    has(w.chat, "replacements changed")
    assert(idAt(1) == "Old")
end)

test("GUID survives full display name and realm metadata changes", function()
    local p, c = P.active()
    apply(plan("SLOT\t3\tspell\tDash"))
    GetUnitName = function(unit) assert(unit == "player"); return char().fullName end
    char().fullName, char().realm = "Seren Grey", ""
    assert(P.character().name == "Seren Grey" and not c.realm)
    char().fullName, char().realm = "Seren Vale", "Another Realm"
    reload()
    assert(P.active() == p and P.character() == c and c.name == "Seren Vale" and c.realm == "Another Realm")
    assert(p.pending[3] and p.undo)
    GetUnitName = nil
end)

test("foreign profile copies are independent local drafts, even for other classes", function()
    w.guid = "Player-C"
    local text = plan("CLASS\tPRIEST\nSLOT\t3\tspell\tDash\nENSURE\tB\tBUTTON")
    assert(P.manage("create", "Leveling", text))
    apply(text)
    local source = P.active()
    source.overwrite = true
    P.setBarManaged(source, 61, false)
    w.guid = "Player-A"
    assert(not P.manage("select", "Leveling"))
    assert(P.manage("create", "Leveling", plan("SLOT\t2\tspell\tProwl")))
    local oldDraft = P.active()
    assert(P.copyFrom("Player-C", "Leveling") == "Leveling (2)")
    local copy, c = P.active()
    assert(not copy.lastApplied and source.lastApplied == text)
    assert(copy ~= source and copy.text == text and not copy.undo and not copy.pending and not copy.overwrite)
    assert(c.active == "Leveling (2)" and c.profiles.Leveling == oldDraft)
    P.setBarManaged(copy, 61, true)
    assert(P.managesSlot(copy, 64) and not P.managesSlot(source, 64))
    char().known[3] = true
    event()
    assert(not idAt(3) and w.saves == 1)
    has(BP.run(text, true), "different class")
    apply(plan("CLASS\tDRUID\nSLOT\t3\tspell\tWrath"))
    assert(idAt(3) == 5 and source.text == text)
    w.guid = "Player-C"
    assert(P.active() == source and source.pending[3] and source.undo)
end)

test("excluded Bar 2 slots skip Check and Apply while explicit binding changes still run", function()
    spell(61, 1); spell(72, 1); spell(73, 1)
    w.keys.Z, w.keys.X = "MULTIACTIONBAR1BUTTON1", "MULTIACTIONBAR1BUTTON1"
    local p = P.active()
    local text = plan("SLOT\t60\tspell\tWrath\nSLOT\t61\tclear\t\nSLOT\t72\tspell\tWrath\nSLOT\t73\tspell\tWrath\nENSURE\tB\tMULTIACTIONBAR1BUTTON1")
    BP.run(text, true)
    P.setBarManaged(p, 61, false)
    has(BP.run(text, false), "Run Check")
    local s = BP.run(text, true)
    has(s, "Skipped 2 planned slots on excluded bars")
    char().slots[61] = { "flyout", 23 } -- an unrelated edit after Check
    has(BP.run(text, false), "Done:")
    assert(idAt(60) == 5 and idAt(61) == 23 and idAt(72) == 1 and idAt(73) == 5)
    assert(w.keys.B == w.keys.Z and w.keys.Z == w.keys.X and w.keys.Z == "MULTIACTIONBAR1BUTTON1")
    assert(P.manage("duplicate", "Resto"))
    P.setBarManaged(P.active(), 61, true)
    assert(not P.managesSlot(p, 61))
    assert(P.manage("select", "Default"))
    reload()
    assert(not P.managesSlot(P.active(), 72))
end)

test("leveling filters empty, occupied and stale approved slots by physical form page", function()
    spell(74, 1); spell(97, 1)
    local p = P.active()
    apply(plan("SLOT\t73\tspell\tDash\nSLOT\t74\tspell\tDash\nSLOT\t97\tspell\tDash"))
    char().known[3] = true
    BP.levelUpdates("review")
    P.setBarManaged(p, 73, false)
    BP.levelUpdates("confirm")
    assert(not idAt(73) and idAt(74) == 1 and idAt(97) == 1)
    event()
    assert(#w.prompts == 1)
    has(w.prompts, "1 newly available")
    BP.levelUpdates("review"); BP.levelUpdates("confirm")
    assert(idAt(97) == 3 and not idAt(73) and idAt(74) == 1)
    p.overwrite = true
    event()
    assert(not idAt(73) and idAt(74) == 1 and #w.prompts == 1)
end)

test("Revert skips newly excluded stale slots and preserves current exclusions", function()
    spell(1, 1); spell(61, 1)
    apply(plan("SLOT\t1\tspell\tWrath\nSLOT\t61\tspell\tWrath\nENSURE\tB\tBUTTON"))
    BP.revert(false)
    P.setBarManaged(P.active(), 61, false)
    has(BP.revert(true), "Preview Revert again")
    char().slots[61] = { "flyout", 99 }
    revert()
    assert(idAt(61) == 99 and idAt(1) == 1 and w.keys.B == "PACK")
    assert(not P.managesSlot(P.active(), 61))
end)

test("Revert cannot delete a macro still on a newly excluded slot", function()
    apply(plan("MACRO\tKeep\t\t1\t/dance\nSLOT\t61\tmacro\tKeep\nENSURE\tB\tBUTTON"))
    P.setBarManaged(P.active(), 61, false)
    has(BP.revert(false), "Macro Keep is now used on Bar 2")
    assert(idAt(61) == "Keep" and w.macros.Keep and w.keys.B == "BUTTON" and P.active().undo)
end)

test("dynamic tooltip icon is accepted and recorded for Revert", function()
    local original = CreateMacro
    CreateMacro = function(n, icon, body, perChar)
        return original(n, icon == 134400 and 132140 or icon, body, perChar)
    end
    local text = plan("MACRO\tClaw\t134400\t1\t#showtooltip Claw\\n/startattack [harm,nodead]\\n/cast Claw\nSLOT\t1\tmacro\tClaw")
    local ok, err = pcall(function()
        apply(text)
        assert(w.macros.Claw.icon == 132140 and idAt(1) == "Claw")
        assert(P.active().undo.ops[1].after.icon == 132140)
        reload()
        revert()
        assert(not w.macros.Claw and not idAt(1))
    end)
    CreateMacro = original
    assert(ok, err)
end)

test("resolved tooltip macro rolls back after a later slot rejection", function()
    local original = CreateMacro
    CreateMacro = function(n, icon, body, perChar)
        return original(n, icon == 134400 and 132140 or icon, body, perChar)
    end
    local ok, err = pcall(function()
        spell(1, 1); spell(2, 1)
        local text = plan("MACRO\tClaw\t134400\t1\t#showtooltip Claw\\n/cast Claw\nSLOT\t1\tmacro\tClaw\nSLOT\t2\tspell\tWrath\nENSURE\tB\tBUTTON")
        has(BP.run(text, true), "Check OK")
        w.rejectSlot = 2
        has(BP.run(text, false), "Previous state restored")
        assert(not w.macros.Claw and idAt(1) == 1 and idAt(2) == 1 and w.keys.B == "PACK")
    end)
    CreateMacro = original
    assert(ok, err)
end)

test("unexpected fixed icon is still rejected", function()
    local original = CreateMacro
    CreateMacro = function(n, icon, body, perChar)
        return original(n, 132140, body, perChar)
    end
    local ok, err = pcall(function()
        local text = plan("MACRO\tClaw\t42\t1\t#showtooltip Claw\\n/cast Claw")
        has(BP.run(text, true), "Check OK")
        has(BP.run(text, false), "Game did not restore/place Claw")
        assert(not P.active().text)
    end)
    CreateMacro = original
    assert(ok, err)
end)

print(passed .. " passed, " .. failed .. " failed")
assert(failed == 0)

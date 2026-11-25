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
        if w.cursor[1] == "spell" then return "spell", 17, "spell", w.cursor[2] end
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

test("excluded Bar 2 slots and their explicit bindings are protected", function()
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
    assert(w.keys.B == "PACK" and w.keys.Z == w.keys.X and w.keys.Z == "MULTIACTIONBAR1BUTTON1")
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

test("Revert protects original, applied and newly acquired excluded binding owners", function()
    local bar = "MULTIACTIONBAR1BUTTON1"
    w.keys.Z, w.keys.X = bar, bar
    apply(plan("ENSURE\tZ\tBUTTON\nENSURE\tB\t" .. bar .. "\nENSURE\tF5\tBUTTON\nENSURE\tF6\tPACK"))
    P.setBarManaged(P.active(), 61, false)
    w.keys.B, w.keys.F5 = "OTHER", bar
    local summary = BP.revert(false)
    has(summary, "Revert last Apply?")
    has(BP.revert(true), "Reverted")
    assert(w.keys.Z == "BUTTON" and w.keys.X == bar and w.keys.B == "OTHER" and w.keys.F5 == bar)
    assert(not w.keys.F6 and w.keys.NUMLOCK == "RUN")
end)

test("protected Revert binding cannot authorize deletion of a directly bound macro", function()
    local bar = "MULTIACTIONBAR1BUTTON1"
    w.keys.X = bar
    apply(plan("MACRO\tKeep\t42\t1\t/dance\nENSURE\tX\tMACRO Keep"))
    P.setBarManaged(P.active(), 61, false)
    has(BP.revert(false), "Macro now has a binding on X")
    assert(w.keys.X == "MACRO Keep" and w.macros.Keep)
end)

test("explicit shared macro edits identify the excluded button using them", function()
    CreateMacro("Shared", 42, "/dance", true)
    char().slots[61] = { "macro", "Shared" }
    P.setBarManaged(P.active(), 61, false)
    local text = plan("MACRO\tShared\t42\t1\t/wave")
    local _, _, details = BP.run(text, true)
    has(details, "Editing macro Shared also changes its use on excluded Bar 2 button 1 [61]")
    has(BP.run(text, false), "Done:")
    assert(w.macros.Shared.body == "/wave" and idAt(61) == "Shared")
    revert()
    assert(w.macros.Shared.body == "/dance" and idAt(61) == "Shared")
end)

local function withAPI(api, run)
    local saved = {}
    for name, fn in pairs(api) do saved[name], _G[name] = _G[name], fn end
    local ok, err = pcall(run)
    for name in pairs(api) do _G[name] = saved[name] end
    assert(ok, err)
end

local selected = { GetSelectedMacroIcon = function(index)
    local name = GetMacroInfo(index)
    return name and w.macros[name].icon
end }
local macroInfo = GetMacroInfo
local function displayIcon(index)
    local name, icon, body = macroInfo(index)
    if icon == 134400 then icon = w.texture or 132140 end
    return name, icon, body
end

test("dynamic macro selection survives target changes, export, edit, reload and Revert", function()
    withAPI({ C_Macro = selected, GetMacroInfo = displayIcon }, function()
        CreateMacro("Charge", 134400, "#showtooltip\n/cast Charge", true)
        char().slots[97] = { "macro", "Charge" }
        local text = plan("MACRO\tCharge\t42\t1\t#showtooltip Bear\\n/cast Bear\nSLOT\t73\tmacro\tCharge")
        has(BP.run(text, true), "Check OK")
        w.texture = 12345
        assert(tonumber(BP.parse(BP.exportCurrent()).macros[1].icon) == 134400)
        has(BP.run(text, false), "Done:")
        assert(w.macros.Charge.icon == 42 and P.active().undo.ops[1].before.icon == 134400)
        reload(); revert()
        assert(w.macros.Charge.icon == 134400 and idAt(97) == "Charge" and not idAt(73))
        apply(plan("MACRO\tClaw\t134400\t1\t#showtooltip\\n/cast Claw\nSLOT\t73\tmacro\tClaw"))
        assert(P.active().undo.ops[1].after.icon == 134400)
        w.texture = 34567
        reload(); revert()
        assert(not w.macros.Claw and not idAt(73))
    end)
end)

test("fixed selected icon edit matching the displayed texture still blocks Apply and Revert", function()
    withAPI({ C_Macro = selected, GetMacroInfo = displayIcon }, function()
        local text = plan("MACRO\tClaw\t134400\t1\t#showtooltip Claw\\n/cast Claw")
        apply(text)
        has(BP.run(text, true), "Check OK")
        w.macros.Claw.icon = 132140
        local summary, _, details = BP.run(text, false)
        has(summary, "Run Check again")
        has(details, "Macro Claw / before / icon: 134400 -> 132140")
        local _, _, revertDetails = BP.revert(false)
        has(revertDetails, "Macro Claw / icon: 134400 -> 132140")
        assert(P.active().undo and w.macros.Claw.icon == 132140)
    end)
end)

test("an explicit icon-only edit is reviewed, verified and reversible", function()
    withAPI({ C_Macro = selected, GetMacroInfo = displayIcon }, function()
        CreateMacro("Claw", 134400, "#showtooltip Claw", true)
        local text = plan("MACRO\tClaw\t132140\t0\t#showtooltip Claw")
        local _, _, details = BP.run(text, true)
        has(details, "Update character macro Claw")
        has(BP.run(text, false), "Done:")
        assert(w.macros.Claw.icon == 132140 and w.macros.Claw.perChar)
        revert()
        assert(w.macros.Claw.icon == 134400)
    end)
end)

test("old observed-icon snapshot reverts a created macro only with the reviewed selection", function()
    withAPI({ C_Macro = selected, GetMacroInfo = displayIcon }, function()
        apply(plan("MACRO\tClaw\t134400\t1\t#showtooltip Claw"))
        local u = P.active().undo
        u.selectedIcons, u.ops[1].after.icon = nil, 132140
        reload()
        w.macros.Claw.icon = 132140
        has(BP.revert(false), "changed since Apply")
        w.macros.Claw.icon = 134400
        revert()
        assert(not w.macros.Claw)
    end)
end)

test("partial macro write restores actual prior macro and binding before publishing history", function()
    local edit = EditMacro
    CreateMacro("Old", 17, "/wave", true)
    withAPI({ EditMacro = function(i,n,icon,body)
        edit(i,n,icon,body == "/dance" and "/wrong" or body)
    end }, function()
        local text = plan("MACRO\tOld\t42\t1\t/dance\nENSURE\tB\tBUTTON")
        has(BP.run(text, true), "Check OK")
        has(BP.run(text, false), "Previous state restored")
        assert(w.macros.Old.icon == 17 and w.macros.Old.body == "/wave" and w.keys.B == "PACK" and not P.active().undo)
    end)
end)

test("a creation returned in the wrong scope is rejected and recovered by verified index", function()
    local create = CreateMacro
    withAPI({ CreateMacro = function(n,icon,body,charMacro) return create(n,icon,body,not charMacro) end }, function()
        local text = plan("MACRO\tNew\t42\t1\t/dance")
        has(BP.run(text, true), "Check OK")
        has(BP.run(text, false), "Previous state restored")
        assert(not w.macros.New and not P.active().lastApplied)
    end)
end)

test("only an Auto-fill event fills newly enabled empty slots from the applied profile", function()
    local p = P.active()
    P.setBarManaged(p, 61, false)
    local saved = plan("SLOT\t61\tspell\tThorns\nSLOT\t62\tspell\tWrath\nENSURE\tZ\tMULTIACTIONBAR1BUTTON1")
    apply(saved)
    event()
    assert(not idAt(61) and not idAt(62) and not w.keys.Z)
    w.event("SPELLS_CHANGED")
    P.setBarManaged(p, 61, true)
    local draft = plan("SLOT\t61\tspell\tWrath\nENSURE\tZ\tBUTTON")
    has(BP.run(draft, true), "Check OK")
    assert(not idAt(61) and not idAt(62) and not w.keys.Z)
    w.timer()
    assert(idAt(61) == 1 and idAt(62) == 5 and not w.keys.Z and p.text == saved)
    local summary, _, details = BP.run(draft, false)
    has(summary, "Run Check again")
    has(details, "Bar 2 button 1 [61] / current / kind")
    assert(idAt(61) == 1 and not w.keys.Z and p.lastApplied == saved)
end)

test("reapplying while excluded preserves only an already approved pending target", function()
    spell(61, 1); spell(62, 1)
    apply(plan("SLOT\t61\tspell\tDash\nSLOT\t62\tspell\tProwl"))
    local p = P.active()
    P.setBarManaged(p, 61, false)
    char().known[3], char().known[4] = true, true
    apply(plan("SLOT\t61\tspell\tDash\nSLOT\t62\tspell\tWrath"))
    assert(p.pending[61] and not p.pending[62])
    event()
    assert(idAt(61) == 1 and idAt(62) == 1)
    P.setBarManaged(p, 61, true)
    event(); BP.levelUpdates("review"); BP.levelUpdates("confirm")
    assert(idAt(61) == 3 and idAt(62) == 1)
end)

test("availability, profile and leveling confirmation diagnostics identify the changed fields", function()
    local text = plan("SLOT\t73\tspell\tDash")
    spell(73, 1)
    has(BP.run(text, true), "Check OK")
    P.active().overwrite, char().known[3] = true, true
    local _, _, details = BP.run(text, false)
    has(details, 'Cat Form button 1 [73] / unavailable: "not learned yet" -> (absent)')
    has(details, "intended / id: (absent) -> 3")
    has(details, "Profile / overwrite: false -> true")
    assert(idAt(73) == 1)
    char().known[3] = nil
    apply(text)
    char().known[3] = true
    BP.levelUpdates("review")
    spell(73, 5)
    local _, _, changed = BP.levelUpdates("confirm")
    has(changed, "[73] / before / id: 1 -> 5")
    assert(idAt(73) == 5)
end)

-- Model two physical spells with the same visible override in each form.
-- Only the reverse action-bar query distinguishes the two stored actions.
test("form overrides preserve per-slot identity across Check, Apply, export and Revert", function()
    local names = { [101] = "Feral Charge (Cat)", [102] = "Feral Charge (Bear)" }
    local form = 201
    char().known[101], char().known[102] = true, true
    local rawAction = GetActionInfo
    local api = {
        Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 }, ActionBarSet = { Mkb = 1 } },
        C_Spell = { GetSpellName = function(id) return names[id] end },
        C_SpellBook = {
            GetNumSpellBookSkillLines = function() return 1 end,
            GetSpellBookSkillLineInfo = function() return { numSpellBookItems = 2 } end,
            GetSpellBookItemInfo = function(index)
                return { name = "Current charge", spellID = form, actionID = 100 + index, itemType = 1 }
            end,
            PickupSpellBookItem = function(i) PickupSpell(100 + i) end,
            FindBaseSpellByID = function(id) return id == form and 101 or id end,
            FindSpellOverrideByID = function(id) return names[id] and form or id end,
        },
        C_ActionBar = { FindSpellActionButtons = function(base, bank)
            assert(bank == 1)
            local slots = {}
            for slot, action in pairs(char().slots) do
                if action[2] == base then table.insert(slots, slot) end
            end
            return slots
        end },
        GetActionInfo = function(slot)
            local kind, id = rawAction(slot)
            if names[id] then return kind, form end
            return kind, id
        end,
    }
    withAPI(api, function()
        spell(73, 101); spell(97, 102)
        local planText = plan("SLOT\t73\tspell\tFeral Charge (Cat)\nSLOT\t97\tspell\tFeral Charge (Bear)\n"
            .. "SLOT\t74\tspell\tspell:102\nSLOT\t98\tspell\tspell:101")
        for _, active in ipairs({201, 202, 203, 204}) do
            form = active
            local export = BP.parse(BP.exportCurrent())
            assert(export.slots[1].value == "spell:101" and export.slots[2].value == "spell:102")
            has(BP.run(planText, true), "Check OK")
            form = active + 1
            has(BP.run(planText, false), "Done:")
            assert(idAt(73) == 101 and idAt(97) == 102 and idAt(74) == 102 and idAt(98) == 101)
            revert()
        end
        has(BP.run(planText, true), "Check OK")
        spell(97, 101) -- same visible texture and reported spell, different stored identity
        local _, _, changes = BP.run(planText, false)
        has(changes, "[97] / current / id: 102 -> 101")
        assert(not idAt(74))
    end)
end)

test("changed name-only spell resolution requires Check and exact qualifications stay strict", function()
    local id = 31
    char().known[31], char().known[32] = true, true
    withAPI({ C_Spell = {
        GetSpellIDForSpellIdentifier = function() return id end,
        GetSpellName = function() return "Feral Charge" end,
        GetSpellSubtext = function() return nil end,
    } }, function()
        local text = plan("SLOT\t97\tspell\tFeral Charge\nSLOT\t73\tspell\tFeral Charge (Cat)\nSLOT\t74\tspell\tspell:31")
        has(BP.run(text, true), "Check OK")
        id = 32
        local _, _, changed = BP.run(text, false)
        has(changed, "[97] / intended / id: 31 -> 32")
        assert(not idAt(97))
        apply(text)
        assert(idAt(97) == 32 and not idAt(73) and idAt(74) == 31 and P.active().pending[73])
    end)
end)

test("book order cannot choose between two named form variants", function()
    char().known[41], char().known[42] = true, true
    local variants = { "Cat", "Bear" }
    withAPI({
        GetNumSpellTabs = function() return 1 end,
        GetSpellTabInfo = function() return nil, nil, 0, 2 end,
        GetSpellBookItemName = function(i) return "Feral Charge", variants[i], 40 + i end,
        GetSpellBookItemInfo = function(i) return "SPELL", 40 + i end,
        PickupSpellBookItem = function(i) PickupSpell(40 + i) end,
    }, function()
        local text = plan("SLOT\t73\tspell\tFeral Charge (Cat)\nSLOT\t97\tspell\tFeral Charge (Bear)\nSLOT\t1\tspell\tFeral Charge")
        has(BP.run(text, true), "Multiple spell variants for Feral Charge")
        assert(not P.active().text and not idAt(73) and not idAt(97))
        apply(plan("SLOT\t73\tspell\tFeral Charge (Cat)\nSLOT\t97\tspell\tFeral Charge (Bear)"))
        assert(idAt(73) == 41 and idAt(97) == 42 and not idAt(1))
    end)
end)

local combatSlots = { 79, 97, 104 }
local combatNames = { "Seren Shred", "Seren Swipe", "Seren Maul" }
local function combatPlan()
    local macros, slots = {}, {}
    for i, name in ipairs(combatNames) do
        local spellName = name:sub(7)
        macros[i] = { name = name, icon = 134400, perChar = true,
            body = "#showtooltip " .. spellName .. "\n/startattack [harm,nodead]\n/cast " .. spellName }
        slots[i] = { slot = combatSlots[i], kind = "macro", value = name }
    end
    return BP.serialize({ class = "DRUID", slots = slots, macros = macros })
end

local function seedSurvivors()
    for i = 1, 7 do CreateMacro("Keep " .. i, 42, "/dance", true) end
    char().slots[55] = { "macro", "Keep 7" }
end

local function loseCombatMacros()
    for i, name in ipairs(combatNames) do
        w.macros[name] = nil
        char().slots[combatSlots[i]] = { "macro" } -- ID zero and no label
    end
end

test("audit distinguishes verified batch from post-reload loss; repair preserves the manual recreation", function()
    seedSurvivors()
    local text = combatPlan()
    apply(text)
    assert(select(2, GetNumMacros()) == 10)
    loseCombatMacros()
    reload(); event("PLAYER_ENTERING_WORLD")
    has(w.chat, "After UI load: macro state differs")
    for i, name in ipairs(combatNames) do
        has(w.chat, name .. ": definition missing")
        has(w.chat, "Slot " .. combatSlots[i] .. " / macro " .. name)
        assert(GetMacroIndexByName(name) == 0)
    end
    local m = BP.parse(text).macros[1]
    CreateMacro(m.name, 134400, m.body, true)
    local manual = w.macros[m.name]
    local writes = 0
    local create = CreateMacro
    withAPI({ CreateMacro = function(...)
        writes = writes + 1
        return create(...)
    end, EditMacro = function() error("unexpected edit") end }, function()
        local summary, _, details = BP.run(text, true)
        has(summary, "Check OK")
        for i, name in ipairs(combatNames) do has(details, "[" .. combatSlots[i] .. "]: verify and repair " .. name) end
        assert(select(2, GetNumMacros()) == 8 and writes == 0 and HasAction(79) and not GetActionText(79))
        has(BP.run(text, false), "Done:")
        assert(writes == 2 and w.macros[m.name] == manual)
        reload(); event("PLAYER_ENTERING_WORLD")
        has(w.chat, "verified 2 newly created macro(s) and 2 assigned slot(s)")
        for i, name in ipairs(combatNames) do assert(idAt(combatSlots[i]) == name) end
        assert(select(2, GetNumMacros()) == 10 and w.saves == 0 and w.keys.NUMLOCK == "RUN")
        revert()
        assert(select(2, GetNumMacros()) == 8 and w.macros[m.name] == manual)
        for _, slot in ipairs(combatSlots) do assert(not HasAction(slot)) end
        assert(idAt(55) == "Keep 7" and w.keys.R == "RUN")
    end)
end)

test("a temporary label failure with ID zero returns the actual macro before writing the bank", function()
    seedSurvivors()
    local text = combatPlan()
    apply(text)
    char().slots[79] = { "macro", "Keep 7" }
    local action, getText = GetActionInfo, GetActionText
    withAPI({
        GetActionInfo = function(s)
            if s == 79 and HasAction(s) then return "macro", 0 end
            return action(s)
        end,
        GetActionText = function(s) if s ~= 79 then return getText(s) end end,
    }, function()
        has(BP.run(text, true), "Check OK")
        has(BP.run(text, false), "yielded a recoverable macro")
        assert(idAt(79) == "Keep 7" and not GetCursorInfo() and select(2, GetNumMacros()) == 10)
    end)
end)

test("a broken-looking slot never authorizes an arbitrary plan, clear, or Auto-fill replacement", function()
    seedSurvivors()
    local text = combatPlan()
    apply(text); loseCombatMacros()
    local wrong = plan("SLOT\t79\tclear\t\nENSURE\tR\tBUTTON")
    has(BP.run(wrong, true), "no macro label")
    assert(not pcall(BP.exportCurrent))
    event()
    assert(HasAction(79) and w.keys.R == "RUN" and GetMacroIndexByName(combatNames[1]) == 0)
    assert(P.manage("create", "Other", text))
    has(BP.run(text, true), "no macro label")
end)

test("positive action ID, spell subtype, incomplete bank and inconsistent name lookup block repairs", function()
    seedSurvivors()
    local text = combatPlan()
    apply(text); loseCombatMacros()
    local action, getInfo, index = GetActionInfo, GetMacroInfo, GetMacroIndexByName
    for _, tuple in ipairs({ {15}, {0, "spell"}, {0, "item"} }) do
        withAPI({ GetActionInfo = function(s)
            if s == 79 then return "macro", tuple[1], tuple[2] end
            return action(s)
        end }, function() has(BP.run(text, true), "no macro label") end)
    end
    withAPI({ GetMacroInfo = function(i) if i ~= 122 then return getInfo(i) end end },
        function() has(BP.run(text, true), "Macro bank is incomplete") end)
    withAPI({ GetMacroIndexByName = function(n) return n == combatNames[1] and 126 or index(n) end },
        function() has(BP.run(text, true), "lookup disagrees") end)
    withAPI({ C_ActionBar = { IsMacroActionWithShowTooltip = function() return true end } },
        function() has(BP.run(text, true), "no macro label") end)
    assert(HasAction(79) and select(2, GetNumMacros()) == 7)
end)

test("an inconclusive pickup leaves the slot untouched and history unpublished", function()
    seedSurvivors()
    local text = combatPlan()
    apply(text); loseCombatMacros()
    local snapshot = P.active().undo
    withAPI({ PickupAction = function() end }, function()
        has(BP.run(text, true), "Check OK")
        has(BP.run(text, false), "Cannot confirm a dangling macro on slot 79")
        assert(HasAction(79) and not GetCursorInfo() and P.active().undo == snapshot and select(2, GetNumMacros()) == 7)
    end)
end)

test("a candidate that resolves between Check and Apply requires fresh review", function()
    seedSurvivors()
    local text = combatPlan()
    apply(text); loseCombatMacros()
    has(BP.run(text, true), "Check OK")
    char().slots[79] = { "macro", "Keep 7" }
    has(BP.run(text, false), "Run Check again")
    assert(idAt(79) == "Keep 7" and select(2, GetNumMacros()) == 7)
end)

test("late eviction of an earlier created macro fails final verification and recovers the original layout", function()
    seedSurvivors()
    spell(79, 5)
    local place = PlaceAction
    withAPI({ PlaceAction = function(s)
        place(s)
        if s == 104 then
            w.macros[combatNames[1]] = nil
            char().slots[79] = { "macro" }
        end
    end }, function()
        local text = combatPlan()
        has(BP.run(text, true), "Check OK")
        local summary, _, details = BP.run(text, false)
        has(summary, "Final macro verification failed")
        has(summary, "Previous state restored")
        has(details, "Macro Seren Shred: definition missing")
        has(details, "Slot 79 / macro Seren Shred")
        assert(idAt(79) == 5 and not idAt(97) and not idAt(104) and idAt(55) == "Keep 7")
        assert(select(2, GetNumMacros()) == 7 and not P.active().lastApplied)
    end)
end)

test("late reindexing that moves a previously correct slot to a different valid macro is reported", function()
    seedSurvivors()
    local text = plan("MACRO\tNew\t42\t1\t/dance\nSLOT\t55\tmacro\tKeep 7\nSLOT\t79\tmacro\tNew\nENSURE\tB\tBUTTON")
    local place = PlaceAction
    withAPI({ PlaceAction = function(s)
        place(s)
        if s == 79 then char().slots[55] = { "macro", "Keep 2" } end
    end }, function()
        has(BP.run(text, true), "Check OK")
        local summary, _, details = BP.run(text, false)
        has(summary, "Final macro verification failed")
        has(summary, "Recovery incomplete")
        has(details, 'Slot 55 / macro Keep 7 / name: "Keep 7" -> "Keep 2"')
        assert(idAt(55) == "Keep 2" and w.keys.B == "PACK" and not w.macros.New and not P.active().text)
    end)
end)

test("a zero action ID with a readable label still names a real macro", function()
    seedSurvivors()
    local text = combatPlan()
    apply(text)
    local action = GetActionInfo
    withAPI({ GetActionInfo = function(s)
        if s == 79 then return "macro", 0 end
        return action(s)
    end, C_ActionBar = { GetActionText = function() end } }, function()
        -- The legacy label identifies the real action while the other label
        -- API temporarily returns nil. No candidate or cursor probe is needed.
        apply(text)
        assert(idAt(79) == combatNames[1])
    end)
end)

test("rollback after a failed repair restores bindings and never deletes a manually recreated macro", function()
    seedSurvivors()
    local base = BP.parse(combatPlan())
    base.binds = {{ op = "ENSURE", key = "R", command = "BUTTON" }}
    local text = BP.serialize(base)
    apply(text); loseCombatMacros()
    local m = base.macros[1]
    CreateMacro(m.name, tonumber(m.icon), m.body, true)
    local snapshot, manual = P.active().undo, w.macros[m.name]
    w.keys.R, w.rejectSlot = "RUN", 104
    has(BP.run(text, true), "Check OK")
    local summary = BP.run(text, false)
    has(summary, "Cleared invalid reference(s) on slot(s) 79, 97, 104")
    assert(w.keys.R == "RUN" and w.keys.NUMLOCK == "RUN" and w.macros[m.name] == manual)
    assert(select(2, GetNumMacros()) == 8 and P.active().undo == snapshot and idAt(55) == "Keep 7")
    for _, slot in ipairs(combatSlots) do assert(not HasAction(slot)) end
end)

test("a bank lookup corroborates the stored spelling of a uniquely matched macro", function()
    CreateMacro("Mixed Case", 42, "/dance", true)
    local old = w.macros["Mixed Case"]
    apply(plan("MACRO\tmixed case\t42\t1\t/dance\nSLOT\t79\tmacro\tmixed case"))
    assert(w.macros["Mixed Case"] == old and idAt(79) == "Mixed Case" and select(2, GetNumMacros()) == 1)
end)

test("an unrelated blank-name macro prevents a repair probe but allows normal named writes", function()
    seedSurvivors()
    CreateMacro("", 42, "/wave", true)
    local text = combatPlan()
    apply(text); loseCombatMacros()
    has(BP.run(text, true), "unnamed stored macro")
    assert(HasAction(79) and w.macros[""].body == "/wave")
end)

test("excluded dangling slots remain untouched during a reapply", function()
    seedSurvivors()
    local text = combatPlan()
    apply(text); loseCombatMacros()
    P.setBarManaged(P.active(), 97, false)
    apply(text)
    assert(idAt(79) == combatNames[1] and HasAction(97) and not GetActionText(97))
    assert(HasAction(104) and not GetActionText(104) and idAt(55) == "Keep 7")
end)

local function spellButtons(id)
    local slots = {}
    for slot, action in pairs(char().slots) do
        if action[1] == "spell" and action[2] == id then table.insert(slots, slot) end
    end
    return slots
end

test("a learned action survives changing stance, effective cursor IDs and transiently blank slot reads", function()
    local rawAction, cursor, active = GetActionInfo, GetCursorInfo, 301
    local pickups, blank = 0, false
    char().known[51] = true
    withAPI({
        PickupSpell = function(id) pickups = pickups + 1; w.cursor = { "spell", id } end,
        GetCursorInfo = function()
            if w.cursor and w.cursor[2] == 51 then return "spell", 9, "spell", active, 51 end
            return cursor()
        end,
        GetActionInfo = function(slot)
            if slot == 81 and idAt(slot) == 51 then
                if blank then return end
                return "spell", active
            end
            return rawAction(slot)
        end,
        HasAction = function(slot) return not blank and idAt(slot) ~= nil end,
        C_ActionBar = { FindSpellActionButtons = spellButtons, GetSpell = idAt },
    }, function()
        local text = plan("SLOT\t81\tspell\tspell:51")
        for _, stance in ipairs({ 301, 302, 303 }) do
            active = stance
            apply(text)
            assert(idAt(81) == 51 and not P.active().pending[81])
            local afterApply = pickups
            active = stance + 10
            local export = BP.parse(BP.exportCurrent())
            assert(export.slots[1].value == "spell:51")
            blank = true
            event(); event("BAG_UPDATE_DELAYED"); event()
            blank = false
            assert(pickups == afterApply)
            revert()
        end
    end)
end)

test("a wrong book pickup retries by exact ID before touching the slot", function()
    char().known[41] = true
    local calls, original = {}, PickupSpell
    withAPI({
        GetNumSpellTabs = function() return 1 end,
        GetSpellTabInfo = function() return nil, nil, 0, 1 end,
        GetSpellBookItemInfo = function() return "SPELL", 41 end,
        GetSpellBookItemName = function() return "Technique", "Stance A", 41 end,
        PickupSpellBookItem = function() table.insert(calls, "book"); w.cursor = { "spell", 42 } end,
        PickupSpell = function(id) assert(not w.cursor); table.insert(calls, id); original(id) end,
    }, function()
        apply(plan("SLOT\t81\tspell\tTechnique (Stance A)"))
        assert(#calls == 2 and calls[1] == "book" and calls[2] == 41 and idAt(81) == 41)
    end)
end)

for _, case in ipairs({
    { name = "sibling override", cursor = { "spell", 51, "spell", 53, 50 }, issue = "cursor base does not identify" },
    { name = "sibling without a fifth result", cursor = { "spell", 51, "spell", 53 }, issue = "unexpected cursor spell ID" },
    { name = "pet action", cursor = { "petaction", 51 }, issue = "unexpected cursor type" },
    { name = "pet bank", cursor = { "spell", 51, "pet", 51 }, issue = "unexpected spellbook bank" },
    { name = "book index equal to requested ID", cursor = { "spell", 51 }, issue = "missing cursor spell identity" },
    { name = "unavailable pickup", cursor = {}, issue = "empty cursor" },
}) do
    test("pickup rejects " .. case.name .. " with diagnostics and restores previous writes", function()
        local cursor, pickup = GetCursorInfo, PickupSpell
        char().known[51] = true
        spell(81, 1)
        withAPI({
            C_Spell = { GetBaseSpell = function(id) return id >= 51 and 50 or id end,
                GetOverrideSpell = function(id) return id == 50 and 53 or id end },
            GetCursorInfo = function()
                if w.cursor and w.cursor[2] == 51 then return unpack(case.cursor) end
                return cursor()
            end,
            PickupSpell = function(id) pickup(id) end,
        }, function()
            local text = plan("SLOT\t1\tspell\tWrath\nSLOT\t81\tspell\tspell:51\nENSURE\tB\tBUTTON")
            has(BP.run(text, true), "Check OK")
            local summary, _, details = BP.run(text, false)
            has(summary, "Previous state restored")
            has(details, "Cat Form button 9 [81], request spell:51")
            has(details, "base 50, override 51")
            has(details, case.issue)
            assert(idAt(81) == 1 and not idAt(1) and w.keys.B == "PACK" and not P.active().undo and not w.cursor)
        end)
    end)
end

test("a base-only cursor for an explicit variant requires exclusive physical membership", function()
    local cursor, place = GetCursorInfo, PlaceAction
    local storesBase = false
    char().known[51], char().known[50] = true, true
    spell(81, 1)
    withAPI({
        GetCursorInfo = function()
            if w.cursor and w.cursor[2] == 51 then return "spell", 4, "spell", 50 end
            return cursor()
        end,
        C_Spell = { GetBaseSpell = function(id) return id == 51 and 50 or id end,
            GetOverrideSpell = function(id) return id == 50 and 51 or id end },
        C_ActionBar = { FindSpellActionButtons = spellButtons },
        PlaceAction = function(slot)
            if storesBase and w.cursor[2] == 51 then w.cursor[2] = 50 end
            place(slot)
        end,
    }, function()
        local text = plan("SLOT\t81\tspell\tspell:51")
        apply(text)
        assert(idAt(81) == 51)
        revert()
        storesBase = true
        has(BP.run(text, true), "Check OK")
        local summary, _, details = BP.run(text, false)
        has(summary, "Previous state restored")
        has(details, "reported spell 50, stored spell 50, expected spell 51")
        assert(idAt(81) == 1 and not w.cursor)
    end)
end)

test("a qualified temporary override becomes eligible only when independently learned", function()
    local visible, known, picks = true, false, 0
    withAPI({
        C_Spell = { GetSpellIDForSpellIdentifier = function() return 71 end,
            GetSpellName = function() return "Technique (Stealth)" end,
            PickupSpell = function(id) picks = picks + 1; w.cursor = { "spell", id } end },
        C_SpellBook = { IsSpellKnownOrInSpellBook = function(_, _, includeOverrides)
            return known or (includeOverrides ~= false and visible)
        end },
    }, function()
        local text = plan("SLOT\t81\tspell\tTechnique (Stealth)")
        local _, _, details = BP.run(text, true)
        has(details, "temporary override (spell:71)")
        has(BP.run(text, false), "Done:")
        for _ = 1, 3 do visible = false; event(); visible = true; event() end
        assert(picks == 0 and P.active().pending[81])
        known = true
        event("LEARNED_SPELL_IN_SKILL_LINE")
        assert(idAt(81) == 71 and picks == 1 and not P.active().pending[81])
    end)
end)

test("failed spell sleeps through event storms while independent spells and bag reservations fill", function()
    local attempts, rank, bag, learned = 0, 81, false, false
    local pickup = PickupSpell
    withAPI({
        C_Spell = { GetSpellIDForSpellIdentifier = function(name)
            if name == "Technique" then return learned and rank end
        end, PickupSpell = function(id)
            if id == 81 then attempts = attempts + 1; return end
            if id == 82 then attempts = attempts + 1; w.cursor = { "spell", id }; return end
            pickup(id)
        end },
        IsSpellKnown = function(id) return learned and id == rank end,
        GetItemCount = function() return bag and 1 or 0 end,
        PickupItem = function(id) w.cursor = { "item", id } end,
    }, function()
        local text = plan("SLOT\t81\tspell\tTechnique\nSLOT\t2\tspell\tDash\nSLOT\t3\titem\titem:42")
        apply(text)
        learned, char().known[3], bag = true, true, true
        event("BAG_UPDATE_DELAYED")
        assert(idAt(3) == 42 and not idAt(2) and attempts == 0)
        event()
        assert(idAt(2) == 3 and attempts == 1 and not idAt(81))
        has(w.chat, "Auto-fill paused for Cat Form button 9 [81] (pending)")
        local messages = #w.chat
        for _ = 1, 3 do event(); event("BAG_UPDATE_DELAYED") end
        learned = false; event(); learned = true; event()
        assert(#w.chat == messages and attempts == 1)
        rank = 82
        event()
        assert(idAt(81) == 82 and attempts == 2 and not next(P.active().pending))
    end)
end)

test("coalesced bag and spell notifications survive both combat and cursor deferral", function()
    local count, bag = 0, false
    withAPI({
        C_Timer = { After = function(_, fn) count = count + 1; w.timer = fn end },
        GetItemCount = function() return bag and 1 or 0 end,
        PickupItem = function(id) w.cursor = { "item", id } end,
    }, function()
        apply(plan("SLOT\t1\tspell\tDash\nSLOT\t2\titem\titem:42"))
        w.combat, char().known[3], bag = true, true, true
        w.event("SPELLS_CHANGED"); w.event("SPELLS_CHANGED"); event("BAG_UPDATE_DELAYED")
        assert(count == 1 and not idAt(1) and not idAt(2))
        w.combat, w.cursor = false, { "spell", 1 }
        event("PLAYER_REGEN_ENABLED")
        assert(not idAt(1) and not idAt(2))
        w.cursor = nil; event("CURSOR_CHANGED")
        assert(count == 3 and idAt(1) == 3 and idAt(2) == 42)
    end)
end)

test("a transient false HasAction cannot authorize an occupied slot replacement", function()
    apply(plan("SLOT\t81\tspell\tWrath"))
    P.active().overwrite = true
    spell(81, 1)
    withAPI({ HasAction = function() return false end }, function()
        event(); event()
        assert(idAt(81) == 1 and #w.prompts == 0)
    end)
end)

test("a verified placement requires a physical empty-slot change to re-arm the same refill", function()
    local pickup, attempts = PickupSpell, 0
    withAPI({ PickupSpell = function(id) attempts = attempts + 1; pickup(id) end }, function()
        apply(plan("SLOT\t81\tspell\tWrath"))
        withAPI({ GetActionInfo = function() end, HasAction = function() return false end }, function()
            w.event("ACTIONBAR_SLOT_CHANGED", 0)
            event(); event(); event("BAG_UPDATE_DELAYED")
            assert(attempts == 1 and idAt(81) == 5)
        end)
        char().slots[81] = nil
        w.event("ACTIONBAR_SLOT_CHANGED", 81)
        assert(attempts == 1)
        event(); event()
        assert(attempts == 2 and idAt(81) == 5)
    end)
end)

test("a hidden player book row verifies its base when the cursor omits its fifth field", function()
    local effective = 700
    local cursor = GetCursorInfo
    local row = { itemType = 1, actionID = 61, spellID = effective, name = "Shifted technique" }
    withAPI({
        Enum = { SpellBookSpellBank = { Player = 0, Pet = 1 }, SpellBookItemType = { Spell = 1 } },
        C_SpellBook = {
            FindSpellBookSlotForSpell = function() return 7, 0 end,
            GetSpellBookItemInfo = function(i, bank) if i == 7 and bank == 0 then return row end end,
            PickupSpellBookItem = function(i, bank) assert(i == 7 and bank == 0); w.cursor = { "spell", 61 } end,
        },
        GetCursorInfo = function()
            if w.cursor and w.cursor[2] == 61 then return "spell", 7, "spell", effective end
            return cursor()
        end,
    }, function()
        apply(plan("SLOT\t81\tspell\tspell:61"))
        assert(idAt(81) == 61)
        effective = 799 -- same book index, unexpected effective spell
        local text = plan("SLOT\t82\tspell\tspell:61")
        has(BP.run(text, true), "Check OK")
        local _, _, details = BP.run(text, false)
        has(details, "unexpected cursor spell ID")
        assert(not idAt(82) and idAt(81) == 61)
    end)
end)

test("login seeds verified placements and explicit Auto-fill re-enable retries a failed slot", function()
    local pickup, calls, fail = PickupSpell, 0, false
    withAPI({ PickupSpell = function(id)
        calls = calls + 1
        if not fail then pickup(id) end
    end }, function()
        apply(plan("SLOT\t81\tspell\tWrath"))
        reload(); event("PLAYER_ENTERING_WORLD")
        withAPI({ GetActionInfo = function() end, HasAction = function() return false end }, function()
            event()
            assert(calls == 1)
        end)
        char().slots[81] = nil
        w.event("ACTIONBAR_SLOT_CHANGED", 81)
        fail = true
        event(); event()
        assert(calls == 2 and not idAt(81))
        fail = false
        SlashCmdList.BARSMITH("auto"); SlashCmdList.BARSMITH("auto")
        event()
        assert(calls == 3 and idAt(81) == 5)
    end)
end)

test("export keeps the physical base even when the other action API and reverse query expose its alias", function()
    spell(81, 50)
    withAPI({
        HasAction = function() return false end,
        C_Spell = { GetBaseSpell = function(id) return id == 51 and 50 or id end,
            GetOverrideSpell = function(id) return id == 50 and 51 or id end },
        C_ActionBar = { GetSpell = function() return 51 end,
            FindSpellActionButtons = function(id) return (id == 51 or id == 50) and {81} or {} end },
    }, function()
        local exported = BP.parse(BP.exportCurrent())
        assert(#exported.slots == 1 and exported.slots[1].value == "spell:50")
    end)
end)

test("inconclusive physical membership cannot export or overwrite a transient display ID", function()
    spell(81, 51)
    withAPI({
        C_Spell = { GetBaseSpell = function(id) return id == 51 and 50 or id end },
        C_ActionBar = { FindSpellActionButtons = function() return {} end },
    }, function()
        local ok, msg = pcall(BP.exportCurrent)
        assert(not ok); has({msg}, "reported 51, possible base 50")
        has(BP.run(plan("SLOT\t81\tspell\tWrath"), true), "Cannot identify the physical spell")
        assert(idAt(81) == 51 and not w.cursor)
    end)
end)

test("oscillating target IDs each fail once and a confirmed relearn can retry the same ID", function()
    local id, calls, learned = 81, 0, false
    withAPI({
        C_Spell = { GetSpellIDForSpellIdentifier = function() return id end,
            PickupSpell = function() calls = calls + 1 end },
        IsSpellKnown = function(spellID) return learned and id == spellID end,
    }, function()
        apply(plan("SLOT\t81\tspell\tTechnique"))
        learned = true
        for _, target in ipairs({ 81, 82, 81, 82, 81 }) do id = target; event() end
        assert(calls == 2)
        learned = false; event()
        learned = true; event()
        assert(calls == 2)
        w.event("LEARNED_SPELL_IN_SKILL_LINE", 81); event("BAG_UPDATE_DELAYED")
        w.event("LEARNED_SPELL_IN_SKILL_LINE", 81); event()
        assert(calls == 3 and not idAt(81) and P.active().pending[81])
    end)
end)

print(passed .. " passed, " .. failed .. " failed")
assert(failed == 0)

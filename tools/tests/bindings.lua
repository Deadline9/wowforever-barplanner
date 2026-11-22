-- Run at the repository root with lua or texlua. Exercise the real Check/Apply entry point.
local owners, registry, overrides, scope, writes, saves, rejected, output, clears, slotEdits
local summary, full, details, emptied
local unpack = table.unpack or unpack
local failures, passed = 0, 0
local function test(name, fn)
    owners = { R = "RUN", NUMLOCK = "RUN", B = "PACK", ["SHIFT-B"] = "ALLBAGS", F13 = "ADDON" }
    registry = { "RUN", "PACK", "BUTTON", "ALLBAGS", "ADDON", "UNBOUND" }
    overrides, scope, writes, saves, rejected, output, clears, slotEdits = {}, 2, {}, 0, nil, {}, 0, 0
    BarsmithDB, summary, full, details, emptied = {}, {}, {}, {}, {}
    local ok, err = pcall(fn)
    if ok then passed = passed + 1 else failures = failures + 1; print(name, err) end
end
GetNumBindings = function() return #registry end
GetCurrentBindingSet = function() return scope end
GetBindingAction = function(k, override) return (override and overrides[k]) or owners[k] or "" end
GetBindingKey = function(cmd)
    local list = {}
    for k, v in pairs(owners) do if v == cmd then list[#list + 1] = k end end
    table.sort(list)
    return unpack(list)
end
GetBinding = function(i, includePad)
    assert(includePad == true)
    return registry[i], "TEST", GetBindingKey(registry[i])
end
SetBinding = function(k, cmd)
    writes[#writes + 1] = k
    if k == rejected then return false end
    owners[k] = cmd
    return true
end
SaveBindings = function(set) assert(set == scope); saves = saves + 1 end
CreateFrame = function() return { SetScript = function() end, RegisterEvent = function() end } end
GetNumMacros = function() return 0, 0 end
UnitClass = function() return "Mage", "MAGE" end
InCombatLockdown = function() return false end
ClearCursor = function() clears = clears + 1 end
GetActionInfo = function(slot) if not emptied[slot] then return "spell", 100 end end
HasAction = function(slot) return not emptied[slot] end
PickupAction = function(slot) emptied[slot] = true; slotEdits = slotEdits + 1 end
UnitGUID = function() return "Player-1" end
UnitName = function() return "Tester" end
GetRealmName = function() return "Realm" end
IsPlayerSpell = function(id) return id == 100 end
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, line) output[#output+1] = line end }

dofile("addon/Barsmith/Bindings.lua")
dofile("addon/Barsmith/Profiles.lua")
dofile("addon/Barsmith/Changes.lua")
dofile("addon/Barsmith/Barsmith.lua")
local BP = Barsmith
local function run(records, version)
    version = version or 2
    local text = "BP" .. version .. ":" .. BP.b64encode("BARPLAN\t" .. version .. "\n" .. records)
    summary, full, details = BP.run(text, true)
    assert(#writes == 0 and saves == 0 and clears == 0 and slotEdits == 0, "Check mutated state")
    return function() BP.run(text, false) end
end
local function says(msg)
    local report = table.concat(full, "\n") .. "\n" .. table.concat(output, "\n")
    assert(report:find(msg, 1, true), report)
end

test("1 preserve Autorun", function()
    run("ENSURE\tR\tRUN")()
    says("Bindings: 0 to change, 1 already correct, 1 safely preserved.")
    assert(owners.NUMLOCK == "RUN" and owners.R == "RUN" and #writes == 0)
end)
test("2 orphan warns before intentional changes", function()
    run("SLOT\t1\tclear\t\nENSURE\tB\tBUTTON")()
    says("Warning: PACK will be unbound: B to BUTTON.")
    assert(owners.B == "BUTTON" and #writes == 1 and slotEdits == 1 and BP.profiles.active().text)
end)
test("3 safe displacement", function()
    owners["CTRL-B"] = "PACK"
    run("ENSURE\tB\tBUTTON")()
    says("PACK remains on CTRL-B")
    assert(owners.B == "BUTTON" and owners["CTRL-B"] == "PACK" and saves == 1)
end)
test("4 unrelated bag key", function()
    run("ENSURE\tB\tBUTTON\nALLOWORPHAN\tPACK")()
    assert(owners["SHIFT-B"] == "ALLBAGS" and #writes == 1 and writes[1] == "B")
end)
test("5 addon key untouched", function()
    run("ENSURE\tF1\tBUTTON")()
    assert(owners.F13 == "ADDON" and #writes == 1)
end)
test("6 multiple keys", function()
    owners.F2 = "RUN"
    run("ENSURE\tR\tBUTTON")()
    assert(owners.F2 == "RUN" and owners.NUMLOCK == "RUN" and #writes == 1)
end)
test("7 final graph", function()
    run("ENSURE\tB\tBUTTON\nENSURE\tX\tPACK")()
    says("PACK remains on X")
    assert(owners.B == "BUTTON" and owners.X == "PACK" and saves == 1)
end)
test("8 guarded removal", function()
    run("REMOVE\tR\tRUN")()
    assert(not owners.R and owners.NUMLOCK == "RUN" and #writes == 1)
end)
test("9 legacy exact semantics", function()
    run("BIND\tR\tRUN", 1)()
    says("Legacy exact removal: NUMLOCK from RUN")
    assert(owners.R == "RUN" and not owners.NUMLOCK and #writes == 1)
end)
test("10 no-op", function()
    run("ENSURE\tB\tPACK\nENSURE\tF13\tADDON")()
    assert(#writes == 0 and saves == 0)
end)
test("conflicting intent", function()
    run("ENSURE\tctrl-shift-b\tPACK\nENSURE\tSHIFT-CTRL-B\tBUTTON")()
    says("competing instructions")
    assert(#writes == 0)
end)
test("multiple planned displacements orphan together", function()
    run("ENSURE\tR\tBUTTON\nENSURE\tNUMLOCK\tPACK")()
    says("RUN will be unbound: NUMLOCK to PACK, R to BUTTON.")
    assert(#writes == 2)
end)
test("guard rejects wrong owner", function()
    run("REMOVE\tB\tRUN")()
    says("Removal owner changed")
    assert(#writes == 0)
end)
test("changed account scope", function()
    local apply = run("ENSURE\tX\tPACK")
    scope = 1
    apply()
    assert(#writes == 0 and not BP.profiles.active().text)
end)
test("stale census", function()
    local apply = run("ENSURE\tX\tPACK")
    owners.X = "ADDON"
    apply()
    assert(#writes == 0 and not BP.profiles.active().text)
end)
test("failed write rolls back before slots", function()
    rejected = "Y"
    run("SLOT\t1\tclear\t\nENSURE\tX\tPACK\nENSURE\tY\tBUTTON")()
    says("Previous bindings restored")
    assert(not owners.X and not owners.Y and saves == 0 and slotEdits == 0)
end)
test("runtime-masked alternate", function()
    owners.X, overrides.X = "PACK", "CLICK Addon:A"
    run("ENSURE\tB\tBUTTON")()
    says("All remaining keys for PACK have runtime overrides.")
    says("Runtime override warnings: 0.")
    says("X -> CLICK Addon:A")
    assert(#writes == 0)
end)
test("unindexed dynamic owner", function()
    owners.X = "CLICK Frame:LeftButton"
    run("ENSURE\tX\tPACK")()
    says("CLICK Frame:LeftButton will be unbound: X to PACK.")
    assert(#writes == 1)
end)
test("census includes available, unbound and extra keys", function()
    owners.F3, overrides.R = "RUN", "CLICK Frame:A"
    local census = BP.bindings.census(function(s) return s end)
    local raw = BP.b64decode(census:sub(5))
    assert(raw:find("CMD\t0\tUNBOUND\tTEST\tUNBOUND\tbinding", 1, true))
    assert(raw:find("CMD\t0\tRUN\tTEST\tRUN\tbinding\tF3\tNUMLOCK\tR", 1, true))
    assert(raw:find("OVERRIDE\tR\tCLICK Frame:A", 1, true))
    assert(#writes == 0 and saves == 0)
end)
test("mixed versions rejected", function()
    assert(not BP.parse("BP2:" .. BP.b64encode("BARPLAN\t2\nBIND\tR\tRUN")))
end)
test("slot dry run reports skipped stale and cleared actions", function()
    run("SLOT\t4\tspell\tFuture Spell\nSLOT\t5\tclear\t")
    says("spell 100 -> Future Spell (future replacement; keep current: not learned yet)")
    says("spell 100 -> empty")
    local _, mentions = table.concat(details):gsub("Future Spell", "")
    assert(mentions == 1)
    assert(slotEdits == 0)
end)
test("explicit last removal is intentional", function()
    run("REMOVE\tB\tPACK")()
    says("PACK will be unbound: B (removed).")
    assert(not owners.B and saves == 1)
end)
test("account save uses the active set", function()
    scope = 1
    run("ENSURE\tF1\tADDON")()
    says("account-wide")
    assert(saves == 1)
end)
test("save error restores original keys and resaves original profile", function()
    local save = SaveBindings
    SaveBindings = function(set)
        saves = saves + 1
        assert(set == scope)
        if saves == 1 then error("Failed to save") end
    end
    run("ENSURE\tX\tPACK")()
    SaveBindings = save
    says("Previous bindings restored")
    assert(not owners.X and saves == 2)
end)
test("census collects sparse varargs and extra contexts", function()
    local get = GetBinding
    C_KeyBindings = { GetBindingContextForAction = function(cmd) return cmd == "PAD" and 9 or 0 end }
    registry[#registry + 1] = "PAD"
    GetBinding = function(i, includePad)
        if registry[i] == "PAD" then return "PAD", "Gamepad", nil, "PAD1", "PAD2" end
        return get(i, includePad)
    end
    local s = BP.bindings.capture()
    assert(s.rows.PAD.keys.PAD1 and s.rows.PAD.keys.PAD2 and not s.owners.PAD1)
    run("ENSURE\tX\tPAD")()
    says("Unsupported binding context")
    assert(#writes == 0)
    GetBinding, C_KeyBindings = get, nil
end)
test("ordinary Check uses one chat line and a count summary", function()
    run("ENSURE\tR\tRUN\nENSURE\tB\tPACK\nENSURE\tF13\tADDON")
    assert(#output == 1 and output[1]:find("Check OK - 0 binding changes", 1, true))
    assert(output[1]:find("Open Details", 1, true))
    says("Bindings: 0 to change, 3 already correct, 1 safely preserved.")
    says("Displaced commands: 0. Orphaned: 0. Blocking errors: 0. Runtime override warnings: 0.")
end)
test("only Full diagnostics shows each correct and preserved key", function()
    run("ENSURE\tR\tRUN")
    assert(not table.concat(summary):find("NUMLOCK") and not table.concat(output):find("NUMLOCK"))
    assert(#details == 1 and details[1] == "No changes or warnings.")
    says("Already correct: R -> RUN")
    says("Preserved on RUN: NUMLOCK")
end)
test("orphan summary counts commands once and precedes details", function()
    run("ENSURE\tR\tBUTTON\nENSURE\tNUMLOCK\tBUTTON")
    assert(output[1]:find("Check OK", 1, true))
    assert(summary[2]:find("Displaced commands: 1. Orphaned: 1. Blocking errors: 0.", 1, true))
    assert(output[2]:find("RUN will be unbound", 1, true))
    says("Displacement: R from RUN to BUTTON")
end)
test("safe displacements, removals and runtime warnings remain visible", function()
    owners.X, overrides.X = "PACK", "CLICK Frame:A"
    owners["CTRL-B"] = "PACK"
    run("ENSURE\tB\tBUTTON\nREMOVE\tR\tRUN\nENSURE\tX\tPACK\nENSURE\tF2\tBUTTON")
    says("Bindings: 3 to change, 1 already correct, 2 safely preserved.")
    says("Displaced commands: 1. Orphaned: 0. Blocking errors: 0. Runtime override warnings: 1.")
    says("PACK remains on CTRL-B, X")
    says("Runtime override on X: CLICK Frame:A")
    says("RUN remains on NUMLOCK")
    says("Explicit removal: R from RUN")
    says("New binding: F2 -> BUTTON")
end)
test("informational overrides only appear in Full diagnostics", function()
    overrides.R, overrides.F13 = "CombatModeSlot1", "CombatModeSlot2"
    run("ENSURE\tR\tRUN")
    assert(#output == 1 and not table.concat(output):find("CombatMode"))
    assert(not table.concat(summary):find("CombatMode"))
    says("Runtime override warnings: 0.")
    assert(not table.concat(details):find("CombatMode"))
    says("Runtime override on R: CombatModeSlot1")
    says("Runtime override on F13: CombatModeSlot2")
end)
test("override on a changed key warns without blocking", function()
    overrides.X = "CombatModeSlot3"
    run("ENSURE\tX\tBUTTON")()
    assert(table.concat(summary):find("Warning: Runtime override on X: CombatModeSlot3", 1, true))
    assert(owners.X == "BUTTON")
end)
test("acknowledgment cannot bypass an unsafe fallback", function()
    owners.X, overrides.X = "PACK", "CombatModeSlot3"
    run("ENSURE\tB\tBUTTON\nALLOWORPHAN\tPACK")()
    assert(output[1]:find("Check BLOCKED", 1, true))
    assert(output[2]:find("All remaining keys for PACK have runtime overrides.", 1, true))
    assert(#writes == 0)
end)
test("Details keeps changes and safety issues in a mixed report", function()
    overrides.F2, overrides.F13 = "CombatModeSlot2", "CombatModeSlot13"
    run("ENSURE\tB\tBUTTON\nENSURE\tF2\tRUN\nENSURE\tF13\tADDON\nREMOVE\tR\tRUN\n"
        .. "SLOT\t4\tspell\tFuture Spell\nSLOT\t5\tclear\t\nSLOT\t6\tspell\tspell:100")
    local changes = table.concat(details, "\n")
    for _, msg in ipairs({"Displacement: B", "PACK will be unbound", "Runtime override on F2",
        "New binding: F2", "Explicit removal: R", "RUN remains on", "Future Spell (future replacement", "[5]: spell 100 -> empty"}) do
        assert(changes:find(msg, 1, true), changes)
        assert(table.concat(full, "\n"):find(msg, 1, true))
    end
    for _, msg in ipairs({"CombatModeSlot13", "Already correct: F13", "[6]: spell 100 -> already correct"}) do
        assert(not changes:find(msg, 1, true) and table.concat(full, "\n"):find(msg, 1, true))
    end
end)
test("changing a runtime override after Check invalidates Apply", function()
    local apply = run("ENSURE\tX\tBUTTON")
    overrides.R = "CombatModeSlot4"
    apply()
    says("Run Check again.")
    apply()
    says("Run Check before Apply.")
    assert(#writes == 0 and not BP.profiles.active().text)
end)
for version = 1, 2 do
    test("BP" .. version .. " places learned names missing from the book and keeps explicit ranks", function()
        -- Both book APIs enumerate zero entries. The modern name lookup returns
        -- the learned override, while generic GetSpellInfo can return its base.
        local ids = { ["Find Herbs"] = 701, ["Feral Charge"] = 702, ["Feral Charge(Cat)"] = 702,
            ["Heal(Rank 1)"] = 703, ["Heal(Rank 9)"] = 703, ["Future Spell"] = 704, ["Passive Talent"] = 705 }
        local learned = { [701] = true, [702] = true, [703] = true, [705] = true }
        local slots, pickups, cursor = {}, {}, nil
        local getAction, hasAction, clear = GetActionInfo, HasAction, ClearCursor
        local function pickup(id) pickups[#pickups + 1] = id; cursor = id end
        local function sub(id) return id == 702 and "Cat" or id == 703 and "Rank 1" or "" end
        if version == 1 then
            GetSpellInfo = function(name)
                if type(name) == "number" then return name == 703 and "Heal" or "Feral Charge" end
                return name, nil, nil, nil, nil, nil, ids[name]
            end
            GetSpellSubtext, PickupSpell = sub, pickup
            IsSpellKnown = function(id) return learned[id] end
            IsPassiveSpell = function(id) return id == 705 end
        else
            C_Spell = {
                GetSpellIDForSpellIdentifier = function(name)
                    if name ~= "Find Herbs" then return ids[name] end
                end,
                GetSpellInfo = function(name)
                    return { spellID = name == "Feral Charge" and 900 or ids[name] }
                end,
                GetSpellSubtext = sub, PickupSpell = pickup,
                IsSpellPassive = function(id) return id == 705 end,
            }
            C_SpellBook = { IsSpellKnownOrInSpellBook = function(id) return learned[id] end }
        end
        ClearCursor = function() cursor = nil end
        GetCursorInfo = function() if cursor then return "spell", cursor end end
        PlaceAction = function(slot) slots[slot] = assert(cursor) end
        HasAction = function(slot) return slots[slot] ~= nil end
        GetActionInfo = function(slot) if slots[slot] then return "spell", slots[slot] end end
        local apply = run("SLOT\t1\tspell\tFind Herbs\nSLOT\t2\tspell\tFeral Charge\n"
            .. "SLOT\t3\tspell\tFeral Charge (Cat)\nSLOT\t4\tspell\tHeal(Rank 1)\n"
            .. "SLOT\t5\tspell\tFuture Spell\nSLOT\t6\tspell\tHeal(Rank 9)\nSLOT\t7\tspell\tPassive Talent", version)
        assert(#pickups == 0)
        apply()
        GetActionInfo, HasAction, ClearCursor = getAction, hasAction, clear
        GetCursorInfo, PlaceAction, PickupSpell, IsPassiveSpell, IsSpellKnown = nil, nil, nil, nil, nil
        GetSpellInfo, GetSpellSubtext, C_SpellBook, C_Spell = nil, nil, nil, nil
        says("4 slot changes, 3 skipped")
        assert(#pickups == 4 and slots[1] == 701 and slots[2] == 702 and slots[3] == 702 and slots[4] == 703)
        assert(not slots[5] and not slots[6] and not slots[7])
        assert(BP.parse(BP.profiles.active().text).slots[1].value == "Find Herbs")
    end)
end
test("setup export round-trips exact slot IDs", function()
    local actions = { 301, 302, 303, 304, 305, 306, 307 }
    local names = { [301] = "Feral Charge (Cat)", [302] = "Find Herbs", [303] = "Talent Surge",
        [304] = "Heal", [305] = "Heal", [307] = "Focus (Bear)" }
    local book = { {301, names[301]}, {999, names[303]}, {304, "Heal", "Rank 1"}, {305, "Heal", "Rank 2"},
        {310, "Focus", "Bear"} }
    local getAction, hasAction, getClass = GetActionInfo, HasAction, UnitClass
    UnitName = function() return "Druid" end
    UnitClass = function() return "Druid", "DRUID" end
    HasAction = function(slot)
        return actions[slot] ~= nil or (slot >= 109 and slot < 109 + #actions) or slot == 8 or slot == 116
    end
    GetActionInfo = function(slot)
        if slot == 8 or slot == 116 then return "item", 42 end
        local id = actions[slot] or actions[slot - 108]
        if id then return "spell", id end
    end
    C_Item = { GetItemNameByID = function() return "Spent item" end,
        GetItemInfoInstant = function() return 42 end, GetItemCount = function() return 0 end }
    C_Spell = { GetSpellName = function(id) return names[id] end,
        GetSpellSubtext = function(id) return id == 304 and "Rank 1" or id == 303 and "Talent" or "" end }
    IsPlayerSpell = function() return false end
    GetNumSpellTabs = function() return 1 end
    GetSpellTabInfo = function() return nil, nil, 0, #book end
    GetSpellBookItemName = function(i) return book[i][2], book[i][3] end
    GetSpellBookItemInfo = function(i) return "SPELL", book[i][1] end

    local text = BP.exportCurrent()
    local expected = {"spell:301", "spell:302", "spell:303", "Heal(Rank 1)", "Heal", "spell:306", "spell:307", "item:42"}
    local plan = assert(BP.parse(text))
    assert(#plan.slots == #expected)
    for _, slot in ipairs(plan.slots) do assert(slot.value == expected[slot.slot], slot.value) end
    local _, report, changes = BP.run(text, true)
    assert(#changes == 1 and changes[1] == "No changes or warnings.")
    local lines = table.concat(report, "\n")
    assert(lines:find("0 to fill, 0 to clear, 8 already right", 1, true), lines)
    assert(not lines:find("compatibility copy", 1, true), lines)
    assert(lines:find("[1]: Feral Charge (Cat) (spell 301) -> already correct", 1, true))
    assert(not lines:find("[109", 1, true))
    assert(not lines:find("skipped") and #output == 1)
    BP.run(text, false)
    assert(BP.profiles.active().text == text and slotEdits == 0)

    -- The very same unknown ID must still skip on a different slot.
    local _, other = BP.run(BP.serialize({ slots = {{slot = 12, kind = "spell", value = "spell:302"}} }), true)
    assert(table.concat(other):find("skipped spell:302", 1, true))
    GetActionInfo, HasAction, UnitClass = getAction, hasAction, getClass
    C_Item, C_Spell = nil, nil
    IsPlayerSpell = function(id) return id == 100 end
    GetNumSpellTabs, GetSpellTabInfo, GetSpellBookItemName, GetSpellBookItemInfo = nil, nil, nil, nil
end)
test("real frame gates Apply, switches reports, and invalidates edits immediately", function()
    local buttons, window, profileName = {}
    local noop = function() end
    local methods = {}
    local function widget(kind, name, parent, template)
        local w = setmetatable({ kind = kind, scripts = {}, enabled = true, text = "" },
            { __index = function(_, k) return methods[k] or noop end })
        if name == "BarsmithFrame" then window = w end
        if template == "InputBoxTemplate" then profileName = w end
        return w
    end
    methods.CreateFontString, methods.CreateTexture = widget, widget
    function methods:SetText(value)
        self.text = value
        if self.kind == "Button" then buttons[value] = self end
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
    end
    function methods:GetText() return self.text end
    function methods:HookScript(event, handler) self.scripts[event] = handler end
    function methods:SetSize(width, height) self.width, self.height = width, height end
    function methods:SetPoint(point, x, y) self.anchor, self.x, self.y = point, x, y end
    function methods:SetScript(event, handler) self.scripts[event] = handler end
    function methods:Show() self.visible = true end
    function methods:Hide() self.visible = false end
    function methods:Enable() self.enabled = true end
    function methods:Disable() self.enabled = false end
    function methods:HighlightText() self.selected = self.text end
    CreateFrame, UISpecialFrames, tinsert = widget, {}, table.insert
    SlashCmdList.BARSMITH("")
    local function click(label)
        local button = buttons[label]
        assert(button.enabled and button.visible ~= false, label)
        button.scripts.OnClick(button)
    end
    -- Check the actual anchored control bounds at the fixed frame size.
    for _, labels in ipairs({
        { "Select profile", "Managed bars..." },
        { "Save new", "Rename", "Duplicate", "Delete", "Import old plan" },
        { "Review pending updates", "Revert last Apply", "Confirm", "Cancel" },
    }) do
        local right = 0
        for _, label in ipairs(labels) do
            local b = assert(buttons[label])
            assert(b.anchor == "BOTTOMLEFT" and b.x >= right and b.x + b.width <= window.width - 10, label)
            right = b.x + b.width + 4
        end
    end
    for _, label in ipairs({ "Import old plan", "Census", "Revert last Apply", "Review pending updates" }) do
        assert(buttons[label].scripts.OnEnter and buttons[label].scripts.OnLeave)
    end
    local slotsOnly = BP.serialize({ slots = {{slot = 1, kind = "clear", value = ""}} })
    window.edit:SetText(slotsOnly)
    assert(not buttons.Apply.enabled and window.hint.text == "Run Check before Apply.")
    BP.run(slotsOnly, false)
    assert(slotEdits == 0)
    click("Check")
    assert(buttons.Apply.enabled)
    window.edit:SetText(slotsOnly .. " ")
    window.edit:SetText(slotsOnly)
    assert(not buttons.Apply.enabled)
    BP.run(slotsOnly, false)
    assert(slotEdits == 0)
    click("Check")
    click("Apply")
    assert(slotEdits == 1 and not buttons.Apply.enabled)
    window.edit:SetText(BP.serialize({ binds = {{ key = "B", command = "BUTTON" }, { key = "R", command = "RUN" }} }))
    click("Check")
    local warning = "Warning: PACK will be unbound: B to BUTTON."
    assert(buttons.Apply.enabled and window.status.text:find(warning, 1, true))
    assert(not window.status.text:find("Displacement:"))
    click("Details")
    assert(window.status.text:find(warning, 1, true) and window.status.text:find("Displacement:"))
    local normal = window.status.text
    assert(not normal:find("Already correct: R"))
    click("Full diagnostics")
    local exhaustive = window.status.text
    assert(exhaustive:find("Already correct: R") and exhaustive:find(warning, 1, true))
    click("Copy report")
    assert(window.status.selected == exhaustive)
    click("Hide diagnostics")
    assert(window.status.text == normal)
    click("Full diagnostics")
    click("Check")
    assert(not window.diagnosticsButton.visible and buttons.Apply.enabled)
    click("Details")
    assert(window.status.text == normal)
    click("Summary")
    click("Copy report")
    assert(window.status.selected == normal)
    assert(window.status.selected:find("Displacement:"))
    window.status.text = "accidental edit"
    window.status.scripts.OnTextChanged(window.status, true)
    assert(window.status.text == window.status.selected and window.status.text:find(warning, 1, true))
    owners.B = "ADDON"
    click("Apply")
    assert(not buttons.Apply.enabled and #writes == 0 and window.status.text:find("Run Check again."))
    window.edit:SetText(BP.serialize({ binds = {{ key = "B", command = "BUTTON" }, { key = "B", command = "RUN" }} }))
    click("Check")
    assert(not buttons.Apply.enabled and window.status.text:find("competing instructions"))
    click("Details")
    assert(window.status.text:find("competing instructions"))

    -- Use the actual window controls to save a draft, apply, preview/cancel
    -- Revert, confirm it, and delete the profile.
    local plan = BP.serialize({ binds = {{ key = "B", command = "BUTTON" }} })
    window.edit:SetText(plan)
    profileName:SetText("Healing")
    click("Save new")
    local profile, character = BP.profiles.active()
    assert(character.active == "Healing" and profile.text == plan and owners.B == "ADDON")
    click("Check"); click("Apply")
    assert(owners.B == "BUTTON" and profile.undo)
    click("Revert last Apply"); click("Details")
    assert(window.status.text:find("ADDON") and owners.B == "BUTTON")
    click("Cancel")
    assert(profile.undo and owners.B == "BUTTON")
    click("Revert last Apply"); click("Confirm revert")
    assert(owners.B == "ADDON" and not profile.undo)
    click("Delete"); click("Delete profile")
    assert(character.active == "Default" and not character.profiles.Healing)

    local root
    local function menuNode(label)
        local node = { label = label, children = {} }
        function node:CreateButton(text, click)
            local child = menuNode(text)
            self.children[text], child.click = child, click
            return child
        end
        function node:CreateRadio(text, selected, click)
            local child = self:CreateButton(text, click)
            child.selected = selected
        end
        node.CreateCheckbox = node.CreateRadio
        function node:CreateTitle(text) self.title = text end
        function node:SetScrollMode(limit) self.limit = limit end
        node.CreateDivider = noop
        return node
    end
    MenuUtil = { CreateContextMenu = function(owner, build)
        root = menuNode()
        build(owner, root)
    end }
    GetUnitName = function() return "Seren Grey" end
    GetRealmName = function() return "" end
    local imported = BP.serialize({name = "Leveling", slots = {}})
    assert(buttons["Import old plan"].visible == false)
    BarsmithDB.last = imported
    BP.profiles.init()
    click("Select profile")
    assert(root.title == "Seren Grey" and root.limit and root.children.Default.selected())
    window.edit:SetText(imported)
    click("Save new")
    assert(character.active == "Leveling" and buttons["Import old plan"].visible)
    click("Select profile")
    root.children.Default.click()
    assert(character.active == "Default")
    click("Import old plan")
    assert(window.edit:GetText() == imported and BarsmithDB.legacyPlan == imported and not buttons.Apply.enabled)
    click("Check"); click("Apply")
    assert(not BarsmithDB.legacyPlan and not buttons["Import old plan"].visible)

    -- Long profile lists remain selectable by name. A foreign row can only copy.
    for i = 1, 80 do character.profiles["Layout " .. i] = {} end
    BarsmithDB.characters.alt = { name = "Seren Grey", realm = "Other Realm",
        profiles = { Holy = { text = plan, overwrite = true } }, active = "Holy" }
    click("Select profile")
    assert(root.children.Default.selected() and root.children["Layout 80"] and root.limit <= 360)
    local group = root.children["Other characters"].children["Seren Grey - Other Realm"]
    assert(group.title == "Copy to Seren Grey" and group.limit)
    group.children.Holy.click()
    assert(character.active == "Holy" and BP.profiles.active() ~= BarsmithDB.characters.alt.profiles.Holy)
    assert(not BP.profiles.active().pending and not buttons.Apply.enabled)
    click("Check")
    click("Managed bars...")
    local bar = root.children["Bar 2 (61–72)"]
    assert(bar.selected())
    bar.click()
    assert(not bar.selected() and not buttons.Apply.enabled and window.edit:GetText() == plan)
end)
print(passed .. " passed, " .. failures .. " failed")
assert(failures == 0)

-- Run at the repository root with lua or texlua. Exercise the real Check/Apply entry point.
local owners, registry, overrides, scope, writes, saves, rejected, output, clears, slotEdits
local unpack = table.unpack or unpack
local failures, passed = 0, 0
local function test(name, fn)
    owners = { R = "RUN", NUMLOCK = "RUN", B = "PACK", ["SHIFT-B"] = "ALLBAGS", F13 = "ADDON" }
    registry = { "RUN", "PACK", "BUTTON", "ALLBAGS", "ADDON", "UNBOUND" }
    overrides, scope, writes, saves, rejected, output, clears, slotEdits = {}, 2, {}, 0, nil, {}, 0, 0
    BarsmithDB = {}
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
GetActionInfo = function() return "spell", 100 end
HasAction = function() return true end
PickupAction = function() slotEdits = slotEdits + 1 end
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, line) output[#output+1] = line end }

dofile("addon/Barsmith/Bindings.lua")
dofile("addon/Barsmith/Barsmith.lua")
local BP = Barsmith
local function run(records, version, verbose)
    version = version or 2
    local text = "BP" .. version .. ":" .. BP.b64encode("BARPLAN\t" .. version .. "\n" .. records)
    BP.run(text, true, verbose)
    assert(#writes == 0 and saves == 0 and clears == 0 and slotEdits == 0, "Check mutated state")
    return function() BP.run(text, false) end
end
local function says(msg)
    assert(table.concat(output, "\n"):find(msg, 1, true), table.concat(output, "\n"))
end

test("1 preserve Autorun", function()
    run("ENSURE\tR\tRUN")()
    says("Bindings: 0 to change, 1 already correct, 1 safely preserved.")
    assert(owners.NUMLOCK == "RUN" and owners.R == "RUN" and #writes == 0)
end)
test("2 orphan gates even slot edits", function()
    run("SLOT\t1\tclear\t\nENSURE\tB\tBUTTON")()
    says("Orphan: PACK will be unbound.")
    assert(owners.B == "PACK" and #writes == 0 and slotEdits == 0 and not BarsmithDB.last)
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
    says("Orphan: RUN")
    assert(#writes == 0)
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
    assert(#writes == 0 and not BarsmithDB.last)
end)
test("stale census", function()
    local apply = run("ENSURE\tX\tPACK")
    owners.X = "ADDON"
    apply()
    assert(#writes == 0 and not BarsmithDB.last)
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
    says("Runtime override warnings: 1.")
    says("X -> CLICK Addon:A")
    assert(#writes == 0)
end)
test("unindexed dynamic owner", function()
    owners.X = "CLICK Frame:LeftButton"
    run("ENSURE\tX\tPACK")()
    says("Orphan: CLICK Frame:LeftButton")
    assert(#writes == 0)
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
    says("spell 100 -> keep current (skipped Future Spell)")
    says("spell 100 -> empty")
    local _, mentions = table.concat(output):gsub("Future Spell", "")
    assert(mentions == 1)
    assert(slotEdits == 0)
end)
test("explicit last removal is intentional", function()
    run("REMOVE\tB\tPACK")()
    says("Orphan: PACK will be unbound. Explicitly requested.")
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
test("ordinary Check summarizes all matching keys in two lines", function()
    run("ENSURE\tR\tRUN\nENSURE\tB\tPACK\nENSURE\tF13\tADDON")
    assert(#output == 2)
    says("Bindings: 0 to change, 3 already correct, 1 safely preserved.")
    says("Displaced commands: 0. Orphaned: 0. Blocking errors: 0. Runtime override warnings: 0.")
end)
test("verbose Check still shows each correct and preserved key", function()
    run("ENSURE\tR\tRUN", 2, true)
    says("Already correct: R -> RUN")
    says("Preserved on RUN: NUMLOCK")
end)
test("orphan summary counts commands once and precedes details", function()
    run("ENSURE\tR\tBUTTON\nENSURE\tNUMLOCK\tBUTTON")
    assert(output[1]:find("Check BLOCKED", 1, true))
    assert(output[2]:find("Displaced commands: 1. Orphaned: 1. Blocking errors: 1.", 1, true))
    says("Orphan: RUN will be unbound.")
    says("Displacement: R from RUN to BUTTON")
end)
test("safe displacements, removals and runtime warnings remain visible", function()
    owners.X, overrides.X = "PACK", "CLICK Frame:A"
    owners["CTRL-B"] = "PACK"
    run("ENSURE\tB\tBUTTON\nREMOVE\tR\tRUN\nENSURE\tX\tPACK\nENSURE\tF2\tBUTTON")
    says("Bindings: 3 to change, 1 already correct, 2 safely preserved.")
    says("Displaced commands: 1. Orphaned: 0. Blocking errors: 0. Runtime override warnings: 1.")
    says("PACK remains on CTRL-B, X")
    says("Override on X: CLICK Frame:A")
    says("RUN remains on NUMLOCK")
    says("Explicit removal: R from RUN")
    says("New binding: F2 -> BUTTON")
end)
print(passed .. " passed, " .. failures .. " failed")
assert(failures == 0)

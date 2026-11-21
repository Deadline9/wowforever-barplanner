-- Barsmith: applies a plan made on the Barsmith page (index.html).
-- Paste the plan string into /barsmith and press Apply. It
--   * creates or updates the plan's macros (matched by name),
--   * puts spells, macros and items into the planned action slots,
--   * binds the planned keys to the planned buttons and saves the bindings.
-- Slots and buttons that are not in the plan are left alone.
--
-- EllesmereUI, Bartender4, Dominos and ElvUI show the game's normal action slots
-- and pass the game's normal button bindings (ACTIONBUTTON1, MULTIACTIONBAR1BUTTON1, ...)
-- on to their own buttons, so whatever this addon sets shows up on those bars.
-- Some of them switch the main bar in forms where the game doesn't; see COPY_PAGES.
--
-- The last applied plan is kept in BarsmithDB. With auto-fill on (the default),
-- a spell you learn or an item you get later goes into its planned slot if that slot is empty.

Barsmith = Barsmith or {}
local BP = Barsmith

local B = BP.bindings
local DEFAULT_ICON = "INV_Misc_QuestionMark"
local MACRO_BODY_MAX = 255

------------------------------------------------------------------------
-- Bars, slots and binding commands (same tables as index.html)
------------------------------------------------------------------------

-- first = first action slot of the bar, bind = binding command prefix
local PAGES = {
    { first = 1,   label = "Bar 1",          bind = "ACTIONBUTTON" },
    { first = 61,  label = "Bar 2",          bind = "MULTIACTIONBAR1BUTTON" },
    { first = 49,  label = "Bar 3",          bind = "MULTIACTIONBAR2BUTTON" },
    { first = 25,  label = "Bar 4",          bind = "MULTIACTIONBAR3BUTTON" },
    { first = 37,  label = "Bar 5",          bind = "MULTIACTIONBAR4BUTTON" },
    { first = 145, label = "Bar 6",          bind = "MULTIACTIONBAR5BUTTON" },
    { first = 157, label = "Bar 7",          bind = "MULTIACTIONBAR6BUTTON" },
    { first = 169, label = "Bar 8",          bind = "MULTIACTIONBAR7BUTTON" },
    { first = 73,  label = "Bar 1 stance 1" },
    { first = 85,  label = "Bar 1 stance 2" },
    { first = 97,  label = "Bar 1 stance 3" },
    { first = 109, label = "Bar 1 stance 4" },
    { first = 13,  label = "Bar 1 page 2" }, -- Shift+2; pages 3-6 are bars 4, 5, 3 and 2
}

-- Main bar pages some bar addons switch to although Forever's own bars don't. Apply fills each with
-- a copy of the page the game shows in that form, so the main bar looks the same either way.
-- The game never shows these slots, so the copies don't change anything without such an addon.
--   Shadowform:   Dominos and ElvUI switch to 73-84; the game keeps the normal main bar.
--   Moonkin Form: Dominos switches to 109-120; the game keeps the normal main bar.
--   Prowl:        Bartender4 and ElvUI switch to 85-96; the game keeps the Cat Form page (73-84).
local COPY_PAGES = {
    PRIEST = { { from = 1, to = 73, label = "Shadowform" } },
    DRUID = { { from = 1, to = 109, label = "Moonkin Form" }, { from = 73, to = 85, label = "Prowl" } },
}

local function copyPagesFor(class)
    return COPY_PAGES[class] or {}
end

-- The plan's slots plus their copies (marked copy = true). A slot the plan sets itself is never overwritten.
local function slotsWithCopies(plan, class)
    local list, bySlot = {}, {}
    for _, s in ipairs(plan.slots) do
        list[#list + 1] = s
        bySlot[s.slot] = s
    end
    for _, c in ipairs(copyPagesFor(class)) do
        for i = 0, 11 do
            local s = bySlot[c.from + i]
            if s and not bySlot[c.to + i] then
                list[#list + 1] = { slot = c.to + i, kind = s.kind, value = s.value, copy = true }
            end
        end
    end
    return list
end

-- Non-bar commands the planner offers under "Other keybinds".
local OTHER_COMMANDS = {
    "MOVEFORWARD", "MOVEBACKWARD", "TURNLEFT", "TURNRIGHT", "STRAFELEFT", "STRAFERIGHT",
    "JUMP", "TOGGLEAUTORUN", "SITORSTAND", "TOGGLESHEATH",
    "TARGETNEARESTENEMY", "TARGETPREVIOUSENEMY", "TARGETNEARESTFRIEND", "ASSISTTARGET",
    "INTERACTTARGET", "TARGETSELF", "TARGETPARTYMEMBER1", "TARGETPARTYMEMBER2",
    "TARGETPARTYMEMBER3", "TARGETPARTYMEMBER4", "OPENALLBAGS", "TOGGLEWORLDMAP",
}

local function slotLabel(slot)
    for _, p in ipairs(PAGES) do
        if slot >= p.first and slot < p.first + 12 then
            return p.label .. " button " .. (slot - p.first + 1)
        end
    end
    return "slot " .. slot
end

local function allCommands()
    local list = {}
    for _, p in ipairs(PAGES) do
        if p.bind then
            for i = 1, 12 do list[#list + 1] = p.bind .. i end
        end
    end
    for i = 1, 10 do list[#list + 1] = "SHAPESHIFTBUTTON" .. i end -- stance bar
    for i = 1, 10 do list[#list + 1] = "BONUSACTIONBUTTON" .. i end -- pet bar
    for _, c in ipairs(OTHER_COMMANDS) do list[#list + 1] = c end
    return list
end

------------------------------------------------------------------------
-- Plan string: "BP2:" (legacy "BP1:" also accepted) + base64 of UTF-8 text, one record per line,
-- fields separated by tabs. Backslash, tab and newline inside a field
-- are written as \\, \t and \n.
--   BARPLAN <version>
--   CLASS   <WARRIOR, SHAMAN, ...> (optional; Apply refuses a plan for another class)
--   RACE    <race name> (optional; the planner uses it for racials and the backdrop)
--   NAME    <plan name>
--   MACRO   <name> <icon> <0|1 per character> <body>
--   SLOT    <slot> <spell|macro|item|clear> <value>
--   ENSURE | REMOVE <key> <command>; ALLOWORPHAN <command>
--   BP1 only: BIND <key> <command> (exact keys on each named command)
-- No WoW API is used in this section, so it can be tested outside the game.
------------------------------------------------------------------------

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64DEC = {}
for i = 1, 64 do B64DEC[B64:byte(i)] = i - 1 end

function BP.b64encode(s)
    local out = {}
    for i = 1, #s, 3 do
        local a, b, c = s:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
            .. (b and B64:sub(c3 + 1, c3 + 1) or "=")
            .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

function BP.b64decode(s)
    local out = {}
    local bits, nbits = 0, 0
    for i = 1, #s do
        local v = B64DEC[s:byte(i)]
        if v then -- skips padding, spaces and line breaks
            bits = bits * 64 + v
            nbits = nbits + 6
            if nbits >= 8 then
                nbits = nbits - 8
                local p = 2 ^ nbits
                local byte = math.floor(bits / p)
                bits = bits - byte * p
                out[#out + 1] = string.char(byte)
            end
        end
    end
    return table.concat(out)
end

local UNESC = { n = "\n", t = "\t", ["\\"] = "\\" }
local function unesc(s)
    return ((s or ""):gsub("\\(.)", UNESC))
end

local function esc(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\")
    s = s:gsub("\t", "\\t")
    s = s:gsub("\r", "")
    s = s:gsub("\n", "\\n")
    return s
end

local function splitTabs(line)
    local t = {}
    for f in (line .. "\t"):gmatch("(.-)\t") do t[#t + 1] = f end
    return t
end

local function trim(s)
    return ((s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Cut a UTF-8 string to at most n bytes without splitting a character.
local function cutBytes(s, n)
    if #s <= n then return s end
    local i = n + 1
    while i > 1 and s:byte(i) >= 0x80 and s:byte(i) < 0xC0 do i = i - 1 end
    return s:sub(1, i - 1)
end

-- Returns plan or nil, error message.
function BP.parse(text)
    text = trim(text)
    if text == "" then return nil, "Paste a plan string first." end
    local expected = tonumber(text:match("^BP([12]):"))
    if not expected then return nil, "Paste a BP2 or legacy BP1 plan." end
    local payload = text:sub(5):gsub("%s+", "")
    local raw = BP.b64decode(payload)
    if expected == 2 and BP.b64encode(raw) ~= payload then return nil, "Invalid BP2 encoding." end
    local plan = { name = "", macros = {}, slots = {}, binds = {} }
    local version
    for line in raw:gmatch("[^\n]+") do
        local f = splitTabs((line:gsub("\r$", "")))
        local kind = f[1]
        if kind == "BARPLAN" then
            if version then return nil, "Duplicate plan header." end
            version = tonumber(f[2])
        elseif kind == "CLASS" then
            plan.class = f[2]
        elseif kind == "RACE" then
            plan.race = unesc(f[2])
        elseif kind == "NAME" then
            plan.name = unesc(f[2])
        elseif kind == "MACRO" and f[2] and f[2] ~= "" then
            plan.macros[#plan.macros + 1] = {
                name = unesc(f[2]), icon = unesc(f[3]), perChar = f[4] == "1", body = unesc(f[5]),
            }
        elseif kind == "SLOT" and tonumber(f[2]) and f[3] then
            plan.slots[#plan.slots + 1] = { slot = tonumber(f[2]), kind = f[3], value = trim(unesc(f[4])) }
        elseif kind == "BIND" or kind == "ENSURE" or kind == "REMOVE" or kind == "ALLOWORPHAN" then
            if (kind == "BIND") ~= (expected == 1) then return nil, "Wrong binding syntax for this plan version." end
            local ack = kind == "ALLOWORPHAN"
            if #f ~= (ack and 2 or 3) or f[2] == "" or f[3] == "" then return nil, "Invalid " .. kind .. " record." end
            local command = f[ack and 2 or 3]
            if expected == 2 then command = unesc(command) end
            local key
            if not ack then key = B.key(expected == 2 and unesc(f[2]) or f[2]) end
            plan.binds[#plan.binds + 1] = { op = kind, command = command, key = key }
        elseif expected == 2 then
            return nil, "Unknown or malformed record: " .. kind
        end
    end
    if version ~= expected then return nil, "Plan header and prefix must match." end
    plan.version = version
    return plan
end

function BP.serialize(plan)
    local version = plan.version or 2
    local lines = { "BARPLAN\t" .. version }
    if plan.class then lines[#lines + 1] = "CLASS\t" .. plan.class end
    if plan.race then lines[#lines + 1] = "RACE\t" .. esc(plan.race) end
    if plan.name and plan.name ~= "" then lines[#lines + 1] = "NAME\t" .. esc(plan.name) end
    for _, m in ipairs(plan.macros or {}) do
        lines[#lines + 1] = table.concat({ "MACRO", esc(m.name), esc(m.icon), m.perChar and "1" or "0", esc(m.body) }, "\t")
    end
    for _, s in ipairs(plan.slots or {}) do
        lines[#lines + 1] = table.concat({ "SLOT", s.slot, s.kind, esc(s.value) }, "\t")
    end
    for _, b in ipairs(plan.binds or {}) do
        if version == 1 then lines[#lines + 1] = table.concat({ "BIND", b.key, b.command }, "\t")
        elseif b.op == "ALLOWORPHAN" then lines[#lines + 1] = "ALLOWORPHAN\t" .. esc(b.command)
        else lines[#lines + 1] = table.concat({ b.op or "ENSURE", esc(b.key), esc(b.command) }, "\t") end
    end
    return "BP" .. version .. ":" .. BP.b64encode(table.concat(lines, "\n"))
end

-- Everything below needs the game client.
if not CreateFrame then return end

------------------------------------------------------------------------
-- Game API wrappers (Forever has a mix of old and new spell APIs)
------------------------------------------------------------------------

local BOOK = BOOKTYPE_SPELL or "spell"

local function say(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff0cd29fBarsmith|r: " .. msg)
end

local function getSpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
end

local function getSpellSubtext(id)
    if C_Spell and C_Spell.GetSpellSubtext then return C_Spell.GetSpellSubtext(id) end
    if GetSpellSubtext then return GetSpellSubtext(id) end
end

local function getSpellIDByName(name)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(name)
        if info then return info.spellID end
    end
    if GetSpellInfo then return (select(7, GetSpellInfo(name))) end
end

local function pickupSpellID(id)
    if C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(id)
    elseif PickupSpell then PickupSpell(id) end
end

local function isKnownSpell(id)
    return (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id)) or false
end

local function getItemName(id)
    if C_Item and C_Item.GetItemNameByID then return C_Item.GetItemNameByID(id) end
    if GetItemInfo then return (GetItemInfo(id)) end
end

local function getItemID(nameOrID)
    if C_Item and C_Item.GetItemInfoInstant then return (C_Item.GetItemInfoInstant(nameOrID)) end
    if GetItemInfoInstant then return (GetItemInfoInstant(nameOrID)) end
end

local function pickupItem(id)
    if C_Item and C_Item.PickupItem then C_Item.PickupItem(id) else PickupItem(id) end
end

-- The game only lets you pick up an item you carry or wear.
local function haveItem(id)
    local count = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id)) or (GetItemCount and GetItemCount(id)) or 0
    if count > 0 then return true end
    local equipped = (C_Item and C_Item.IsEquippedItem) or IsEquippedItem
    return equipped and equipped(id) or false
end

local function useNewSpellBook()
    return C_SpellBook and C_SpellBook.GetSpellBookItemInfo and Enum and Enum.SpellBookSpellBank
end

-- Usable (non-passive) spells in the player's spellbook, in book order.
-- Ranks of a spell are listed lowest first, so the last match is the highest rank.
local function spellbookEntries()
    local count = 0
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        for t = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(t)
            if info then count = math.max(count, (info.itemIndexOffset or 0) + (info.numSpellBookItems or 0)) end
        end
    elseif GetNumSpellTabs then
        for t = 1, GetNumSpellTabs() do
            local _, _, offset, num = GetSpellTabInfo(t)
            count = math.max(count, (offset or 0) + (num or 0))
        end
    end
    local list = {}
    for i = 1, count do
        local name, rank, spellID, usable
        if useNewSpellBook() then
            local info = C_SpellBook.GetSpellBookItemInfo(i, Enum.SpellBookSpellBank.Player)
            if info and info.name then
                name, rank, spellID = info.name, info.subName, info.spellID
                usable = info.itemType == Enum.SpellBookItemType.Spell and not info.isPassive
            end
        else
            name, rank, spellID = GetSpellBookItemName(i, BOOK)
            local kind, bookID
            if GetSpellBookItemInfo then kind, bookID = GetSpellBookItemInfo(i, BOOK) end
            spellID = spellID or bookID
            usable = name and kind == "SPELL" and not (IsPassiveSpell and IsPassiveSpell(i, BOOK))
        end
        if usable then
            list[#list + 1] = { index = i, name = name, rank = rank or "", spellID = spellID }
        end
    end
    return list
end

local function pickupBookEntry(e)
    if useNewSpellBook() and C_SpellBook.PickupSpellBookItem then
        C_SpellBook.PickupSpellBookItem(e.index, Enum.SpellBookSpellBank.Player)
    elseif PickupSpellBookItem then
        PickupSpellBookItem(e.index, BOOK)
    end
    if not GetCursorInfo() and e.spellID then pickupSpellID(e.spellID) end
end

-- value: "Lightning Bolt", "Healing Wave(Rank 1)" or "spell:403".
-- Returns { kind, id, pickup } or nil, reason.
local function resolveSpell(value, book)
    local id = tonumber(value:match("^spell:(%d+)$"))
    if id then
        if not isKnownSpell(id) then return nil, "not learned yet" end
        return { kind = "spell", id = id, pickup = function() pickupSpellID(id) end }
    end
    local base, rank = value:match("^(.-)%s*%(([^()]*)%)$")
    base = (base or value):lower()
    rank = rank and trim(rank):lower()
    local found
    for _, e in ipairs(book) do
        if e.name:lower() == base and (not rank or e.rank:lower() == rank) then found = e end
    end
    if found then
        return { kind = "spell", id = found.spellID, pickup = function() pickupBookEntry(found) end }
    end
    if rank then
        local rid = getSpellIDByName(value)
        if rid and isKnownSpell(rid) then
            return { kind = "spell", id = rid, pickup = function() pickupSpellID(rid) end }
        end
        return nil, "that rank isn't in your spellbook (turn on Show All Spell Ranks)"
    end
    return nil, "not learned yet"
end

local function resolveItem(value)
    local id = tonumber(value:match("^item:(%d+)")) or tonumber(value) or getItemID(value)
    if not id or not haveItem(id) then return nil, "not in bags" end
    return { kind = "item", id = id, pickup = function() pickupItem(id) end }
end

-- The game allows 16-character macro names. If it cut a longer one, find it by
-- the cut name so a second Apply doesn't make a duplicate.
local MACRO_NAME_MAX = 16
local function macroIndex(name)
    local idx = GetMacroIndexByName(name)
    if idx and idx > 0 then return idx end
    local chars = name:match(("[%z\1-\127\194-\244][\128-\191]*"):rep(MACRO_NAME_MAX))
    for _, cut in ipairs({ cutBytes(name, MACRO_NAME_MAX), chars }) do
        if cut and cut ~= name then
            idx = GetMacroIndexByName(cut)
            if idx and idx > 0 then return idx end
        end
    end
    return 0
end

local function resolveMacro(value)
    local idx = macroIndex(value)
    if not idx or idx == 0 then return nil, "no macro with that name" end
    return { kind = "macro", id = idx, pickup = function() PickupMacro(idx) end }
end

local function slotHolds(slot, target)
    local kind, id = GetActionInfo(slot)
    return kind == target.kind and id == target.id
end

local function placeTarget(slot, target)
    ClearCursor()
    target.pickup()
    if not GetCursorInfo() then return false end
    PlaceAction(slot)
    ClearCursor()
    return HasAction(slot)
end

------------------------------------------------------------------------
-- Applying a plan
------------------------------------------------------------------------

local function applyMacros(plan, dry, r)
    local nAccount, nChar = GetNumMacros()
    local maxAccount = MAX_ACCOUNT_MACROS or 120
    local maxChar = MAX_CHARACTER_MACROS or 18
    for _, m in ipairs(plan.macros) do
        -- The game refuses a longer body instead of cutting it, so cut it here.
        local body = cutBytes(m.body, MACRO_BODY_MAX)
        if body ~= m.body then
            r.problems[#r.problems + 1] = ("Macro %s is %d characters; only the first %d are kept.")
                :format(m.name, #m.body, MACRO_BODY_MAX)
        end
        local icon = tonumber(m.icon) or (m.icon ~= "" and m.icon) or nil
        local idx = macroIndex(m.name)
        if idx and idx > 0 then
            local _, oldIcon, oldBody = GetMacroInfo(idx)
            if trim(oldBody) == trim(body) then
                r.macrosSame = r.macrosSame + 1
            else
                local ok, res = true, nil
                if not dry then ok, res = pcall(EditMacro, idx, m.name, icon or oldIcon, body) end
                if ok then
                    r.macrosChanged = r.macrosChanged + 1
                else
                    r.problems[#r.problems + 1] = "Macro " .. m.name .. ": couldn't change it (" .. tostring(res) .. ")."
                end
            end
        elseif m.perChar and nChar >= maxChar then
            r.problems[#r.problems + 1] = "Macro " .. m.name .. ": character macros are full (" .. maxChar .. ")."
        elseif not m.perChar and nAccount >= maxAccount then
            r.problems[#r.problems + 1] = "Macro " .. m.name .. ": general macros are full (" .. maxAccount .. ")."
        else
            local ok, res = true, true
            if not dry then ok, res = pcall(CreateMacro, m.name, icon or DEFAULT_ICON, body, m.perChar) end
            if ok and res then
                r.macrosNew = r.macrosNew + 1
                if m.perChar then nChar = nChar + 1 else nAccount = nAccount + 1 end
            else
                r.problems[#r.problems + 1] = "Macro " .. m.name .. ": couldn't create it (" .. tostring(res) .. ")."
            end
        end
    end
end

local function applySlots(plan, dry, r)
    local planMacros = {}
    for _, m in ipairs(plan.macros) do planMacros[m.name:lower()] = true end
    local book = spellbookEntries()
    local _, class = UnitClass("player")
    for _, s in ipairs(slotsWithCopies(plan, class)) do
        local label = slotLabel(s.slot)
        local function detail(action, alreadyCorrect)
            if not dry then return end
            local kind, id = GetActionInfo(s.slot)
            local current = kind and (kind .. " " .. tostring(id)) or "empty"
            local msg = ("%s [%d%s]: %s -> %s"):format(
                label, s.slot, s.copy and ", compatibility copy" or "", current, action)
            r.slotDetails[#r.slotDetails + 1] = msg
            if not alreadyCorrect then r.slotChanges[#r.slotChanges + 1] = msg end
        end
        -- An installed action can outlive its spellbook entry or inventory item.
        -- Its exact ID proves a no-op only on this slot, never on another slot.
        local kind, id = GetActionInfo(s.slot)
        local exact = (kind == "spell" or kind == "item") and id and s.kind == kind and s.value == kind .. ":" .. id
        if exact then
            detail("already correct", true)
            if s.copy then r.copiedSame = r.copiedSame + 1 else r.same = r.same + 1 end
        elseif s.copy then
            -- Copies are counted on their own; anything wrong with them is already reported for the original.
            local target, why
            if s.kind == "spell" then target, why = resolveSpell(s.value, book)
            elseif s.kind == "macro" then
                target, why = resolveMacro(s.value)
                if not target and dry and planMacros[s.value:lower()] then target = { kind = "macro", id = -1 } end
            elseif s.kind == "item" then target = resolveItem(s.value, s.slot)
            end
            if s.kind == "clear" then
                if HasAction(s.slot) then
                    detail("empty")
                    if not dry then PickupAction(s.slot); ClearCursor() end
                    r.copied = r.copied + 1
                end
            elseif target and slotHolds(s.slot, target) then
                detail("already correct", true)
                r.copiedSame = r.copiedSame + 1
            elseif target and (dry or placeTarget(s.slot, target)) then
                detail(s.kind .. " " .. s.value)
                r.copied = r.copied + 1
            elseif not target and s.kind ~= "clear" then
                detail("keep current (skipped " .. s.value .. "): " .. (why or "unknown slot type"))
                r.copiesSkipped = r.copiesSkipped + 1
            elseif target then
                r.problems[#r.problems + 1] = label .. ": couldn't place the copy of " .. s.value .. "."
            end
        elseif s.kind == "clear" then
            if HasAction(s.slot) then
                detail("empty")
                if not dry then PickupAction(s.slot); ClearCursor() end
                r.cleared = r.cleared + 1
            end
        else
            local target, why
            if s.kind == "spell" then
                target, why = resolveSpell(s.value, book)
            elseif s.kind == "macro" then
                target, why = resolveMacro(s.value)
                if not target and dry and planMacros[s.value:lower()] then
                    target = { kind = "macro", id = -1 } -- created by Apply
                end
            elseif s.kind == "item" then
                target, why = resolveItem(s.value, s.slot)
            else
                why = "unknown slot type " .. tostring(s.kind)
            end
            if not target then detail("keep current (skipped " .. s.value .. "): " .. tostring(why)) end
            if not target and why == "not learned yet" then
                r.notLearned[#r.notLearned + 1] = s.value
            elseif not target and why == "not in bags" then
                local id = tonumber(s.value:match("^item:(%d+)"))
                r.notInBags[#r.notInBags + 1] = (id and getItemName(id)) or s.value
            elseif not target then
                r.skipped[#r.skipped + 1] = label .. ": " .. s.value .. " (" .. why .. ")"
            elseif slotHolds(s.slot, target) then
                detail("already correct", true)
                r.same = r.same + 1
            elseif dry then
                detail(s.kind .. " " .. s.value)
                r.placed = r.placed + 1
            elseif placeTarget(s.slot, target) then
                r.placed = r.placed + 1
            else
                r.problems[#r.problems + 1] = label .. ": couldn't place " .. s.value .. "."
            end
        end
    end
end

function BP.apply(plan, dry, preview)
    local r = {
        placed = 0, same = 0, cleared = 0, macrosNew = 0, macrosChanged = 0, macrosSame = 0,
        bound = 0, bindsSame = 0, notLearned = {}, notInBags = {}, skipped = {}, problems = {},
        copied = 0, copiedSame = 0, copiesSkipped = 0, slotDetails = {}, slotChanges = {},
    }
    if #plan.binds > 0 then
        if not preview then return nil, "Run Check on this plan before Apply." end
        r.binding = preview
        r.bound, r.bindsSame = #preview.changes, preview.same
        if not dry then
            local ok, err = B.commit(plan, preview)
            if not ok then return nil, err end
        end
    end
    applyMacros(plan, dry, r)
    applySlots(plan, dry, r)
    if not dry and #plan.slots > 0 then ClearCursor() end
    return r
end

local function countLabel(n, label)
    return n .. " " .. label .. (n == 1 and "" or "s")
end

local function reportLines(r, dry)
    local summary, chat, details = {}, {}, {}
    local function highlight(msg)
        summary[#summary + 1] = msg
        details[#details + 1] = msg
    end
    local binding = r.binding
    local errors = binding and binding.errors or {}
    local warnings = binding and binding.warnings or {}
    if dry then
        local title = #errors > 0 and "Check BLOCKED" or "Check OK"
        chat[1] = title .. " - " .. countLabel(r.bound, "binding change")
        if binding then
            title = title .. " (" .. (binding.before.set == 1 and "account-wide" or "character-specific")
                .. ", " .. (binding.legacy and "BP1 exact replacement" or "BP2") .. ")"
        end
        summary[1] = ("%s - Bindings: %d to change, %d already correct, %d safely preserved.")
            :format(title, r.bound, r.bindsSame, binding and binding.preserved or 0)
        summary[2] = ("Displaced commands: %d. Orphaned: %d. Blocking errors: %d. Runtime override warnings: %d.")
            :format(binding and binding.displaced or 0, binding and binding.orphaned or 0,
                #errors, binding and binding.overrideWarnings or 0)
        local slots = r.placed + r.cleared + r.copied
        local skipped = #r.notLearned + #r.notInBags + #r.skipped + r.copiesSkipped
        if slots + skipped > 0 then
            local counts = countLabel(slots, "slot change") .. ", " .. skipped .. " skipped"
            chat[1] = chat[1] .. ", " .. counts
            summary[#summary + 1] = counts
        end
        if r.macrosNew + r.macrosChanged > 0 then
            highlight(("Macros: %d new, %d changed."):format(r.macrosNew, r.macrosChanged))
        end
        if #errors + #warnings + #r.problems > 0 then
            chat[1] = chat[1] .. ", " .. countLabel(#errors, "error") .. ", " .. countLabel(#warnings + #r.problems, "warning")
            local reason = errors[1] or warnings[1] or r.problems[1]
            if #reason <= 180 then chat[2] = reason end
        end
        chat[#chat] = chat[#chat] .. "  Open Details for the full report."
    else
        highlight(("Done: %d slots filled, %d already right, %d cleared. Macros: %d new, %d changed. Keys changed: %d.")
            :format(r.placed, r.same, r.cleared, r.macrosNew, r.macrosChanged, r.bound))
    end
    for _, msg in ipairs(errors) do highlight("Blocked: " .. msg) end
    for _, msg in ipairs(warnings) do highlight("Warning: " .. msg) end
    for _, msg in ipairs(r.problems) do highlight("Warning: " .. msg) end
    local full = {}
    local function change(msg)
        full[#full + 1] = msg
        details[#details + 1] = msg
    end
    for _, msg in ipairs(summary) do full[#full + 1] = msg end
    if dry then
        full[#full + 1] = ("Slots: %d to fill, %d to clear, %d already right. Macros: %d new, %d changed, %d unchanged.")
            :format(r.placed, r.cleared, r.same, r.macrosNew, r.macrosChanged, r.macrosSame)
    end
    if r.copied + r.copiedSame > 0 then
        local _, class = UnitClass("player")
        local names = {}
        for _, c in ipairs(copyPagesFor(class)) do names[#names + 1] = c.label end
        full[#full + 1] = ("Copies for bar addons that switch the main bar in %s: %d %s, %d already right.")
            :format(table.concat(names, " and "), r.copied, dry and "to change" or "changed", r.copiedSame)
    end
    if binding then
        for _, msg in ipairs(binding.lines) do change(msg) end
        for _, msg in ipairs(binding.details) do full[#full + 1] = msg end
    end
    -- Check already names each skipped slot, its current contents and the reason.
    if not dry and #r.notLearned > 0 then
        change(("Not learned yet (or misspelled), skipped (%d): %s"):format(#r.notLearned, table.concat(r.notLearned, ", ")))
    end
    if not dry and #r.notInBags > 0 then
        change(("Not in your bags, skipped (%d): %s"):format(#r.notInBags, table.concat(r.notInBags, ", ")))
    end
    for _, s in ipairs(r.slotChanges) do details[#details + 1] = s end
    for _, s in ipairs(r.slotDetails) do full[#full + 1] = s end
    if not dry then
        for _, s in ipairs(r.skipped) do change("Skipped " .. s) end
    end
    if #details == 0 then details[1] = "No changes or warnings." end
    return summary, full, dry and chat or summary, details
end

------------------------------------------------------------------------
-- Export: turn the current bars and keys into a plan string
------------------------------------------------------------------------

local function exportSpell(id, book)
    local name = getSpellName(id)
    if name then
        local target = resolveSpell(name, book)
        if target and target.id == id then return name end
        local sub = getSpellSubtext(id)
        if sub and sub ~= "" then
            local ranked = name .. "(" .. sub .. ")"
            target = resolveSpell(ranked, book)
            if target and target.id == id then return ranked end
        end
    end
    return "spell:" .. id
end

function BP.exportCurrent()
    local _, class = UnitClass("player")
    local plan = { name = (UnitName("player") or "?") .. " (from game)", class = class,
        race = UnitRace and (UnitRace("player")) or nil, macros = {}, slots = {}, binds = {} }
    local book = spellbookEntries()
    local seenMacro = {}
    local maxAccount = MAX_ACCOUNT_MACROS or 120
    local copyPage = {} -- leave out the copies Apply made; the planner has no such pages
    for _, c in ipairs(copyPagesFor(class)) do copyPage[c.to] = true end
    for _, p in ipairs(PAGES) do
        for i = 0, 11 do
            local slot = p.first + i
            if not copyPage[p.first] and HasAction(slot) then
                local kind, id = GetActionInfo(slot)
                if kind == "spell" then
                    plan.slots[#plan.slots + 1] = { slot = slot, kind = kind, value = exportSpell(id, book) }
                elseif kind == "macro" then
                    local name, icon, body = GetMacroInfo(id)
                    if name then
                        plan.slots[#plan.slots + 1] = { slot = slot, kind = "macro", value = name }
                        if not seenMacro[name] then
                            seenMacro[name] = true
                            plan.macros[#plan.macros + 1] = {
                                name = name, icon = tostring(icon or ""), perChar = id > maxAccount, body = body or "",
                            }
                        end
                    end
                elseif kind == "item" then
                    local name = getItemName(id)
                    local target = name and resolveItem(name)
                    local value = target and target.id == id and name or ("item:" .. id)
                    plan.slots[#plan.slots + 1] = { slot = slot, kind = kind, value = value }
                end
            end
        end
    end
    for _, cmd in ipairs(allCommands()) do
        for _, key in pairs({ GetBindingKey(cmd) }) do
            plan.binds[#plan.binds + 1] = { key = key, command = cmd }
        end
    end
    return BP.serialize(plan)
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------

local frame
local SETUP_HELP = "BP2 setup: action slots, macros used on those slots, and supported keybindings. Press Ctrl+C to copy."

local checked
local CHECK_HINT = "Run Check before Apply."

local function refreshApply()
    if not frame then return end
    if checked and checked.text == frame.edit:GetText() then
        frame.apply:Enable()
        frame.hint:SetText("Checked. Ready to Apply.")
    else
        frame.apply:Disable()
        frame.hint:SetText(CHECK_HINT)
    end
end

local function display(view)
    frame.view = view
    frame.reportText = table.concat(frame[view], "\n")
    if view == "summary" then
        frame.summaryTab:Disable()
        frame.detailsTab:Enable()
        frame.diagnosticsButton:Hide()
    else
        frame.summaryTab:Enable()
        frame.detailsTab:Disable()
        frame.diagnosticsButton:SetText(view == "full" and "Hide diagnostics" or "Full diagnostics")
        frame.diagnosticsButton:Show()
    end
    frame.status:ClearFocus()
    frame.status:SetText(frame.reportText)
    frame.status:SetCursorPosition(0)
    frame.report:SetVerticalScroll(0)
end

local function showStatus(summary, full, chat, details)
    for _, msg in ipairs(chat or summary) do say(msg) end
    if frame then
        frame.summary, frame.full, frame.details = summary, full or summary, details or summary
        display("summary")
        refreshApply()
    end
    return summary, full or summary, details or summary
end

function BP.run(text, dry)
    local previous = checked
    checked = nil
    refreshApply()
    local function stop(msg)
        local title = dry and "Check BLOCKED" or "Apply stopped"
        return showStatus({ title .. ": " .. msg }, nil, { title .. ": " .. msg .. "  Open Details for the full report." })
    end
    if InCombatLockdown() then return stop("Can't change bars or keys in combat. Try again after the fight.") end
    if not dry and (not previous or previous.text ~= text) then return stop(CHECK_HINT) end
    local plan, err = BP.parse(text)
    if not plan then return stop(err) end
    local _, myClass = UnitClass("player")
    if plan.class and myClass and plan.class ~= myClass then
        return stop(("This plan is for a %s and this character is a %s. Switch class in the planner and copy that plan.")
            :format(plan.class:lower(), myClass:lower()))
    end
    local preview
    if dry and #plan.binds > 0 then
        local ok, result = pcall(function() return B.preview(plan, B.capture(plan.binds)) end)
        if not ok then return stop(tostring(result)) end
        preview = result
        preview.legacy = plan.version == 1
    elseif previous and not dry then
        preview = previous.preview
    end
    local ok, r, failure = pcall(BP.apply, plan, dry, preview)
    if not ok or not r then return stop(tostring(failure or r)) end
    if dry and (not preview or #preview.errors == 0) then checked = { text = text, preview = preview } end
    if not dry then BarsmithDB.last = trim(text) end
    return showStatus(reportLines(r, dry))
end

local function buildFrame()
    local f = CreateFrame("Frame", "BarsmithFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(620, 470)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "BarsmithFrame") -- Esc closes it

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText("Barsmith")

    local help = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    help:SetPoint("TOPLEFT", 16, -34)
    help:SetPoint("TOPRIGHT", -16, -34)
    help:SetJustifyH("LEFT")
    help:SetText("Paste a setup plan and click Check. Review the summary before applying changes.")

    local scroll = CreateFrame("ScrollFrame", "BarsmithScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -56)
    scroll:SetPoint("BOTTOMRIGHT", -38, 245)

    local bg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    bg:SetPoint("TOPLEFT", scroll, -4, 4)
    bg:SetPoint("BOTTOMRIGHT", scroll, 4, -4)
    bg:SetColorTexture(0, 0, 0, 0.6)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(560)
    edit:SetMaxLetters(0)
    if edit.SetMaxBytes then edit:SetMaxBytes(0) end
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    scroll:SetScrollChild(edit)
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)
    f.edit = edit

    local report = CreateFrame("ScrollFrame", "BarsmithReport", f, "UIPanelScrollFrameTemplate")
    report:SetPoint("TOPLEFT", scroll, "BOTTOMLEFT", 0, -44)
    report:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -38, 50)
    local status = CreateFrame("EditBox", nil, report)
    status:SetMultiLine(true)
    status:SetAutoFocus(false)
    status:SetFontObject(ChatFontNormal)
    status:SetWidth(558)
    status:SetMaxLetters(0)
    if status.SetMaxBytes then status:SetMaxBytes(0) end
    status:SetScript("OnEscapePressed", status.ClearFocus)
    status:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self:SetText(f.reportText); self:HighlightText() end
    end)
    report:SetScrollChild(status)
    f.report, f.status = report, status
    f.summary, f.details, f.full, f.reportText = {}, {}, {}, ""

    local function button(text, x, width, onClick, y)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(width, 24)
        b:SetPoint("BOTTOMLEFT", x, y or 14)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        return b
    end
    f.summaryTab = button("Summary", 16, 82, function() display("summary"); refreshApply() end, 210)
    f.detailsTab = button("Details", 102, 72, function() display("details"); refreshApply() end, 210)
    f.summaryTab:Disable()
    f.diagnosticsButton = button("Full diagnostics", 288, 124, function()
        display(f.view == "full" and "details" or "full")
        refreshApply()
    end, 210)
    f.diagnosticsButton:Hide()
    button("Copy report", 178, 106, function()
        display(f.view == "full" and "full" or "details")
        status:SetFocus()
        status:HighlightText()
        f.hint:SetText("Press Ctrl+C to copy.")
    end, 210)
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.hint:SetPoint("LEFT", f, "BOTTOMLEFT", 418, 222)
    button("Check", 16, 68, function() edit:ClearFocus(); BP.run(edit:GetText(), true) end)
    f.apply = button("Apply", 88, 68, function() edit:ClearFocus(); BP.run(edit:GetText(), false) end)
    f.apply:Disable()
    f.hint:SetText(CHECK_HINT)
    edit:SetScript("OnTextChanged", function()
        checked = nil
        f.summary, f.details, f.full = {}, {}, {}
        display("summary")
        refreshApply()
    end)
    local function exportHelp(msg)
        f.summary, f.details, f.full = { msg }, { msg }, { msg }
        display("summary")
    end
    f.exportHelp = exportHelp
    button("Export setup", 160, 117, function()
        edit:SetText(BP.exportCurrent())
        edit:SetFocus()
        edit:HighlightText()
        exportHelp(SETUP_HELP)
    end)
    button("Clear", 281, 55, function() edit:SetText(""); edit:SetFocus() end)
    button("Census", 338, 72, function()
        local ok, snapshot = pcall(B.census, esc)
        if not ok then showStatus({ "Census failed: " .. tostring(snapshot) }); return end
        edit:SetText(snapshot)
        edit:SetFocus()
        edit:HighlightText()
        exportHelp("Copy this read-only BC1 census. Load it into the planner with your plan open.")
    end)

    local auto = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    auto:SetSize(24, 24)
    auto:SetPoint("BOTTOMRIGHT", -150, 14)
    local autoLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autoLabel:SetPoint("LEFT", auto, "RIGHT", 2, 0)
    autoLabel:SetText("Auto-fill new spells")
    auto:SetChecked(BarsmithDB.auto)
    auto:SetScript("OnClick", function(self) BarsmithDB.auto = self:GetChecked() and true or false end)
    f.auto = auto

    f:Hide()
    return f
end

local function openFrame(text)
    frame = frame or buildFrame()
    frame.auto:SetChecked(BarsmithDB.auto)
    if text then frame.edit:SetText(text) end
    frame:Show()
end

------------------------------------------------------------------------
-- Auto-fill: when you learn a spell or get an item, put it in its planned slot if empty
------------------------------------------------------------------------

local autoQueued, autoAfterCombat = false, false

local function autoFill()
    autoQueued = false
    if not (BarsmithDB and BarsmithDB.auto and BarsmithDB.last) then return end
    if InCombatLockdown() then autoAfterCombat = true return end
    local plan = BP.parse(BarsmithDB.last)
    local _, myClass = UnitClass("player")
    if not plan or (plan.class and plan.class ~= myClass) then return end
    local book
    for _, s in ipairs(slotsWithCopies(plan, myClass)) do
        if (s.kind == "spell" or s.kind == "item") and not HasAction(s.slot) then
            local target
            if s.kind == "spell" then
                book = book or spellbookEntries()
                target = resolveSpell(s.value, book)
            else
                target = resolveItem(s.value)
            end
            if target and placeTarget(s.slot, target) and not s.copy then
                local id = s.kind == "item" and tonumber(s.value:match("^item:(%d+)"))
                say("Put " .. ((id and getItemName(id)) or s.value) .. " on " .. slotLabel(s.slot) .. ".")
            end
        end
    end
    ClearCursor()
end

local function queueAutoFill()
    if autoQueued then return end
    autoQueued = true
    C_Timer.After(1, autoFill)
end

local events = CreateFrame("Frame")
-- Not every client has every event (Classic Era has no LEARNED_SPELL_IN_TAB;
-- newer clients call it LEARNED_SPELL_IN_SKILL_LINE),
-- and registering an unknown one is an error that would stop the file here.
for _, ev in ipairs({ "ADDON_LOADED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_ENABLED" }) do
    pcall(events.RegisterEvent, events, ev)
end
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Barsmith" then
            BarsmithDB = BarsmithDB or {}
            if BarsmithDB.auto == nil then BarsmithDB.auto = true end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if autoAfterCombat then autoAfterCombat = false; queueAutoFill() end
    elseif BarsmithDB then
        queueAutoFill()
    end
end)

------------------------------------------------------------------------
-- Slash command
------------------------------------------------------------------------

SLASH_BARSMITH1 = "/barsmith"
SlashCmdList.BARSMITH = function(msg)
    msg = trim(msg):lower()
    if msg == "apply" then
        if BarsmithDB.last then openFrame(BarsmithDB.last); BP.run(BarsmithDB.last, true)
        else say("No plan applied yet. Type /barsmith and paste one.") end
    elseif msg == "auto" then
        BarsmithDB.auto = not BarsmithDB.auto
        say("Auto-fill new spells is " .. (BarsmithDB.auto and "on." or "off."))
        if frame then frame.auto:SetChecked(BarsmithDB.auto) end
    elseif msg == "export" then
        openFrame(BP.exportCurrent())
        frame.edit:SetFocus()
        frame.edit:HighlightText()
        frame.exportHelp(SETUP_HELP)
    elseif frame and frame:IsShown() then
        frame:Hide()
    else
        local fresh = not frame
        openFrame()
        if fresh and BarsmithDB.last then frame.edit:SetText(BarsmithDB.last) end
    end
end

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
-- Some of them switch the main bar in forms where the game doesn't; see ALTERNATE_PAGES.
--
-- Character profiles and their pending leveling placements are kept in BarsmithDB.

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

-- The browser has no selectable page for these addon-specific forms. Export
-- their buttons when an applied profile explicitly manages those destinations.
local ALTERNATE_PAGES = {
    PRIEST = { [73] = true }, -- Shadowform
    DRUID = { [109] = true, [85] = true }, -- Moonkin and Prowl
}

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

BP.cutBytes = cutBytes

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

local function pickupSpellID(id)
    if C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(id)
    elseif PickupSpell then PickupSpell(id) end
end

local function isKnownSpell(id)
    return (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id)) or false
end

-- A name lookup can see spells outside the enumerated skill lines. Confirm the
-- returned ID belongs to this player before using it as a pickup target.
local function learnedSpellIDByName(name, rank)
    local function matches(id)
        if not id or id <= 0 then return false end
        local passive = (C_Spell and C_Spell.IsSpellPassive) or IsPassiveSpell
        if passive and passive(id) then return false end
        if rank then
            -- A parenthesis can be part of the actual name or an explicit rank.
            -- Reject an API result that supplies a different subtext.
            local sub = getSpellSubtext(id)
            if sub and sub:lower() ~= rank and (getSpellName(id) or ""):lower() ~= name:lower() then return false end
        end
        return isKnownSpell(id)
            or (C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook and C_SpellBook.IsSpellKnownOrInSpellBook(id))
            or (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id))
            or (IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(id))
    end
    if C_Spell and C_Spell.GetSpellIDForSpellIdentifier then
        local id = C_Spell.GetSpellIDForSpellIdentifier(name)
        if matches(id) then return id end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(name)
        if info and matches(info.spellID) then return info.spellID end
    end
    if GetSpellInfo then
        local id = select(7, GetSpellInfo(name))
        if matches(id) then return id end
    end
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
    -- Preserve the book's rank selection above. On a miss, ask the client for
    -- the learned form/override by name, keeping any rank or form qualifier.
    id = learnedSpellIDByName(value, rank)
    if not id and rank then
        local qualified = value:gsub("%s+%(([^()]*)%)$", "(%1)")
        if qualified ~= value then id = learnedSpellIDByName(qualified, rank) end
    end
    if id then
        return { kind = "spell", id = id, pickup = function() pickupSpellID(id) end }
    end
    if rank then
        return nil, "that rank isn't in your spellbook (turn on Show All Spell Ranks)"
    end
    return nil, "not learned yet"
end

local function resolveItem(value)
    local id = tonumber(value:match("^item:(%d+)")) or tonumber(value) or getItemID(value)
    if not id or not haveItem(id) then return nil, "not in bags" end
    return { kind = "item", id = id, pickup = function() pickupItem(id) end }
end

local MACRO_NAME_MAX = 16
local C, P = BP.changes, BP.profiles

local function spellKnown(id)
    return isKnownSpell(id)
        or (C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook and C_SpellBook.IsSpellKnownOrInSpellBook(id))
        or (IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(id))
end

function C.pickup(action)
    if action.kind == "spell" then
        if spellKnown(action.id) then return function() pickupSpellID(action.id) end end
        for _, entry in ipairs(spellbookEntries()) do
            if entry.spellID == action.id then return function() pickupBookEntry(entry) end end
        end
    elseif action.kind == "item" and haveItem(action.id) then
        return function() pickupItem(action.id) end
    elseif action.kind == "macro" then
        local macro = C.macro(action.name)
        if macro and macro.perChar == action.perChar then
            return function() PickupMacro(GetMacroIndexByName(action.name)) end
        end
    end
end

local function label(action)
    if action.kind == "empty" then return "empty" end
    if action.kind == "macro" then return "macro " .. action.name end
    local name
    if action.kind == "spell" then name = getSpellName(action.id)
    elseif action.kind == "item" then name = getItemName(action.id) end
    local id = action.kind .. " " .. tostring(action.id)
    return name and (name .. " (" .. id .. ")") or id
end

local function available(s, book)
    if s.kind == "spell" then return resolveSpell(s.value, book) end
    if s.kind == "item" then return resolveItem(s.value) end
end

local function requireRestorable(slot, before)
    assert(before.kind == "empty" or C.pickup(before),
        slotLabel(slot) .. ": cannot restore " .. label(before) .. ". Move it manually before continuing.")
end

-- Older hand-authored plans sometimes clear a stale slot before reserving it
-- for a future spell. Review that pair as one physical change.
local function managedSlots(plan, profile)
    local slots, bySlot, clearFirst = {}, {}, {}
    for _, s in ipairs(plan.slots) do
        assert(s.slot >= 1 and s.slot <= 180 and s.slot == math.floor(s.slot), "Invalid slot: " .. s.slot)
        local i = bySlot[s.slot]
        if not i then
            table.insert(slots, s)
            bySlot[s.slot] = #slots
        elseif slots[i].kind == "clear" or s.kind == "clear" then
            clearFirst[s.slot] = slots[i].kind == "clear"
            slots[i] = s
        else
            assert(C.equal(slots[i], s), "Competing actions for " .. slotLabel(s.slot))
        end
    end
    if not profile.excludedBars then return slots, clearFirst, 0 end
    local included = {}
    for _, s in ipairs(slots) do
        if P.managesSlot(profile, s.slot) then table.insert(included, s) end
    end
    return included, clearFirst, #slots - #included
end

local function macroName(value)
    if #value <= MACRO_NAME_MAX then return value end
    -- Existing clients may have kept sixteen multibyte characters, or cut at
    -- sixteen bytes. Match either existing spelling before creating a macro.
    local existing = C.macro(value)
    if existing then return existing.name end
    local chars = value:match(("[%z\1-\127\194-\244][\128-\191]*"):rep(MACRO_NAME_MAX))
    existing = chars and C.macro(chars)
    return existing and existing.name or cutBytes(value, MACRO_NAME_MAX)
end

local function reviewPlan(plan, preview, profile)
    local r = {
        binding = preview, bound = preview and #preview.changes or 0, bindsSame = preview and preview.same or 0,
        placed = 0, same = 0, cleared = 0, macrosNew = 0, macrosChanged = 0, macrosSame = 0,
        notLearned = {}, notInBags = {}, skipped = {}, problems = {}, slotDetails = {}, slotChanges = {},
        ops = {}, pending = {}, inspected = {}, overwrites = 0, futureOverwrites = 0,
    }
    local pickups, macros = {}, {}
    local account, character = GetNumMacros()
    for _, m in ipairs(plan.macros) do
        local name = macroName(m.name)
        local key = name:lower()
        assert(not macros[key], "Duplicate macro: " .. name)
        local before = C.macro(name)
        local body = cutBytes(m.body, MACRO_BODY_MAX)
        if body ~= m.body then table.insert(r.problems, "Macro " .. name .. " will be shortened to 255 bytes.") end
        local after = { name = before and before.name or name, body = body,
            icon = tonumber(m.icon) or (m.icon ~= "" and m.icon) or (before and before.icon) or DEFAULT_ICON,
            perChar = m.perChar }
        if before then after.perChar = before.perChar end
        macros[key] = after
        table.insert(r.inspected, { macro = name, before = before })
        if before and trim(before.body) == trim(body) then
            r.macrosSame = r.macrosSame + 1
        else
            table.insert(r.ops, { name = name, before = before, after = after })
            if before then
                r.macrosChanged = r.macrosChanged + 1
            else
                if after.perChar then character = character + 1 else account = account + 1 end
                assert(character <= (MAX_CHARACTER_MACROS or 18) and account <= (MAX_ACCOUNT_MACROS or 120),
                    "Macro storage is full for " .. name)
                r.macrosNew = r.macrosNew + 1
            end
        end
    end
    local book = spellbookEntries()
    local slots, clearFirst, excluded = managedSlots(plan, profile)
    r.excluded = excluded
    for _, s in ipairs(slots) do
        local before = C.slot(s.slot)
        local after, pickup, why
        if s.kind == "clear" then
            after = { kind = "empty" }
        elseif s.kind == "macro" then
            local name = macroName(s.value)
            local m = macros[name:lower()] or C.macro(name)
            if m then
                after = { kind = "macro", name = m.name, perChar = m.perChar }
            else why = "no macro with that name" end
        elseif s.kind == "spell" or s.kind == "item" then
            if before.kind == s.kind and s.value == s.kind .. ":" .. tostring(before.id) then
                after = before
            else
                local target
                target, why = available(s, book)
                if target then
                    assert(target.id, "Cannot identify " .. s.value)
                    after = { kind = s.kind, id = target.id }
                    if before.kind == s.kind and before.id == target.id then after = before end
                    pickup = target.pickup
                else
                    r.pending[s.slot] = true
                end
            end
        else error("Unknown slot type: " .. tostring(s.kind)) end
        local oldMacro = before.kind == "macro" and C.macro(before.name) or nil
        local nextMacro = after and after.kind == "macro" and C.macro(after.name) or nil
        table.insert(r.inspected, { slot = s.slot, before = before, after = after, oldMacro = oldMacro, nextMacro = nextMacro })
        local description, same
        if not after then
            local list = why == "not learned yet" and r.notLearned or why == "not in bags" and r.notInBags or r.skipped
            table.insert(list, s.value)
            if clearFirst[s.slot] then
                after = { kind = "empty" }
                description = "empty (explicit clear; reserved for " .. s.value .. ")"
            else
                description = "keep current (skipped " .. s.value .. "): " .. tostring(why)
                if r.pending[s.slot] and before.kind ~= "empty" then
                    r.futureOverwrites = r.futureOverwrites + 1
                    description = s.value .. " (future replacement; keep current: " .. tostring(why) .. ")"
                end
            end
        end
        if after then
            if C.equal(before, after) then
                same, description = true, description or "already correct"
                r.same = r.same + 1
            else
                requireRestorable(s.slot, before)
                table.insert(r.ops, { slot = s.slot, before = before, after = after, previousMacro = oldMacro, placedMacro = nextMacro })
                pickups[#r.ops] = pickup
                if before.kind ~= "empty" then r.overwrites = r.overwrites + 1 end
                if after.kind == "empty" then r.cleared = r.cleared + 1 else r.placed = r.placed + 1 end
                description = description or (s.kind == "clear" and "empty" or s.kind .. " " .. s.value)
            end
        end
        local line = ("%s [%d]: %s -> %s"):format(slotLabel(s.slot), s.slot, label(before), description)
        table.insert(r.slotDetails, line)
        if not same then table.insert(r.slotChanges, line) end
    end
    return r, pickups
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
        local slots = r.placed + r.cleared
        local skipped = #r.notLearned + #r.notInBags + #r.skipped
        if slots + skipped > 0 then
            local counts = countLabel(slots, "slot change") .. ", " .. skipped .. " skipped"
            chat[1] = chat[1] .. ", " .. counts
            summary[#summary + 1] = counts
        end
        if r.overwrites > 0 or r.futureOverwrites > 0 then
            highlight(countLabel(r.overwrites, "occupied slot") .. " will be replaced now. "
                .. countLabel(r.futureOverwrites, "occupied slot")
                .. (r.futureOverwrites == 1 and " has a future replacement." or " have future replacements."))
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
    for _, op in ipairs(r.ops) do
        if op.name then
            change((op.before and "Update " or "Create ") .. (op.after.perChar and "character macro " or "account macro ") .. op.name)
        end
    end
    if r.excluded > 0 then
        local msg = ("Skipped %s on excluded bars."):format(countLabel(r.excluded, "planned slot"))
        summary[#summary + 1] = msg
        change(msg)
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
    local profile = P.active()
    local saved = profile and profile.pending and profile.text and BP.parse(profile.text)
    local explicit = {}
    if saved then for _, s in ipairs(saved.slots) do explicit[s.slot] = true end end
    local alternate = ALTERNATE_PAGES[class] or {}
    for _, p in ipairs(PAGES) do
        for i = 0, 11 do
            local slot = p.first + i
            if (not alternate[p.first] or explicit[slot]) and HasAction(slot) then
                local kind, id = GetActionInfo(slot)
                if kind == "spell" then
                    plan.slots[#plan.slots + 1] = { slot = slot, kind = kind, value = exportSpell(id, book) }
                elseif kind == "macro" then
                    local macro = C.slotMacro(slot)
                    plan.slots[#plan.slots + 1] = { slot = slot, kind = "macro", value = macro.name }
                    if not seenMacro[macro.name] then
                        seenMacro[macro.name] = true
                        plan.macros[#plan.macros + 1] = macro
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

-- Check, batch confirmation and Revert all bind their review to the active profile.
local review, refreshProfiles, queueAutoFill
local function invalidate()
    checked, review = nil, nil
    if frame then frame.confirm:Hide(); frame.later:Hide() end
    refreshApply()
end

local function profileState(p)
    local pending = p.pending and {}
    for slot in pairs(p.pending or {}) do pending[slot] = true end
    local excluded = {}
    for first in pairs(p.excludedBars or {}) do excluded[first] = true end
    return { text = p.text, pending = pending, excludedBars = excluded }
end

local function ready()
    assert(not InCombatLockdown(), "Can't change bars or keys in combat.")
    assert(not (GetCursorInfo and GetCursorInfo()), "Empty the cursor and try again.")
end

function BP.run(text, dry)
    local previous = checked
    invalidate()
    local function stop(msg)
        local title = dry and "Check BLOCKED" or "Apply stopped"
        return showStatus({ title .. ": " .. msg }, nil, { title .. ": " .. msg .. "  Open Details for the full report." })
    end
    local profile = P.active()
    if not profile then return stop("Character identity unavailable.") end
    if not dry and (not previous or previous.text ~= text or previous.profile ~= profile) then return stop(CHECK_HINT) end
    local plan, err = BP.parse(text)
    if not plan then return stop(err) end
    local _, class = UnitClass("player")
    if plan.class and plan.class ~= class then return stop("This plan is for a different class: " .. plan.class) end
    local ok, result = pcall(function()
        ready()
        local preview = previous and not dry and previous.preview or nil
        if dry and #plan.binds > 0 then
            preview = B.preview(plan, B.capture(plan.binds))
            preview.legacy = plan.version == 1
        end
        local r, pickups = reviewPlan(plan, preview, profile)
        local state = profileState(profile)
        if dry then
            if not preview or #preview.errors == 0 then
                checked = { text = text, profile = profile, state = state, inspected = r.inspected, preview = preview }
            end
        else
            assert(C.equal(previous.inspected, r.inspected) and C.equal(previous.state, state),
                "Slots, macros, available actions or the profile changed. Run Check again.")
            local snapshot = { before = state, ops = r.ops, text = trim(text), visit = BarsmithDB.characterVisit }
            snapshot.bindings = C.execute(r.ops, plan, preview, pickups)
            profile.text, profile.pending = snapshot.text, r.pending
            if #r.ops > 0 or snapshot.bindings or not C.equal(state, profileState(profile)) then
                profile.undo = snapshot
            end
            profile.lastApplied = text
            if BarsmithDB.legacyPlan == text then BarsmithDB.legacyPlan = nil end
        end
        return r
    end)
    if not ok then return stop(tostring(result)) end
    if not dry and frame then refreshProfiles() end
    return showStatus(reportLines(result, dry))
end

local function showReview(kind, title, lines, ticket)
    invalidate()
    review = ticket
    review.kind = kind
    if frame then
        frame.confirm:SetText(kind == "revert" and "Confirm revert" or kind == "delete" and "Delete profile" or "Approve batch")
        frame.confirm:Show()
        frame.later:Show()
    end
    return showStatus({ title }, lines, { title }, lines)
end

local function macroInUse(name, ops)
    local changing = {}
    for _, op in ipairs(ops) do
        if op.slot then changing[op.slot] = true end
    end
    for slot = 1, math.max(MAX_ACTION_BUTTONS or 0, 180) do
        if not changing[slot] and GetActionInfo(slot) == "macro" and C.slotMacro(slot).name == name then
            return "Macro " .. name .. " is now used on " .. slotLabel(slot)
        end
    end
end

local function revertPlan(profile)
    ready()
    local u = assert(profile.undo, "This profile has no Apply to revert.")
    assert(profile.text == u.text, "Profile plan changed since Apply.")
    local ops, lines, editedMacros = {}, {}, {}
    local included = {}
    for _, op in ipairs(u.ops) do
        if not op.slot or P.managesSlot(profile, op.slot) then
            table.insert(included, op)
            if op.name then editedMacros[op.name:lower()] = true end
        else
            table.insert(lines, "Leave excluded " .. slotLabel(op.slot) .. " untouched.")
        end
    end
    for i = #included, 1, -1 do
        local op = included[i]
        local where = op.name or slotLabel(op.slot)
        assert(C.equal(C.read(op), op.after), where .. " changed since Apply.")
        if op.slot then
            requireRestorable(op.slot, op.before)
            if op.placedMacro and not editedMacros[op.placedMacro.name:lower()] then
                assert(C.equal(C.macro(op.placedMacro.name), op.placedMacro),
                    "Placed slot macro changed: " .. op.placedMacro.name)
            end
            if op.previousMacro and not editedMacros[op.previousMacro.name:lower()] then
                assert(C.equal(C.macro(op.previousMacro.name), op.previousMacro),
                    "Previous slot macro changed: " .. op.previousMacro.name)
            end
            table.insert(lines, where .. ": " .. label(op.after) .. " -> " .. label(op.before))
        else
            if not op.before then
                assert(op.after.perChar or u.visit == BarsmithDB.characterVisit,
                    "Cannot verify other characters' uses of new account macro " .. op.name .. " after switching characters.")
                local used = macroInUse(op.name, included)
                assert(not used, used)
                -- A new key bound directly to this macro would lose its action.
                local cmd = "MACRO " .. op.name
                local bound = B.capture({}, { [cmd] = true }).rows[cmd].keys
                local moving = {}
                if u.bindings then
                    for _, b in ipairs(u.bindings.plan.binds) do moving[b.key] = true end
                end
                for key in pairs(bound) do
                    assert(moving[key],
                        "Macro now has a binding on " .. key)
                end
            end
            table.insert(lines, op.before and ("Restore macro " .. op.name .. ":\n" .. op.before.body)
                or ("Delete macro " .. op.name .. " created by Apply."))
        end
        table.insert(ops, { slot = op.slot, name = op.name, before = op.after, after = op.before })
    end
    local preview = C.reverseBindings(u.bindings)
    if preview then
        table.insert(lines, preview.before.set == 1 and "Account-wide bindings" or "Character-specific bindings")
        for _, msg in ipairs(preview.lines) do table.insert(lines, msg) end
        for _, msg in ipairs(preview.warnings) do table.insert(lines, msg) end
    end
    local old = u.before.text and BP.parse(u.before.text)
    local name = old and (old.name ~= "" and old.name or "unnamed plan") or "no saved plan"
    local count = 0
    for _ in pairs(u.before.pending or {}) do count = count + 1 end
    table.insert(lines, "Restore profile to " .. name .. " with " .. countLabel(count, "pending placement") .. ".")
    return ops, preview, lines
end

function BP.revert(confirm)
    local previous = review
    invalidate()
    local profile = P.active()
    local ok, result = pcall(function()
        assert(profile, "Character identity unavailable.")
        if confirm then
            assert(previous and previous.kind == "revert" and previous.profile == profile and previous.undo == profile.undo
                and C.equal(previous.state, profileState(profile)),
                "Preview Revert again.")
        end
        local ops, preview, lines = revertPlan(profile)
        if not confirm then
            return showReview("revert", "Revert last Apply? Open Details to review the batch.", lines,
                { profile = profile, undo = profile.undo, state = profileState(profile), preview = preview })
        end
        local u = profile.undo
        C.execute(ops, u.bindings and u.bindings.plan, previous.preview)
        profile.text, profile.pending, profile.undo = u.before.text, u.before.pending, nil
        if frame then frame.edit:SetText(profile.text or "") end
        return showStatus({ "Reverted the last Apply for this profile." })
    end)
    if not ok then return showStatus({ "Revert stopped: " .. tostring(result) }) end
    return result
end

local function setAuto(enabled)
    BarsmithDB.auto = enabled
    invalidate()
    if frame then frame.auto:SetChecked(enabled) end
    if enabled then queueAutoFill()
    elseif StaticPopup_Hide then StaticPopup_Hide("BARSMITH_LEVEL_UPDATES") end
end

local function tooltip(button, text)
    button:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function profileMenu(_, root)
    local current = P.character()
    if not current then return end
    root:SetScrollMode(320)
    root:CreateTitle(current.name or "Current character")
    for _, name in ipairs(P.names(current)) do
        root:CreateRadio(name, function() return current.active == name end, function()
            if P.character() == current and current.active ~= name then P.manage("select", name) end
        end)
    end

    local others, counts, qualifiedCounts = {}, {}, {}
    for guid, c in pairs(BarsmithDB.characters) do
        local name = c.name or guid
        local qualified = c.realm and c.realm ~= "" and (name .. " - " .. c.realm) or name
        counts[name] = (counts[name] or 0) + 1
        qualifiedCounts[qualified] = (qualifiedCounts[qualified] or 0) + 1
        if c ~= current then
            table.insert(others, { guid = guid, owner = c, name = name, qualified = qualified })
        end
    end
    if #others == 0 then return end
    for _, row in ipairs(others) do
        row.label = counts[row.name] == 1 and row.name or row.qualified
        if qualifiedCounts[row.qualified] > 1 then row.label = row.label .. " (" .. row.guid .. ")" end
    end
    table.sort(others, function(a, b) return a.label < b.label end)
    root:CreateDivider()
    local section = root:CreateButton("Other characters")
    section:SetScrollMode(320)
    for _, row in ipairs(others) do
        local group = section:CreateButton(row.label)
        group:SetScrollMode(320)
        group:CreateTitle("Copy to " .. (current.name or "this character"))
        for _, name in ipairs(P.names(row.owner)) do
            group:CreateButton(name, function()
                if P.character() ~= current then return end
                local copied, err = P.copyFrom(row.guid, name)
                showStatus({ copied and ("Copied " .. copied .. " as a draft. Review the plan with Check before Apply.") or err })
            end)
        end
    end
end

local FORM_LABELS = {
    DRUID = { [73] = "Cat Form", [85] = "Prowl", [97] = "Bear Form", [109] = "Moonkin Form" },
    WARRIOR = { [73] = "Battle Stance", [85] = "Defensive Stance", [97] = "Berserker Stance" },
    ROGUE = { [73] = "Stealth" }, PRIEST = { [73] = "Shadowform" },
}

local function managedBarsMenu(_, root)
    local p = P.active()
    if not p then return end
    local forms = FORM_LABELS[select(2, UnitClass("player"))] or {}
    root:SetScrollMode(360)
    root:CreateTitle("Managed action slots")
    local function page(first, name)
        root:CreateCheckbox(("%s (%d–%d)"):format(name, first, first + 11),
            function() return P.managesSlot(p, first) end,
            function() P.setBarManaged(p, first, not P.managesSlot(p, first)) end)
    end
    for _, bar in ipairs(PAGES) do page(bar.first, forms[bar.first] or bar.label) end
    -- BP2 also accepts explicit SLOT records on these two physical pages.
    page(121, "Other page 11")
    page(133, "Other page 12")
end

local PROFILE_NAME_DIALOG = "BARSMITH_PROFILE_NAME"
local nameActions = {
    create = { prompt = "New profile name:", accept = "Save" },
    rename = { prompt = "Rename profile:", accept = "Rename" },
    duplicate = { prompt = "Duplicate profile as:", accept = "Duplicate" },
}

local function askProfileName(op, editorText)
    local profile, c = P.active()
    if not profile then return showStatus({ "Character identity unavailable." }) end
    local suggested = c.active
    if op == "create" then
        local plan = BP.parse(editorText)
        suggested = plan and trim(plan.name) or ""
        if suggested:match(" %(from game%)$") then suggested = "" end
        suggested = cutBytes(suggested, 64)
    elseif op == "duplicate" then
        local n = 1
        repeat
            local suffix = n == 1 and " Copy" or (" Copy " .. n)
            suggested = cutBytes(c.active, 64 - #suffix) .. suffix
            n = n + 1
        until not c.profiles[suggested]
    end
    local dialog = StaticPopup_Show(PROFILE_NAME_DIALOG, nameActions[op].prompt, nil,
        { op = op, profile = profile, suggested = suggested, editorText = editorText })
    if not dialog then showStatus({ "Close another dialog and try again." }) end
end

local function buildFrame()
    local f = CreateFrame("Frame", "BarsmithFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(620, 558)
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
    help:SetPoint("TOPLEFT", 16, -93)
    help:SetWidth(448)
    help:SetJustifyH("LEFT")
    help:SetText("Paste a setup plan and click Check to review it before Apply.")

    local scroll = CreateFrame("ScrollFrame", "BarsmithScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -117)
    scroll:SetPoint("BOTTOMRIGHT", -38, 306)

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
    report:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -38, 108)
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
    f.summaryTab = button("Summary", 16, 82, function() display("summary"); refreshApply() end, 271)
    f.detailsTab = button("Details", 102, 72, function() display("details"); refreshApply() end, 271)
    f.summaryTab:Disable()
    f.diagnosticsButton = button("Full diagnostics", 288, 124, function()
        display(f.view == "full" and "details" or "full")
        refreshApply()
    end, 271)
    f.diagnosticsButton:Hide()
    button("Copy report", 178, 106, function()
        display(f.view == "full" and "full" or "details")
        status:SetFocus()
        status:HighlightText()
        f.hint:SetText("Press Ctrl+C to copy.")
    end, 271)
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.hint:SetPoint("LEFT", f, "BOTTOMLEFT", 418, 283)
    button("Check", 16, 68, function() edit:ClearFocus(); BP.run(edit:GetText(), true) end)
    f.apply = button("Apply", 88, 68, function() edit:ClearFocus(); BP.run(edit:GetText(), false) end)
    f.apply:Disable()
    f.hint:SetText(CHECK_HINT)
    edit:SetScript("OnTextChanged", function()
        invalidate()
        f.summary, f.details, f.full = {}, {}, {}
        display("summary")
        refreshApply()
    end)
    local function exportHelp(msg)
        f.summary, f.details, f.full = { msg }, { msg }, { msg }
        display("summary")
    end
    local function selectText(text, helpText)
        edit:SetText(text)
        refreshApply()
        edit:SetFocus()
        edit:HighlightText()
        exportHelp(helpText)
    end
    local function exportSetup()
        local ok, result = pcall(BP.exportCurrent)
        if not ok then return showStatus({ "Export stopped: " .. tostring(result) }) end
        selectText(result, SETUP_HELP)
    end
    f.exportSetup = exportSetup
    button("Export setup", 160, 117, exportSetup)
    button("Last applied plan", 281, 124, function()
        local profile = P.active()
        local last = profile and profile.lastApplied
        if not last or last == "" then
            f.hint:SetText("No plan applied yet.")
            return
        end
        selectText(last, "Last applied plan. Press Ctrl+C to copy, or Check to review it for reapplication.")
    end)
    local census = button("Census", 409, 72, function()
        local ok, snapshot = pcall(B.census, esc)
        if not ok then showStatus({ "Census failed: " .. tostring(snapshot) }); return end
        selectText(snapshot, "Copy this read-only BC1 census. Load it into the planner with your plan open.")
    end)
    button("Clear", 485, 55, function() edit:SetText(""); edit:SetFocus() end)

    tooltip(census, "Creates a read-only snapshot of current WoW keybindings, including detectable secondary and addon bindings. Use it with the planner or an AI assistant to avoid conflicts.")

    local auto = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    auto:SetSize(24, 24)
    auto:SetPoint("BOTTOMLEFT", 494, 14)
    local autoLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autoLabel:SetPoint("LEFT", auto, "RIGHT", 2, 0)
    autoLabel:SetText("Auto-fill new spells")
    auto:SetChecked(BarsmithDB.auto)
    auto:SetScript("OnClick", function(self) setAuto(self:GetChecked() and true or false) end)
    f.auto = auto

    local characterLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    characterLabel:SetPoint("TOPLEFT", 16, -33)
    characterLabel:SetWidth(190)
    characterLabel:SetWordWrap(false)
    characterLabel:SetJustifyH("LEFT")
    local selector = CreateFrame("DropdownButton", nil, f, "WowStyle1DropdownTemplate")
    selector:SetSize(326, 24)
    selector:SetPoint("TOPRIGHT", -18, -25)
    selector.Text:SetJustifyH("LEFT")
    selector:SetupMenu(profileMenu)
    local profileLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    profileLabel:SetPoint("RIGHT", selector, "LEFT", -12, 0)
    profileLabel:SetText("Profile:")

    button("Save new", 16, 100, function() askProfileName("create", edit:GetText()) end, 478)
    button("Rename", 122, 92, function() askProfileName("rename") end, 478)
    button("Duplicate", 220, 98, function() askProfileName("duplicate") end, 478)
    button("Delete", 324, 80, function()
        local p, c = P.active()
        if p then showReview("delete", "Delete profile " .. c.active .. " and its Revert snapshot?",
            { "Your live action bars and bindings will stay in place." }, { profile = p }) end
    end, 478)
    button("Managed bars...", 478, 126, function(self) MenuUtil.CreateContextMenu(self, managedBarsMenu) end, 478)
    local legacy = button("Import old plan", 478, 126, function()
        if BarsmithDB.legacyPlan then
            edit:SetText(BarsmithDB.legacyPlan)
            showStatus({ "Legacy account plan loaded for review. Check and Apply on the owning character." })
        end
    end, 447)
    tooltip(legacy, "Loads the account-wide Barsmith plan saved before profiles were added. Loading only fills the editor. Use Check, then Apply on the intended character.")
    local overwrite = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    overwrite:SetSize(24, 24)
    overwrite:SetPoint("BOTTOMLEFT", 16, 44)
    local policyLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    policyLabel:SetPoint("LEFT", overwrite, "RIGHT", 2, 0)
    policyLabel:SetText("Auto-overwrite occupied managed slots for newly available actions")
    overwrite:SetScript("OnClick", function(self)
        local p = P.active()
        if p then p.overwrite = self:GetChecked() and true or false end
        invalidate()
        if p and p.overwrite and BarsmithDB.auto then queueAutoFill() end
    end)
    refreshProfiles = function()
        if BarsmithDB and BarsmithDB.legacyPlan then legacy:Show() else legacy:Hide() end
        local p, c = P.active()
        if not p then return end
        characterLabel:SetText(c.name or "Current character")
        selector:OverrideText(c.active)
        overwrite:SetChecked(p.overwrite == true)
    end
    local pending = button("Review pending updates", 16, 184, function() BP.levelUpdates("review") end, 75)
    local revert = button("Revert last Apply", 204, 140, function() BP.revert(false) end, 75)
    tooltip(pending, "Auto-fill handles leveling automatically. Review occupied-slot replacements here, including any you postponed.")
    tooltip(revert, "Preview and restore the Barsmith-managed state from immediately before this profile's most recent Apply.")
    f.confirm = button("Confirm", 348, 138, function()
        if not review then return end
        if review.kind == "revert" then BP.revert(true)
        elseif review.kind == "level" then BP.levelUpdates("confirm")
        elseif review.kind == "delete" and review.profile == P.active() then
            invalidate()
            local ok, err = P.manage("delete")
            if not ok then showStatus({ err }) end
        end
    end, 75)
    f.later = button("Cancel", 490, 76, function()
        invalidate()
        showStatus({ "Canceled. You can review this batch again." })
    end, 75)
    f.confirm:Hide()
    f.later:Hide()
    f:SetScript("OnHide", function()
        invalidate()
        StaticPopup_Hide(PROFILE_NAME_DIALOG)
    end)

    f:Hide()
    return f
end

local function openFrame(text)
    if not frame then
        frame = buildFrame()
        local profile = P.active()
        text = text or (profile and profile.text)
    end
    refreshProfiles()
    frame.auto:SetChecked(BarsmithDB.auto)
    if text then frame.edit:SetText(text) end
    frame:Show()
end

------------------------------------------------------------------------
-- Only pending (previously unavailable) actions can displace an occupied slot.
-- An empty slot on an applied profile retains the original refill behavior.
local autoQueued, autoAfterCombat, autoAfterCursor = false, false, false
local notified

local function levelBatch(profile)
    local batch = { empty = {}, occupied = {}, settled = {} }
    local pickups = {}
    if not profile or not profile.pending or not profile.text then return batch, pickups end
    local plan = assert(BP.parse(profile.text))
    assert(not plan.class or plan.class == select(2, UnitClass("player")), "Plan class mismatch.")
    local book = spellbookEntries()
    for _, s in ipairs(managedSlots(plan, profile)) do
        if (s.kind == "spell" or s.kind == "item") and (profile.pending[s.slot] or not HasAction(s.slot)) then
            local target = available(s, book)
            if target and target.id then
                local before = C.slot(s.slot)
                if before.kind == s.kind and before.id == target.id then
                    table.insert(batch.settled, s.slot)
                else
                    local op = { slot = s.slot, before = before, after = { kind = s.kind, id = target.id } }
                    if before.kind == "macro" then op.previousMacro = C.macro(before.name) end
                    table.insert(before.kind == "empty" and batch.empty or batch.occupied, op)
                    pickups[s.slot] = target.pickup
                end
            end
        end
    end
    return batch, pickups
end

local function placeBatch(profile, ops, pickups)
    local byIndex = {}
    for i, op in ipairs(ops) do
        requireRestorable(op.slot, op.before)
        byIndex[i] = pickups[op.slot]
    end
    C.execute(ops, nil, nil, byIndex)
    for _, op in ipairs(ops) do profile.pending[op.slot] = nil end
end

function BP.levelUpdates(mode)
    local profile = P.active()
    local previous = review
    if mode ~= "event" then invalidate() end
    if not (BarsmithDB and BarsmithDB.auto and profile) then
        if mode ~= "event" then showStatus({ "Auto-fill is disabled or the character is unavailable." }) end
        return
    end
    local ok, err = pcall(function()
        ready()
        local batch, pickups = levelBatch(profile)
        local occupied = batch.occupied
        if mode == "confirm" then
            assert(previous and previous.kind == "level" and previous.profile == profile
                and previous.text == profile.text and C.equal(previous.ops, occupied),
                "Leveling replacements changed. Open Review pending updates again.")
            placeBatch(profile, occupied, pickups)
            notified = nil
            return showStatus({ #occupied .. " reviewed replacements applied." })
        end
        if mode == "event" then
            for _, slot in ipairs(batch.settled) do profile.pending[slot] = nil end
            placeBatch(profile, batch.empty, pickups)
            if #batch.empty > 0 then say("Filled " .. #batch.empty .. " empty managed slots.") end
            if #occupied == 0 then notified = nil; return end
            if profile.overwrite then
                placeBatch(profile, occupied, pickups)
                say("Updated " .. #occupied .. " occupied managed slots for this profile.")
                notified = nil
                return
            end
            if notified and notified.profile == profile and C.equal(notified.ops, occupied) then return end
            notified = { profile = profile, ops = occupied }
            local msg = #occupied .. " newly available actions would replace occupied managed slots."
            if StaticPopup_Show then
                StaticPopup_Show("BARSMITH_LEVEL_UPDATES", msg)
            else say(msg .. " Open Review pending updates.") end
        elseif #occupied == 0 then
            showStatus({ "No occupied managed slots need leveling updates." })
        else
            local lines = {}
            for _, op in ipairs(occupied) do
                table.insert(lines, slotLabel(op.slot) .. ": " .. label(op.before) .. " -> " .. label(op.after))
            end
            showReview("level", #occupied .. " leveling replacements. Review Details, then approve the batch.",
                lines, { profile = profile, text = profile.text, ops = occupied })
        end
    end)
    if not ok then
        if mode == "event" then say("Auto-fill paused: " .. tostring(err))
        else showStatus({ "Level updates stopped: " .. tostring(err) }) end
    end
end

if StaticPopupDialogs then
    StaticPopupDialogs[PROFILE_NAME_DIALOG] = {
        text = "%s", button1 = "Save", button2 = "Cancel", hasEditBox = true,
        editBoxWidth = 280, maxLetters = 64, timeout = 0, whileDead = true, hideOnEscape = true,
        OnShow = function(dialog, data)
            dialog:GetButton1():SetText(nameActions[data.op].accept)
            local input = dialog:GetEditBox()
            input:SetText(data.suggested)
            input:SetFocus()
            input:HighlightText()
        end,
        OnAccept = function(dialog, data)
            if P.active() ~= data.profile then
                showStatus({ "The active profile changed. Open the name dialog again." })
                return
            end
            local ok, err = P.manage(data.op, dialog:GetEditBox():GetText(), data.editorText)
            if not ok then
                dialog:SetFormattedText("%s\n%s", nameActions[data.op].prompt, err)
                dialog:Resize()
                return true -- Keep the input available for correction.
            end
        end,
        EditBoxOnEnterPressed = function(input) StaticPopup_OnClick(input:GetParent(), 1) end,
        EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
    }
    StaticPopupDialogs.BARSMITH_LEVEL_UPDATES = {
        text = "%s", button1 = "Review batch", button2 = "Later", timeout = 0, whileDead = false, hideOnEscape = true,
        OnAccept = function() openFrame(); BP.levelUpdates("review") end,
    }
end

P.onBarsChanged = function()
    invalidate()
    notified = nil
    if StaticPopup_Hide then StaticPopup_Hide("BARSMITH_LEVEL_UPDATES") end
    showStatus({ "Managed bars updated. Run Check to review the plan with these settings." })
end

P.onChange = function()
    invalidate()
    notified = nil
    if StaticPopup_Hide then StaticPopup_Hide("BARSMITH_LEVEL_UPDATES") end
    if frame then
        local profile = P.active()
        frame.edit:SetText(profile.text or "")
        refreshProfiles()
    end
end

queueAutoFill = function()
    if autoQueued then return end
    autoQueued = true
    C_Timer.After(1, function()
        autoQueued = false
        if InCombatLockdown() then autoAfterCombat = true; return end
        if GetCursorInfo() then autoAfterCursor = true; return end
        autoAfterCursor = false
        BP.levelUpdates("event")
    end)
end

local events = CreateFrame("Frame")
-- Not every client has every event (Classic Era has no LEARNED_SPELL_IN_TAB;
-- newer clients call it LEARNED_SPELL_IN_SKILL_LINE),
-- and registering an unknown one is an error that would stop the file here.
for _, ev in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE", "BAG_UPDATE_DELAYED", "CURSOR_CHANGED", "PLAYER_REGEN_ENABLED" }) do
    pcall(events.RegisterEvent, events, ev)
end
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Barsmith" then
            P.init()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        P.character()
        queueAutoFill()
    elseif event == "CURSOR_CHANGED" then
        if autoAfterCursor and not GetCursorInfo() then queueAutoFill() end
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
        local p = P.active()
        if p and p.lastApplied then openFrame(p.lastApplied); BP.run(p.lastApplied, true)
        else say("No plan applied yet. Type /barsmith and paste one.") end
    elseif msg == "auto" then
        setAuto(not BarsmithDB.auto)
        say("Auto-fill new spells is " .. (BarsmithDB.auto and "on." or "off."))
    elseif msg == "export" then
        openFrame()
        frame.exportSetup()
    elseif frame and frame:IsShown() then
        frame:Hide()
    else
        openFrame()
    end
end

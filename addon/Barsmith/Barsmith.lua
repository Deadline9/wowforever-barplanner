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

local B, T = BP.bindings, BP.transformations
local DEFAULT_ICON = 134400
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

local FORM_LABELS = {
    DRUID = { [73] = "Cat Form", [85] = "Prowl", [97] = "Bear Form", [109] = "Moonkin Form" },
    WARRIOR = { [73] = "Battle Stance", [85] = "Defensive Stance", [97] = "Berserker Stance" },
    ROGUE = { [73] = "Stealth" }, PRIEST = { [73] = "Shadowform" },
}

local function slotLabel(slot)
    for _, p in ipairs(PAGES) do
        if slot >= p.first and slot < p.first + 12 then
            local forms = FORM_LABELS[select(2, UnitClass("player"))]
            return (forms and forms[p.first] or p.label) .. " button " .. (slot - p.first + 1)
        end
    end
    return "slot " .. slot
end

-- ACTIONBUTTON is one physical key row across every paged main bar.
-- Its ownership switch is Bar 1. Form/page exclusions only protect slots.
local function protectedCommands(profile)
    local protected = {}
    for _, page in ipairs(PAGES) do
        if page.bind and not BP.profiles.managesSlot(profile, page.first) then
            for button = 1, 12 do protected[page.bind .. button] = page.label end
        end
    end
    return protected
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

local function spellKnown(id)
    return isKnownSpell(id)
        or (C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook and C_SpellBook.IsSpellKnownOrInSpellBook(id))
        or (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id))
        or (IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(id))
end

local function baseSpell(id)
    local find = C_SpellBook and C_SpellBook.FindBaseSpellByID or C_Spell and C_Spell.GetBaseSpell
    return find and id and find(id)
end

local function overrideSpell(id)
    local find = C_SpellBook and C_SpellBook.FindSpellOverrideByID or C_Spell and C_Spell.GetOverrideSpell
    return find and id and find(id)
end

-- The spellbook query may return the input ID when an override is inactive.
-- Check both sources and let the caller verify the proposed physical action.
local function visitSpellBases(id, visit)
    if not id or id <= 0 then return end
    if C_SpellBook and C_SpellBook.FindBaseSpellByID then visit(C_SpellBook.FindBaseSpellByID(id)) end
    if C_Spell and C_Spell.GetBaseSpell then visit(C_Spell.GetBaseSpell(id)) end
end

local function overridesSpell(base, alias)
    return base and base ~= alias
        and ((C_SpellBook and C_SpellBook.FindSpellOverrideByID and C_SpellBook.FindSpellOverrideByID(base) == alias)
            or (C_Spell and C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(base) == alias))
end

-- Exclude override-only matches when the plan asks for a specific variant.
local function independentlyKnown(id)
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    return isKnownSpell(id)
        or (C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook and C_SpellBook.IsSpellKnownOrInSpellBook(id, bank, false))
        or (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id))
end

local function spellNameKey(name)
    return (name or ""):lower():gsub("%s+%(", "(")
end

local function matchesSpellName(wanted, name, subtext)
    if not name or name == "" then return false end
    return spellNameKey(name) == wanted
        or (subtext and subtext ~= "" and spellNameKey(name .. "(" .. subtext .. ")") == wanted)
end

-- Identifier APIs may return the currently displayed spell, even for a name
-- with a different qualifier. Only an exact name/subtext identifies an alias.
local function learnedSpellIDByName(name, qualifier, aliases)
    local wanted = spellNameKey(name)
    local learned, overrideOnly
    local function inspect(id)
        if not id or id <= 0 then return end
        local passive = (C_Spell and C_Spell.IsSpellPassive) or IsPassiveSpell
        if passive and passive(id) then return end
        local actual, sub = getSpellName(id), getSpellSubtext(id)
        if matchesSpellName(wanted, actual, sub) then
            -- Numbered subtexts can be localized ranks. Keep them exact.
            if not (qualifier and qualifier:find("%d")) or spellNameKey(actual) == wanted then aliases[id] = true end
        elseif qualifier and (actual and actual ~= "" or (sub or ""):lower() ~= qualifier) then
            return
        end
        if not spellKnown(id) then return end
        if qualifier and not independentlyKnown(id) then overrideOnly = overrideOnly or id
        else learned = learned or id end
    end
    if C_Spell and C_Spell.GetSpellIDForSpellIdentifier then inspect(C_Spell.GetSpellIDForSpellIdentifier(name)) end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(name)
        if info then inspect(info.spellID) end
    end
    if GetSpellInfo then inspect(select(7, GetSpellInfo(name))) end
    return learned, overrideOnly
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
local function spellbookEntries(verifyContext)
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
    local list = { byID = {}, transforms = T.view(verifyContext) }
    for i = 1, count do
        local name, rank, spellID, overrideID, overrideName, overrideRank, usable
        if useNewSpellBook() then
            local info = C_SpellBook.GetSpellBookItemInfo(i, Enum.SpellBookSpellBank.Player)
            if info and info.itemType == Enum.SpellBookItemType.Spell and not info.isPassive and not info.isOffSpec and info.name then
                name, rank, spellID = info.name, info.subName, info.spellID
                if info.actionID and info.actionID ~= info.spellID then
                    overrideName, overrideRank = info.name, info.subName
                    spellID, overrideID = info.actionID, info.spellID
                    name, rank = getSpellName(spellID), getSpellSubtext(spellID)
                end
                usable = spellID and (name or overrideName)
            end
        else
            name, rank, spellID = GetSpellBookItemName(i, BOOK)
            local kind, bookID
            if GetSpellBookItemInfo then kind, bookID = GetSpellBookItemInfo(i, BOOK) end
            spellID = spellID or bookID
            usable = name and kind == "SPELL" and not (IsPassiveSpell and IsPassiveSpell(i, BOOK))
        end
        if usable and type(spellID) == "number" and spellID > 0 then
            list[#list + 1] = { index = i, name = name or "", rank = rank or "", spellID = spellID,
                overrideID = overrideID, overrideName = overrideName, overrideRank = overrideRank }
            list.byID[spellID] = list[#list]
        end
    end
    return list
end
BP.changes.spellbookEntries = spellbookEntries

-- Scope the forward index to one book read. Check, Apply, export and event
-- scans each get a fresh view without querying every spell for every slot.
local function bookBases(book, alias)
    if not book.basesByOverride then
        local byOverride, overridden = {}, {}
        local function record(base, display)
            if not display or display <= 0 or display == base then return end
            byOverride[display] = byOverride[display] or {}
            byOverride[display][base], overridden[base] = true, true
        end
        local function forward(base)
            if C_SpellBook and C_SpellBook.FindSpellOverrideByID then record(base, C_SpellBook.FindSpellOverrideByID(base)) end
            if C_Spell and C_Spell.GetOverrideSpell then record(base, C_Spell.GetOverrideSpell(base)) end
        end
        for _, entry in ipairs(book) do
            record(entry.spellID, entry.overrideID)
            forward(entry.spellID)
        end
        local v = book.transforms
        for _, talent in ipairs(v and v.talents or {}) do
            if talent.replaces and talent.replaces > 0 then record(talent.replaces, talent.id) end
            if not book.byID[talent.id] then forward(talent.id) end
        end
        book.basesByOverride, book.overridden = byOverride, overridden
    end
    return book.basesByOverride[alias] or {}
end

-- A displayed override can represent different stored spells on different
-- buttons. Only substitute a base ID when the action-bar API locates that
-- base on this physical slot. Never infer an ability from the page's form.
local function slotContainsSpell(slot, id)
    if not (C_ActionBar and C_ActionBar.FindSpellActionButtons) then return false end
    local bank = Enum and Enum.ActionBarSet and Enum.ActionBarSet.Mkb
    for _, button in ipairs(C_ActionBar.FindSpellActionButtons(id, bank) or {}) do
        if slot == button then return true end
    end
    return false
end

local function pickupBookEntry(index)
    if useNewSpellBook() and C_SpellBook.PickupSpellBookItem then
        C_SpellBook.PickupSpellBookItem(index, Enum.SpellBookSpellBank.Player)
    elseif PickupSpellBookItem then
        PickupSpellBookItem(index, BOOK)
    end
end

local function exactBookIndex(id)
    if useNewSpellBook() and C_SpellBook.FindSpellBookSlotForSpell then
        local i, bank = C_SpellBook.FindSpellBookSlotForSpell(id, true, true, false, false)
        if i and bank == Enum.SpellBookSpellBank.Player then
            local row = C_SpellBook.GetSpellBookItemInfo(i, bank)
            if row and row.itemType == Enum.SpellBookItemType.Spell and not row.isPassive and row.actionID == id then return i end
        end
    end
end

local function placeableBase(book, id)
    if not id or id <= 0 then return false end
    if book.byID[id] or exactBookIndex(id) then return true end
    local passive = (C_Spell and C_Spell.IsSpellPassive) or IsPassiveSpell
    return independentlyKnown(id) and not (passive and passive(id))
end

function BP.changes.slotSpellID(slot, reported, book)
    local verified, competing
    local function locate(base)
        if not base or base <= 0 or base == reported or base == verified then return end
        competing = base
        if slotContainsSpell(slot, base) then
            assert(not verified, "Ambiguous base spell on " .. slotLabel(slot) .. " [" .. slot .. "]")
            verified = base
        end
    end
    book = book or spellbookEntries()
    visitSpellBases(reported, locate)
    if C_ActionBar and C_ActionBar.GetSpell and C_ActionBar.FindSpellActionButtons then
        local candidate = C_ActionBar.GetSpell(slot)
        -- GetSpell can also return the effective spell. Reverse lookup is
        -- documented for base IDs; an override alias is not a second base.
        if candidate and candidate ~= reported and baseSpell(candidate) ~= reported
            and not (C_Spell and C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(candidate) == reported)
            and not overridesSpell(reported, candidate) then locate(candidate) end
    end
    for base in pairs(bookBases(book, reported)) do locate(base) end
    local v = book.transforms
    local history = v and v.edges[reported]
    if history and not verified then
        local containsReported = slotContainsSpell(slot, reported)
        for base in pairs(history) do
            if placeableBase(book, base) then
                if containsReported then
                    assert(not slotContainsSpell(slot, base), ("Ambiguous physical spell on %s [%d]: both %d and observed base %d match.")
                        :format(slotLabel(slot), slot, reported, base))
                else locate(base) end
            end
        end
    end
    if competing and not verified and not slotContainsSpell(slot, reported) then
        error(("Cannot identify the physical spell on %s [%d]: reported %s, possible base %s, no matching slot membership.")
            :format(slotLabel(slot), slot, tostring(reported), tostring(competing)))
    end
    return verified or reported
end

local function spellTarget(id, entry)
    local index = entry and entry.index or exactBookIndex(id)
    return { kind = "spell", id = id, pickup = function(alternate)
        if alternate and not index then return false end
        if index and not alternate then pickupBookEntry(index) else pickupSpellID(id) end
    end }
end

local function cursorBookRow(index, bank)
    if not (index and index > 0 and bank ~= nil) then return end
    if useNewSpellBook() then
        local row = C_SpellBook.GetSpellBookItemInfo(index, Enum.SpellBookSpellBank.Player)
        if row and row.itemType == Enum.SpellBookItemType.Spell then return row.actionID, row.spellID end
    elseif GetSpellBookItemInfo then
        local kind, id = GetSpellBookItemInfo(index, BOOK)
        if kind == "SPELL" then return id end
    end
end

-- GetCursorInfo's second result is a book index. Its fourth and fifth
-- results identify the effective and base spells. A common ancestor alone
-- cannot establish which of two independently requested variants is held.
function BP.changes.spellCursor(slot, wanted, requested)
    local kind, index, bank, effective, base = GetCursorInfo()
    local playerBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    local issue, competingBase, rowBase, rowEffective
    local targetBase, targetOverride = baseSpell(wanted), overrideSpell(wanted)
    local cursorBase = kind == "spell" and effective and effective > 0 and baseSpell(effective) or nil
    local validBank = bank == nil or bank == BOOK or bank == playerBank
    if kind == "spell" and validBank and (not base or base <= 0) and effective ~= wanted then
        rowBase, rowEffective = cursorBookRow(index, bank)
    end
    if not kind then issue = "pickup unavailable (empty cursor)"
    elseif kind ~= "spell" then issue = "unexpected cursor type"
    elseif not validBank then issue = "unexpected spellbook bank"
    elseif base and base > 0 then
        if base ~= wanted then
            if effective == wanted and base == targetBase then competingBase = base
            else issue = "cursor base does not identify the requested spell" end
        end
    elseif effective and effective > 0 then
        if effective ~= wanted then
            if (effective == targetBase and overrideSpell(effective) == wanted)
                or (rowBase == effective and rowEffective == wanted) then competingBase = effective
            elseif effective ~= targetOverride and not (rowBase == wanted and rowEffective == effective) then issue = "unexpected cursor spell ID" end
        end
    elseif bank ~= nil and index and index > 0 then
        if rowBase ~= wanted then issue = "cursor book row does not identify the requested spell" end
    else issue = "missing cursor spell identity" end
    if competingBase and not (C_ActionBar and C_ActionBar.FindSpellActionButtons) then
        issue = "cannot verify the physical slot independently of the displayed override"
    end
    local function diagnostic(reason)
        return ("%s [%d], request %s, resolved %s (%s), base %s, override %s; cursor type %s, index %s, bank %s, spell %s, base %s, lookup base %s: %s")
            :format(slotLabel(slot), slot, tostring(requested or ("spell:" .. wanted)), tostring(getSpellName(wanted) or "?"),
                wanted, tostring(targetBase), tostring(targetOverride), tostring(kind), tostring(index), tostring(bank),
                tostring(effective), tostring(base), tostring(cursorBase), reason)
    end
    return issue, diagnostic, competingBase
end
BP.changes.slotContainsSpell = slotContainsSpell

-- Resolve named display spells to physical player actions. Exact book rows
-- take precedence. A directed client relationship can identify a learned
-- base even when the displayed spell itself is absent from the current book.
local function namedSpellTarget(wanted, stem, qualifier, aliases, book)
    local entries, targets = book.byID, {}
    local v = book.transforms
    for _, entry in ipairs(book) do
        local alias = entry.overrideID
        if alias then
            local name = getSpellName(alias)
            local numbered = qualifier and qualifier:find("%d")
            if spellNameKey(entry.overrideName) == wanted or spellNameKey(name) == wanted
                or (not numbered and (matchesSpellName(wanted, entry.overrideName, entry.overrideRank)
                    or matchesSpellName(wanted, name, getSpellSubtext(alias)))) then
                aliases[alias] = true
            end
        end
    end
    -- Selected talent definitions and forward-only clients can expose a
    -- numeric pair even if the identifier lookup for this name returns nil.
    bookBases(book, nil)
    for alias in pairs(book.basesByOverride) do
        local name = getSpellName(alias)
        if spellNameKey(name) == wanted or (not (qualifier and qualifier:find("%d"))
            and matchesSpellName(wanted, name, getSpellSubtext(alias))) then aliases[alias] = true end
    end
    for alias in pairs(aliases) do
        if entries[alias] or exactBookIndex(alias) then
            targets[alias] = true
        else
            local related = false
            local function consider(base)
                if not base or base <= 0 or base == alias then return end
                if not placeableBase(book, base) then return end
                if v then T.record(v.pending, base, alias, wanted) end
                targets[base], related = true, true
            end
            visitSpellBases(alias, consider)
            for base in pairs(bookBases(book, alias)) do consider(base) end
            if qualifier and not related then
                -- Some clients expose the learned base only through a name
                -- lookup. The stem alone never authorizes a placement.
                local base = learnedSpellIDByName(stem, nil, {})
                if overridesSpell(base, alias) then consider(base) end
            end
            if not related and independentlyKnown(alias) then targets[alias] = true end
        end
    end
    -- Numeric subtexts may be localized ranks. Never convert one through
    -- history. A current, exact book row still takes its ordinary path.
    local history = v and not (qualifier and qualifier:find("%d")) and v.edges
    for alias, bases in pairs(history or {}) do
        for base, names in pairs(bases) do
            if names[wanted] and placeableBase(book, base) then
                -- An independent learned variant always gets its normal name
                -- resolution. A historical label alone cannot authorize it.
                if not entries[alias] and not exactBookIndex(alias) and not independentlyKnown(alias) then
                    -- A new exact name lookup can identify a different spell
                    -- even before it is learned. Do not fill from an old name.
                    local conflicting = next(aliases) and not aliases[alias] and not targets[base]
                    visitSpellBases(alias, function(live)
                        if live and live > 0 and live ~= alias and live ~= base then conflicting = true end
                    end)
                    for owner in pairs(bookBases(book, alias)) do
                        if owner ~= base then conflicting = true end
                    end
                    if conflicting then return nil, "observed and current spell relationships disagree; use an exported spell:ID" end
                    targets[base] = true
                end
            end
        end
    end
    local id = next(targets)
    if id then
        if next(targets, id) then
            return nil, "multiple learned actions match this spell name; use an exported spell:ID"
        end
        return spellTarget(id, entries[id])
    end
end

-- value: "Lightning Bolt", "Healing Wave(Rank 1)" or "spell:403".
-- Returns { kind, id, pickup } or nil, reason.
local function resolveSpell(value, book)
    local id = tonumber(value:match("^spell:(%d+)$"))
    if id then
        -- An explicit ID authorizes only that learned spell or book entry.
        if not independentlyKnown(id) and not exactBookIndex(id) then
            for _, e in ipairs(book) do
                if e.spellID == id then
                    return spellTarget(id, e)
                end
            end
            return nil, "not learned yet"
        end
        return spellTarget(id)
    end
    local base, rank = value:match("^(.-)%s*%(([^()]*)%)$")
    local stem = base or value
    base = stem:lower()
    rank = rank and trim(rank):lower()
    local wanted = spellNameKey(value)
    local found, unqualified, variant, ambiguous
    for _, e in ipairs(book) do
        local name = e.name:lower()
        if spellNameKey(e.name) == wanted or (name == base and (not rank or e.rank:lower() == rank)) then
            if rank and found and found.spellID ~= e.spellID and (found.rank == e.rank
                or not (found.rank:find("%d") and e.rank:find("%d"))) then
                return nil, "multiple learned actions match this spell name; use an exported spell:ID"
            end
            found = e
            if not rank and e.rank == "" then unqualified = e end
            if not rank and e.rank ~= "" and not e.rank:find("%d") then
                if variant and variant ~= e.spellID then ambiguous = true end
                variant = e.spellID
            end
        end
    end
    -- Two form qualifiers are alternatives, not successive ranks. An
    -- unqualified shared entry can represent both; book order cannot.
    if variant and unqualified then found = unqualified
    elseif ambiguous then
        error("Multiple spell variants for " .. value .. ". Specify the form or spell:ID.")
    end
    if found then
        return spellTarget(found.spellID, found)
    end
    -- Preserve the book's rank selection above. On a miss, ask the client for
    -- the learned form/override by name, keeping any rank or form qualifier.
    local aliases, overrideOnly = {}
    id, overrideOnly = learnedSpellIDByName(value, rank, aliases)
    if rank then
        local compact = value:gsub("%s+%(", "(")
        local alternate = compact ~= value and compact or value:gsub("%(", " (", 1)
        local other, otherOverride = learnedSpellIDByName(alternate, rank, aliases)
        id, overrideOnly = id or other, overrideOnly or otherOverride
    end
    local numberedRank = rank and rank:match("^rank%s*%d+$")
    if not numberedRank then
        local target, why = namedSpellTarget(wanted, stem, rank, aliases, book)
        if target or why then return target, why end
    end
    if not id and overrideOnly and exactBookIndex(overrideOnly) then id = overrideOnly end
    if id then
        if not rank then
            local baseID = baseSpell(id)
            local passive = (C_Spell and C_Spell.IsSpellPassive) or IsPassiveSpell
            if baseID and baseID ~= id and (getSpellName(baseID) or ""):lower() == base
                and independentlyKnown(baseID) and not (passive and passive(baseID)) then
                id = baseID
            end
        end
        if not independentlyKnown(id) and not exactBookIndex(id) then
            return nil, "only available as a temporary override (spell:" .. id .. ")"
        end
        return spellTarget(id)
    end
    if overrideOnly then return nil, "temporary override (spell:" .. overrideOnly .. "); cannot verify its learned action" end
    if numberedRank then
        return nil, "that rank isn't in your spellbook (turn on Show All Spell Ranks)"
    end
    if rank then return nil, "cannot verify a learned action for this spell name and qualifier; visit its active state or use an exported spell:ID" end
    return nil, "not learned yet"
end

-- Read-only with respect to the game. Observe even with Auto-fill off, in
-- combat or with an occupied cursor. Never call a resolved pickup closure.
local checkedNamesText, checkedCharacter
local observedPlanText, observedCheckText, observedNames
local function observeTransforms(eventBase, eventAlias)
    local v = T.view(true)
    if not v then return end
    local book = spellbookEntries()
    local function record(base, alias, name, sub)
        if not base or not alias or base == alias or not placeableBase(book, base) then return end
        -- Preserve full literal names. A plain name with a ranked/qualified
        -- subtext is evidence only for that exact spelling and subtext.
        if name and (not sub or sub == "" or name:match("%([^()]+%)$")) then
            T.record(v.edges, base, alias, spellNameKey(name))
        elseif name and not sub:find("%d") then
            T.record(v.edges, base, alias, spellNameKey(name .. "(" .. sub .. ")"))
        else T.record(v.edges, base, alias) end
    end
    if eventAlias then
        record(eventBase, eventAlias, getSpellName(eventAlias), getSpellSubtext(eventAlias))
        T.save(v)
        return
    end
    bookBases(book, nil)
    for alias, bases in pairs(book.basesByOverride) do
        for base in pairs(bases) do record(base, alias, getSpellName(alias), getSpellSubtext(alias)) end
    end
    for _, entry in ipairs(book) do
        if entry.overrideID then record(entry.spellID, entry.overrideID, entry.overrideName, entry.overrideRank) end
        visitSpellBases(entry.spellID, function(base)
            record(base, entry.spellID, entry.name, entry.rank)
        end)
    end
    -- Some learned actions are missing from enumerated skill lines. Their
    -- names in an applied plan can still yield a verified numeric API pair.
    local profile = BP.profiles.active()
    local text = profile and profile.pending and profile.text
    local draft = checkedCharacter == v.character and checkedNamesText or nil
    if text ~= observedPlanText or draft ~= observedCheckText then
        observedPlanText, observedCheckText, observedNames = text, draft, {}
        local function watch(planText)
            local plan = planText and BP.parse(planText)
            for _, slot in ipairs(plan and plan.slots or {}) do
                if slot.kind == "spell" and not slot.value:match("^spell:%d+$") then observedNames[slot.value] = true end
            end
        end
        watch(text)
        if draft ~= text then watch(draft) end
    end
    for name in pairs(observedNames or {}) do
        -- An ambiguous name can block Check. It must not interrupt the
        -- read-only inspection of the remaining names in the applied plan.
        pcall(resolveSpell, name, book)
    end
    T.save(v)
end

-- Loading screens and protected combat data can make an optional API read
-- fail. Discovery must never cancel the existing leveling timer or repeat a
-- message on every form change.
local discoveryError
local function discover(base, alias)
    local ok, err = pcall(observeTransforms, base, alias)
    if not ok and not discoveryError then
        discoveryError = true
        say("Spell discovery deferred: " .. tostring(err))
    end
end

local function resolveItem(value)
    local id = tonumber(value:match("^item:(%d+)")) or tonumber(value) or getItemID(value)
    if not id or not haveItem(id) then return nil, "not in bags" end
    return { kind = "item", id = id, pickup = function() pickupItem(id) end }
end

local MACRO_NAME_MAX = 16
local C, P = BP.changes, BP.profiles

function C.pickup(action)
    if action.kind == "spell" then
        if independentlyKnown(action.id) or exactBookIndex(action.id) then return spellTarget(action.id).pickup end
        for _, entry in ipairs(spellbookEntries()) do
            if entry.spellID == action.id then return spellTarget(action.id, entry).pickup end
        end
    elseif action.kind == "item" and haveItem(action.id) then
        return function() pickupItem(action.id) end
    elseif action.kind == "macro" then
        local macro = C.macro(action.name)
        if macro and macro.perChar == action.perChar then
            return function() C.pickupMacro(action) end
        end
    end
end

local function label(action)
    if action.kind == "empty" then return "empty" end
    if action.kind == "unresolvedMacro" then return "unlabelled macro reference (ID 0)" end
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
    if not profile.excludedBars then return slots, clearFirst, {} end
    local included, excluded = {}, {}
    for _, s in ipairs(slots) do
        table.insert(P.managesSlot(profile, s.slot) and included or excluded, s)
    end
    return included, clearFirst, excluded
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

local function slotWhere(slot)
    return ("%s [%d]"):format(slotLabel(slot), slot)
end

local function macroIcon(icon)
    if not icon or icon == "" then return end
    local path = tostring(icon):lower():gsub("/", "\\")
    if path == "inv_misc_questionmark" or path == "interface\\icons\\inv_misc_questionmark" then return DEFAULT_ICON end
    if tonumber(icon) then return tonumber(icon) end
    if GetFileIDFromPath then
        if not path:find("\\", 1, true) then path = "interface\\icons\\" .. path end
        local id = GetFileIDFromPath(path)
        if (not id or id == 0) and not path:match("%.%w+$") then id = GetFileIDFromPath(path .. ".blp") end
        if id and id > 0 then return id end
    end
    return icon
end

local function excludedMacroUses(profile, name)
    local uses = {}
    local getText = C_ActionBar and C_ActionBar.GetActionText or GetActionText
    for first in pairs(profile.excludedBars or {}) do
        for slot = first, first + 11 do
            if GetActionInfo(slot) == "macro" and getText and (getText(slot) or ""):lower() == name:lower() then
                table.insert(uses, slot)
            end
        end
    end
    table.sort(uses)
    return uses
end

local function reviewPlan(plan, preview, profile, reapplying)
    local r = {
        binding = preview, bound = preview and #preview.changes or 0, bindsSame = preview and preview.same or 0,
        placed = 0, same = 0, cleared = 0, macrosNew = 0, macrosChanged = 0, macrosSame = 0,
        notLearned = {}, notInBags = {}, skipped = {}, problems = {}, slotDetails = {}, slotChanges = {},
        ops = {}, macroChecks = {}, pending = {}, fulfilled = {}, inspected = {}, overwrites = 0, futureOverwrites = 0,
    }
    local pickups, macros, repairTargets = {}, {}, {}
    local account, character = GetNumMacros()
    for _, m in ipairs(plan.macros) do
        local name = macroName(m.name)
        local key = name:lower()
        assert(not macros[key], "Duplicate macro: " .. name)
        local before = C.macro(name, true)
        local body = cutBytes(m.body, MACRO_BODY_MAX)
        if body ~= m.body then table.insert(r.problems, "Macro " .. name .. " will be shortened to 255 bytes.") end
        local requestedIcon = macroIcon(m.icon)
        local after = { name = before and before.name or name, body = body,
            icon = requestedIcon or (before and before.icon) or DEFAULT_ICON,
            perChar = m.perChar }
        if before then after.perChar = before.perChar end
        macros[key] = after
        r.inspected["Macro " .. name] = { before = before }
        -- Older clients cannot distinguish a selected question mark from its
        -- resolved texture. An identical body alone never proves a new icon.
        local checkIcon = requestedIcon and (requestedIcon ~= DEFAULT_ICON or (C_Macro and C_Macro.GetSelectedMacroIcon))
        if before and trim(before.body) == trim(body) and (not checkIcon or before.icon == requestedIcon) then
            r.macrosSame = r.macrosSame + 1
            table.insert(r.macroChecks, { name = name, before = before, after = before })
            if before.perChar == m.perChar then repairTargets[key] = before end
        else
            local op = { name = name, before = before, after = after }
            table.insert(r.ops, op)
            table.insert(r.macroChecks, op)
            if not before then repairTargets[key] = after end
            if before then
                local uses = excludedMacroUses(profile, name)
                r.inspected["Macro " .. name].excludedSlots = uses
                for _, slot in ipairs(uses) do
                    table.insert(r.problems, "Editing macro " .. name .. " also changes its use on excluded " .. slotWhere(slot) .. ".")
                end
                r.macrosChanged = r.macrosChanged + 1
            else
                if after.perChar then character = character + 1 else account = account + 1 end
                assert(character <= (MAX_CHARACTER_MACROS or 18) and account <= (MAX_ACCOUNT_MACROS or 120),
                    "Macro storage is full for " .. name)
                r.macrosNew = r.macrosNew + 1
            end
        end
    end
    local book = spellbookEntries("verify")
    local slots, clearFirst, excluded = managedSlots(plan, profile)
    r.excluded = #excluded
    -- A repeated Apply must not discard an already approved future
    -- placement while its page is reserved. Never arm a new excluded target.
    if #excluded > 0 and next(profile.pending or {}) and profile.text then
        local oldPlan = assert(BP.parse(profile.text))
        local _, _, oldExcluded = managedSlots(oldPlan, profile)
        local former = {}
        for _, s in ipairs(oldExcluded) do former[s.slot] = s end
        for _, s in ipairs(excluded) do
            if profile.pending[s.slot] and C.equal(former[s.slot], s) then r.pending[s.slot] = true end
        end
    end
    for _, s in ipairs(slots) do
        local repair = reapplying and s.kind == "macro" and repairTargets[macroName(s.value):lower()]
        local before = C.slot(s.slot, book, repair)
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
        r.inspected[slotWhere(s.slot)] = { current = before, intended = after, unavailable = why,
            currentMacro = oldMacro, intendedMacro = nextMacro }
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
            if after.kind == "spell" or after.kind == "item" then r.fulfilled[s.slot] = after.id end
            if before.kind == "unresolvedMacro" then
                description = "repair reference to " .. after.name
                table.insert(r.problems, slotWhere(s.slot) .. ": verify and repair " .. after.name
                    .. ". A recoverable action stops repair. Revert leaves a confirmed broken reference empty.")
            end
            local op = { slot = s.slot, before = before, after = after, previousMacro = oldMacro, placedMacro = nextMacro,
                requestedSpell = s.kind == "spell" and s.value or nil }
            if after.kind == "macro" then table.insert(r.macroChecks, op) end
            if C.equal(before, after) then
                same, description = true, description or "already correct"
                r.same = r.same + 1
            else
                table.insert(r.ops, op)
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
    if not dry and #r.macroChecks > 0 then
        local definitions = r.macrosSame + r.macrosNew + r.macrosChanged
        change(("Final verification passed for %s and %s."):format(countLabel(definitions, "macro definition"),
            countLabel(#r.macroChecks - definitions, "macro slot")))
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
        if #binding.excluded > 0 then
            local msg = ("Skipped %s to protect excluded bars."):format(countLabel(#binding.excluded, "binding instruction"))
            summary[#summary + 1] = msg
            change(msg)
            for _, reason in ipairs(binding.excluded) do change(reason) end
        end
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
    -- Unbooked names can resolve to a different override next time. Preserve
    -- exact IDs for override entries and for actions outside stable book rows.
    local v = book.transforms
    for _, bases in pairs(v and v.edges or {}) do
        if bases[id] and placeableBase(book, id) then return "spell:" .. id end
    end
    local listed
    for _, entry in ipairs(book) do
        if entry.spellID == id then
            if (book.overridden and book.overridden[id]) or (entry.rank ~= "" and not entry.rank:find("%d")) then return "spell:" .. id end
            listed = true
        end
    end
    if not listed then return "spell:" .. id end
    local name = getSpellName(id)
    if name and not name:match("%([^()]*%)$") then
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
    local book = spellbookEntries("verify")
    local seenMacro = {}
    local profile = P.active()
    local saved = profile and profile.pending and profile.text and BP.parse(profile.text)
    local explicit = {}
    if saved then for _, s in ipairs(saved.slots) do explicit[s.slot] = true end end
    local alternate = ALTERNATE_PAGES[class] or {}
    for _, p in ipairs(PAGES) do
        for i = 0, 11 do
            local slot = p.first + i
            if not alternate[p.first] or explicit[slot] then
                local kind, id = GetActionInfo(slot)
                if kind == "spell" then
                    plan.slots[#plan.slots + 1] = { slot = slot, kind = kind, value = exportSpell(C.slotSpellID(slot, id, book), book) }
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
local autoFailures, fulfilled, autoProfile = {}, {}
local function invalidate()
    checked, review = nil, nil
    if frame then frame.confirm:Hide(); frame.later:Hide() end
    refreshApply()
end

local function resetEditorReview()
    invalidate()
    frame.summary, frame.details, frame.full = {}, {}, {}
    display("summary")
end

-- SetText can notify after the caller has displayed help or completed Check.
-- Invalidate synchronously, even when loading identical text produces no event.
local function loadEditor(text)
    resetEditorReview()
    frame.edit:SetText(text)
end

local function profileState(p)
    local pending = p.pending and {}
    for slot in pairs(p.pending or {}) do pending[slot] = true end
    local excluded = {}
    for first in pairs(p.excludedBars or {}) do excluded[first] = true end
    return { text = p.text, pending = pending, excludedBars = excluded, overwrite = p.overwrite == true, auto = BarsmithDB.auto }
end

local function ready()
    assert(not InCombatLockdown(), "Can't change bars or keys in combat.")
    assert(not (GetCursorInfo and GetCursorInfo()), "Empty the cursor and try again.")
end

local function stopped(title, err)
    local message = type(err) == "table" and err.message or tostring(err)
    local headline = title .. ": " .. message
    local details = type(err) == "table" and err.details or { headline }
    return showStatus({ headline }, details, { headline .. "  Open Details for the full report." }, details)
end

function BP.run(text, dry)
    local previous = checked
    invalidate()
    local function stop(msg)
        return stopped(dry and "Check BLOCKED" or "Apply stopped", msg)
    end
    local profile = P.active()
    if not profile then return stop("Character identity unavailable.") end
    if not dry then
        if not previous then return stop(CHECK_HINT) end
        if previous.profile ~= profile then return stop("Active profile changed. " .. CHECK_HINT) end
        if previous.text ~= text then return stop("Editor plan changed. " .. CHECK_HINT) end
    end
    local plan, err = BP.parse(text)
    if not plan then return stop(err) end
    local _, class = UnitClass("player")
    if plan.class and plan.class ~= class then return stop("This plan is for a different class: " .. plan.class) end
    if dry then checkedNamesText, checkedCharacter = text, P.character() end
    local ok, result = pcall(function()
        ready()
        local preview = previous and not dry and previous.preview or nil
        if dry and #plan.binds > 0 then
            preview = B.preview(plan, B.capture(plan.binds), protectedCommands(profile))
            preview.legacy = plan.version == 1
        end
        local r, pickups = reviewPlan(plan, preview, profile, profile.pending and profile.text == trim(text))
        local state = profileState(profile)
        if not dry then
            local changes = {}
            C.differences(changes, "Reviewed actions", previous.inspected, r.inspected)
            C.differences(changes, "Profile", previous.state, state)
            C.checkDifferences(changes, "Reviewed state changed. Run Check again.")
        end
        for _, op in ipairs(r.ops) do
            if op.slot and op.before.kind ~= "unresolvedMacro" then requireRestorable(op.slot, op.before) end
        end
        if dry then
            if not preview or #preview.errors == 0 then
                checked = { text = text, profile = profile, state = state, inspected = r.inspected, preview = preview }
            end
        else
            local snapshot = { before = state, ops = r.ops, text = trim(text), visit = BarsmithDB.characterVisit,
                selectedIcons = C_Macro and C_Macro.GetSelectedMacroIcon ~= nil or false }
            snapshot.bindings = C.execute(r.ops, plan, preview, pickups, r.macroChecks)
            snapshot.verifyCreatedOnLoad = r.macrosNew > 0 or nil
            profile.text, profile.pending = snapshot.text, r.pending
            if #r.ops > 0 or snapshot.bindings or not C.equal(state, profileState(profile)) then
                profile.undo = snapshot
            end
            autoFailures, fulfilled, autoProfile = {}, r.fulfilled, profile
            profile.lastApplied = text
            if BarsmithDB.last == text then BarsmithDB.last = nil end
            if BarsmithDB.legacyPlan == text then BarsmithDB.legacyPlan = nil end
        end
        return r
    end)
    if not ok then return stop(result) end
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

function C.macroInUse(name, ops)
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

local function legacyMacroAfter(op, plan)
    for _, m in ipairs(plan.macros) do
        if macroName(m.name):lower() == op.name:lower() then
            local icon = macroIcon(m.icon) or (not op.before and DEFAULT_ICON)
            if icon == DEFAULT_ICON then
                return { name = op.after.name, body = op.after.body, perChar = op.after.perChar, icon = icon }
            end
        end
    end
    return op.after
end

local function revertPlan(profile)
    ready()
    local u = assert(profile.undo, "This profile has no Apply to revert.")
    local planDiff = {}
    C.differences(planDiff, "Profile plan", u.text, profile.text)
    C.checkDifferences(planDiff, "Profile plan changed since Apply.")
    local preview = C.reverseBindings(u.bindings, protectedCommands(profile))
    local ops, lines, editedMacros, sharedUses = {}, {}, {}, {}
    local book = spellbookEntries("verify")
    local legacy = not u.selectedIcons and C_Macro and C_Macro.GetSelectedMacroIcon and assert(BP.parse(u.text))
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
        local where = op.name and ("Macro " .. op.name) or slotWhere(op.slot)
        local differences = {}
        local applied = op.after
        if op.name and legacy then
            applied = legacyMacroAfter(op, legacy)
            if op.before and op.before.icon ~= DEFAULT_ICON then
                error(where .. ": older snapshot recorded only the displayed icon. Cannot verify the original icon selection.")
            end
        end
        C.differences(differences, where, applied, C.read(op, book))
        C.checkDifferences(differences, where .. " changed since Apply.")
        if op.slot then
            requireRestorable(op.slot, op.before)
            if op.placedMacro and not editedMacros[op.placedMacro.name:lower()] then
                C.differences(differences, where .. " / macro " .. op.placedMacro.name, op.placedMacro, C.macro(op.placedMacro.name))
                C.checkDifferences(differences, "Placed slot macro changed: " .. op.placedMacro.name)
            end
            if op.previousMacro and not editedMacros[op.previousMacro.name:lower()] then
                C.differences(differences, where .. " / macro " .. op.previousMacro.name, op.previousMacro, C.macro(op.previousMacro.name))
                C.checkDifferences(differences, "Previous slot macro changed: " .. op.previousMacro.name)
            end
            table.insert(lines, where .. ": " .. label(op.after) .. " -> " .. label(op.before))
        else
            if not op.before then
                assert(op.after.perChar or u.visit == BarsmithDB.characterVisit,
                    "Cannot verify other characters' uses of new account macro " .. op.name .. " after switching characters.")
                local used = C.macroInUse(op.name, included)
                assert(not used, used)
                -- A new key bound directly to this macro would lose its action.
                local cmd = "MACRO " .. op.name
                local bound = B.capture({}, { [cmd] = true }).rows[cmd].keys
                local moving = {}
                if preview then
                    for _, edge in ipairs(preview.changes) do moving[edge.key] = edge.new ~= cmd end
                end
                for key in pairs(bound) do
                    assert(moving[key],
                        "Macro now has a binding on " .. key)
                end
            end
            if op.before then
                sharedUses[op.name] = excludedMacroUses(profile, op.name)
                for _, slot in ipairs(sharedUses[op.name]) do
                    table.insert(lines, "Restoring macro " .. op.name .. " also affects excluded " .. slotWhere(slot) .. ".")
                end
            end
            table.insert(lines, op.before and ("Restore macro " .. op.name .. ":\n" .. op.before.body)
                or ("Delete macro " .. op.name .. " created by Apply."))
        end
        table.insert(ops, { slot = op.slot, name = op.name, before = applied, after = op.before })
    end
    if preview then
        for _, msg in ipairs(preview.excluded) do table.insert(lines, msg) end
        table.insert(lines, preview.before.set == 1 and "Account-wide bindings" or "Character-specific bindings")
        for _, msg in ipairs(preview.lines) do table.insert(lines, msg) end
        for _, msg in ipairs(preview.warnings) do table.insert(lines, msg) end
    end
    local old = u.before.text and BP.parse(u.before.text)
    local name = old and (old.name ~= "" and old.name or "unnamed plan") or "no saved plan"
    local count = 0
    for _ in pairs(u.before.pending or {}) do count = count + 1 end
    table.insert(lines, "Restore profile to " .. name .. " with " .. countLabel(count, "pending placement") .. ".")
    return ops, preview, lines, sharedUses
end

function BP.revert(confirm)
    local previous = review
    invalidate()
    local profile = P.active()
    local ok, result = pcall(function()
        assert(profile, "Character identity unavailable.")
        if confirm then
            assert(previous and previous.kind == "revert" and previous.profile == profile and previous.undo == profile.undo,
                "Preview Revert again.")
            local changes = {}
            C.differences(changes, "Profile", previous.state, profileState(profile))
            C.checkDifferences(changes, "Profile changed. Preview Revert again.")
        end
        local ops, preview, lines, sharedUses = revertPlan(profile)
        if not confirm then
            return showReview("revert", "Revert last Apply? Open Details to review the batch.", lines,
                { profile = profile, undo = profile.undo, state = profileState(profile), preview = preview, sharedUses = sharedUses })
        end
        local changes = {}
        C.differences(changes, "Shared macros on excluded slots", previous.sharedUses, sharedUses)
        if preview then C.differences(changes, "Revert bindings", previous.preview.plan, preview.plan) end
        C.checkDifferences(changes, "Revert changed. Preview Revert again.")
        local u = profile.undo
        C.execute(ops, previous.preview and previous.preview.plan, previous.preview)
        profile.text, profile.pending, profile.undo = u.before.text, u.before.pending, nil
        autoFailures, fulfilled = {}, {}
        if frame then loadEditor(profile.text or "") end
        return showStatus({ "Reverted the last Apply for this profile." })
    end)
    if not ok then return stopped("Revert stopped", result) end
    return result
end

local function setAuto(enabled)
    BarsmithDB.auto = enabled
    autoFailures, fulfilled = {}, {}
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

local function managedBarsMenu(_, root)
    local p = P.active()
    if not p then return end
    local forms = FORM_LABELS[select(2, UnitClass("player"))] or {}
    root:SetScrollMode(360)
    root:CreateTitle("Managed slots and button bindings")
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

local LEGACY_HELP = "Preserved pre-profile applied plan. Its owner is unknown. Check and successfully Apply it on the intended character and profile to claim it."

local function appliedPlan()
    local profile = P.active()
    if profile and profile.lastApplied and profile.lastApplied ~= "" then return profile.lastApplied end
    local newer = BarsmithDB and BarsmithDB.last
    if newer and newer ~= "" then return newer, LEGACY_HELP end
    local legacy = BarsmithDB and BarsmithDB.legacyPlan
    if legacy and legacy ~= "" then return legacy, LEGACY_HELP end
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
    edit:SetScript("OnTextChanged", function(_, userInput)
        if userInput then resetEditorReview() end
    end)
    local function exportHelp(msg)
        f.summary, f.details, f.full = { msg }, { msg }, { msg }
        display("summary")
    end
    local function selectText(text, helpText)
        loadEditor(text)
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
        local last, help = appliedPlan()
        if not last then
            f.hint:SetText("No plan applied yet.")
            return
        end
        selectText(last, help or "Last applied plan. Press Ctrl+C to copy, or Check to review it for reapplication.")
    end)
    local census = button("Census", 409, 72, function()
        local ok, snapshot = pcall(B.census, esc)
        if not ok then showStatus({ "Census failed: " .. tostring(snapshot) }); return end
        selectText(snapshot, "Copy this read-only BC1 census. Load it into the planner with your plan open.")
    end)
    button("Clear", 485, 55, function() loadEditor(""); edit:SetFocus() end)

    tooltip(census, "Creates a read-only snapshot of current WoW keybindings, including detectable secondary and addon bindings. Use it with the planner or an AI assistant to avoid conflicts.")

    local auto = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    auto:SetSize(24, 24)
    auto:SetPoint("BOTTOMLEFT", 448, 44)
    local autoLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autoLabel:SetPoint("LEFT", auto, "RIGHT", 2, 0)
    autoLabel:SetWidth(130)
    autoLabel:SetJustifyH("LEFT")
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
    local managed = button("Managed bars...", 478, 126, function(self) MenuUtil.CreateContextMenu(self, managedBarsMenu) end, 478)
    tooltip(managed, "Exclude a bar to protect its slots and button keys. Bar 1 controls the shared main-bar keys for every form. Individual form checkboxes protect slots. Explicit macro edits affect every button using that macro.")
    local legacy = button("Import old plan", 478, 126, function()
        if BarsmithDB.legacyPlan then
            loadEditor(BarsmithDB.legacyPlan)
            showStatus({ "Legacy account plan loaded for review. Check and Apply on the owning character." })
        end
    end, 447)
    tooltip(legacy, "Loads the account-wide Barsmith plan saved before profiles were added. Loading only fills the editor. Use Check, then Apply on the intended character.")
    local overwrite = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    overwrite:SetSize(24, 24)
    overwrite:SetPoint("BOTTOMLEFT", 16, 44)
    local policyLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    policyLabel:SetPoint("LEFT", overwrite, "RIGHT", 2, 0)
    policyLabel:SetWidth(396)
    policyLabel:SetJustifyH("LEFT")
    policyLabel:SetText("Auto-overwrite occupied managed slots for newly available actions")
    overwrite:SetScript("OnClick", function(self)
        local p = P.active()
        if p then p.overwrite = self:GetChecked() and true or false end
        invalidate()
        if p and p.overwrite and BarsmithDB.auto then queueAutoFill() end
    end)
    refreshProfiles = function()
        local p, c = P.active()
        if BarsmithDB and BarsmithDB.legacyPlan then legacy:Show() else legacy:Hide() end
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
    if text then loadEditor(text) end
    frame:Show()
end

------------------------------------------------------------------------
-- Only pending (previously unavailable) actions can displace an occupied slot.
-- An empty slot on an applied profile retains the original refill behavior.
local autoQueued, autoAfterCombat, autoAfterCursor = false, false, false
-- Session-local failure records are scoped to the active profile and physical
-- slot. Spell visibility can flicker without a new rank or a new destination.
local notified, inspectionErrors = {}, {}
local evaluationError
local function levelBatch(profile, topics)
    local batch = { empty = {}, occupied = {}, settled = {} }
    local pickups = {}
    if not profile or not profile.pending or not profile.text then return batch, pickups end
    local plan = assert(BP.parse(profile.text))
    assert(not plan.class or plan.class == select(2, UnitClass("player")), "Plan class mismatch.")
    local book = (not topics or topics.spell) and spellbookEntries() or nil
    local function inspect(s)
        local pending = profile.pending[s.slot]
        if not pending and HasAction(s.slot) then
            if not topics or not topics.full or fulfilled[s.slot] or GetActionInfo(s.slot) ~= s.kind then return end
        end
        local before = C.slot(s.slot, book)
        if not pending and before.kind ~= "empty" and before.kind ~= s.kind then return end
        local target = available(s, book)
        local failure = topics and autoFailures[s.slot]
        if not target then
            if failure and s.kind == "spell" then
                for id in pairs(failure.targets) do
                    if not independentlyKnown(id) then failure.unavailable[id] = true end
                end
            end
            return
        end
        if failure and topics.learned and topics.learned[target.id] and failure.unavailable[target.id] then
            failure.targets[target.id], failure.unavailable[target.id] = nil, nil
        end
        if before.kind == s.kind and before.id == target.id then return nil, nil, target.id end
        if not pending and (before.kind ~= "empty" or (topics and fulfilled[s.slot] == target.id)) then return end
        if before.kind == "empty" and s.kind == "spell" and slotContainsSpell(s.slot, target.id) then
            -- The reverse action map still sees the spell while the forward
            -- slot query is blank. Wait for a consistent read.
            return
        end
        local op = { slot = s.slot, before = before, after = { kind = s.kind, id = target.id },
            requestedSpell = s.kind == "spell" and s.value or nil }
        if before.kind == "macro" then op.previousMacro = C.macro(before.name) end
        return op, target.pickup
    end
    for _, s in ipairs(managedSlots(plan, profile)) do
        if (s.kind == "spell" or s.kind == "item") and (not topics or topics[s.kind]) then
            local ok, op, pickup, settled = pcall(inspect, s)
            if not ok then
                if not topics then error(op, 0) end
                local message = slotLabel(s.slot) .. " [" .. s.slot .. "] " .. s.value .. ": " .. tostring(op)
                if inspectionErrors[s.slot] ~= message then say("Auto-fill could not evaluate " .. message) end
                inspectionErrors[s.slot] = message
            elseif op then
                if topics then inspectionErrors[s.slot] = nil end
                table.insert(op.before.kind == "empty" and batch.empty or batch.occupied, op)
                pickups[s.slot] = pickup
            elseif topics then
                notified[s.slot], inspectionErrors[s.slot] = nil, nil
                if settled then batch.settled[s.slot] = settled end
                if settled or s.kind == "item" then autoFailures[s.slot] = nil end
            end
        end
    end
    return batch, pickups
end

local function batchState(ops)
    local state = {}
    for _, op in ipairs(ops) do state[slotWhere(op.slot)] = op end
    return state
end

local function placeBatch(profile, ops, pickups)
    local byIndex = {}
    for i, op in ipairs(ops) do
        requireRestorable(op.slot, op.before)
        byIndex[i] = pickups[op.slot]
    end
    C.execute(ops, nil, nil, byIndex)
    for _, op in ipairs(ops) do
        profile.pending[op.slot], fulfilled[op.slot] = nil, op.after.id
    end
end

local function autoPlace(profile, ops, pickups)
    local count = 0
    for _, op in ipairs(ops) do
        local failure = autoFailures[op.slot]
        if not failure or not C.equal(failure.before, op.before) or not C.equal(failure.previousMacro, op.previousMacro) then
            failure = { before = op.before, previousMacro = op.previousMacro, targets = {}, unavailable = {} }
        end
        if not failure.targets[op.after.id] then
            local ok, err = pcall(placeBatch, profile, { op }, pickups)
            if ok then
                autoFailures[op.slot] = nil
                count = count + 1
            else
                failure.targets[op.after.id] = true
                autoFailures[op.slot] = failure
                local message = type(err) == "table" and err.message or tostring(err)
                local reason = profile.pending[op.slot] and "pending" or "empty"
                say(("Auto-fill paused for %s [%d] (%s): %s"):format(slotLabel(op.slot), op.slot, reason, message))
                if type(err) == "table" then
                    for _, detail in ipairs(err.details or {}) do say(detail) end
                end
                if GetCursorInfo() or message:find("Recovery incomplete", 1, true) then return count, true end
            end
        end
    end
    return count
end

function BP.levelUpdates(mode, topics)
    local profile = P.active()
    local previous = review
    if mode ~= "event" then invalidate() end
    if not (BarsmithDB and BarsmithDB.auto and profile) then
        if mode ~= "event" then showStatus({ "Auto-fill is disabled or the character is unavailable." }) end
        return
    end
    local ok, err = pcall(function()
        ready()
        if autoProfile ~= profile then
            autoFailures, notified, inspectionErrors, fulfilled, autoProfile = {}, {}, {}, {}, profile
        end
        local batch, pickups = levelBatch(profile, mode == "event" and (topics or { spell = true, item = true }))
        local occupied = batch.occupied
        if mode == "confirm" then
            assert(previous and previous.kind == "level" and previous.profile == profile,
                "Leveling replacements changed. Open Review pending updates again.")
            local changes = {}
            C.differences(changes, "Profile", previous.state, profileState(profile))
            C.differences(changes, "Replacements", previous.batch, batchState(occupied))
            C.checkDifferences(changes, "Leveling replacements changed. Open Review pending updates again.")
            placeBatch(profile, occupied, pickups)
            notified = {}
            return showStatus({ #occupied .. " reviewed replacements applied." })
        end
        if mode == "event" then
            for slot, id in pairs(batch.settled) do profile.pending[slot], fulfilled[slot] = nil, id end
            local filled, interrupted = autoPlace(profile, batch.empty, pickups)
            if filled > 0 then say("Filled " .. filled .. " empty managed slots.") end
            if #occupied == 0 or interrupted then return end
            if profile.overwrite then
                local updated = autoPlace(profile, occupied, pickups)
                if updated > 0 then say("Updated " .. updated .. " occupied managed slots for this profile.") end
                return
            end
            local changed
            for _, op in ipairs(occupied) do
                if not C.equal(notified[op.slot], op) then changed = true end
                notified[op.slot] = op
            end
            if not changed then return end
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
                lines, { profile = profile, state = profileState(profile), batch = batchState(occupied) })
        end
    end)
    if not ok then
        if mode ~= "event" then return stopped("Level updates stopped", err) end
        local message = type(err) == "table" and err.message or tostring(err)
        if evaluationError ~= message then say("Auto-fill evaluation stopped: " .. message) end
        evaluationError = message
    else evaluationError = nil end
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

P.onBarsChanged = function(first, managed)
    for slot = first, first + 11 do autoFailures[slot], fulfilled[slot] = nil, nil end
    invalidate()
    notified = {}
    if StaticPopup_Hide then StaticPopup_Hide("BARSMITH_LEVEL_UPDATES") end
    local state = managed and "enabled" or "excluded"
    showStatus({ ("Managed bars updated. Slots %d–%d %s. Run Check again."):format(first, first + 11, state) })
end

P.onChange = function()
    invalidate()
    notified = {}
    if StaticPopup_Hide then StaticPopup_Hide("BARSMITH_LEVEL_UPDATES") end
    if frame then
        local profile = P.active()
        loadEditor(profile.text or "")
        refreshProfiles()
    end
end

-- A final in-memory read cannot establish persistence across /reload. On
-- the next UI load, compare just the creations in the active undo record.
-- This observation has no placement, binding, creation or deletion path.
local enteredWorld, auditSnapshot
local function auditCreated(snapshot)
    local checks, names, count = {}, {}, 0
    for _, op in ipairs(snapshot.ops) do
        if op.name and not op.before then
            names[op.after.name] = true
            table.insert(checks, op)
            count = count + 1
        end
    end
    for _, op in ipairs(snapshot.ops) do
        if op.slot and op.after.kind == "macro" and names[op.after.name] then table.insert(checks, op) end
    end
    local changes = C.verifyMacros(checks)
    if #changes == 0 then
        say(("After UI load: verified %d newly created macro(s) and %d assigned slot(s) from Apply."):format(count, #checks - count))
    else
        say("After UI load: macro state differs from the final Apply verification.")
        for _, msg in ipairs(changes) do say(msg) end
    end
    snapshot.verifyCreatedOnLoad = nil
end

local queuedTopics = {}
queueAutoFill = function(topic, learnedID)
    if not topic then queuedTopics.spell, queuedTopics.item, queuedTopics.full = true, true, true
    elseif topic ~= "resume" then queuedTopics[topic] = true end
    if not topic or topic == "spell" then queuedTopics.observed = nil end
    if type(learnedID) == "number" then
        queuedTopics.learned = queuedTopics.learned or {}
        queuedTopics.learned[learnedID] = true
    end
    if autoQueued then return end
    autoQueued = true
    C_Timer.After(1, function()
        autoQueued = false
        if auditSnapshot then
            local p = P.active()
            if p and p.undo == auditSnapshot then auditCreated(auditSnapshot) end
            auditSnapshot = nil
        end
        if queuedTopics.spell and not queuedTopics.observed then
            discover()
            queuedTopics.observed = true
        end
        if InCombatLockdown() then autoAfterCombat = true; return end
        if GetCursorInfo() then autoAfterCursor = true; return end
        autoAfterCursor = false
        local topics = queuedTopics
        queuedTopics = {}
        BP.levelUpdates("event", topics)
    end)
end

local events = CreateFrame("Frame")
-- Not every client has every event (Classic Era has no LEARNED_SPELL_IN_TAB;
-- newer clients call it LEARNED_SPELL_IN_SKILL_LINE),
-- and registering an unknown one is an error that would stop the file here.
local talentEvents = { PLAYER_TALENT_UPDATE = true, ACTIVE_TALENT_GROUP_CHANGED = true,
    TRAIT_CONFIG_UPDATED = true, PLAYER_PVP_TALENT_UPDATE = true, PLAYER_SPECIALIZATION_CHANGED = true }
for ev in pairs(talentEvents) do pcall(events.RegisterEvent, events, ev) end
for _, ev in ipairs({ "UPDATE_SHAPESHIFT_FORM", "UPDATE_STEALTH", "UNIT_PET", "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED",
    "ADDON_LOADED", "PLAYER_LOGOUT", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE", "BAG_UPDATE_DELAYED", "ACTIONBAR_SLOT_CHANGED", "CURSOR_CHANGED", "PLAYER_REGEN_ENABLED" }) do
    pcall(events.RegisterEvent, events, ev)
end
events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 == "Barsmith" then
            P.init()
        end
    elseif event == "PLAYER_LOGOUT" then T.save(T.view())
    elseif talentEvents[event] then
        if event ~= "PLAYER_SPECIALIZATION_CHANGED" or not arg1 or arg1 == "player" then T.invalidate() end
    elseif event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_STEALTH" then discover()
    elseif event == "UNIT_PET" then
        if arg1 == "player" then discover() end
    elseif event == "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED" then
        if arg2 then discover(arg1, arg2) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        T.view("verify")
        local p = P.active()
        if p and not enteredWorld then
            enteredWorld = true
            if p.undo and p.undo.verifyCreatedOnLoad then auditSnapshot = p.undo end
        end
        queueAutoFill()
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        -- A specific physical slot becoming empty can re-arm refill. A bulk
        -- display refresh (slot 0) or a spellbook event alone cannot undo a
        -- placement we already verified. Wait for the normal leveling scan.
        if fulfilled[arg1] and not HasAction(arg1) and not GetActionInfo(arg1) then
            fulfilled[arg1] = nil
        end
    elseif event == "CURSOR_CHANGED" then
        if autoAfterCursor and not GetCursorInfo() then queueAutoFill("resume") end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if autoAfterCombat then autoAfterCombat = false; queueAutoFill("resume") end
    elseif BarsmithDB then
        if event == "LEARNED_SPELL_IN_SKILL_LINE" or event == "LEARNED_SPELL_IN_TAB" then T.learned(arg1) end
        queueAutoFill(event == "BAG_UPDATE_DELAYED" and "item" or "spell", event == "LEARNED_SPELL_IN_SKILL_LINE" and arg1)
    end
end)

------------------------------------------------------------------------
-- Slash command
------------------------------------------------------------------------

SLASH_BARSMITH1 = "/barsmith"
SlashCmdList.BARSMITH = function(msg)
    msg = trim(msg):lower()
    if msg == "apply" then
        local text, help = appliedPlan()
        if not text then return say("No plan applied yet. Type /barsmith and paste one.") end
        openFrame(text)
        BP.run(text, true)
        if help then
            table.insert(frame.summary, 1, help)
            display("summary")
        end
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

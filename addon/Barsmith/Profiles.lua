-- Only an authenticated player GUID owns profiles. The legacy string has no owner.
Barsmith = Barsmith or {}
local P = {}
Barsmith.profiles = P

function P.init()
    BarsmithDB = BarsmithDB or {}
    local db = BarsmithDB
    db.characters = db.characters or {}
    if db.auto == nil then db.auto = true end
    if db.last and not db.legacyPlan then
        db.legacyPlan = db.last
        db.last = nil
    end
end

function P.character()
    local guid = UnitGUID("player")
    if not guid or not BarsmithDB then return end
    P.init()
    -- Another character can start using an account macro on bars we cannot
    -- inspect from here. Remember character switches across client restarts.
    if BarsmithDB.lastCharacter ~= guid then
        BarsmithDB.lastCharacter = guid
        BarsmithDB.characterVisit = (BarsmithDB.characterVisit or 0) + 1
    end
    local c = BarsmithDB.characters[guid]
    if not c then
        c = { profiles = { Default = {} }, active = "Default" }
        BarsmithDB.characters[guid] = c
    end
    local name = GetUnitName and GetUnitName("player")
    if not name or name == "" then name = UnitName("player") end
    if name and name ~= "" then c.name = name end
    local realm = GetRealmName()
    c.realm = realm ~= "" and realm or nil
    return c
end

function P.active()
    local c = P.character()
    return c and c.profiles[c.active], c
end

-- Key the exclusion by the first physical slot, including alternate form pages.
function P.managesSlot(profile, slot)
    local first = slot - (slot - 1) % 12
    return not (profile.excludedBars and profile.excludedBars[first])
end

function P.setBarManaged(profile, first, managed)
    if profile ~= P.active() or first < 1 or first > 169 or (first - 1) % 12 ~= 0 then return end
    if P.managesSlot(profile, first) == managed then return end
    profile.excludedBars = profile.excludedBars or {}
    profile.excludedBars[first] = not managed or nil
    if P.onBarsChanged then P.onBarsChanged(first, managed) end
end

local function draft(source)
    local p = { text = source.text }
    if source.excludedBars then
        p.excludedBars = {}
        for first in pairs(source.excludedBars) do p.excludedBars[first] = true end
    end
    return p
end

function P.copyFrom(guid, sourceName)
    local c = P.character()
    local owner = BarsmithDB and BarsmithDB.characters[guid]
    local source = owner and owner.profiles[sourceName]
    if not c or owner == c or not source then return nil, "Source profile unavailable." end
    local name, n = sourceName, 2
    while c.profiles[name] do
        local suffix = " (" .. n .. ")"
        name = Barsmith.cutBytes(sourceName, 64 - #suffix) .. suffix
        n = n + 1
    end
    c.profiles[name] = draft(source)
    c.active = name
    if P.onChange then P.onChange() end
    return name
end

-- Creation and duplication save a draft. Only Check + Apply arms future placements.
function P.manage(op, name, text)
    local p, c = P.active()
    if not c then return nil, "Character identity unavailable." end
    name = (name or ""):match("^%s*(.-)%s*$")
    if op == "select" then
        if not c.profiles[name] then return nil, "Unknown profile." end
        c.active = name
    elseif op == "delete" then
        local names = P.names(c)
        if #names == 1 then return nil, "Keep at least one profile. Create another before deleting this one." end
        c.profiles[c.active] = nil
        c.active = names[1] == c.active and names[2] or names[1]
    else
        if name == "" or #name > 64 then return nil, "Enter a profile name (1-64 bytes)." end
        if c.profiles[name] then return nil, "That profile name is already in use." end
        if op == "create" then
            local plan, err = Barsmith.parse(text or "")
            if not plan then return nil, err end
            if plan.class and plan.class ~= select(2, UnitClass("player")) then return nil, "Plan class mismatch." end
            c.profiles[name] = { text = text }
        elseif op == "duplicate" then
            c.profiles[name] = draft(p)
            c.profiles[name].overwrite = p.overwrite
        elseif op == "rename" then
            c.profiles[name], c.profiles[c.active] = p, nil
        else
            return nil, "Unknown profile operation."
        end
        c.active = name
    end
    if P.onChange then P.onChange() end
    return true
end

function P.names(c)
    local names = {}
    for name in pairs(c.profiles) do names[#names + 1] = name end
    table.sort(names)
    return names
end

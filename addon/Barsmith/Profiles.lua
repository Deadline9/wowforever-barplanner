-- Only an authenticated player GUID owns profiles. The legacy string has no owner.
Barsmith = Barsmith or {}
local P = {}
Barsmith.profiles = P

function P.init()
    BarsmithDB = BarsmithDB or {}
    local db = BarsmithDB
    db.characters = db.characters or {}
    if db.auto == nil then db.auto = true end
    if db.last and not db.legacyPlan then db.legacyPlan, db.last = db.last, nil end
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
    c.name, c.realm = UnitName("player"), GetRealmName()
    return c
end

function P.active()
    local c = P.character()
    return c and c.profiles[c.active], c
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
            c.profiles[name] = { text = p.text, overwrite = p.overwrite }
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

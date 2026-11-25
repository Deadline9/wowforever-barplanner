-- Observations belong to the character, across all their Barsmith profiles.
-- A spell ID pair is evidence. A name is only a way to find that pair.
local T = {}
Barsmith.transformations = T

local function traitContext(config)
    local info = C_Traits.GetConfigInfo(config)
    if not info or not info.treeIDs or #info.treeIDs == 0 then return end
    local selection, spells = {}, {}
    for _, tree in ipairs(info.treeIDs) do
        local nodes = C_Traits.GetTreeNodes(tree)
        if not nodes or #nodes == 0 then return end
        selection[#selection + 1] = "tree=" .. tree
        for _, id in ipairs(nodes) do
            local node = C_Traits.GetNodeInfo(config, id)
            if not node or node.activeRank == nil then return end
            if node.activeRank > 0 then
                local entryID = node.activeEntry and node.activeEntry.entryID
                local committed = node.entryIDsWithCommittedRanks
                if not entryID and committed and #committed == 1 then entryID = committed[1] end
                if not entryID then return end
                selection[#selection + 1] = ("%d/%d/%d"):format(id, entryID, node.activeRank)
                local entry = C_Traits.GetEntryInfo(config, entryID)
                local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
                if def and def.spellID and def.spellID > 0 then
                    spells[#spells + 1] = { id = def.spellID, replaces = def.overriddenSpellID }
                end
            end
        end
    end
    table.sort(selection)
    return "traits/" .. config .. "/" .. table.concat(selection, ","), spells
end

local function talentContext()
    if C_Traits and C_Traits.GetConfigInfo then
        local spec = C_SpecializationInfo
        local group = spec and spec.GetActiveSpecGroup and spec.GetActiveSpecGroup()
        local config = group and spec.GetCombatConfigIDForSpecGroup and spec.GetCombatConfigIDForSpecGroup(group)
        if not config or config <= 0 then
            config = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
        end
        if config and config > 0 then
            if C_Traits.ConfigHasStagedChanges and C_Traits.ConfigHasStagedChanges(config) then return end
            local ok, signature, spells = pcall(traitContext, config)
            if ok and signature then return signature, spells end
            local loadout = C_Traits.GenerateImportString and C_Traits.GenerateImportString(config)
            if type(loadout) == "string" and loadout ~= "" then return "loadout/" .. config .. "/" .. loadout end
            return
        end
    end
    if GetNumTalentTabs and GetNumTalents and GetTalentInfo then
        local tabs = GetNumTalentTabs()
        if not tabs or tabs == 0 then return end
        local ranks = { "classic", tostring(GetActiveTalentGroup and GetActiveTalentGroup() or 1) }
        for tab = 1, tabs do
            local count = GetNumTalents(tab)
            if not count or count == 0 then return end
            for i = 1, count do
                local _, _, _, _, rank = GetTalentInfo(tab, i)
                if rank == nil then return end
                ranks[#ranks + 1] = tostring(rank)
            end
        end
        return table.concat(ranks, "/")
    end
end

local view
function T.invalidate()
    view = nil
end

function T.learned(id)
    local c = Barsmith.profiles.character()
    if not c then return end
    local function forget(edges)
        if not edges then return end
        for alias, owners in pairs(edges) do
            if type(id) ~= "number" or id == alias then edges[alias] = nil
            else
                owners[id] = nil
                if not next(owners) then edges[alias] = nil end
            end
        end
    end
    if c.spellTransforms then forget(c.spellTransforms.edges) end
    if view and view.character == c then
        forget(view.edges)
        forget(view.pending)
    end
end

function T.view(retry)
    local c = Barsmith.profiles.character()
    if not c then return end
    if not view or view.character ~= c or (retry == "verify" or (retry and not view.context)) then
        -- Optional APIs may be unavailable while the character is loading.
        -- Without an inspectable talent configuration only use this session.
        local ok, talents, replacements = pcall(talentContext)
        local build = GetBuildInfo and select(2, GetBuildInfo())
        local key = ok and talents and build and table.concat({ "1", build, GetLocale and GetLocale() or "", talents }, "|")
        local pvp = C_SpecializationInfo and C_SpecializationInfo.GetAllSelectedPvpTalentIDs
        if key and pvp then
            local readable, ids = pcall(pvp)
            if readable then
                local picks = {}
                for _, id in ipairs(ids or {}) do picks[#picks + 1] = id end
                table.sort(picks)
                key = key .. "|pvp/" .. table.concat(picks, ",")
            else key = nil end
        end
        local saved = c.spellTransforms
        local edges = key and saved and saved.context == key and saved.edges
        if not key and view and view.character == c and not view.context then edges = view.edges end
        local pending = view and view.character == c and view.context == key and view.pending or {}
        view = { character = c, context = key, edges = edges or {}, pending = pending, talents = ok and replacements or {} }
    end
    return view
end

function T.record(edges, base, alias, key)
    if not base or base <= 0 or not alias or alias <= 0 or base == alias then return end
    edges[alias] = edges[alias] or {}
    local names = edges[alias][base] or {}
    edges[alias][base] = names
    if key and key ~= "" then names[key] = true end
end

-- Check can obtain a numeric relationship by exact name for an unlisted
-- spell. Keep that evidence in memory until a discovery event or UI logout.
function T.save(v)
    if not v then return end
    for alias, owners in pairs(v.pending) do
        for base, names in pairs(owners) do
            for name in pairs(names) do T.record(v.edges, base, alias, name) end
        end
    end
    v.pending = {}
    if v.context then
        v.character.spellTransforms = next(v.edges) and { context = v.context, edges = v.edges } or nil
    end
end

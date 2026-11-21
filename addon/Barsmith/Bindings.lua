-- Persistent key bindings. Frame-owned overrides are a separate, temporary layer.
Barsmith = Barsmith or {}
local B = {}
Barsmith.bindings = B

local function sorted(map)
    local list = {}
    for k in pairs(map) do list[#list + 1] = k end
    table.sort(list)
    return list
end

local function context(command)
    return C_KeyBindings and C_KeyBindings.GetBindingContextForAction and C_KeyBindings.GetBindingContextForAction(command) or 0
end

local function owner(key, overrides)
    local action = GetBindingAction(key, overrides, 0)
    return action ~= "" and action or nil
end

-- Consume varargs by count: a missing display slot must not hide a later key.
local function addKeys(row, ...)
    for i = 1, select("#", ...) do
        local k = select(i, ...)
        if k and k ~= "" and not row.keys[k] then
            row.keys[k] = true
            row.order[#row.order + 1] = k
        end
    end
end

-- Index every exposed command, even when unbound. Supplement the registry
-- with direct lookups for planned keys (e.g. a dynamically bound CLICK).
function B.capture(binds, knownRows)
    local s = { set = GetCurrentBindingSet(), rows = {}, owners = {}, overrides = {}, customKeys = {} }
    assert(s.set == 1 or s.set == 2, "Unknown active binding set.")
    local function row(command, category)
        if not s.rows[command] then
            s.rows[command] = { keys = {}, order = {}, context = context(command), category = category or "",
                label = _G["BINDING_NAME_" .. command] or command }
        end
        return s.rows[command]
    end
    local count = GetNumBindings()
    assert(count > 0, "Binding registry unavailable.")
    local function indexed(i, command, category, ...)
        assert(command and command ~= "", "Incomplete binding registry.")
        local r = row(command, category)
        addKeys(r, ...)
        if C_KeyBindings and C_KeyBindings.GetCustomBindingType then
            local kind = C_KeyBindings.GetCustomBindingType(i)
            r.custom = kind ~= nil
            if kind ~= nil and Enum and Enum.CustomBindingType and kind == Enum.CustomBindingType.VoicePushToTalk
                and C_VoiceChat and C_VoiceChat.GetPushToTalkBinding then
                local chord = C_VoiceChat.GetPushToTalkBinding()
                if chord and #chord > 0 then addKeys(r, table.concat(chord, "-")) end
            end
        end
    end
    for i = 1, count do indexed(i, GetBinding(i, true)) end
    for command in pairs(knownRows or {}) do row(command) end
    for _, b in ipairs(binds or {}) do
        if b.command then row(b.command) end
        if b.key then
            local current = owner(b.key, false)
            if current then row(current) end
            local effective = owner(b.key, true)
            if effective ~= current then s.overrides[b.key] = effective or "" end
        end
    end
    for command, r in pairs(s.rows) do
        addKeys(r, GetBindingKey(command, nil, r.context))
        if r.custom then
            for key in pairs(r.keys) do s.customKeys[key] = command end
        elseif r.context == 0 then
            for key in pairs(r.keys) do
                assert(not s.owners[key] or s.owners[key] == command, "Ambiguous owner for " .. key)
                s.owners[key] = command
            end
        end
    end
    for _, b in ipairs(binds or {}) do
        if b.key then
            local current = owner(b.key, false)
            if current and not s.owners[b.key] then
                addKeys(row(current), b.key)
                s.owners[b.key] = current
            end
            assert(current == s.owners[b.key], "Inconsistent binding lookup: " .. b.key)
        end
    end
    for key in pairs(s.owners) do
        local effective = owner(key, true)
        if effective ~= s.owners[key] then s.overrides[key] = effective or "" end
    end
    return s
end

-- Prefix modifiers have a single spelling/order in the graph. Preserve keys
-- such as '-' and 'CTRL--'. Never silently discard an unknown modifier.
function B.key(raw)
    local k, mods = raw:upper(), {}
    while true do
        local m, rest = k:match("^(%a+)%-(.+)$")
        if not m then break end
        if m ~= "ALT" and m ~= "CTRL" and m ~= "SHIFT" and m ~= "META" then break end
        mods[m], k = true, rest
    end
    local prefix = ""
    for _, m in ipairs({"ALT", "CTRL", "SHIFT", "META"}) do
        if mods[m] then prefix = prefix .. m .. "-" end
    end
    return prefix .. k
end

function B.preview(plan, s)
    local p = { before = s, desired = {}, changes = {}, lines = {}, details = {}, errors = {},
        same = 0, displaced = 0, preserved = 0, orphaned = 0, overrideWarnings = 0 }
    local assigned, touched, allowed, lost = {}, {}, {}, {}
    local function problem(msg) p.errors[#p.errors + 1] = msg end
    local function claim(key, command)
        if p.desired[key] ~= nil and p.desired[key] ~= command then
            problem("Conflict: " .. key .. " has competing instructions.")
        end
        p.desired[key] = command
    end
    local function writable(command)
        local r = s.rows[command]
        if r and (r.context ~= 0 or r.custom) then problem("Unsupported binding context or custom control: " .. command) end
    end
    for _, b in ipairs(plan.binds) do
        writable(b.command)
        if b.op == "ALLOWORPHAN" then
            allowed[b.command] = true
        elseif b.op == "REMOVE" then
            local old = s.owners[b.key]
            if old and old ~= b.command then problem("Removal owner changed: " .. b.key .. " now belongs to " .. old) end
            claim(b.key, false)
        else
            claim(b.key, b.command)
            assigned[b.command] = true
        end
    end
    if plan.version == 1 then
        for cmd in pairs(assigned) do
            for k in pairs(s.rows[cmd].keys) do
                if p.desired[k] == nil then claim(k, false) end
            end
        end
    end
    local final = {}
    for k, cmd in pairs(s.owners) do final[k] = cmd end
    for _, k in ipairs(sorted(p.desired)) do
        local old, new = s.owners[k], p.desired[k] or nil
        if s.customKeys[k] and old ~= new then problem("Custom control on " .. k .. ": " .. s.customKeys[k]) end
        final[k] = new
        if old == new then
            p.same = p.same + 1
            p.details[#p.details + 1] = "Already correct: " .. k .. " -> " .. (new or "unbound")
        else
            p.changes[#p.changes + 1] = { key = k, old = old, new = new }
            if old then
                touched[old], lost[old] = true, true
                writable(old)
            end
        end
        if s.overrides[k] then
            p.overrideWarnings = p.overrideWarnings + 1
            p.lines[#p.lines + 1] = "Override on " .. k .. ": " .. s.overrides[k] .. " (runtime layer)"
        end
    end
    local taken = {}
    for _, c in ipairs(p.changes) do
        local msg
        if not c.new then msg = (plan.version == 1 and "Legacy exact removal: " or "Explicit removal: ") .. c.key .. " from " .. c.old
        elseif c.old then
            msg = "Displacement: " .. c.key .. " from " .. c.old .. " to " .. c.new
            if not taken[c.old] then p.displaced = p.displaced + 1 end
            taken[c.old] = true
        else msg = "New binding: " .. c.key .. " -> " .. c.new end
        p.lines[#p.lines + 1] = msg
    end
    for cmd in pairs(assigned) do touched[cmd] = true end
    local finalKeys = sorted(final)
    for _, cmd in ipairs(sorted(touched)) do
        local remaining, preserved, masked, usable = {}, {}, {}, false
        for _, key in ipairs(finalKeys) do
            if final[key] == cmd then
                remaining[#remaining + 1] = key
                if not s.overrides[key] or s.overrides[key] == cmd then
                    usable = true
                    if p.desired[key] == nil then p.preserved = p.preserved + 1 end
                elseif lost[cmd] and p.desired[key] == nil then
                    masked[#masked + 1] = key .. " -> " .. s.overrides[key]
                end
                if p.desired[key] == nil then preserved[#preserved + 1] = key end
            end
        end
        if #remaining == 0 then
            p.orphaned = p.orphaned + 1
            local msg = "Orphan: " .. cmd .. " will be unbound."
            if taken[cmd] and not allowed[cmd] then problem(msg)
            else p.lines[#p.lines + 1] = msg .. " Explicitly requested." end
        elseif lost[cmd] then
            p.lines[#p.lines + 1] = cmd .. " remains on " .. table.concat(remaining, ", ")
            if #masked > 0 then
                p.lines[#p.lines + 1] = "Runtime overrides on remaining keys: " .. table.concat(masked, ", ")
                p.overrideWarnings = p.overrideWarnings + 1
            end
            if taken[cmd] and not usable and not allowed[cmd] then
                problem("All remaining keys for " .. cmd .. " have runtime overrides.")
            end
        end
        if #preserved > 0 then p.details[#p.details + 1] = "Preserved on " .. cmd .. ": " .. table.concat(preserved, ", ") end
    end
    p.final = final
    return p
end

local function sameMap(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
end

-- Capture again immediately before writing, then verify before saving. No
-- bulk clear, no profile switching, no writes for a no-op.
function B.commit(plan, p)
    local s = B.capture(plan.binds, p.before.rows)
    local fresh = B.preview(plan, s)
    if #p.errors > 0 or #fresh.errors > 0 or s.set ~= p.before.set or
        not sameMap(s.owners, p.before.owners) or not sameMap(s.overrides, p.before.overrides) then
        return nil, "Bindings changed or Check is blocked. Run Check again."
    end
    if #p.changes == 0 then return true end
    local attempted, saving = {}, false
    local function write(key, command)
        assert(SetBinding(key, command) and owner(key, false) == command, "Game rejected " .. key)
    end
    local ok, err = pcall(function()
        for _, c in ipairs(p.changes) do
            assert(owner(c.key, false) == c.old, "Owner changed for " .. c.key)
            attempted[#attempted + 1] = c
            write(c.key, c.new)
        end
        local after = B.capture(plan.binds, s.rows)
        assert(after.set == s.set and sameMap(after.owners, p.final), "Binding verification failed")
        saving = true
        assert(SaveBindings(s.set) ~= false, "Save failed")
    end)
    if ok then return true end
    local restored = GetCurrentBindingSet() == s.set
    if restored then
        for i = #attempted, 1, -1 do
            local c = attempted[i]
            if owner(c.key, false) ~= c.old then
                if not pcall(write, c.key, c.old) then restored = false end
            end
        end
        local verified, original = pcall(B.capture, plan.binds, s.rows)
        restored = restored and verified and sameMap(original.owners, s.owners)
        if saving and restored then
            local saved, result = pcall(SaveBindings, s.set)
            restored = saved and result ~= false
        end
    end
    return nil, tostring(err) .. (restored and ". Previous bindings restored." or ". Recovery incomplete; inspect bindings.")
end

function B.census(escape)
    local s = B.capture()
    local lines = { "BINDCENSUS\t1\t" .. s.set }
    for _, command in ipairs(sorted(s.rows)) do
        local r = s.rows[command]
        local f = { "CMD", r.context, escape(command), escape(_G[r.category] or r.category), escape(r.label),
            r.custom and "custom" or "binding" }
        for _, k in ipairs(r.order) do f[#f + 1] = escape(k) end
        lines[#lines + 1] = table.concat(f, "\t")
    end
    for _, key in ipairs(sorted(s.overrides)) do
        lines[#lines + 1] = table.concat({ "OVERRIDE", escape(key), escape(s.overrides[key]) }, "\t")
    end
    return "BC1:" .. Barsmith.b64encode(table.concat(lines, "\n"))
end

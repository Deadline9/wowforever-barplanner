-- Small, SavedVariables-safe before/after records. Never store cursor objects,
-- pickup closures or macro indices (the client can renumber macros).
local C = {}
Barsmith.changes = C
local B = Barsmith.bindings

function C.equal(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do if not C.equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function macroIndex(name)
    local account, character = GetNumMacros()
    local max = MAX_ACCOUNT_MACROS or 120
    local found
    for i = 1, account + character do
        local index = i <= account and i or max + i - account
        local n = GetMacroInfo(index)
        if n and n:lower() == name:lower() then
            assert(not found, "Ambiguous macro name: " .. name)
            found = index
        end
    end
    return found
end

function C.macro(name)
    local i = macroIndex(name)
    if not i then return false end
    local n, icon, body = GetMacroInfo(i)
    assert(n and icon and body, "Incomplete macro: " .. name)
    return { name = n, icon = icon, body = body, perChar = i > (MAX_ACCOUNT_MACROS or 120) }
end

function C.slot(slot)
    local kind, id, subtype = GetActionInfo(slot)
    if not kind then
        assert(not HasAction(slot), "Unknown action on slot " .. slot)
        return { kind = "empty" }
    end
    if kind == "macro" then
        local name = GetMacroInfo(id)
        assert(name and macroIndex(name) == id, "Cannot identify macro on slot " .. slot)
        return { kind = kind, name = name, perChar = id > (MAX_ACCOUNT_MACROS or 120) }
    end
    return { kind = kind, id = id, subtype = subtype }
end

function C.read(op)
    if op.slot then return C.slot(op.slot) end
    return C.macro(op.name)
end

-- Bindings retain their own transactional writer, validation and save behavior.
-- Keep just changed edges and their affected rows in the persistent undo record.
function C.bindingUndo(preview)
    if not preview or #preview.changes == 0 then return end
    local undo = { set = preview.before.set, plan = { version = 2, binds = {} }, rows = {}, overrides = {} }
    for _, e in ipairs(preview.changes) do
        table.insert(undo.plan.binds, { key = e.key, op = e.old and "ENSURE" or "REMOVE", command = e.old or e.new })
        if e.old then undo.rows[e.old] = {} end
        if e.new then undo.rows[e.new] = {} end
        undo.overrides[e.key] = preview.before.overrides[e.key] or false
    end
    for key, cmd in pairs(preview.final) do
        if undo.rows[cmd] then
            undo.rows[cmd][key] = true
            undo.overrides[key] = preview.before.overrides[key] or false
        end
    end
    return undo
end

function C.reverseBindings(u)
    if not u then return end
    local s = B.capture(u.plan.binds, u.rows)
    assert(s.set == u.set, "Binding set changed. Select the original set in WoW.")
    for cmd, keys in pairs(u.rows) do
        assert(C.equal(keys, s.rows[cmd].keys), "Binding relationships changed for " .. cmd)
    end
    for key, expected in pairs(u.overrides) do
        assert((s.overrides[key] or false) == expected, "Runtime override changed on " .. key)
        -- Absence matters too: a formerly removed key may now have a new owner.
        assert(not s.owners[key] or (u.rows[s.owners[key]] and u.rows[s.owners[key]][key]),
            "Binding owner changed for " .. key)
    end
    local preview = B.preview(u.plan, s)
    assert(#preview.errors == 0, preview.errors[1])
    return preview
end

local function putMacro(name, value)
    local idx = macroIndex(name)
    if not value then
        assert(idx, "Missing macro: " .. name)
        DeleteMacro(idx)
    elseif idx then
        EditMacro(idx, value.name, value.icon, value.body)
    else
        CreateMacro(value.name, value.icon, value.body, value.perChar)
    end
end

local function write(op, value, pickup)
    if not op.slot then
        putMacro(op.name, value)
    elseif value.kind == "empty" then
        PickupAction(op.slot)
        ClearCursor()
    else
        local fn = pickup or C.pickup(value)
        assert(fn, "Action unavailable for slot " .. op.slot)
        fn()
        local kind, id, _, spellID = GetCursorInfo()
        assert(kind == value.kind and (kind ~= "spell" or not spellID or spellID == value.id)
            and (kind ~= "item" or id == value.id)
            and (kind ~= "macro" or GetMacroInfo(id) == value.name), "Pickup failed for slot " .. op.slot)
        PlaceAction(op.slot)
        ClearCursor()
    end
    local actual = C.read(op)
    -- CreateMacro can translate an icon path into its numeric file ID.
    if not op.slot and value and type(value.icon) == "string" and actual and type(actual.icon) == "number" then
        value.icon = actual.icon
    end
    if op.slot and pickup and value.kind ~= "empty" and not value.subtype and actual.kind == value.kind then
        value.subtype = actual.subtype
    end
    assert(C.equal(actual, value), "Game did not restore/place " .. (op.name or ("slot " .. op.slot)))
end

-- Both Apply and confirmed Revert enter here after a read-only preflight.
-- Reverse completed operations if a later game call rejects the batch.
function C.execute(ops, plan, preview, pickups)
    local undo = C.bindingUndo(preview)
    if preview then
        local ok, err, after = B.commit(plan, preview)
        assert(ok, err)
        if undo then
            for key in pairs(undo.overrides) do undo.overrides[key] = after.overrides[key] or false end
        end
    end
    local attempted = 0
    local ok, err = pcall(function()
        for i, op in ipairs(ops) do
            assert(C.equal(C.read(op), op.before), "State changed for " .. (op.name or ("slot " .. op.slot)))
            attempted = i
            write(op, op.after, pickups and pickups[i])
        end
    end)
    if ok then return undo end
    local recovered = true
    if attempted > 0 and ops[attempted].slot then ClearCursor() end
    for i = attempted, 1, -1 do
        local op = ops[i]
        local restored = pcall(function()
            local live = C.read(op)
            if not C.equal(live, op.before) then
                assert(C.equal(live, op.after))
                write(op, op.before)
            end
        end)
        recovered = restored and recovered
    end
    if undo then
        local restored, result = pcall(function() return B.commit(undo.plan, C.reverseBindings(undo)) end)
        recovered = recovered and restored and result
    end
    error(tostring(err) .. (recovered and ". Previous state restored." or ". Recovery incomplete; inspect bars, macros and keys."))
end

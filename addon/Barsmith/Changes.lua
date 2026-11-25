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

-- Compare saved, scalar configuration fields. Use physical slot IDs and
-- macro names as record keys so insertions never shift the rest of a report.
local function visible(v)
    if v == nil then return "(absent)" end
    if type(v) == "string" then
        if v:match("^%s*BP[12]:") then
            local plan = Barsmith.parse(v)
            return ("%s (%d bytes)"):format(plan and plan.name ~= "" and plan.name or "saved plan", #v)
        end
        return ("%q"):format(v)
    end
    return tostring(v)
end

function C.differences(lines, path, before, now)
    if C.equal(before, now) then return end
    if type(before) == "table" or type(now) == "table" then
        if type(before) ~= "table" then before = {} end
        if type(now) ~= "table" then now = {} end
        local keys, ordered = {}, {}
        for k in pairs(before) do keys[k] = true end
        for k in pairs(now) do keys[k] = true end
        for k in pairs(keys) do table.insert(ordered, k) end
        table.sort(ordered, function(a,b) return tostring(a) < tostring(b) end)
        if #ordered > 0 then
            for _, k in ipairs(ordered) do
                C.differences(lines, path .. " / " .. tostring(k), before[k], now[k])
            end
            return
        end
        -- Even a missing vs empty pending set changes Auto-fill eligibility.
        table.insert(lines, path .. ": empty record added or removed")
    else
        local change = path .. ": " .. visible(before) .. " -> " .. visible(now)
        if type(before) == "string" and type(now) == "string" and before:match("^%s*BP[12]:") then
            local at = 1
            while before:byte(at) == now:byte(at) do at = at + 1 end
            change = change .. " (first difference at byte " .. at .. ")"
        end
        table.insert(lines, change)
    end
end

function C.checkDifferences(lines, message)
    if #lines > 0 then error({ message = message, details = lines }, 0) end
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
    if C_Macro and C_Macro.GetSelectedMacroIcon then
        icon = C_Macro.GetSelectedMacroIcon(i)
    end
    assert(n and icon and body, "Incomplete macro: " .. name)
    return { name = n, icon = icon, body = body, perChar = i > (MAX_ACCOUNT_MACROS or 120) }
end

-- GetActionInfo can describe a macro's item or spell instead of returning its
-- macro index. Read the slot's own label, then require one match across both
-- macro lists. The matching macro record supplies its account/character scope.
function C.slotMacro(slot)
    local getText = C_ActionBar and C_ActionBar.GetActionText or GetActionText
    local name = getText and getText(slot)
    assert(name and name ~= "", "Cannot identify macro on slot " .. slot .. ": no macro label.")
    local macro = C.macro(name)
    assert(macro, "Cannot identify macro on slot " .. slot .. ": no stored macro named " .. name)
    return macro
end

function C.slot(slot, book)
    local kind, id, subtype = GetActionInfo(slot)
    if not kind then
        assert(not HasAction(slot), "Unknown action on slot " .. slot)
        return { kind = "empty" }
    end
    if kind == "macro" then
        local macro = C.slotMacro(slot)
        return { kind = kind, name = macro.name, perChar = macro.perChar }
    end
    if kind == "spell" then id = C.slotSpellID(slot, id, book) end
    return { kind = kind, id = id, subtype = subtype }
end

function C.read(op, book)
    if op.slot then return C.slot(op.slot, book) end
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

function C.reverseBindings(u, protected)
    if not u then return end
    protected = protected or {}
    local s = B.capture(u.plan.binds, u.rows)
    local plan, skipped, reasons = { version = 2, binds = {} }, {}, {}
    local expected, needed = {}, {}
    for cmd, keys in pairs(u.rows) do
        for key in pairs(keys) do expected[key] = cmd end
    end
    for _, bind in ipairs(u.plan.binds) do
        local key = bind.key
        local page = protected[bind.command] or protected[expected[key]] or protected[s.owners[key]]
        if page then
            skipped[key] = true
            table.insert(reasons, "Leave " .. key .. " untouched (excluded " .. page .. ", undo " .. bind.op .. " " .. bind.command .. ").")
        else
            table.insert(plan.binds, bind)
            needed[bind.command] = true
            if expected[key] then needed[expected[key]] = true end
        end
    end
    local lines = {}
    if #plan.binds > 0 then
        C.differences(lines, "Binding set", u.set, s.set)
        for cmd in pairs(needed) do
            local live, saved = {}, {}
            for key in pairs(s.rows[cmd].keys) do if not skipped[key] then live[key] = true end end
            for key in pairs(u.rows[cmd]) do if not skipped[key] then saved[key] = true end end
            C.differences(lines, "Keys on " .. cmd, saved, live)
        end
        for key, override in pairs(u.overrides) do
            if not skipped[key] and (needed[expected[key]] or not expected[key]) then
                C.differences(lines, "Override on " .. key, override, s.overrides[key] or false)
                C.differences(lines, "Owner of " .. key, expected[key], s.owners[key])
            end
        end
    end
    C.checkDifferences(lines, "Binding relationships changed.")
    local preview = B.preview(plan, s, protected)
    assert(#preview.errors == 0, preview.errors[1])
    preview.plan, preview.excluded = plan, reasons
    return preview
end

local function putMacro(name, value)
    local idx = macroIndex(name)
    if not value then
        assert(idx, "Missing macro: " .. name)
        return DeleteMacro(idx)
    elseif idx then
        return EditMacro(idx, value.name, value.icon, value.body)
    else
        return CreateMacro(value.name, value.icon, value.body, value.perChar)
    end
end

local function write(op, value, pickup, receipt, book)
    if not op.slot then
        local index = putMacro(op.name, value)
        if receipt and type(index) == "number" and index > 0 then receipt.index = index end
    elseif value.kind == "empty" then
        PickupAction(op.slot)
        ClearCursor()
    else
        local fn = pickup or C.pickup(value)
        assert(fn, "Action unavailable for slot " .. op.slot)
        fn()
        local kind, id, _, spellID = GetCursorInfo()
        local spellOK = kind ~= "spell" or not spellID or spellID == value.id
        if kind == value.kind and not spellOK and C_SpellBook and C_SpellBook.FindSpellOverrideByID then
            spellOK = spellID == C_SpellBook.FindSpellOverrideByID(value.id)
        end
        assert(kind == value.kind and spellOK
            and (kind ~= "item" or id == value.id)
            and (kind ~= "macro" or GetMacroInfo(id) == value.name), "Pickup failed for slot " .. op.slot)
        PlaceAction(op.slot)
        ClearCursor()
    end
    local actual = C.read(op, book)
    -- Legacy clients expose only the displayed texture. Accept the first
    -- resolution of a requested automatic icon, then compare it strictly.
    if not op.slot and value and actual and not (C_Macro and C_Macro.GetSelectedMacroIcon)
        and value.icon == 134400 and type(actual.icon) == "number"
        and (value.body:lower() .. "\n"):match("^%s*#showtooltip%s")
        and value.name == actual.name and value.body == actual.body and value.perChar == actual.perChar then
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
    local book = #ops > 0 and C_ActionBar and C_ActionBar.FindSpellActionButtons and C.spellbookEntries()
    local undo = C.bindingUndo(preview)
    if preview then
        local ok, err, after = B.commit(plan, preview)
        if not ok then error(err, 0) end
        if undo then
            for key in pairs(undo.overrides) do undo.overrides[key] = after.overrides[key] or false end
        end
    end
    local attempted, failedWrite = 0, nil
    local ok, err = pcall(function()
        for i, op in ipairs(ops) do
            local actual = C.read(op, book)
            local where = op.name or ("slot " .. op.slot)
            if not C.equal(actual, op.before) then
                local differences = {}
                C.differences(differences, where, op.before, actual)
                C.checkDifferences(differences, "State changed for " .. where .. ".")
            end
            attempted = i
            failedWrite = {}
            write(op, op.after, pickups and pickups[i], failedWrite, book)
            failedWrite = nil
        end
    end)
    if ok then return undo end
    local recovered = true
    if attempted > 0 and ops[attempted].slot then ClearCursor() end
    for i = attempted, 1, -1 do
        local op = ops[i]
        local restored = pcall(function()
            local live = C.read(op, book)
            if i == attempted and failedWrite and failedWrite.index and op.name and not live then
                assert(not GetMacroInfo(failedWrite.index), "Unexpected macro name after write")
            end
            if not C.equal(live, op.before) then
                -- A synchronous macro write can change only part of the
                -- record before failing verification. Recover this attempted
                -- name in its verified scope; earlier operations stay strict.
                local partialMacro = i == attempted and failedWrite and op.name and live and op.after
                    and live.name == op.after.name and (live.perChar == op.after.perChar
                        or (not op.before and failedWrite.index == macroIndex(live.name)))
                assert(partialMacro or C.equal(live, op.after))
                write(op, op.before, nil, nil, book)
            end
        end)
        recovered = restored and recovered
    end
    if undo then
        local restored, result = pcall(function() return B.commit(undo.plan, C.reverseBindings(undo)) end)
        recovered = recovered and restored and result
    end
    local recovery = recovered and " Previous state restored." or " Recovery incomplete; inspect bars, macros and keys."
    if type(err) == "table" then
        err.message = err.message .. recovery
        error(err, 0)
    end
    error(tostring(err) .. "." .. recovery)
end

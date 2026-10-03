-- ════════════════════════════════════════════════════════════════════════════
-- w_doorlock · server/bridge.lua
-- Who the player is and what he carries - through w_lib alone, so the same code runs on every
-- core the library knows (Wraith Core, VORP, RSG v1 / v2, QBR, QR, RedEM:RP, RPX, TPZ, FRP) and
-- every bag its inventory bridge drives (w_inventory, vorp_inventory, rsg-inventory, qbr-inventory).
--
--   Bridge.loaded(src)                  true once the player has a character in play
--   Bridge.charId(src)                  the character's id as a string ('12', VORP's charIdentifier)
--   Bridge.groups(src)                  { [name] = grade } - the job, and the gang on cores that have gangs
--   Bridge.inGroup(src, filter)         ox_doorlock's filter: 'name' | { 'a', 'b' } | { name = minGrade }
--   Bridge.findItem(src, items)         the first entry of `items` the player carries, or nil
--   Bridge.takeItem(src, entry)         removes one of it
--   Bridge.isStaff(src)                 exports.w_lib:HasPermissionNode(src, Config.Permission)
--
-- ★ w.framework is loaded lazily (the first access yields while the library detects the core),
--   so it is only ever touched from a thread or a handler, never at file load.
-- ★ On VORP the user object keeps its fields on the shared class: it is read at once, never kept
--   across a Wait.
-- ════════════════════════════════════════════════════════════════════════════
Bridge = {}

local function user(src)
    local ok, u = pcall(function() return w.framework:getUser(tonumber(src)) end)
    if ok and type(u) == 'table' then return u end
    return nil
end

local function call(u, method)
    local fn = u and u[method]
    if type(fn) ~= 'function' then return nil end
    local ok, value = pcall(fn, u)
    if ok then return value end
    return nil
end

function Bridge.loaded(src)
    return user(src) ~= nil
end

function Bridge.charId(src)
    local ids = call(user(src), 'getIdentifiers')
    local id = type(ids) == 'table' and (ids.charid or ids.charIdentifier or ids.citizenid) or nil
    if id == nil then
        -- the library's one citizen id (w_core, then the Fw* bridge)
        local ok, cid = pcall(function() return w.citizen.idOf(src) end)
        id = ok and cid or nil
    end
    if id == nil then return nil end
    return tostring(id)
end

--- The player's gang where the core has one: the RSG PlayerData contract (Wraith Core, RSG, QBR,
--- QR, RPX) keeps it as PlayerData.gang = { name, grade = { level } }, RedEM:RP as gang / ganggrade.
local function gangOf(u)
    local data = type(u.data) == 'table' and u.data or nil
    if not data then return nil end
    local pd = type(data.PlayerData) == 'table' and data.PlayerData or nil
    local gang = pd and pd.gang or data.gang
    if type(gang) == 'table' then
        local grade = gang.grade
        if type(grade) == 'table' then grade = grade.level end
        return gang.name, tonumber(grade) or 0
    elseif type(gang) == 'string' and gang ~= '' then
        return gang, tonumber(data.ganggrade or data.gangGrade) or 0
    end
    return nil
end

function Bridge.groups(src)
    local u = user(src)
    if not u then return {} end
    local out = {}
    local job = call(u, 'getJob')
    if type(job) == 'string' and job ~= '' then
        out[job] = tonumber(call(u, 'getJobGrade')) or 0
    end
    local ok, gang, grade = pcall(gangOf, u)
    if ok and type(gang) == 'string' and gang ~= '' and gang ~= 'none' and out[gang] == nil then
        out[gang] = grade or 0
    end
    return out
end

--- ox_doorlock's group filter: a name, a list of names, or { name = lowest grade }
function Bridge.inGroup(src, filter)
    local mine = Bridge.groups(src)
    if type(filter) == 'string' then
        return mine[filter] ~= nil
    end
    if type(filter) ~= 'table' then return false end
    if filter[1] ~= nil then
        for i = 1, #filter do
            if mine[filter[i]] ~= nil then return true end
        end
        return false
    end
    for name, minGrade in pairs(filter) do
        local grade = mine[name]
        if grade ~= nil and grade >= (tonumber(minGrade) or 0) then return true end
    end
    return false
end

--- An item entry as the board stores it: 'name' or { name, metadata = 'type', remove = bool }.
--- ox_inventory read a metadata string as metadata.type; the library's bridge takes a filter table.
local function entryOf(item)
    if type(item) == 'string' then return { name = item } end
    if type(item) == 'table' and type(item.name) == 'string' and item.name ~= '' then return item end
    return nil
end

local function metaOf(entry)
    local meta = entry.metadata
    if type(meta) == 'string' and meta ~= '' then return { type = meta } end
    if type(meta) == 'table' and next(meta) then return meta end
    return nil
end

function Bridge.findItem(src, items)
    if type(items) ~= 'table' then return nil end
    for i = 1, #items do
        local entry = entryOf(items[i])
        if entry then
            local ok, count = pcall(function()
                return exports.w_lib:InvGetItemCount(src, entry.name, metaOf(entry))
            end)
            if ok and (tonumber(count) or 0) > 0 then return entry end
        end
    end
    return nil
end

function Bridge.takeItem(src, entry)
    if not entry then return false end
    local ok, done = pcall(function()
        return exports.w_lib:InvRemoveItem(src, entry.name, 1, metaOf(entry))
    end)
    return ok and done == true
end

function Bridge.isStaff(src)
    src = tonumber(src)
    if not src then return false end
    if src == 0 then return true end
    local ok, allowed = pcall(function()
        return exports.w_lib:HasPermissionNode(src, Config.Permission)
    end)
    return ok and allowed == true
end

-- The framework module is detected once, early, so the first door anybody uses does not wait for it
CreateThread(function()
    local ok, err = pcall(function() return w.framework end)
    if not ok then w.print.warn('framework bridge: %s', tostring(err)) end
end)

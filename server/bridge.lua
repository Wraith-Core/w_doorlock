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
--   Bridge.knownGroups()                the core's job + gang names as a set, nil when it has no list
--   Bridge.itemKnown(name)              does the bag define it (nil = no bag answers)
--   Bridge.itemLabel(name)              the bag's label for it
--   Bridge.storeStaff(src, storeId)     2.2.0: the w_store store's owner or one of its staff, right now
--   Bridge.storeKnown(storeId)          2.2.0: does w_store have that store (nil = w_store not running)
--   Bridge.stores()                     2.2.0: w_store's stores for the board's picker
--   Bridge.groupList() / itemList()     2026-11-12: jobs, gangs, grades and items with their names (the board's pickers)
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

--- Every job and gang name the core defines, as a set; nil when the core gives no list to read
--- (VORP: a job is any string the server writes), so nothing is refused on a guess.
---@return table<string, true>|nil
function Bridge.knownGroups()
    local set = {}
    local function add(list)
        if type(list) ~= 'table' then return false end
        for name in pairs(list) do
            if type(name) == 'string' then set[name] = true end
        end
        return true
    end
    if GetResourceState('w_core') == 'started' then
        local okJ, jobs = pcall(function() return exports.w_core:GetJobs() end)
        local okG, gangs = pcall(function() return exports.w_core:GetGangs() end)
        if okJ and okG and add(jobs) and add(gangs) and next(set) then return set end
        return nil
    end
    if GetResourceState('rsg-core') == 'started' then
        local ok, shared = pcall(function() return exports['rsg-core']:GetCoreObject().Shared end)
        if ok and type(shared) == 'table' and add(shared.Jobs) and add(shared.Gangs) and next(set) then return set end
    end
    return nil
end

--- The notebook board (2026-11-12): every job and gang with its names and grades, for the board's pickers - the staff
--- choose «الشرطة · ضابط وما فوق» instead of typing police / 1. Empty when the core gives no list.
---@return { name: string, kind: 'job'|'gang', en: string, ar: string, grades: { grade: integer, en: string, ar: string }[] }[]
function Bridge.groupList()
    local out = {}
    local function add(list, kind)
        if type(list) ~= 'table' then return end
        for name, def in pairs(list) do
            if type(name) == 'string' and type(def) == 'table' then
                local grades = {}
                for g, gd in pairs(type(def.grades) == 'table' and def.grades or {}) do
                    local n = tonumber(g)
                    if n and type(gd) == 'table' then
                        grades[#grades + 1] = { grade = math.floor(n), en = tostring(gd.name or gd.label or n),
                            ar = tostring(gd.name_ar or gd.name or gd.label or n) }
                    end
                end
                table.sort(grades, function(a, b) return a.grade < b.grade end)
                out[#out + 1] = { name = name, kind = kind, en = tostring(def.label or name),
                    ar = tostring(def.label_ar or def.label or name), grades = grades }
            end
        end
    end
    if GetResourceState('w_core') == 'started' then
        local okJ, jobs = pcall(function() return exports.w_core:GetJobs() end)
        local okG, gangs = pcall(function() return exports.w_core:GetGangs() end)
        if okJ then add(jobs, 'job') end
        if okG then add(gangs, 'gang') end
    elseif GetResourceState('rsg-core') == 'started' then
        local ok, shared = pcall(function() return exports['rsg-core']:GetCoreObject().Shared end)
        if ok and type(shared) == 'table' then add(shared.Jobs, 'job') add(shared.Gangs, 'gang') end
    end
    table.sort(out, function(a, b) if a.kind ~= b.kind then return a.kind == 'job' end return a.name < b.name end)
    return out
end

--- The notebook board (2026-11-12): every item the bag defines with its label ({ name, label }), for the board's key picker. Empty when the
--- bag gives no list (the typed name is then checked on save as before).
function Bridge.itemList()
    local out = {}
    local all
    if GetResourceState('w_inventory') == 'started' then
        local ok, list = pcall(function() return exports.w_inventory:Items() end)
        all = ok and type(list) == 'table' and list or nil
    elseif GetResourceState('rsg-core') == 'started' then
        local ok, list = pcall(function() return exports['rsg-core']:GetCoreObject().Shared.Items end)
        all = ok and type(list) == 'table' and list or nil
    end
    for name, def in pairs(all or {}) do
        if type(name) == 'string' and type(def) == 'table' and #out < 3000 then
            out[#out + 1] = { name = name, label = type(def.label) == 'string' and def.label ~= '' and def.label or name }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

--- Does the bag define this item? true / false, nil when no bag answers.
function Bridge.itemKnown(name)
    local okName, bag = pcall(function() return exports.w_lib:InvName() end)
    if not okName or not bag then return nil end
    local ok, def = pcall(function() return exports.w_lib:InvItems(name) end)
    if not ok then return nil end
    return type(def) == 'table'
end

--- An item's name as the player reads it (the bag's label), else the id itself.
function Bridge.itemLabel(name)
    local ok, def = pcall(function() return exports.w_lib:InvItems(name) end)
    if ok and type(def) == 'table' and type(def.label) == 'string' and def.label ~= '' then return def.label end
    return tostring(name)
end

-- ════════════════════════════════════════════════════════════════════════════
-- 2.2.0 (the owner, 2026-11-02): a door linked on the board to a w_store store. w_store is asked on
-- every use (its GetRole export), so the right follows the store the moment it is sold, handed on or
-- taken by the central bank. A soft link: with w_store stopped it grants nothing and nothing fails.
-- ════════════════════════════════════════════════════════════════════════════

local function storesUp() return GetResourceState('w_store') == 'started' end

--- The store's owner or one of its staff? (GetRole: 'owner' | 'employee' | nil - nil for everyone
--- while the store is government-run, held by the central bank or waiting on a debt)
function Bridge.storeStaff(src, storeId)
    if not storesUp() then return false end
    local ok, role = pcall(function() return exports.w_store:GetRole(src, storeId) end)
    return ok and (role == 'owner' or role == 'employee')
end

--- Does w_store have this store? true / false, nil when w_store is not running (or does not answer)
function Bridge.storeKnown(storeId)
    if not storesUp() then return nil end
    local ok, store = pcall(function() return exports.w_store:GetStore(storeId) end)
    if not ok then return nil end
    return type(store) == 'table'
end

--- The stores for the board's picker: { { id, name, owner, at } } (w_store's enabled ones), {} without w_store
function Bridge.stores()
    if not storesUp() then return {} end
    local ok, list = pcall(function() return exports.w_store:GetStores() end)
    if not ok or type(list) ~= 'table' then return {} end
    local out = {}
    for _, s in ipairs(list) do
        local id = type(s) == 'table' and math.tointeger(tonumber(s.id))
        if id then
            local c = type(s.cashier) == 'table' and s.cashier or nil
            local x, y, z = c and tonumber(c.x), c and tonumber(c.y), c and tonumber(c.z)
            out[#out + 1] = {
                id = id,
                name = type(s.name) == 'string' and s.name or ('#' .. id),
                owner = type(s.ownerName) == 'string' and s.ownerName ~= '' and s.ownerName or nil,
                at = (x and y and z) and { x = x, y = y, z = z } or nil,
            }
        end
    end
    return out
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

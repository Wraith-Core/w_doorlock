-- ════════════════════════════════════════════════════════════════════════════
-- w_doorlock · server/admin.lua
-- The board: /doorlock, and what the staff do on it - every door with all its settings, a new
-- door, a door saved, a door deleted. Every call checks the permission again; the page is never
-- trusted, and everything it sends is cleaned before it reaches the table.
-- ════════════════════════════════════════════════════════════════════════════

local function notify(src, key, style)
    TriggerClientEvent('w_doorlock:client:notify', src, key, style)
end

-- ════════════════════════════════════════════════════════════════════════════
-- Cleaning what the page sends
-- ════════════════════════════════════════════════════════════════════════════

--- A trimmed string of at most `max` characters (UTF-8 aware: an Arabic name is never cut in half)
local function clip(value, max)
    if type(value) == 'number' then value = tostring(value) end
    if type(value) ~= 'string' then return nil end
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    if value == '' then return nil end
    if utf8.len(value) == nil then return nil end
    if utf8.len(value) > max then value = value:sub(1, utf8.offset(value, max + 1) - 1) end
    return value
end

local function number(value, low, high)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    if value < low then return low end
    if value > high then return high end
    return value
end

local function flag(value)
    return value == true or value == 1 or value == 'true'
end

local function sound(value)
    if type(value) ~= 'string' then return nil end
    for _, name in ipairs(Config.DoorSounds or {}) do
        if name == value then return name end
    end
    return nil
end

--- A character id as the cores write it: the library's citizen id when it reads as one ('012' -> '12'),
--- otherwise the trimmed text (another core's own id format)
local function character(value)
    local text = clip(value, 64)
    if not text then return nil end
    local ok, id = pcall(function() return w.citizen.normalize(text) end)
    if ok and type(id) == 'string' and id ~= '' then return id end
    return text
end

local DIFFICULTIES = { easy = true, medium = true, hard = true }

local function difficulty(value)
    if type(value) == 'string' and DIFFICULTIES[value] then return value end
    if type(value) == 'table' then
        local size, speed = number(value.areaSize, 5, 180), number(value.speedMultiplier, 0.1, 5)
        if size and speed then return { areaSize = math.floor(size), speedMultiplier = speed } end
    end
    return nil
end

local function position(data)
    if type(data) ~= 'table' then return nil end
    local coords = DoorVec(data.coords)
    local hash = tonumber(data.hash)
    if not coords or not hash then return nil end
    return {
        coords = coords,
        hash = math.floor(hash),
        model = tonumber(data.model) and math.floor(tonumber(data.model)) or nil,
        heading = number(data.heading, -360, 360) and math.floor(number(data.heading, -360, 360) + 0.5) or 0,
    }
end

local function some(list) return next(list) ~= nil and list or nil end

--- The board's form, cleaned. `current` is the door being edited (its place in the world stays its
--- own: the board never moves a door), nil for a new door whose place comes with the form.
---@return table|nil door, string|nil why
local function clean(form, current)
    if type(form) ~= 'table' then return nil, 'invalid' end
    local door = {}

    door.name = clip(form.name, 100)
    door.passcode = clip(form.passcode, 32)

    local autolock = number(form.autolock, 0, 86400)
    door.autolock = autolock and autolock >= 1 and math.floor(autolock) or nil

    local distance = number(form.maxDistance, 0, 30)
    door.maxDistance = (distance and distance >= 0.5) and distance or 2.0

    local rate = number(form.doorRate, 0, 10)
    door.doorRate = rate and rate > 0 and rate or nil

    door.lockSound = sound(form.lockSound)
    door.unlockSound = sound(form.unlockSound)

    door.state = flag(form.state) and 1 or 0
    door.auto = flag(form.auto) or nil
    door.lockpick = flag(form.lockpick) or nil
    door.hideUi = flag(form.hideUi) or nil
    door.holdOpen = flag(form.holdOpen) or nil

    -- 2.2.0: the w_store store the door is linked to (its id; 0 / '' / none = no link). Whether the
    -- store exists is asked in saveDoor
    local store = number(form.store, 0, 2147483647)
    door.store = store and math.tointeger(store) or nil
    if door.store and door.store < 1 then door.store = nil end

    local characters, seen = {}, {}
    for _, value in ipairs(type(form.characters) == 'table' and form.characters or {}) do
        local id = character(value)
        if id and not seen[id] and #characters < 64 then
            characters[#characters + 1] = id
            seen[id] = true
        end
    end
    door.characters = some(characters)

    -- the page sends { { name, grade }, ... }; the table keeps ox_doorlock's { name = grade }
    local groups, count = {}, 0
    local rows = type(form.groups) == 'table' and form.groups or {}
    if rows[1] == nil then
        local list = {}
        for name, grade in pairs(rows) do list[#list + 1] = { name = name, grade = grade } end
        rows = list
    end
    for _, row in ipairs(rows) do
        local name = type(row) == 'table' and clip(row.name, 50) or clip(row, 50)
        if name and groups[name] == nil and count < 32 then
            groups[name] = math.floor(number(type(row) == 'table' and row.grade or 0, 0, 100) or 0)
            count = count + 1
        end
    end
    door.groups = some(groups)

    local items = {}
    for _, row in ipairs(type(form.items) == 'table' and form.items or {}) do
        local name = type(row) == 'table' and clip(row.name, 64) or clip(row, 64)
        if name and #items < 32 then
            items[#items + 1] = {
                name = name,
                metadata = type(row) == 'table' and clip(row.metadata, 64) or nil,
                remove = type(row) == 'table' and flag(row.remove) or false,
            }
        end
    end
    door.items = some(items)

    local rounds = {}
    for _, value in ipairs(type(form.lockpickDifficulty) == 'table' and form.lockpickDifficulty or {}) do
        local round = difficulty(value)
        if round and #rounds < 10 then rounds[#rounds + 1] = round end
    end
    door.lockpickDifficulty = some(rounds)

    -- where the door is
    if current then
        door.coords, door.heading, door.model, door.hash = current.coords, current.heading, current.model, current.hash
        door.doors = current.doors
    elseif type(form.doors) == 'table' and form.doors[1] then
        local a, b = position(form.doors[1]), position(form.doors[2])
        if not a or not b then return nil, 'invalid' end
        if a.hash == b.hash then return nil, 'same_door' end
        door.doors = { a, b }
        door.coords = vector3((a.coords.x + b.coords.x) / 2, (a.coords.y + b.coords.y) / 2, (a.coords.z + b.coords.z) / 2)
    else
        local at = position(form)
        if not at then return nil, 'invalid' end
        door.coords, door.heading, door.model, door.hash = at.coords, at.heading, at.model, at.hash
    end

    door.name = door.name or ('door %d %d %d'):format(math.floor(door.coords.x), math.floor(door.coords.y), math.floor(door.coords.z))
    return door
end

--- The hashes of every door but `except`: the same door is never locked twice
local function takenBy(door, except)
    local hashes = {}
    if door.doors then hashes = { door.doors[1].hash, door.doors[2].hash } else hashes = { door.hash } end
    for id, other in pairs(Doors) do
        if id ~= except then
            local theirs = other.doors and { other.doors[1].hash, other.doors[2].hash } or { other.hash }
            for _, a in ipairs(hashes) do
                for _, b in ipairs(theirs) do
                    if a == b then return other end
                end
            end
        end
    end
    return nil
end

--- A job / gang or key item the server does not define: a typo there makes a door only the staff can
--- open, so the save is refused with the name. Nothing is refused when the core or the bag gives no list.
---@return string|nil why, string|nil name
local function unknownName(door)
    if door.groups then
        local known = Bridge.knownGroups()
        if known then
            for name in pairs(door.groups) do
                if not known[name] then return 'unknown_group', name end
            end
        end
    end
    for _, entry in ipairs(door.items or {}) do
        if Bridge.itemKnown(entry.name) == false then return 'unknown_item', entry.name end
    end
    return nil
end

-- ════════════════════════════════════════════════════════════════════════════
-- The board's calls
-- ════════════════════════════════════════════════════════════════════════════

--- Every door with all its settings, by id (the board's list)
local function boardDoors()
    local list = {}
    for _, door in pairs(Doors) do list[#list + 1] = DoorFull(door) end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

--- A door saved: a new one (id nil, its place comes with the form) or an existing one (its place stays its own).
--- `by` names who did it on the console line.
---@return boolean ok, table|string door or why, string|nil name the unknown job / gang / item
local function saveDoor(id, form, by)
    if not DoorsLoaded() then return false, 'not_ready' end

    id = tonumber(id)
    local current = id and Doors[id] or nil
    if id and not current then return false, 'missing' end

    local door, why = clean(form, current)
    if not door then return false, why end

    local unknown, name = unknownName(door)
    if unknown then return false, unknown, name end

    -- 2.2.0: a store link names a store w_store has. The link the door already had is kept as it is, so
    -- the website's edits (which never send it) and a save while w_store is stopped neither drop nor refuse it
    if door.store and not (current and current.store == door.store) then
        local known = Bridge.storeKnown(door.store)
        if known == nil then return false, 'store_offline' end
        if not known then return false, 'unknown_store', tostring(door.store) end
    end

    if not current then
        if takenBy(door) then return false, 'taken' end
        local newId = Db.insert(door.name, DoorEncode(door))
        if not newId then return false, 'db' end
        door = DoorAdd(newId, door, door.name)
        if not door then return false, 'invalid' end
        w.print.info('%s added door %d (%s)', by, newId, door.name)
    else
        door.id = id
        door._autolockStamp = current._autolockStamp
        if not Db.update(id, door.name, DoorEncode(door)) then return false, 'db' end
        door = DoorAdd(id, door, door.name)
        w.print.info('%s saved door %d (%s)', by, id, door.name)
    end

    TriggerClientEvent('w_doorlock:client:upsert', -1, DoorPublic(door))
    return true, DoorFull(door)
end

---@return boolean ok, string|nil why
local function deleteDoor(id, by)
    id = tonumber(id)
    local door = id and Doors[id]
    if not door then return false, 'missing' end
    if not Db.delete(id) then return false, 'db' end
    Doors[id] = nil
    TriggerClientEvent('w_doorlock:client:remove', -1, id)
    w.print.info('%s deleted door %d (%s)', by, id, door.name)
    return true
end

w.callback.register('w_doorlock:admin:doors', function(src)
    if not Bridge.isStaff(src) then return false end
    while not DoorsLoaded() do Wait(100) end
    return boardDoors()
end)

--- 2.2.0: the stores the board may link a door to (w_store's; empty when it is not running)
w.callback.register('w_doorlock:admin:stores', function(src)
    if not Bridge.isStaff(src) then return false end
    return Bridge.stores()
end)

w.callback.register('w_doorlock:admin:save', function(src, id, form)
    if not Bridge.isStaff(src) then return false, 'no_permission' end
    return saveDoor(id, form, GetPlayerName(src) or src)
end)

w.callback.register('w_doorlock:admin:delete', function(src, id)
    if not Bridge.isStaff(src) then return false, 'no_permission' end
    return deleteDoor(id, GetPlayerName(src) or src)
end)

-- ════════════════════════════════════════════════════════════════════════════
-- The website (w_connector, 2026-10-22): the board's data ops, run by the board's own code as the
-- console. Choosing a door in the world (a new door, its place, its leaves) stays in game. The website
-- checked the staff member's rank (system.doors) and logs every change under their name.
--   doors                 -> { doors = SiteDoor[], total }      read
--   lock   { id, locked } -> { id, state }                      lock (true) or unlock (false) now
--   edit   { id, form }   -> DoorFull                           an existing door's settings (never a new door)
--   delete { id }         -> -
-- ════════════════════════════════════════════════════════════════════════════

local SITE_OPS = { doors = 'read', lock = 'write', edit = 'write', delete = 'write' }
local SITE_MAX = 1000

-- the settings the website may send; anything else in its form is dropped, and clean() keeps the door's
-- own place (coords, heading, model, hash, the double door's leaves)
local SITE_FIELDS = {
    'name', 'passcode', 'autolock', 'maxDistance', 'doorRate', 'lockSound', 'unlockSound', 'state', 'auto',
    'lockpick', 'hideUi', 'holdOpen', 'characters', 'groups', 'items', 'lockpickDifficulty',
}

local function round1(n) n = tonumber(n) return n and math.floor(n * 10 + 0.5) / 10 or nil end

--- A board row without the place's numbers the website has no use for (a short `at` names where it is)
local function siteRow(door)
    local row = DoorFull(door)
    local c = door.coords
    row.at = c and { x = round1(c.x), y = round1(c.y), z = round1(c.z) } or nil
    row.double = door.doors ~= nil
    row.coords, row.doors, row.hash, row.model, row.heading = nil, nil, nil, nil, nil
    return row
end

local SITE = {}

function SITE.doors()
    if not DoorsLoaded() then return false, 'not_ready' end
    local ids = {}
    for id in pairs(Doors) do ids[#ids + 1] = id end
    table.sort(ids)
    local rows = {}
    for i = 1, math.min(#ids, SITE_MAX) do rows[i] = siteRow(Doors[ids[i]]) end
    return true, { doors = rows, total = #ids }
end

function SITE.lock(args)
    local door = Doors[tonumber(args.id)]
    if not door then return false, 'missing' end
    if type(args.locked) ~= 'boolean' then return false, 'invalid' end
    DoorSetState(door, args.locked and 1 or 0)
    return true, { id = door.id, state = door.state }
end

function SITE.edit(args, by)
    local id = tonumber(args.id)
    if not id or not Doors[id] then return false, 'missing' end
    if type(args.form) ~= 'table' then return false, 'invalid' end
    -- the door as it is, with only the settings the website sent changed ('' clears a text, [] a list)
    local form = DoorFull(Doors[id])
    for _, key in ipairs(SITE_FIELDS) do
        if args.form[key] ~= nil then form[key] = args.form[key] end
    end
    return saveDoor(id, form, by)
end

function SITE.delete(args, by)
    return deleteDoor(args.id, by)
end

exports('SiteAdmin', function(op, args, by)
    if GetInvokingResource() ~= 'w_connector' then return { ok = false, error = 'forbidden' } end
    local kind = type(op) == 'string' and SITE_OPS[op] or nil
    if not kind then return { ok = false, error = 'unknown_action' } end
    local who = ('%s (website)'):format(type(by) == 'string' and by ~= '' and by or 'staff')
    local ok, done, res, detail = pcall(SITE[op], type(args) == 'table' and args or {}, who)
    if not ok then
        print(('^1[w_doorlock] website op %s failed: %s^0'):format(op, tostring(done)))
        return { ok = false, error = 'error' }
    end
    -- detail: the unknown job / gang / item name behind 'unknown_group' / 'unknown_item'
    if not done then
        return { ok = false, error = type(res) == 'string' and res or 'failed', detail = type(detail) == 'string' and detail or nil }
    end
    return { ok = true, data = res, read = (kind == 'read') or nil }
end)

-- ════════════════════════════════════════════════════════════════════════════
-- /doorlock [closest]
-- ════════════════════════════════════════════════════════════════════════════

w.addCommand(Config.Command or 'doorlock', {
    help = locale('command.help'),
    params = {
        { name = 'closest', help = locale('command.closest'), optional = true },
    },
}, function(source, args)
    if source == 0 then
        return w.print.info('the board needs a player in the game')
    end
    if not Bridge.isStaff(source) then
        return notify(source, 'notify.no_permission', 'error')
    end
    TriggerClientEvent('w_doorlock:client:openBoard', source, args.closest ~= nil)
end)

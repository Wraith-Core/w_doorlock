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

-- ════════════════════════════════════════════════════════════════════════════
-- The board's calls
-- ════════════════════════════════════════════════════════════════════════════

w.callback.register('w_doorlock:admin:doors', function(src)
    if not Bridge.isStaff(src) then return false end
    while not DoorsLoaded() do Wait(100) end
    local list = {}
    for _, door in pairs(Doors) do list[#list + 1] = DoorFull(door) end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end)

w.callback.register('w_doorlock:admin:save', function(src, id, form)
    if not Bridge.isStaff(src) then return false, 'no_permission' end
    if not DoorsLoaded() then return false, 'not_ready' end

    id = tonumber(id)
    local current = id and Doors[id] or nil
    if id and not current then return false, 'missing' end

    local door, why = clean(form, current)
    if not door then return false, why end

    if not current then
        if takenBy(door) then return false, 'taken' end
        local newId = Db.insert(door.name, DoorEncode(door))
        if not newId then return false, 'db' end
        door = DoorAdd(newId, door, door.name)
        if not door then return false, 'invalid' end
        w.print.info('%s added door %d (%s)', GetPlayerName(src) or src, newId, door.name)
    else
        door.id = id
        door._autolockStamp = current._autolockStamp
        if not Db.update(id, door.name, DoorEncode(door)) then return false, 'db' end
        door = DoorAdd(id, door, door.name)
        w.print.info('%s saved door %d (%s)', GetPlayerName(src) or src, id, door.name)
    end

    TriggerClientEvent('w_doorlock:client:upsert', -1, DoorPublic(door))
    return true, DoorFull(door)
end)

w.callback.register('w_doorlock:admin:delete', function(src, id)
    if not Bridge.isStaff(src) then return false, 'no_permission' end
    id = tonumber(id)
    local door = id and Doors[id]
    if not door then return false, 'missing' end
    if not Db.delete(id) then return false, 'db' end
    Doors[id] = nil
    TriggerClientEvent('w_doorlock:client:remove', -1, id)
    w.print.info('%s deleted door %d (%s)', GetPlayerName(src) or src, id, door.name)
    return true
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

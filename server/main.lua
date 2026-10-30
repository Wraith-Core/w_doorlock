-- ════════════════════════════════════════════════════════════════════════════
-- w_doorlock · server/main.lua
-- The doors: loaded from the table, the state of each one (the server's word is the only one),
-- who may lock and unlock what, the code, the lock pick, and the exports other resources call.
--
-- Who may use a door (ox_doorlock's rules, unchanged):
--   1. Config.AdminBypass and the board's permission, or the ACE  w_doorlock.door.<name>
--   2. a character listed on the door
--   3. a group (job or gang, from a grade up) - or, failing that, an item listed on the door
--   4. a door with a code asks for it: on its own when the door has no group or item, after them
--      otherwise. A door with no rule at all opens for nobody but the staff and the ACE.
--
-- ★ A door's code never leaves the server: the client is told 'passcode' and asks the player.
-- ★ The client asks, the server decides - and checks the player stands at the door.
-- ════════════════════════════════════════════════════════════════════════════
Doors = {}

local loaded = false

-- ════════════════════════════════════════════════════════════════════════════
-- The shape of a door
-- ════════════════════════════════════════════════════════════════════════════

local function toVec(c)
    if type(c) == 'vector3' then return c end
    if type(c) == 'table' then
        local x, y, z = tonumber(c.x or c[1]), tonumber(c.y or c[2]), tonumber(c.z or c[3])
        if x and y and z then return vector3(x + 0.0, y + 0.0, z + 0.0) end
    end
    return nil
end
DoorVec = toVec

local function middle(a, b)
    return vector3((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2)
end

--- A door read from the table (or handed in by the board / an export), ready to be used
local function prepare(id, data, name)
    data.id = id
    data.name = name or data.name
    if type(data.doors) == 'table' and data.doors[1] and data.doors[2] then
        for i = 1, 2 do data.doors[i].coords = toVec(data.doors[i].coords) end
        if not data.doors[1].coords or not data.doors[2].coords then return nil end
        data.coords = toVec(data.coords) or middle(data.doors[1].coords, data.doors[2].coords)
    else
        data.doors = nil
        data.coords = toVec(data.coords)
    end
    if not data.coords then return nil end

    data.state = (tonumber(data.state) or 1) ~= 0 and 1 or 0
    if not tonumber(data.maxDistance) or tonumber(data.maxDistance) <= 0 then data.maxDistance = 2.0 end

    -- ox_doorlock kept a bare item list once ({ 'key' }): every entry becomes { name, remove }
    if type(data.items) == 'table' then
        for i = 1, #data.items do
            if type(data.items[i]) == 'string' then data.items[i] = { name = data.items[i], remove = false } end
        end
    end
    return data
end

local FIELDS = {
    'auto', 'autolock', 'coords', 'characters', 'groups', 'heading', 'items', 'lockpick', 'hideUi',
    'holdOpen', 'lockSound', 'maxDistance', 'doorRate', 'model', 'hash', 'state', 'unlockSound',
    'passcode', 'lockpickDifficulty',
}

local function leaf(d)
    return { coords = d.coords, heading = d.heading, model = d.model, hash = d.hash }
end

--- The row's JSON: the fields of ox_doorlock's table, nothing the server keeps for itself
function DoorEncode(door)
    local out = {}
    for _, key in ipairs(FIELDS) do out[key] = door[key] end
    if door.doors then out.doors = { leaf(door.doors[1]), leaf(door.doors[2]) } end
    return json.encode(out)
end

--- What every client gets: where the door is and how it behaves - no code, no access lists
function DoorPublic(door)
    return {
        id = door.id,
        name = door.name,
        coords = door.coords,
        heading = door.heading,
        model = door.model,
        hash = door.hash,
        doors = door.doors and { leaf(door.doors[1]), leaf(door.doors[2]) } or nil,
        state = door.state,
        maxDistance = door.maxDistance,
        doorRate = door.doorRate,
        auto = door.auto,
        holdOpen = door.holdOpen,
        hideUi = door.hideUi,
        lockSound = door.lockSound,
        unlockSound = door.unlockSound,
        lockpick = door.lockpick,
    }
end

--- What the board gets: everything, the code included (the board is the staff's)
function DoorFull(door)
    local out = json.decode(DoorEncode(door))
    out.id = door.id
    out.name = door.name
    return out
end

function DoorAdd(id, data, name)
    local door = prepare(id, data, name)
    if not door then
        w.print.warn('door %s has no position and was skipped', tostring(id))
        return nil
    end
    Doors[id] = door
    return door
end

-- ════════════════════════════════════════════════════════════════════════════
-- Loading
-- ════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    if not Db.init() then
        -- no table, no doors: the callbacks still answer (empty) rather than keep every caller waiting
        loaded = true
        w.print.error('no doors: the database is not available (see the line above)')
        return
    end
    local count = 0
    for _, row in ipairs(Db.all()) do
        local ok, data = pcall(json.decode, row.data)
        if ok and type(data) == 'table' then
            if DoorAdd(tonumber(row.id), data, row.name) then count = count + 1 end
        else
            w.print.warn('door %s holds data that is not JSON and was skipped', tostring(row.id))
        end
    end
    loaded = true
    w.print.info('%d door(s) loaded', count)
    TriggerEvent('w_doorlock:loaded')
end)

function DoorsLoaded() return loaded end

-- ════════════════════════════════════════════════════════════════════════════
-- Changing a door's state
-- ════════════════════════════════════════════════════════════════════════════

local function normState(state)
    if state == 1 or state == true then return 1 end
    if state == 0 or state == false then return 0 end
    return tonumber(state) == 1 and 1 or 0
end

--- The one way a door changes: everyone is told, the autolock is armed, other resources hear it
---@param door table
---@param state 0 | 1
---@param src? number the player who did it (nil for the server, an export, the autolock)
---@param usedItem? string the item that opened it
function DoorSetState(door, state, src, usedItem)
    door.state = state
    TriggerClientEvent('w_doorlock:client:setState', -1, door.id, state, src)

    if door.autolock and state == 0 then
        -- a newer unlock re-arms the clock: an older timer never locks the door early
        local stamp = (door._autolockStamp or 0) + 1
        door._autolockStamp = stamp
        SetTimeout(door.autolock * 1000, function()
            if Doors[door.id] ~= door or door._autolockStamp ~= stamp or door.state == 1 then return end
            door.state = 1
            TriggerClientEvent('w_doorlock:client:setState', -1, door.id, 1)
            TriggerEvent('w_doorlock:stateChanged', nil, door.id, true)
        end)
    end

    TriggerEvent('w_doorlock:stateChanged', src, door.id, state == 1, usedItem or false)
end

-- ════════════════════════════════════════════════════════════════════════════
-- Who may use a door
-- ════════════════════════════════════════════════════════════════════════════

--- The player must stand at the door (the door's distance plus room for the leaf and the lag)
local function nearDoor(src, door)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local at = GetEntityCoords(ped)
    return #(at - door.coords) <= (door.maxDistance or 2.0) + 3.0
end

local function listed(list, value)
    if type(list) ~= 'table' or value == nil then return false end
    for i = 1, #list do
        if tostring(list[i]) == value then return true end
    end
    return false
end

---@return true | 'passcode' | false granted
---@return table|string|nil detail the item that opened it, or why not
local function authorise(src, door, code)
    if Config.AdminBypass and Bridge.isStaff(src) then return true end
    if door.name and IsPlayerAceAllowed(src, ('w_doorlock.door.%s'):format(door.name)) then return true end
    if not Bridge.loaded(src) then return false end

    if door.characters and listed(door.characters, Bridge.charId(src)) then return true end

    local granted = door.passcode ~= nil
    local item
    if door.groups then granted = Bridge.inGroup(src, door.groups) end
    if not granted and door.items then
        item = Bridge.findItem(src, door.items)
        granted = item ~= nil
    end
    if not granted then return false end

    if door.passcode then
        if code == nil then return 'passcode' end
        if tostring(code) ~= tostring(door.passcode) then return false, 'wrong_code' end
    end
    return true, item
end

local operationLocks = {}
local lastUse = {}
local wrongCodes = {}   -- [src] = { count, since }: five wrong codes a minute, then a pause

local function codeLocked(src)
    local entry = wrongCodes[src]
    if not entry then return false end
    if GetGameTimer() - entry.since > 60000 then wrongCodes[src] = nil return false end
    return entry.count >= 5
end

local function wrongCode(src)
    local entry = wrongCodes[src]
    if not entry or GetGameTimer() - entry.since > 60000 then
        entry = { count = 0, since = GetGameTimer() }
        wrongCodes[src] = entry
    end
    entry.count = entry.count + 1
end

--- Lock or unlock. Answers true, 'passcode' (ask the player and call again with it), or false + why
w.callback.register('w_doorlock:use', function(src, id, state, code)
    if operationLocks[src] then return false, 'busy' end
    operationLocks[src] = true
    local packed = table.pack(pcall(function()
    local door = Doors[tonumber(id)]
    if not door then return false, 'missing' end

    local now = GetGameTimer()
    if now - (lastUse[src] or 0) < 400 then return false, 'busy' end
    lastUse[src] = now

    if not nearDoor(src, door) then return false, 'far' end
    state = normState(state)

    if code ~= nil then
        if type(code) ~= 'string' and type(code) ~= 'number' then code = nil end
        if codeLocked(src) then return false, 'code_locked' end
    end

    local granted, detail = authorise(src, door, code)
    if granted == 'passcode' then return 'passcode' end
    if not granted then
        if detail == 'wrong_code' then
            wrongCode(src)
            return false, 'wrong_code'
        end
        return false, state == 0 and 'cannot_unlock' or 'cannot_lock'
    end

    local usedItem
    if type(detail) == 'table' then
        usedItem = detail.name
        if detail.remove and Bridge.takeItem(src, detail) ~= true then return false, state == 0 and 'cannot_unlock' or 'cannot_lock' end
    end
    DoorSetState(door, state, src, usedItem)
    return true
    end))
    operationLocks[src] = nil
    if not packed[1] then print('[w_doorlock] Operation failed: ' .. tostring(packed[2]));return false, 'busy' end
    return table.unpack(packed, 2, packed.n)
end)

-- ════════════════════════════════════════════════════════════════════════════
-- The lock pick
--
-- * The skill check runs on the client (the page), so the server cannot watch it; what it can do
--   it does: the door must allow it, the player must carry a pick and stand at the door, the
--   attempt must take the time its rounds take, and the pick breaks by the server's dice.
-- ════════════════════════════════════════════════════════════════════════════

local picking = {}  -- [src] = { id, token, at, rounds }

-- ox_lib's skill-check presets - the lock pick plays them the same way (web/src/door.ts PRESETS)
local PRESETS = {
    easy = { areaSize = 50, speedMultiplier = 1 },
    medium = { areaSize = 40, speedMultiplier = 1.5 },
    hard = { areaSize = 25, speedMultiplier = 1.75 },
}

-- The page is told where the mark sits and how fast the needle runs, and it is told nothing else:
-- it cannot draw a wider zone than the one below, and its own verdict is never asked for.
local function pickRounds(door)
    local list = type(door.lockpickDifficulty) == 'table' and #door.lockpickDifficulty > 0 and door.lockpickDifficulty
        or Config.Lockpick.difficulty
    local rounds = {}
    for i = 1, math.min(#list, 10) do
        local r = list[i]
        local preset
        if type(r) == 'string' and PRESETS[r] then
            preset = PRESETS[r]
        elseif type(r) == 'table' and tonumber(r.areaSize) and tonumber(r.speedMultiplier) then
            preset = { areaSize = tonumber(r.areaSize), speedMultiplier = tonumber(r.speedMultiplier) }
        end
        if preset then
            -- the same clamps the page applies, so the zone sent and the zone drawn always agree
            local size = math.min(180, math.max(5, tonumber(preset.areaSize) or 40))
            rounds[#rounds + 1] = {
                areaSize = size,
                speedMultiplier = math.min(5, math.max(0.1, tonumber(preset.speedMultiplier) or 1)),
                -- the mark never sits at the very start of the sweep: there is always a moment to see it coming
                from = 100 + math.random() * math.max(10, 240 - size),
            }
        end
    end
    if #rounds == 0 then
        rounds[1] = { areaSize = 40, speedMultiplier = 1.5, from = 100 + math.random() * 200 }
    end
    return rounds
end

local function canPick(door)
    return door.lockpick == true and (door.state == 1 or Config.Lockpick.canLock == true)
end

w.callback.register('w_doorlock:hasPick', function(src)
    return Bridge.findItem(src, Config.Lockpick.items) ~= nil
end)

w.callback.register('w_doorlock:pickStart', function(src, id)
    local door = Doors[tonumber(id)]
    if not door or not canPick(door) then return false, 'cannot_pick' end
    if not nearDoor(src, door) then return false, 'far' end
    if not Bridge.findItem(src, Config.Lockpick.items) then return false, 'no_pick' end

    local rounds = pickRounds(door)
    local token = ('%d-%d'):format(math.random(100000, 999999), GetGameTimer())
    local now = GetGameTimer()
    picking[src] = { id = door.id, token = token, at = now, roundAt = now, plan = rounds, next = 1, good = 0 }
    return token, rounds
end)

-- The page's needle: one full turn in PICK_SWEEP_MS at speed 1 (web/src/ui/Pick.tsx BASE_SWEEP).
local PICK_SWEEP_MS = 2300

--- One press, judged here and now: the angle is measured against the zone this server drew, so a page
--- that paints a wide mark, or one that simply claims a win, earns nothing.
w.callback.register('w_doorlock:pickPress', function(src, token, round, angle)
    local attempt = picking[src]
    if not attempt or attempt.token ~= token or attempt.missed then return false end
    local index = tonumber(round)
    local plan = index and attempt.plan[index]
    -- rounds are judged in order, and only once each
    if not plan or index ~= attempt.next then return false end
    local a = tonumber(angle)
    if not a or a ~= a or a < 0 or a > 360 then attempt.missed = true return false end
    -- ★ The needle cannot be at `a` before it had the time to turn there. The server's clock for the
    --   round starts when it answered the previous press (or handed out the token), which is always
    --   before the page restarts its own sweep, so an honest press is never early; a client that
    --   answers with the zone the instant the round opens is.
    local needed = a / 360 * (PICK_SWEEP_MS / (plan.speedMultiplier or 1))
    local hit = a >= plan.from and a <= plan.from + plan.areaSize
        and (GetGameTimer() - attempt.roundAt) + 150 >= needed
    if hit then
        attempt.good = attempt.good + 1
        attempt.next = attempt.next + 1
        attempt.roundAt = GetGameTimer()
    else
        -- ★ A miss ends the attempt, as it does on the page: no second try at the same round, so the
        --   zone cannot be searched for by pressing again and again
        attempt.missed = true
    end
    return hit
end)

--- The end of an attempt. Every round was already judged in pickPress, so this is told only whether the
--- player gave up; the page's own "success" is not a parameter and is never read.
w.callback.register('w_doorlock:pickFinish', function(src, token, given)
    if operationLocks[src] then return false, 'busy' end
    operationLocks[src] = true
    local packed = table.pack(pcall(function()
    local attempt = picking[src]
    picking[src] = nil
    if not attempt or attempt.token ~= token then return false end
    -- giving up is free only before a miss: a miss already happened, and its break chance is owed
    if given and not attempt.missed then return false end

    local door = Doors[attempt.id]
    if not door or not canPick(door) then return false end
    if not nearDoor(src, door) then return false end

    -- every round drawn, and not faster than the rounds can be played
    local success = attempt.good >= #attempt.plan
    if success and GetGameTimer() - attempt.at < #attempt.plan * 350 then success = false end

    local pick = Bridge.findItem(src, Config.Lockpick.items)
    if not pick then return false end

    local chance = success and (Config.Lockpick.breakOnSuccess or 0) or (Config.Lockpick.breakOnFail or 0)
    local broke = chance > 0 and math.random(1, 100) <= chance
    if broke and Bridge.takeItem(src, pick) ~= true then return false, false end

    if success then
        DoorSetState(door, door.state == 1 and 0 or 1, src, pick.name)
    end
    return success == true, broke
    end))
    operationLocks[src] = nil
    if not packed[1] then print('[w_doorlock] Operation failed: ' .. tostring(packed[2]));return false, 'busy' end
    return table.unpack(packed, 2, packed.n)
end)

-- ════════════════════════════════════════════════════════════════════════════
-- The doors for the clients
-- ════════════════════════════════════════════════════════════════════════════

w.callback.register('w_doorlock:getDoors', function()
    while not loaded do Wait(100) end
    local list = {}
    for _, door in pairs(Doors) do list[#list + 1] = DoorPublic(door) end
    return list
end)

AddEventHandler('playerDropped', function()
    local src = source
    if not src then return end
    operationLocks[src] = nil
    lastUse[src] = nil
    wrongCodes[src] = nil
    picking[src] = nil
end)

-- ════════════════════════════════════════════════════════════════════════════
-- Exports - ox_doorlock's names, so a script written for it needs only the resource name changed
-- ════════════════════════════════════════════════════════════════════════════

local function summary(door)
    door = type(door) == 'table' and door or Doors[tonumber(door)]
    if not door then return false end
    return {
        id = door.id,
        name = door.name,
        state = door.state,
        coords = door.coords,
        characters = door.characters,
        groups = door.groups,
        items = door.items,
        maxDistance = door.maxDistance,
    }
end

exports('getDoor', summary)

exports('getAllDoors', function()
    local out = {}
    for _, door in pairs(Doors) do out[#out + 1] = summary(door) end
    return out
end)

exports('getDoorFromName', function(name)
    for _, door in pairs(Doors) do
        if door.name == name then return summary(door) end
    end
end)

--- Set a door's state from another resource (no rules apply: the calling script decides)
---@param id number
---@param state 0 | 1 | boolean  1 / true = locked
---@return boolean
exports('setDoorState', function(id, state)
    local door = Doors[tonumber(id)]
    if not door then return false end
    DoorSetState(door, normState(state))
    return true
end)

--- Change a door's settings from another resource: the same fields as the board ('' clears one)
exports('editDoor', function(id, data)
    local door = Doors[tonumber(id)]
    if not door or type(data) ~= 'table' then return false end
    for key, value in pairs(data) do
        if key ~= 'id' and key ~= 'coords' and key ~= 'doors' then
            local current = door[key]
            if current ~= nil and value ~= '' and type(current) ~= type(value) then
                error(("expected '%s' for door.%s, received %s (%s)"):format(type(current), key, type(value), tostring(value)))
            end
            if value == '' then door[key] = nil else door[key] = value end
        end
    end
    prepare(door.id, door, door.name)
    if not Db.update(door.id, door.name, DoorEncode(door)) then return false end
    TriggerClientEvent('w_doorlock:client:upsert', -1, DoorPublic(door))
    return true
end)

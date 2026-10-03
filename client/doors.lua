-- ════════════════════════════════════════════════════════════════════════════
-- w_doorlock · client/doors.lua
-- The doors in the world: registered with the game's door system, held in the state the server
-- says, found as entities when the player comes near, and heard when they lock or open.
--
--   WDoor.Doors      [id] = door (what the server sends every client: no code, no access lists)
--   WDoor.Nearby     the doors within 20 m, refreshed every 500 ms
--   WDoor.Closest    the closest door within its own interact distance
--   WDoor.EntityDoor [entity] = door id
--
-- ★ RDR3 door states: 0 unlocked, 1 locked, 4 the reset the door sequence starts from. A door
--   is registered by pushing 4 and then its real state.
-- ════════════════════════════════════════════════════════════════════════════
WDoor = WDoor or {}
WDoor.Doors = {}
WDoor.Nearby = {}
WDoor.Closest = nil
WDoor.EntityDoor = {}

local Doors = WDoor.Doors

-- The door system natives (OBJECT namespace). The three known by hash only are invoked by it,
-- exactly as the previous w_doorlock did on this server; the hold-open native is skipped on a
-- client that does not expose it.
local ADD_DOOR_TO_SYSTEM_NEW     <const> = 0xD99229FE93B46286
local DOOR_SYSTEM_SET_DOOR_STATE <const> = 0x6BAB9442830C7F53
local DOOR_SYSTEM_FORCE_SHUT     <const> = 0x276AAF0F1C7F2494
local STATE_RESET <const> = 4

local function addToSystem(hash) Citizen.InvokeNative(ADD_DOOR_TO_SYSTEM_NEW, hash, true, true, false, 0, 0, false) end
local function setDoorState(hash, state) Citizen.InvokeNative(DOOR_SYSTEM_SET_DOOR_STATE, hash, state) end
local function forceShut(hash) Citizen.InvokeNative(DOOR_SYSTEM_FORCE_SHUT, hash, false) end

local function holdOpen(hash, on)
    if DoorSystemSetHoldOpen then pcall(DoorSystemSetHoldOpen, hash, on) end
end

-- ════════════════════════════════════════════════════════════════════════════
-- The shape of a door on the client
-- ════════════════════════════════════════════════════════════════════════════

local function toVec(c)
    if type(c) == 'vector3' then return c end
    if type(c) == 'table' then
        local x, y, z = tonumber(c.x or c[1]), tonumber(c.y or c[2]), tonumber(c.z or c[3])
        if x and y and z then return vector3(x + 0.0, y + 0.0, z + 0.0) end
    end
    return nil
end

--- A hash as an integer: a JSON number may come back as a float, and a native reads a float as garbage
local function toHash(v)
    local n = tonumber(v)
    if not n then return nil end
    return math.floor(n)
end

--- The parts that move: both leaves of a double door, or the door itself
function WDoor.leaves(door)
    if door.doors then return door.doors end
    return { door }
end
local leaves = WDoor.leaves

local function prepare(data)
    data.id = tonumber(data.id)
    data.coords = toVec(data.coords)
    data.hash = toHash(data.hash)
    data.model = toHash(data.model)
    data.state = tonumber(data.state) == 0 and 0 or 1
    data.maxDistance = tonumber(data.maxDistance) or 2.0
    if type(data.doors) == 'table' and data.doors[1] and data.doors[2] then
        for i = 1, 2 do
            local leaf = data.doors[i]
            leaf.coords = toVec(leaf.coords)
            leaf.hash = toHash(leaf.hash)
            leaf.model = toHash(leaf.model)
        end
    else
        data.doors = nil
    end
    if not data.id or not data.coords then return nil end
    return data
end

--- The middle of the door's model in the world (the hinge is where the entity stands)
local function centreOf(entity)
    local min, max = GetModelDimensions(GetEntityModel(entity))
    return GetOffsetFromEntityInWorldCoords(entity, (min.x + max.x) / 2, (min.y + max.y) / 2, (min.z + max.z) / 2)
end

-- ════════════════════════════════════════════════════════════════════════════
-- The door system
-- ════════════════════════════════════════════════════════════════════════════

local function register(door)
    for _, leaf in ipairs(leaves(door)) do
        if leaf.hash then
            addToSystem(leaf.hash)
            setDoorState(leaf.hash, STATE_RESET)
            setDoorState(leaf.hash, door.state)
            if door.doorRate or not door.auto then
                DoorSystemSetAutomaticRate(leaf.hash, (door.doorRate or 10.0) + 0.0)
            end
            if door.holdOpen then holdOpen(leaf.hash, door.state == 0) end
        end
    end
end

--- A door that leaves the board goes back to the game, open
local function release(door)
    for _, leaf in ipairs(leaves(door)) do
        if leaf.hash then
            setDoorState(leaf.hash, STATE_RESET)
            setDoorState(leaf.hash, 0)
        end
        if leaf.entity then WDoor.EntityDoor[leaf.entity] = nil end
    end
end

--- The stores and banks the game keeps locked (Config.UnlockedDoors); a door on the board wins
local function openFixedDoors()
    local taken = {}
    for _, door in pairs(Doors) do
        for _, leaf in ipairs(leaves(door)) do
            if leaf.hash then taken[leaf.hash] = true end
        end
    end
    for _, hash in ipairs(Config.UnlockedDoors or {}) do
        hash = toHash(hash)
        if hash and not taken[hash] then
            addToSystem(hash)
            setDoorState(hash, STATE_RESET)
            setDoorState(hash, 0)
        end
    end
end

local function changed()
    TriggerEvent('w_doorlock:client:doorsChanged')
end

-- ════════════════════════════════════════════════════════════════════════════
-- The door sounds - played by the page at a volume that falls with the distance
-- ════════════════════════════════════════════════════════════════════════════

local function playSound(door, state)
    local base = tonumber(Config.SoundVolume) or 0.3
    if base <= 0 then return end
    local distance = #(GetEntityCoords(PlayerPedId()) - door.coords)
    if distance >= 20 then return end
    local volume = math.min(1.0, base / math.max(distance / 2, 0.05))
    local sound = (state == 0 and door.unlockSound) or door.lockSound or Config.DefaultSound
    if type(sound) ~= 'string' or sound == '' then return end
    SendNUIMessage({ action = 'dl:door-sound', sound = sound, volume = volume })
end

-- ════════════════════════════════════════════════════════════════════════════
-- What the server says
-- ════════════════════════════════════════════════════════════════════════════

RegisterNetEvent('w_doorlock:client:setState', function(id, state)
    local door = Doors[tonumber(id)]
    if not door then return end
    door.state = tonumber(state) == 0 and 0 or 1

    for _, leaf in ipairs(leaves(door)) do
        if leaf.hash then
            setDoorState(leaf.hash, door.state)
            if door.holdOpen then holdOpen(leaf.hash, door.state == 0) end
            -- a door locked while it stands open is shut, so the lock is heard on a closed door
            if door.state == 1 and not IsDoorClosed(leaf.hash) then forceShut(leaf.hash) end
        end
    end

    playSound(door, door.state)
    TriggerEvent('w_doorlock:client:stateChanged', door.id, door.state)
end)

RegisterNetEvent('w_doorlock:client:upsert', function(data)
    if type(data) ~= 'table' then return end
    local door = prepare(data)
    if not door then return end
    local old = Doors[door.id]
    if old then release(old) end
    Doors[door.id] = door
    register(door)
    changed()
end)

RegisterNetEvent('w_doorlock:client:remove', function(id)
    id = tonumber(id)
    local door = Doors[id]
    if not door then return end
    Doors[id] = nil
    release(door)
    openFixedDoors()
    changed()
end)

-- ════════════════════════════════════════════════════════════════════════════
-- Loading the doors
-- ════════════════════════════════════════════════════════════════════════════

local function load()
    local list
    for _ = 1, 10 do
        local ok, result = pcall(w.callback.await, 'w_doorlock:getDoors', false)
        if ok and type(result) == 'table' then list = result break end
        Wait(3000)
    end
    if not list then return w.print.warn('the doors could not be read from the server') end

    for id, door in pairs(Doors) do
        release(door)
        Doors[id] = nil
    end
    for _, data in ipairs(list) do
        local door = prepare(data)
        if door then
            Doors[door.id] = door
            register(door)
        end
    end
    openFixedDoors()
    WDoor.loaded = true
    changed()
end

--- After the character is picked the world around the player is new: every door is pushed again
local function reapply()
    if not WDoor.loaded then return end
    for _, door in pairs(Doors) do register(door) end
    openFixedDoors()
end

CreateThread(load)

for _, event in ipairs({ 'WCore:Client:OnPlayerLoaded', 'RSGCore:Client:OnPlayerLoaded', 'QBCore:Client:OnPlayerLoaded', 'vorp:SelectedCharacter' }) do
    RegisterNetEvent(event, function()
        SetTimeout(1000, reapply)
    end)
end

-- ════════════════════════════════════════════════════════════════════════════
-- Who is near: distances, entities, the closest door (every 500 ms)
-- ════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        local at = GetEntityCoords(PlayerPedId())
        local near = {}
        local closest

        for _, door in pairs(Doors) do
            door.distance = #(at - door.coords)

            if door.distance < 80 then
                for _, leaf in ipairs(leaves(door)) do
                    if leaf.hash and (not leaf.entity or not DoesEntityExist(leaf.entity)) then
                        local entity = GetEntityByDoorhash(leaf.hash, 0)
                        if entity and entity ~= 0 then
                            leaf.entity = entity
                            WDoor.EntityDoor[entity] = door.id
                            -- a single door is reached at its middle, not at its hinge
                            if not door.doors then door.coords = centreOf(entity) end
                        end
                    end
                end
                if door.distance < 20 then near[#near + 1] = door end
            else
                for _, leaf in ipairs(leaves(door)) do
                    if leaf.entity then
                        WDoor.EntityDoor[leaf.entity] = nil
                        leaf.entity = nil
                    end
                end
            end
        end

        for _, door in ipairs(near) do
            if door.distance <= door.maxDistance and (not closest or door.distance < closest.distance) then
                closest = door
            end
        end

        WDoor.Nearby = near
        WDoor.Closest = closest
        Wait(500)
    end
end)

-- ════════════════════════════════════════════════════════════════════════════
-- Zones, for the board's list (the map's region, in the player's language)
-- ════════════════════════════════════════════════════════════════════════════

local ZONES = {
    [2025841068] = 'bayou_nwa', [822658194] = 'big_valley', [1308232528] = 'bluewater_marsh',
    [-108848014] = 'cholla_springs', [1835499550] = 'cumberland', [426773653] = 'diez_coronas',
    [-2066240242] = 'gaptooth_ridge', [476637847] = 'great_plains', [-120156735] = 'grizzlies_east',
    [1645618177] = 'grizzlies_west', [-512529193] = 'guarma', [131399519] = 'heartlands',
    [892930832] = 'hennigans_stead', [-1319956120] = 'perdido', [1453836102] = 'punta_orgullo',
    [-2145992129] = 'rio_bravo', [178647645] = 'roanoke', [-864275692] = 'scarlett_meadows',
    [1684533001] = 'tall_trees',
}

function WDoor.zoneOf(coords)
    if not coords then return '' end
    local ok, zone = pcall(GetMapZoneAtCoords, coords.x, coords.y, coords.z, 10)
    local key = ok and ZONES[zone] or nil
    return key and locale('zone.' .. key) or ''
end

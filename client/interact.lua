-- ════════════════════════════════════════════════════════════════════════════
-- w_doorlock · client/interact.lua
-- The player at a door: the walk-up prompt (WDoorPrompt.at, client/walkup.lua) on every door in reach -
-- its title and its key follow the door's state and the player's language - the code note, the
-- lock pick, the key turning in the lock, and the client exports.
--
-- ★ One prompt record per NEARBY door only (WDoor.Nearby, 20 m): a server with hundreds of doors
--   never asks the library to weigh hundreds of records every frame.
-- ★ The library shows the closest record whose canInteract passes, hides them all while a page
--   holds the focus, and fires onComplete in a thread of its own.
-- ════════════════════════════════════════════════════════════════════════════
WDoor = WDoor or {}

local Prompt = Config.Prompt or {}
local KEY = tostring(Prompt.key or 'J'):upper()
local PICK_KEY = tostring(Prompt.pickKey or 'G'):upper()

local records = {}       -- [door id] = the WDoorPrompt.at record
local busy = false
local carryPick = { value = false, at = -60000, asking = false }

local function door(id) return WDoor.Doors[id] end

local function pickable(d)
    return d.lockpick == true and (d.state == 1 or Config.Lockpick.canLock == true)
end

-- ════════════════════════════════════════════════════════════════════════════
-- The prompt's texts
-- ════════════════════════════════════════════════════════════════════════════

local function relabel(id)
    local rec, d = records[id], door(id)
    if not rec or not d then return end
    rec.setTitle(locale(d.state == 1 and 'prompt.locked' or 'prompt.unlocked'))
    rec.setLabel(KEY, locale(d.state == 1 and 'prompt.unlock' or 'prompt.lock'))
    rec.setLabel(PICK_KEY, locale('prompt.pick'))
    rec.setVisible(PICK_KEY, pickable(d) and carryPick.value == true)
end

--- Does the player carry a pick? Asked of the server when a pickable door comes in reach, kept 10 s
local function checkPick(id)
    if carryPick.asking or GetGameTimer() - carryPick.at < 10000 then return relabel(id) end
    carryPick.asking = true
    CreateThread(function()
        local ok, has = pcall(w.callback.await, 'w_doorlock:hasPick', false)
        carryPick.value = ok and has == true
        carryPick.at = GetGameTimer()
        carryPick.asking = false
        relabel(id)
    end)
end

-- ════════════════════════════════════════════════════════════════════════════
-- The key turning in the lock (the previous w_doorlock's animation and prop)
-- ════════════════════════════════════════════════════════════════════════════

local KEY_DICT <const> = 'script_common@jail_cell@unlock@key'
local KEY_CLIP <const> = 'action'
local KEY_PROP <const> = 'P_KEY02X'
local KEY_BONE <const> = 'SKEL_R_Finger12'

local function keyTurn()
    if not Config.Animation then return end
    CreateThread(function()
        local ped = PlayerPedId()
        if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return end
        if not pcall(w.requestAnimDict, KEY_DICT, 2000) then return end

        local prop
        local okModel, model = pcall(w.requestModel, KEY_PROP, 2000)
        if okModel and model then
            local at = GetEntityCoords(ped)
            prop = CreateObject(model, at.x, at.y, at.z, false, false, false)
            AttachEntityToEntity(prop, ped, GetEntityBoneIndexByName(ped, KEY_BONE), 0.02, 0.012, -0.0085,
                0.024, -160.0, 200.0, true, true, false, true, 1, true)
            SetModelAsNoLongerNeeded(model)
        end

        TaskPlayAnim(ped, KEY_DICT, KEY_CLIP, 8.0, -8.0, 1500, 31, 0, false, false, false)
        RemoveAnimDict(KEY_DICT)
        Wait(1500)
        if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    end)
end

-- ════════════════════════════════════════════════════════════════════════════
-- Using a door
-- ════════════════════════════════════════════════════════════════════════════

--- The code note (the page); nil when the player backed out
function WDoor.askCode()
    return WDoor.Nui.ask('passcode', { action = 'dl:passcode' })
end

--- Lock or unlock a door the player stands at
local function useDoor(d)
    local target = d.state == 1 and 0 or 1
    local ok, reason = w.callback.await('w_doorlock:use', false, d.id, target)

    if ok == 'passcode' then
        local code = WDoor.askCode()
        if not code then return false end   -- the player backed out: nothing to say
        ok, reason = w.callback.await('w_doorlock:use', false, d.id, target, code)
    end

    if ok == true then
        keyTurn()
    elseif ok == false then
        WDoor.notify('notify.' .. tostring(reason or 'cannot_unlock'), 'error')
    end
    return ok == true
end

---@return boolean done
function WDoor.use(id)
    local d = door(id)
    if not d or busy or WDoor.Nui.surface then return false end
    busy = true
    -- ! whatever happens on the way (the library restarting mid-call), the player is never left
    --   unable to touch a door again
    local ok, done = pcall(useDoor, d)
    busy = false
    if not ok then w.print.warn('using door %s: %s', tostring(id), tostring(done)) return false end
    return done
end

-- ════════════════════════════════════════════════════════════════════════════
-- Picking a lock
-- ════════════════════════════════════════════════════════════════════════════

local PICK_DICT <const> = 'script_common@jail_cell@unlock@key'
local PICK_CLIP <const> = 'action'

WDoor.picking = false

local function pickDoor(d)
    local token, rounds = w.callback.await('w_doorlock:pickStart', false, d.id)
    if not token then
        if token == false then WDoor.notify('notify.' .. tostring(rounds or 'cannot_pick'), 'error') end
        return false
    end

    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, d.coords.x, d.coords.y, d.coords.z, 1000)
    Wait(600)
    if pcall(w.requestAnimDict, PICK_DICT, 2000) then
        TaskPlayAnim(ped, PICK_DICT, PICK_CLIP, 3.0, -3.0, -1, 31, 0, false, false, false)
    end

    -- the page judges each press against the server (client/nui.lua 'dl:pickPress'); it is handed the
    -- token so its reports belong to this attempt, and the server never hears a verdict from the page
    WDoor.Nui.pickToken = token
    local result = WDoor.Nui.ask('pick', { action = 'dl:pick', rounds = rounds })
    WDoor.Nui.pickToken = nil

    StopAnimTask(ped, PICK_DICT, PICK_CLIP, 1.0)
    RemoveAnimDict(PICK_DICT)

    local given = result ~= 'success' and result ~= 'fail'
    local done, broke = w.callback.await('w_doorlock:pickFinish', false, token, given)

    if broke then
        WDoor.notify('notify.lockpick_broke', 'error')
        carryPick.at = -60000   -- ask again: that may have been the last one
    elseif not given and not done then
        WDoor.notify('notify.pick_failed', 'error')
    end
    return done == true
end

---@return boolean done
function WDoor.pick(id)
    local d = door(id)
    if not d or busy or WDoor.Nui.surface then return false end
    if not pickable(d) then return false end
    busy = true
    WDoor.picking = true
    local ok, done = pcall(pickDoor, d)
    WDoor.picking = false
    busy = false
    if not ok then
        w.print.warn('picking door %s: %s', tostring(id), tostring(done))
        if WDoor.Nui.surface == 'pick' then WDoor.Nui.answer('pick', 'cancel') end
        return false
    end
    return done
end

-- ════════════════════════════════════════════════════════════════════════════
-- The prompt records: one per door within reach
-- ════════════════════════════════════════════════════════════════════════════

local function canInteract()
    return not busy and not WDoor.Nui.surface and not WDoor.selecting
end

local function create(d)
    local id = d.id
    local rec = WDoorPrompt.at({
        coords = d.coords,
        distance = d.maxDistance,
        title = locale(d.state == 1 and 'prompt.locked' or 'prompt.unlocked'),
        position = Prompt.position,
        prompts = {
            {
                key = KEY,
                label = locale(d.state == 1 and 'prompt.unlock' or 'prompt.lock'),
                hold = Prompt.hold,
                onComplete = function() WDoor.use(id) end,
            },
            {
                key = PICK_KEY,
                label = locale('prompt.pick'),
                hold = false,
                visible = false,
                onComplete = function() WDoor.pick(id) end,
            },
        },
        canInteract = canInteract,
        onEnter = function()
            local current = door(id)
            if current and current.lockpick then checkPick(id) end
        end,
    })
    records[id] = rec
    if d.lockpick then relabel(id) end
end

local function drop(id)
    local rec = records[id]
    if not rec then return end
    records[id] = nil
    pcall(rec.remove)
end

local function dropAll()
    for id in pairs(records) do drop(id) end
end

-- Every 500 ms: a record for every door that came in reach, none for a door that left
CreateThread(function()
    while true do
        local wanted = {}
        if not WDoor.selecting then
            for _, d in ipairs(WDoor.Nearby) do
                if not d.hideUi and d.coords then
                    wanted[d.id] = true
                    local rec = records[d.id]
                    if rec then
                        rec.setCoords(d.coords)   -- the middle of the door, once its entity is found
                    else
                        create(d)
                    end
                end
            end
        end
        for id in pairs(records) do
            if not wanted[id] then drop(id) end
        end
        Wait(500)
    end
end)

AddEventHandler('w_doorlock:client:stateChanged', function(id)
    relabel(id)
end)

-- A door saved or deleted on the board: its record is made again from the new settings
AddEventHandler('w_doorlock:client:doorsChanged', dropAll)

-- The player switched his language
AddEventHandler('w_doorlock:client:relabel', function()
    for id in pairs(records) do relabel(id) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then dropAll() end
end)

-- ════════════════════════════════════════════════════════════════════════════
-- Exports - ox_doorlock's names
-- ════════════════════════════════════════════════════════════════════════════

local function closestId()
    return WDoor.Closest and WDoor.Closest.id or nil
end

exports('useClosestDoor', function()
    local id = closestId()
    if not id then return false end
    CreateThread(function() WDoor.use(id) end)
    return true
end)

exports('pickClosestDoor', function()
    local id = closestId()
    if not id then return false end
    CreateThread(function() WDoor.pick(id) end)
    return true
end)

exports('getClosestDoor', function() return WDoor.Closest end)
exports('getClosestDoorId', closestId)
exports('getDoorIdFromEntity', function(entity) return WDoor.EntityDoor[entity] end)

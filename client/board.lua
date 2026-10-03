-- ════════════════════════════════════════════════════════════════════════════
-- w_doorlock · client/board.lua
-- The staff's board (/doorlock): every door with its settings, a new door chosen in the world,
-- edit, copy and paste, teleport, delete. The server checks the permission on every call; this
-- file only carries the page's requests and does what the page cannot - look into the world.
--
-- A new door: the page sends its settings, the board steps aside, and the staff member looks at
-- the door (both leaves of a double door, one after the other): E takes the door under the
-- crosshair, Backspace takes back the last leaf or gives up. Then the board comes back.
-- ════════════════════════════════════════════════════════════════════════════
WDoor = WDoor or {}
WDoor.selecting = false

local function withZones(list)
    for _, d in ipairs(list) do d.zone = WDoor.zoneOf(d.coords) end
    return list
end

local function openBoard(focus)
    if WDoor.Nui.surface or WDoor.selecting then return end
    local ok, list = pcall(w.callback.await, 'w_doorlock:admin:doors', false)
    if not ok or type(list) ~= 'table' then
        return WDoor.notify('notify.no_permission', 'error')
    end
    WDoor.Nui.show('board', {
        action = 'dl:board',
        doors = withZones(list),
        sounds = Config.DoorSounds or {},
        defaultSound = Config.DefaultSound,
        focus = focus,
    })
end

RegisterNetEvent('w_doorlock:client:openBoard', function(closest)
    openBoard(closest and WDoor.Closest and WDoor.Closest.id or nil)
end)

--- The board comes back as the staff member left it (the page kept its state while hidden)
local function resumeBoard(extra)
    local message = { action = 'dl:board:resume' }
    for k, v in pairs(extra or {}) do message[k] = v end
    WDoor.Nui.show('board', message)
end

-- ════════════════════════════════════════════════════════════════════════════
-- Choosing a door in the world
-- ════════════════════════════════════════════════════════════════════════════

local DRAW_MARKER <const> = 0x2A32FAA57B937173
local MARKER_BOX    <const> = 0x6EB7D3BB
local MARKER_SPHERE <const> = 0x50638AB9

local function marker(kind, at, size, r, g, b, a)
    Citizen.InvokeNative(DRAW_MARKER, kind, at.x, at.y, at.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        size, size, size, r, g, b, a, false, false, 0, false)
end

--- The door system's hash of an entity, when the entity is a door the game knows
local function doorHashOf(entity)
    local ok, active = pcall(DoorSystemGetActive)
    if not ok or type(active) ~= 'table' then return nil end
    for _, pair in ipairs(active) do
        if pair[2] == entity then return pair[1] end
    end
    return nil
end

local function centreOf(entity)
    local min, max = GetModelDimensions(GetEntityModel(entity))
    return GetOffsetFromEntityInWorldCoords(entity, (min.x + max.x) / 2, (min.y + max.y) / 2, (min.z + max.z) / 2)
end

---@param count 1 | 2 the leaves to take
---@return table[] | nil leaves { entity, hash }; nil when the staff member gave up
local function chooseDoors(count)
    WDoor.selecting = true
    local picked = {}
    local result
    local pressed = { pick = false, back = false }

    local hints = w.prompt.createGroup(locale(count == 2 and 'select.title_double' or 'select.title'),
        WDoor.Nui.lang() == 'ar' and 'bottom-left' or 'bottom-right')
    hints.addPrompt('E', locale('select.pick'), false)
    hints.addPrompt('BACK', locale('select.back'), false)
    hints.display()

    local listeners = {
        w.rawKeys.listen('E', function(down) if down then pressed.pick = true end end),
        w.rawKeys.listen('BACK', function(down) if down then pressed.back = true end end),
    }

    local function taken(entity)
        for _, leaf in ipairs(picked) do
            if leaf.entity == entity then return true end
        end
        return false
    end

    while not result do
        DisablePlayerFiring(PlayerId(), true)

        local hit, entity, endCoords = w.raycast.fromCamera(1 | 16, 4, 25.0)

        for _, leaf in ipairs(picked) do
            if DoesEntityExist(leaf.entity) then marker(MARKER_BOX, centreOf(leaf.entity), 0.6, 203, 1, 1, 140) end
        end

        local hash
        if hit and entity and entity ~= 0 and GetEntityType(entity) == 3
            and not WDoor.EntityDoor[entity] and not taken(entity) then
            hash = doorHashOf(entity)
            if hash then marker(MARKER_BOX, centreOf(entity), 0.6, 242, 242, 242, 110) end
        end
        if hit and endCoords then marker(MARKER_SPHERE, endCoords, 0.12, 242, 242, 242, 160) end

        if pressed.pick then
            pressed.pick = false
            if hash then
                picked[#picked + 1] = { entity = entity, hash = hash }
                WDoorSound.play('select')
                if #picked >= count then result = 'done' end
            else
                WDoorSound.play('locked')
            end
        end

        if pressed.back then
            pressed.back = false
            WDoorSound.play('back')
            if #picked > 0 then table.remove(picked) else result = 'cancel' end
        end
    end

    for _, id in ipairs(listeners) do pcall(w.rawKeys.removeListener, id) end
    pcall(hints.hide)
    pcall(hints.delete)
    WDoor.selecting = false

    if result ~= 'done' then return nil end
    return picked
end

local function placeOf(leaf)
    local at = GetEntityCoords(leaf.entity)
    return {
        hash = leaf.hash,
        model = GetEntityModel(leaf.entity),
        coords = { x = at.x, y = at.y, z = at.z },
        heading = math.floor(GetEntityHeading(leaf.entity) + 0.5),
    }
end

--- A new door: chosen in the world, then sent with the settings the page filled
local function addDoor(form)
    WDoor.Nui.hide('board', true)

    local leaves = chooseDoors(form.double and 2 or 1)
    if not leaves then
        return resumeBoard()
    end

    if form.double then
        form.doors = { placeOf(leaves[1]), placeOf(leaves[2]) }
    else
        local place = placeOf(leaves[1])
        form.hash, form.model, form.coords, form.heading = place.hash, place.model, place.coords, place.heading
    end

    local ok, door = w.callback.await('w_doorlock:admin:save', false, nil, form)
    if ok ~= true then
        WDoor.notify('notify.' .. tostring(door or 'save_failed'), 'error')
        return resumeBoard()
    end

    WDoor.notify('notify.door_added', 'success')
    door.zone = WDoor.zoneOf(door.coords)
    resumeBoard({ saved = door })
end

-- ════════════════════════════════════════════════════════════════════════════
-- The page's calls
-- ════════════════════════════════════════════════════════════════════════════

RegisterNUICallback('dl:board:close', function(_, cb)
    cb({ ok = true })
    WDoor.Nui.hide('board')
end)

RegisterNUICallback('dl:board:save', function(data, cb)
    local form = type(data) == 'table' and data.form
    if type(form) ~= 'table' then return cb({ ok = false, reason = 'invalid' }) end

    local id = tonumber(data.id)
    if not id then
        cb({ ok = true, choosing = true })
        CreateThread(function() addDoor(form) end)
        return
    end

    local ok, door = w.callback.await('w_doorlock:admin:save', false, id, form)
    if ok ~= true then
        return cb({ ok = false, reason = door or 'save_failed' })
    end
    door.zone = WDoor.zoneOf(door.coords)
    cb({ ok = true, door = door })
end)

RegisterNUICallback('dl:board:delete', function(data, cb)
    local ok, reason = w.callback.await('w_doorlock:admin:delete', false, tonumber(data and data.id))
    cb({ ok = ok == true, reason = reason })
end)

RegisterNUICallback('dl:board:teleport', function(data, cb)
    cb({ ok = true })
    local door = WDoor.Doors[tonumber(data and data.id)]
    local at = door and door.coords
    if not at then return end
    WDoor.Nui.hide('board', true)
    SetEntityCoords(PlayerPedId(), at.x, at.y, at.z, false, false, false, false)
end)

RegisterNUICallback('dl:board:notify', function(data, cb)
    cb({ ok = true })
    if data and type(data.key) == 'string' then WDoor.notify(data.key, data.style or 'success') end
end)

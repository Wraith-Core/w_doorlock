-- ════════════════════════════════════════════════════════════════════════════
-- w_doorlock · client/board.lua
-- The staff's board (/doorlock): every door with its settings, a new door chosen in the world,
-- edit, copy and paste, teleport, delete. The server checks the permission on every call; this
-- file only carries the page's requests and does what the page cannot - look into the world.
--
-- A new door: the page sends its settings, the board steps aside, and the staff member looks at
-- the door (both leaves of a double door, one after the other): J takes the door under the
-- crosshair, Backspace takes back the last leaf or gives up. Then the board comes back.
--
-- The notebook board (2026-11-12, owner: the builders' look and idea on every board): each door is
-- said in words with its place and distance (client/words.lua), and TAB takes the staff member into
-- the world (w_lib 4.5.0 lib.worldEdit): a pin over every door near him, J on a door he looks at
-- adds it (or both leaves of a double door) to a new door on the board, J on a pin opens it on the
-- board or locks / unlocks it, Ctrl+Z takes the last lock back. On an older w_lib the board works
-- as before (no TAB).
-- ════════════════════════════════════════════════════════════════════════════
WDoor = WDoor or {}
WDoor.selecting = false

-- { key, name }: the job / gang / item a refused save named, for the page's notice that follows
local refusedName = nil

-- leaves chosen in the world for the next new door (J on a door: «أضف هذا الباب»); nil = choose on save
local pendingLeaves = nil
-- the names the board shows instead of keys (jobs, gangs, grades, items), asked once
local names = nil
-- the world mode while the board is open (lib.worldEdit), the door the board shows, the locks to undo
local edit = nil
local current = nil
local undo = {}

local function withZones(list)
    for _, d in ipairs(list) do
        d.zone = WDoor.zoneOf(d.coords)
        d.label = WDoor.label(d.name)
        local spot = WDoor.where(d.coords)
        d.where, d.meters = spot.text, spot.meters
    end
    return list
end

local function worldReady()
    local ok, we = pcall(function() return w.worldEdit end)
    return ok and type(we) == 'table' and type(we.start) == 'function'
end

local startWorld, stopWorld

local function openBoard(focus, fresh)
    if WDoor.Nui.surface or WDoor.selecting then return end
    local ok, list = pcall(w.callback.await, 'w_doorlock:admin:doors', false)
    if not ok or type(list) ~= 'table' then
        return WDoor.notify('notify.no_permission', 'error')
    end
    -- 2.2.0: the stores a door may be linked to (none when w_store is not running)
    local okStores, stores = pcall(w.callback.await, 'w_doorlock:admin:stores', false)
    if not names then
        local okNames, got = pcall(w.callback.await, 'w_doorlock:admin:names', false)
        if okNames and type(got) == 'table' then names = got end
    end
    if not fresh then pendingLeaves = nil end
    current = focus
    WDoor.Nui.show('board', {
        action = 'dl:board',
        doors = withZones(list),
        stores = okStores and type(stores) == 'table' and stores or {},
        sounds = Config.DoorSounds or {},
        defaultSound = Config.DefaultSound,
        focus = focus,
        names = names or { groups = {}, items = {} },
        world = worldReady(),
        fresh = fresh,
    })
    startWorld()
end

RegisterNetEvent('w_doorlock:client:openBoard', function(closest)
    openBoard(closest and WDoor.Closest and WDoor.Closest.id or nil)
end)

--- The board comes back as the staff member left it (the page kept its state while hidden)
local function resumeBoard(extra)
    local message = { action = 'dl:board:resume' }
    for k, v in pairs(extra or {}) do message[k] = v end
    WDoor.Nui.show('board', message)
    if edit then pcall(function() edit:setWorld(false) end) end
end

-- ════════════════════════════════════════════════════════════════════════════
-- Choosing a door in the world
-- ════════════════════════════════════════════════════════════════════════════

-- 2.1.1 (the owner 2026-10-23): the game's glitter instead of DrawMarker (w_lib 4.1.0 w.glow.frame, look 2): a door
-- is a big spot at its centre (a picked one in the theme's red), the aim a small one
local RED <const> = { 203, 1, 1 }

local function marker(key, at, scale, color)
    w.glow.frame(key, 'point', at, { look = 2, scale = scale, color = color })
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
---@param already? table[] leaves taken before (J on a door in the world mode)
---@return table[] | nil leaves { entity, hash }; nil when the staff member gave up
local function chooseDoors(count, already)
    WDoor.selecting = true
    local picked = {}
    for _, leaf in ipairs(already or {}) do picked[#picked + 1] = leaf end
    local result
    local pressed = { pick = false, back = false }

    local hints = w.prompt.createGroup(locale(count == 2 and 'select.title_double' or 'select.title'),
        WDoor.Nui.lang() == 'ar' and 'bottom-left' or 'bottom-right')
    hints.addPrompt('J', locale('select.pick'), false)
    hints.addPrompt('BACK', locale('select.back'), false)
    hints.display()

    local listeners = {
        w.rawKeys.listen('J', function(down) if down then pressed.pick = true end end),
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
            if DoesEntityExist(leaf.entity) then marker('picked:' .. leaf.entity, centreOf(leaf.entity), 1.6, RED) end
        end

        local hash
        if hit and entity and entity ~= 0 and GetEntityType(entity) == 3
            and not WDoor.EntityDoor[entity] and not taken(entity) then
            hash = doorHashOf(entity)
            if hash then marker('door', centreOf(entity), 1.6) end
        end
        if hit and endCoords then marker('aim', endCoords, 0.5) end

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

    local want = form.double and 2 or 1
    local leaves = pendingLeaves
    pendingLeaves = nil
    if not leaves or #leaves ~= want then
        leaves = chooseDoors(want, leaves and #leaves < want and leaves or nil)
    end
    if not leaves then
        return resumeBoard()
    end

    if form.double then
        form.doors = { placeOf(leaves[1]), placeOf(leaves[2]) }
    else
        local place = placeOf(leaves[1])
        form.hash, form.model, form.coords, form.heading = place.hash, place.model, place.coords, place.heading
    end

    local ok, door, name = w.callback.await('w_doorlock:admin:save', false, nil, form)
    if ok ~= true then
        WDoor.notify('notify.' .. tostring(door or 'save_failed'), 'error', name)
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
    stopWorld()
end)

--- The page shows a door (or the list): its pin is the red one
RegisterNUICallback('dl:board:current', function(data, cb)
    cb({ ok = true })
    current = tonumber(data and data.id)
end)

--- TAB on the board: the board steps aside (kept as it is) and the staff member walks the world
RegisterNUICallback('dl:board:world', function(_, cb)
    cb({ ok = true })
    if not edit then return end
    WDoor.Nui.hide('board', true)
    pcall(function() edit:setWorld(true) end)
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

    local ok, door, name = w.callback.await('w_doorlock:admin:save', false, id, form)
    if ok ~= true then
        -- the page names the refusal by its key alone: the unknown name waits here for that notice
        refusedName = { key = 'notify.' .. tostring(door or 'save_failed'), name = name }
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
    stopWorld()
    SetEntityCoords(PlayerPedId(), at.x, at.y, at.z, false, false, false, false)
end)

RegisterNUICallback('dl:board:notify', function(data, cb)
    cb({ ok = true })
    if data and type(data.key) == 'string' then
        local held = refusedName
        refusedName = nil
        WDoor.notify(data.key, data.style or 'success', held and held.key == data.key and held.name or nil)
    end
end)

-- ════════════════════════════════════════════════════════════════════════════
-- The world mode (TAB on the board; w_lib 4.5.0 lib.worldEdit)
-- ════════════════════════════════════════════════════════════════════════════

local PIN_RANGE <const> = 60.0
local PIN_MAX <const> = 60

local function stateWord(door)
    return locale(door.state == 1 and 'board.locked' or 'board.unlocked')
end

--- the doors near the staff member, as pins (the one the board shows in red)
local function nearItems()
    local at = GetEntityCoords(PlayerPedId())
    local near = {}
    for id, door in pairs(WDoor.Doors or {}) do
        local c = door.coords
        if c then
            local d = #(at - vector3(c.x, c.y, c.z))
            if d <= PIN_RANGE then near[#near + 1] = { door = door, d = d, id = id } end
        end
    end
    table.sort(near, function(a, b) return a.d < b.d end)
    local items = {}
    for i = 1, math.min(#near, PIN_MAX) do
        local door = near[i].door
        items[#items + 1] = {
            id = tostring(door.id or near[i].id),
            label = ('%s · %s'):format(WDoor.label(door.name), stateWord(door)),
            x = door.coords.x, y = door.coords.y, z = door.coords.z,
            lift = 2.4, kind = 'point', move = false, turn = false,
            state = (current and tonumber(door.id) == current) and 'cur' or nil,
        }
    end
    return items
end

--- lock / unlock a door from the world (kept for Ctrl+Z)
local function setLock(door, locked, keep)
    local ok, done = pcall(w.callback.await, 'w_doorlock:admin:lock', false, door.id, locked)
    if not ok or done ~= true then
        WDoorSound.play('locked')
        return WDoor.notify('notify.save_failed', 'error')
    end
    if keep then undo[#undo + 1] = { id = door.id, locked = not locked } end
    WDoorSound.play('select')
    WDoor.notify(locked and 'notify.locked_now' or 'notify.unlocked_now', 'success')
end

--- the board on a new door whose leaves were taken in the world
local function newFromWorld(leaves, double)
    if edit then pcall(function() edit:setWorld(false) end) end
    pendingLeaves = leaves
    local first = leaves[1] and leaves[1].entity
    if not first then
        -- «باب جديد من اللوحة»: nothing taken yet, the door is chosen after «اختيار الباب» as before
        pendingLeaves = nil
        return openBoard(nil, { double = false, blank = true })
    end
    local spot = DoesEntityExist(first) and WDoor.where(GetEntityCoords(first)) or { text = '' }
    openBoard(nil, { double = double, where = spot.text })
end

local function aimedDoor()
    local hit, entity = w.raycast.fromCamera(1 | 16, 4, 25.0)
    if not hit or not entity or entity == 0 or GetEntityType(entity) ~= 3 then return nil end
    local known = WDoor.EntityDoor[entity]
    if known then return { known = WDoor.Doors[known] } end
    local hash = doorHashOf(entity)
    if hash then return { entity = entity, hash = hash } end
    return nil
end

local function doorRows(door)
    return {
        { title = locale('world.open'), description = locale('world.open_d'), icon = 'lock', onSelect = function()
            if edit then pcall(function() edit:setWorld(false) end) end
            openBoard(door.id)
        end },
        { title = locale(door.state == 1 and 'world.unlock' or 'world.lock'), description = locale('world.lock_d'),
          icon = door.state == 1 and 'unlock' or 'lock', onSelect = function()
            CreateThread(function() setLock(door, door.state ~= 1, true) end)
        end },
    }
end

local function groundRows()
    local aim = aimedDoor()
    if aim and aim.known then return doorRows(aim.known) end
    local rows = {}
    if aim then
        local spot = WDoor.where(GetEntityCoords(aim.entity))
        rows[#rows + 1] = { title = locale('world.add'), description = locale('world.add_d', spot.text), icon = 'lock',
            onSelect = function() newFromWorld({ { entity = aim.entity, hash = aim.hash } }, false) end }
        rows[#rows + 1] = { title = locale('world.add_double'), description = locale('world.add_double_d'), icon = 'lock',
            onSelect = function()
                CreateThread(function()
                    if edit then pcall(function() edit:setWorld(false) end) end
                    local leaves = chooseDoors(2, { { entity = aim.entity, hash = aim.hash } })
                    if leaves then
                        newFromWorld(leaves, true)
                    elseif edit then
                        pcall(function() edit:setWorld(true) end)
                    end
                end)
            end }
    else
        rows[#rows + 1] = { title = locale('world.look'), description = locale('world.look_d'), disabled = true }
    end
    rows[#rows + 1] = { title = locale('world.new'), description = locale('world.new_d'), onSelect = function()
        newFromWorld({}, false)
    end }
    return rows
end

startWorld = function()
    if edit or not worldReady() then return end
    local ok, started = pcall(w.worldEdit.start, {
        key = 'doorlock',
        title = locale('world.title'),
        items = nearItems(),
        ground = function() return groundRows() end,
        pinMenu = function(item)
            local door = WDoor.Doors[tonumber(item.id)]
            return door and doorRows(door) or {}
        end,
        onUndo = function()
            local last = table.remove(undo)
            local door = last and WDoor.Doors[last.id]
            if not door then return WDoor.notify('world.undo_none', 'info') end
            CreateThread(function() setLock(door, last.locked, false) end)
        end,
        onBoard = function() resumeBoard() end,
        onStop = function() edit = nil end,
        range = PIN_RANGE,
        near = 30.0,
    })
    if not ok or type(started) ~= 'table' then return end
    edit = started
    local mine = edit
    CreateThread(function()
        while edit == mine do
            Wait(1000)
            if edit ~= mine then break end
            pcall(function() mine:setItems(nearItems()) end)
        end
    end)
end

stopWorld = function()
    local was = edit
    edit = nil
    undo = {}
    pendingLeaves = nil
    if was then pcall(function() was:stop() end) end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then stopWorld() end
end)

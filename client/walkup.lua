-- ════════════════════════════════════════════════════════════════════════════
-- w_doorlock · client/walkup.lua
-- The walk-up prompt on a door: WDoorPrompt.at(opts) is the library's w.prompt.at where the
-- library has one (w_lib 4.x, the Wraith Core), and the same record built here on
-- w.prompt.createGroup where it does not (w_lib 3.39, MajestyRP) - one shape for interact.lua
-- on both hosts.
--
--   local rec = WDoorPrompt.at({
--     coords = vector3(x, y, z), distance = 2.0, title = 'Door' | false, position = 'center-left',
--     prompts = { { key = 'E', label = 'Unlock', hold = false | true | 1500, visible = true,
--                   onComplete = function(rec) end } },
--     canInteract = function() return true end,   -- checked every frame
--     onEnter = function(rec) end, onExit = function(rec) end,
--   })
--   rec.remove()  rec.setTitle(t)  rec.setLabel(key, label)  rec.setVisible(key, bool)  rec.setCoords(c)
--
-- ★ Only what the doors use: a record at coords, its title, its keys' labels and visibility,
--   canInteract, onEnter / onExit, onComplete, setCoords, remove.
-- ★ The keys fire through the library's own completion event (w_lib:promptCompleted, sent by its
--   prompt bridge for the group on screen), so nothing here polls controls.
-- ★ Every frame the closest record whose canInteract passes is shown, the others hide; none while
--   a page holds the focus. A group another script put on screen over ours is left alone 500 ms.
-- ════════════════════════════════════════════════════════════════════════════
WDoorPrompt = {}

local records, order, nextId = {}, {}, 0
local shown = nil
local looping = false

local function keyOf(key)
    return tostring(key or 'E'):upper()
end

local function holdOf(hold)
    if hold == true then return 1000 end
    local n = tonumber(hold)
    if n and n > 0 then return n end
    return false
end

local function toVector(coords)
    local t = type(coords)
    if t == 'vector3' then return coords end
    if t == 'vector4' then return vector3(coords.x, coords.y, coords.z) end
    if t == 'table' then
        local x, y, z = coords.x or coords[1], coords.y or coords[2], coords.z or coords[3]
        if x and y then return vector3(x + 0.0, y + 0.0, (z or 0.0) + 0.0) end
    end
    return nil
end

-- ════════════════════════════════════════════════════════════════════════════
-- The group on screen
-- ════════════════════════════════════════════════════════════════════════════

local function hide(rec)
    if rec.group then pcall(rec.group.hide) end
    if rec.shown then
        rec.shown = false
        if shown == rec then shown = nil end
        if rec.onExit then pcall(rec.onExit, rec) end
    end
end

local function build(rec)
    if rec.group then pcall(rec.group.delete) rec.group = nil end
    local group = w.prompt.createGroup(rec.title or false, rec.position or 'bottom-right')
    rec.group, rec.groupId = group, group.id
    for _, row in ipairs(rec.prompts) do
        local key = keyOf(row.key)
        group.addPrompt(key, row.label or '', holdOf(row.hold))
        if row.visible == false then group.setVisible(key, false) end
    end
end

local function show(rec)
    if not rec.group then build(rec) end
    rec.group.display()
    if not rec.shown then
        rec.shown = true
        shown = rec
        if rec.onEnter then pcall(rec.onEnter, rec) end
    end
end

--- One pass: the closest record within reach that may be used wins; true while a door is close
local function tick()
    if IsNuiFocused() then
        if shown then hide(shown) end
        return true
    end

    local at = GetEntityCoords(PlayerPedId())
    local winner, winnerDist, near = nil, nil, false

    for i = 1, #order do
        local rec = records[order[i]]
        if rec and rec.coords and #rec.prompts > 0 then
            local d = #(rec.coords - at)
            rec.inside = d <= rec.distance
            if d <= rec.distance + 1.5 then near = true end
            if rec.inside and (not winnerDist or d < winnerDist) then
                local ok, allowed = true, true
                if rec.canInteract then ok, allowed = pcall(rec.canInteract, rec) end
                if ok and allowed ~= false then winner, winnerDist = rec, d end
            end
        end
    end

    if winner then
        if shown and shown ~= winner then hide(shown) end
        if winner.shown then
            if not winner.group.isVisible() then
                -- another script's group took the screen (a menu, the wheel): step back, retry shortly
                hide(winner)
                winner.displacedUntil = GetGameTimer() + 500
            end
        elseif not winner.displacedUntil or GetGameTimer() > winner.displacedUntil then
            show(winner)
        end
    elseif shown then
        hide(shown)
    end

    return near
end

local function ensureLoop()
    if looping then return end
    looping = true
    CreateThread(function()
        while next(records) do
            local ok, near = pcall(tick)
            if not ok then w.print.warn('door prompt: %s', tostring(near)) end
            Wait(ok and near and 0 or 250)
        end
        looping = false
    end)
end

AddEventHandler('w_lib:promptCompleted', function(groupId, key)
    local rec = shown
    if not rec or rec.groupId ~= groupId then return end
    key = keyOf(key)
    for _, row in ipairs(rec.prompts) do
        if keyOf(row.key) == key and row.visible ~= false then
            if row.onComplete then
                CreateThread(function()
                    local ok, err = pcall(row.onComplete, rec)
                    if not ok then w.print.warn('door prompt %s: %s', key, tostring(err)) end
                end)
            end
            return
        end
    end
end)

-- ════════════════════════════════════════════════════════════════════════════
-- The record
-- ════════════════════════════════════════════════════════════════════════════

local function create(opts)
    nextId = nextId + 1

    local prompts = {}
    for i, r in ipairs(opts.prompts or {}) do
        prompts[i] = { key = r.key, label = r.label, hold = r.hold, visible = r.visible, onComplete = r.onComplete }
    end

    local rec = {
        id = nextId,
        coords = toVector(opts.coords),
        distance = tonumber(opts.distance) or 2.0,
        title = opts.title == nil and false or opts.title,
        position = opts.position,
        prompts = prompts,
        canInteract = opts.canInteract,
        onEnter = opts.onEnter,
        onExit = opts.onExit,
        shown = false,
        inside = false,
    }

    local function row(key)
        key = keyOf(key)
        for _, r in ipairs(rec.prompts) do
            if keyOf(r.key) == key then return r end
        end
    end

    function rec.remove()
        hide(rec)
        if rec.group then pcall(rec.group.delete) rec.group = nil end
        records[rec.id] = nil
        for i = #order, 1, -1 do
            if order[i] == rec.id then table.remove(order, i) end
        end
    end

    function rec.setTitle(title)
        rec.title = title == nil and false or title
        if rec.group then rec.group.setTitle(rec.title or '') end
    end

    function rec.setLabel(key, label)
        local r = row(key)
        if not r then return false end
        r.label = label
        if rec.group then rec.group.setLabel(keyOf(key), label or '') end
        return true
    end

    function rec.setVisible(key, visible)
        local r = row(key)
        if not r then return false end
        r.visible = visible ~= false
        if rec.group then rec.group.setVisible(keyOf(key), r.visible) end
        return true
    end

    function rec.setCoords(coords)
        rec.coords = toVector(coords) or rec.coords
    end

    function rec.isShown()
        return rec.shown == true
    end

    records[rec.id] = rec
    order[#order + 1] = rec.id
    ensureLoop()
    return rec
end

-- ════════════════════════════════════════════════════════════════════════════
-- The one entry point
-- ════════════════════════════════════════════════════════════════════════════

local libraryAt   -- the library's w.prompt.at, false when it has none (asked once)

---@param opts table (see the header of this file)
---@return table rec
function WDoorPrompt.at(opts)
    if libraryAt == nil then
        local ok, fn = pcall(function() return w.prompt.at end)
        libraryAt = ok and type(fn) == 'function' and fn or false
    end
    if libraryAt then return libraryAt(opts) end
    return create(opts)
end

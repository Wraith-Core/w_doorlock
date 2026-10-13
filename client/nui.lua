-- ════════════════════════════════════════════════════════════════════════════
-- w_doorlock · client/nui.lua
-- The page: one frame, three surfaces, one at a time -
--
--   board      the staff's board of doors (client/board.lua)    cursor + keyboard
--   passcode   the paper note that asks for a door's code       cursor + keyboard
--   pick       the lock pick's skill check                       keyboard only
--
-- and, open or closed, the door sounds played in the world. Every text the page shows comes from
-- here (locales/{ar,en}.json through w_lib): the page carries no dictionary of its own.
--
-- The 'Select' / 'Back' buttons are not drawn by the page: they are the library's prompt group
-- (w.prompt.createGroup), shown in the corner the page leaves free - as on the pause menu.
-- ════════════════════════════════════════════════════════════════════════════
WDoor = WDoor or {}

local Nui = { surface = nil, pickToken = nil }   -- pickToken: the attempt a page's presses belong to
WDoor.Nui = Nui

local pending = nil      -- { surface, promise } while a passcode note or a pick waits for the page
local effectOn = false

-- ════════════════════════════════════════════════════════════════════════════
-- The language
-- ════════════════════════════════════════════════════════════════════════════

--- The language the library states, restricted to the two the server runs in
---@return 'ar' | 'en'
function Nui.lang()
    local ok, key = pcall(w.getLocaleKey)
    return (ok and key == 'ar') and 'ar' or 'en'
end

local function strings()
    local out = {}
    for k, v in pairs(w.getLocales()) do out[k] = v end
    return out
end

function Nui.localePayload()
    local key = Nui.lang()
    return { action = 'dl:locale', locale = key, dir = key == 'ar' and 'rtl' or 'ltr', strings = strings() }
end

-- ════════════════════════════════════════════════════════════════════════════
-- The key hints (the library's prompt group)
-- ════════════════════════════════════════════════════════════════════════════

local HINTS = {
    board    = { { 'RETURN', 'hint.select' }, { 'BACK', 'hint.back' } },
    passcode = { { 'RETURN', 'hint.confirm' }, { 'BACK', 'hint.cancel' } },
    pick     = { { 'E', 'hint.pick' }, { 'BACK', 'hint.give_up' } },
}

local hints
local hintsFor

local function hideHints()
    if not hints then return end
    pcall(hints.hide)
    pcall(hints.delete)
    hints = nil
end

local function showHints(surface)
    hideHints()
    local rows = HINTS[surface]
    if not rows then return end
    hintsFor = surface
    -- the corner the page leaves free: the board stands on the right in Arabic, on the left in English
    local ok, group = pcall(w.prompt.createGroup, false, Nui.lang() == 'ar' and 'bottom-left' or 'bottom-right')
    if not ok or not group then return end
    hints = group
    for _, row in ipairs(rows) do hints.addPrompt(row[1], locale(row[2]), false) end
    hints.display()
end

--- The page changed inside the board (a text field holds the keyboard, a confirmation is up...)
function Nui.relabel(page)
    if not hints or hintsFor ~= 'board' then return end
    pcall(hints.setLabel, 'RETURN', locale(page == 'confirm' and 'hint.confirm' or page == 'field' and 'hint.next' or 'hint.select'))
end

-- ════════════════════════════════════════════════════════════════════════════
-- Showing and hiding a surface
-- ════════════════════════════════════════════════════════════════════════════

local function setEffect(on)
    local name = Config.Effect
    if type(name) ~= 'string' or name == '' or on == effectOn then return end
    effectOn = on
    pcall(function()
        if on then AnimpostfxPlay(name) else AnimpostfxStop(name) end
    end)
end

---@param surface 'board' | 'passcode' | 'pick'
---@param message table the page's opening message
function Nui.show(surface, message)
    Nui.surface = surface
    SendNUIMessage(Nui.localePayload())
    SendNUIMessage(message)
    SetNuiFocus(true, surface ~= 'pick')
    if surface ~= 'pick' then WDoorSound.play('open') end
    setEffect(true)
    showHints(surface)
end

function Nui.hide(surface, silent)
    if Nui.surface ~= surface then return end
    Nui.surface = nil
    if surface == 'pick' then Nui.pickToken = nil end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'dl:close', surface = surface })
    if not silent and surface ~= 'pick' then WDoorSound.play('close') end
    setEffect(false)
    hideHints()
end

--- Opens a surface and waits for the page's answer (the passcode note, the pick)
---@return any answer  nil when the player backed out, or when another surface is already up
function Nui.ask(surface, message)
    if Nui.surface or pending then return nil end
    local p = promise.new()
    pending = { surface = surface, promise = p }
    Nui.show(surface, message)
    return Citizen.Await(p)
end

function Nui.answer(surface, value)
    if not pending or pending.surface ~= surface then return end
    local p = pending.promise
    pending = nil
    Nui.hide(surface, true)
    p:resolve(value)
end

-- ════════════════════════════════════════════════════════════════════════════
-- The page's calls
-- ════════════════════════════════════════════════════════════════════════════

RegisterNUICallback('dl:ready', function(_, cb)
    SendNUIMessage(Nui.localePayload())
    cb({ ok = true })
end)

RegisterNUICallback('dl:sound', function(data, cb)
    if data and type(data.name) == 'string' then WDoorSound.play(data.name) end
    cb({ ok = true })
end)

RegisterNUICallback('dl:page', function(data, cb)
    Nui.relabel(data and data.page)
    cb({ ok = true })
end)

RegisterNUICallback('dl:passcode', function(data, cb)
    cb({ ok = true })
    local code = data and data.code
    if type(code) ~= 'string' or code == '' then code = nil end
    Nui.answer('passcode', code)
end)

RegisterNUICallback('dl:pick', function(data, cb)
    cb({ ok = true })
    local result = data and data.result
    if result ~= 'success' and result ~= 'fail' then result = 'cancel' end
    Nui.answer('pick', result)
end)

--- One press, sent the instant it happens. The server holds the zone, so it measures the angle itself
--- and hands back the only thing the page is allowed to act on: whether the round was won.
RegisterNUICallback('dl:pickPress', function(data, cb)
    -- the page counts its rounds from 0, the server's plan from 1 (Lua): the +1 is the bridge between them
    local round = tonumber(data and data.round)
    local ok, hit = pcall(w.callback.await, 'w_doorlock:pickPress', false,
        Nui.pickToken, round and round + 1, tonumber(data and data.angle))
    cb({ ok = true, hit = ok and hit == true })
end)

-- ════════════════════════════════════════════════════════════════════════════
-- The language changed in w_lib: every text is redone in the language of the moment
--
-- * The library reloads the dictionary in its own handler; it is reloaded again here so the order
--   of the handlers does not matter, then the texts and the hints go out again.
-- ════════════════════════════════════════════════════════════════════════════
AddEventHandler('w_lib:setLocale', function(key)
    w.locale((key == 'ar') and 'ar' or 'en')
    SendNUIMessage(Nui.localePayload())
    if Nui.surface then showHints(Nui.surface) end
    TriggerEvent('w_doorlock:client:relabel')
end)

-- * Releasing the focus on stop is not courtesy: a resource that stops while holding the NUI focus
--   leaves the player with a cursor and no game under it.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if Nui.surface then SetNuiFocus(false, false) end
    setEffect(false)
    hideHints()
end)

-- ════════════════════════════════════════════════════════════════════════════
-- Notices (the library's floating notice), always in the player's own language
-- ════════════════════════════════════════════════════════════════════════════

local ICONS = { success = 'tick', error = 'cross', info = 'lock' }

---@param key string a dictionary key (notify.*)
---@param style? 'success' | 'error' | 'info'
function WDoor.notify(key, style, ...)
    local text = locale(key, ...)
    w.notify({
        title = text,
        description = '',
        icon = ICONS[style or 'info'] or 'lock',
        placement = 'middle-right',
        duration = 4000,
        useBackground = false,
        contentAlignment = 'center',
        isRTL = Nui.lang() == 'ar',
    })
end

RegisterNetEvent('w_doorlock:client:notify', function(key, style)
    if type(key) ~= 'string' then return end
    WDoor.notify(key, style)
end)

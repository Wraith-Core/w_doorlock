-- ════════════════════════════════════════════════════════════════════════════
-- w_doorlock · client/sound.lua
-- The board's sounds - the game's own menu sounds, the very pairs of w_pausemenu.
--
-- ! The native's signature in RDR3:
--       PLAY_SOUND_FRONTEND(const char* audioName, const char* audioRef, BOOL, Any)
--    the name comes first and the set second. The native never complains about a wrong pair: it
--    simply goes quiet. Which is why the checker below asks the engine about every pair at boot
--    (PREPARE_SOUND with the id -2, Rockstar's own gate for verifying) and swaps in `alt` when the
--    engine refuses the original.
-- ════════════════════════════════════════════════════════════════════════════
WDoorSound = {}

local PREPARE_SOUNDSET <const> = 0xD9130842D7226045 -- PREPARE_SOUNDSET(set, BOOL) -> BOOL
local PREPARE_SOUND    <const> = 0xE368E8422C860BA7 -- PREPARE_SOUND(name, set, soundId) -> BOOL
local RELEASE_SOUNDSET <const> = 0x531A78D6BF27014B -- _RELEASE_SOUNDSET(set)

local function truthy(v) return v == true or v == 1 end

local lastAt = {}

--- Does the engine know this pair?
---@return boolean
local function pairExists(name, set)
    if type(name) ~= 'string' or type(set) ~= 'string' then return false end
    local ok, res = pcall(function()
        local setOk  = truthy(Citizen.InvokeNative(PREPARE_SOUNDSET, set, false))
        local pairOk = truthy(Citizen.InvokeNative(PREPARE_SOUND, name, set, -2))
        pcall(function() Citizen.InvokeNative(RELEASE_SOUNDSET, set) end)
        return setOk and pairOk
    end)
    return ok and res == true
end

--- Plays a cue by its name in Config.Sounds
---@param key string 'open' | 'close' | 'navUp' | 'navDown' | 'select' | 'back' | 'locked' | 'toggleOn' | 'toggleOff'
function WDoorSound.play(key)
    local cfg = Config.Sounds or {}
    if cfg.enabled == false then return end

    local cue = cfg[key]
    if type(cue) ~= 'table' or not (cue.name and cue.set) then return end

    local now = GetGameTimer()
    local gap = tonumber(cue.gap) or tonumber(cfg.gap) or 55
    if now - (lastAt[key] or 0) < gap then return end
    lastAt[key] = now

    PlaySoundFrontend(cue.name, cue.set, true, 0)
end

CreateThread(function()
    Wait(4000)

    local cfg = Config.Sounds or {}
    if cfg.enabled == false then return end

    local dead = {}
    for key, cue in pairs(cfg) do
        if type(cue) == 'table' and cue.name and cue.set and not pairExists(cue.name, cue.set) then
            local alt = cue.alt
            if type(alt) == 'table' and pairExists(alt.name, alt.set) then
                w.print.debug('sound %s: %s/%s <- the alternative %s/%s', key, cue.set, cue.name, alt.set, alt.name)
                cue.name, cue.set = alt.name, alt.set
            else
                dead[#dead + 1] = ('%s (%s/%s)'):format(key, cue.set, cue.name)
            end
        end
    end

    if #dead > 0 then w.print.debug('silent sounds: %s', table.concat(dead, ', ')) end
end)

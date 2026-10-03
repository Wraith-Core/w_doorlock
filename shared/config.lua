Config = {}

----------------------------------
-- The language
--
-- * Nothing to set here: the doorlock follows w_lib. The dictionary is locales/ar.json and
--   locales/en.json, loaded by the library at start (w_lib { 'locale' } in the manifest) and
--   reloaded live on w_lib:setLocale when a player switches his language in /w_lib.
-- * Only 'ar' and 'en' exist; anything else the library reports counts as English.
-- * Debug output goes through w.print.debug:  setr w_lib:printlevel:w_doorlock debug
----------------------------------

----------------------------------
-- Who manages the doors
--
--   /doorlock            opens the board: every door, a new one, edit, copy, teleport, delete
--   /doorlock closest    opens the board straight on the door you stand at
--
-- * One ACE node, checked on the server through exports.w_lib:HasPermissionNode (the full
--   admins pass by themselves):   add_ace group.staff w_doorlock.admin allow
-- * Any single door can also be opened through ACE, by its name on the board:
--       add_ace group.police "w_doorlock.door.valentine_sheriff_front" allow
----------------------------------
Config.Command    = 'doorlock'
Config.Permission = 'w_doorlock.admin'

--- Whoever passes Config.Permission opens every door (false = the door's own rules apply to the staff too)
Config.AdminBypass = false

----------------------------------
-- The door prompt (w_lib's walk-up prompt group, the same one every [wraith] script shows)
--
--   key        lock / unlock
--   pickKey    pick the lock - only on a door that allows it, and only with a pick in the bag
--   hold       ms the key is held (false = a plain press)
--   position   'bottom-right' | 'center-right' | 'top-right' | 'bottom-left' | 'center-left' | 'top-left'
----------------------------------
Config.Prompt = {
    key      = 'E',
    pickKey  = 'G',
    hold     = false,
    position = 'center-left',
}

--- The key-turn the character plays when a door opens or locks for him (false = none)
Config.Animation = true

----------------------------------
-- Lockpicking
--
--   items        the items that count as a lock pick (any one of them)
--   difficulty   the rounds of the skill check, when the door sets none of its own on the board:
--                'easy' | 'medium' | 'hard' | { areaSize = degrees, speedMultiplier = n }
--   canLock      a pick may also lock a door that stands open
--   breakOnFail / breakOnSuccess   % chance the pick breaks (decided by the server)
----------------------------------
Config.Lockpick = {
    items          = { 'lockpick' },
    difficulty     = { 'easy', 'easy', 'medium' },
    canLock        = false,
    breakOnFail    = 20,
    breakOnSuccess = 1,
}

----------------------------------
-- The door sounds - heard in the world by whoever stands near the door
--
-- * The files are web/public/sounds/<name>.ogg (served as web/build/sounds/<name>.ogg). A new
--   sound is a new .ogg there plus its name here; the board offers exactly this list.
----------------------------------
Config.DoorSounds   = { 'door-bolt-4', 'button-remote', 'metal-locker', 'metallic-creak' }
Config.DefaultSound = 'door-bolt-4'
Config.SoundVolume  = 0.3           -- at two metres; it falls with the distance (0 = silent)

----------------------------------
-- Doors the game keeps locked that must stay open for everybody (stores, banks...)
--
-- * Door hashes. No prompt shows on them and nobody can lock them; a door on the board wins
--   over this list.
----------------------------------
Config.UnlockedDoors = {
    586229709,  -- Saint Denis Medic
    3804893186, -- Saint Denis Clothing Store
    3277501452, -- Blackwater Clothing Store
    3208189941, -- Tumbleweed Clothing Store
    94437577,   -- Strawberry Clothing Store
    2432590327, -- Rhodes Clothing Store

    -- Valentine Savings Bank
    2642457609, 3886827663,         -- main door
    1340831050, 2343746133,         -- barred right / left
    334467483, 3718620420,          -- inner doors
    576950805,                      -- vault

    -- Bank of Rhodes
    3317756151, 3088209306,         -- main door
    2058564250, 3142122679, 1634148892, -- inner doors
    3483244267,                     -- vault

    -- Lemoyne National Bank, Saint Denis
    2158285782, 1733501235, 2089945615, 2817024187, -- main doors
    1830999060,                     -- inner private door
    965922748, 1634115439,          -- manager
    1751238140,                     -- vault

    -- West Elizabeth Co-Operative Bank, Blackwater
    531022111,                      -- main door
    2117902999,                     -- inner door
    2817192481,                     -- manager
    1462330364,                     -- vault

    -- Bank of Armadillo
    3101287960,                     -- main door
    3550475905, 1329318347,         -- inner doors
    1366165179,                     -- back door
}

----------------------------------
-- The look and the sound of the board, the code note and the lock pick - the pause menu's
-- (w_pausemenu/shared/config.lua): the game's own menu sounds, every pair checked at boot
--
-- ! The native's order in RDR3 is (name, set), not (set, name); a pair the engine does not know
--   is silent and never complains, which is why client/sound.lua checks each one at boot and
--   swaps in `alt` when the engine refuses the original.
----------------------------------
Config.Effect = 'PauseMenuIn'   -- an AnimPostFX effect while the board is open (false = none)

Config.Sounds = {
    enabled = true,

    open      = { set = 'HUD_PLAYER_MENU',     name = 'MENU_ENTER' },
    close     = { set = 'HUD_PLAYER_MENU',     name = 'MENU_CLOSE' },
    navUp     = { set = 'HUD_PLAYER_MENU',     name = 'NAV_UP',   alt = { set = 'Ledger_Sounds', name = 'NAV_UP'   } },
    navDown   = { set = 'HUD_PLAYER_MENU',     name = 'NAV_DOWN', alt = { set = 'Ledger_Sounds', name = 'NAV_DOWN' } },
    select    = { set = 'HUD_SHOP_SOUNDSET',   name = 'SELECT' },
    back      = { set = 'HUD_SHOP_SOUNDSET',   name = 'BACK' },
    locked    = { set = 'Ledger_Sounds',       name = 'UNAFFORDABLE', alt = { set = 'HUD_SHOP_SOUNDSET', name = 'BACK' } },
    toggleOn  = { set = 'PAUSE_MENU_SOUNDSET', name = 'NAV_RIGHT', alt = { set = 'Ledger_Sounds', name = 'INFO_SHOW' } },
    toggleOff = { set = 'PAUSE_MENU_SOUNDSET', name = 'NAV_LEFT',  alt = { set = 'Ledger_Sounds', name = 'INFO_HIDE' } },

    -- The smallest gap between two clicks of the same kind (ms) - fast navigation does not growl
    gap = 55,
}

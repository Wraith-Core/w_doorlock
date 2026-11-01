fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'w_doorlock'
author 'Wraith Studio'
version '2.1.3'
license 'GPL-3.0-or-later'
description "Red River Doorlock -- every door locked, opened, picked and edited in the game (/doorlock), on the pause menu's torn-paper board. Built on w_lib; a port of ox_doorlock (Overextended, GPL-3.0)"

-- ════════════════════════════════════════════════════════════════════════════
-- What runs where
--
--   server   the doors (one table through w_lib's database bridge), who may use what (w_lib's
--            framework and inventory bridges: every core and bag the library knows), the code,
--            the lock pick's dice, /doorlock and the board's saves
--   client   the doors in the game's door system, the library's walk-up prompt on each one, the
--            key turning in the lock, and the page: the board, the code note, the lock pick
--
-- ★ No ox_lib, no jo_libs, no oxmysql line: w_lib alone (it loads oxmysql for its Db* exports).
-- ★ The page is our own (web/build), so the library's own frame (w.minigame, w.promptNui) is not
--   ours to draw in: the lock pick is drawn by our page, the prompts by w_lib's frame through
--   its exports (w.prompt.at / w.prompt.createGroup; client/walkup.lua stands in for w.prompt.at
--   on a w_lib without it), the notices by w.notify.
-- ════════════════════════════════════════════════════════════════════════════

shared_scripts {
    '@w_lib/init.lua',      -- the library first (w / lib / cache / locale)
    'shared/config.lua',
}

-- The dictionary (locales/{ar,en}.json) is read before our scripts run, on both sides
w_lib { 'locale' }

client_scripts {
    'client/sound.lua',     -- the board's sounds: the game's own menu sounds (the pause menu's pairs)
    'client/nui.lua',       -- the page: one surface at a time, the key hints, the notices, the language
    'client/doors.lua',     -- the doors in the game's door system, their sounds, who is near
    'client/walkup.lua',    -- the walk-up prompt: the library's w.prompt.at, or our own on w_lib 3.x
    'client/interact.lua',  -- the prompt on each door, the code, the lock pick, the client exports
    'client/board.lua',     -- the staff's board, and choosing a new door in the world
}

server_scripts {
    'server/bridge.lua',    -- the player through w_lib: character, job / gang, items, the staff
    'server/db.lua',        -- the w_doorlock table, the one-time moves from ox_doorlock and the old list
    'server/main.lua',      -- the doors, the rules, the code, the lock pick, the exports
    'server/admin.lua',     -- /doorlock and the board's calls
}

ui_page 'web/build/index.html'

files {
    'web/build/index.html',
    'web/build/**/*',
    'locales/*.json',
}

dependencies {
    'w_lib',
}

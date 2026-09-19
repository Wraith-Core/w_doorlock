# w_doorlock
Doorlock Handler for Wraith Core RedM

- Built on w_lib 4.0: one library proximity prompt per door (`w.prompt.at`, lock / unlock label and title following the door state), the lock animation (`w.progressBar` with the key prop), callbacks and notifications.
- Language follows the library (`w_lib:locale` convar / the player's `/w_lib` choice): `locales/en.json` and `locales/ar.json` hold every player-facing string.
- Door lists live in `shared/sh_doors.lua` (see `EXAMPLES.lua`); the prompt key, hold time and position in `shared/sh_config.lua`.

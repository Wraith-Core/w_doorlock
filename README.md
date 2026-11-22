# w_doorlock

Interactive RedM door lock system with job/gang/item permissions, lockpicking, database persistence, and an in-game visual door editor (`/doorlock`) for **Wraith Framework RedM**.

## Key Features

- Lock/unlock single and double doors across the RedM map (press `J`).
- Job, grade, gang, citizen, and item-based access control.
- Built-in lockpicking support.
- In-game admin board and door picker (`/doorlock`) backed by the `w_doorlock` MySQL table.

## Installation

1. Place `w_doorlock` in `resources/[wraith]/w_doorlock`.
2. Add `ensure w_doorlock` to `server.cfg` after `w_lib` and `w_core`.

## Key Exports

```lua
-- 1 = locked, 0 = unlocked
exports.w_doorlock:setDoorState(doorId, 1)
local door    = exports.w_doorlock:getDoor(doorId)
local byName  = exports.w_doorlock:getDoorFromName('valentine_sheriff_cell_1')
local closest = exports.w_doorlock:getClosestDoor()
```

## Documentation & Links

- **Developer Docs:** https://wraith-core.github.io/docs/#/resources/interface-world
- **txAdmin Recipe:** https://github.com/Wraith-Core/txAdminRecipe
- **Credits:** See [CREDITS.md](CREDITS.md)

## License

GPL-3.0 — see [LICENSE](LICENSE).

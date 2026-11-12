# w_doorlock — the notebook board and the saved doors (2026-11-12)

The notebook board (the builders' look on `/doorlock`) reads and writes the doors exactly as the 2.3 board did:
`web/src/door.ts` (`formOf` / `payloadOf` / `validate`) is unchanged, the table `w_doorlock` keeps its columns
(`id`, `name`, `data`), and nothing is written until a staff member presses «حفظ». The new things are computed on
the way to the page and never saved:

- `label` — the name in words (`client/words.lua`, locales `word.*`): `valentine_sheriff_front` →
  «مكتب الشريف · الباب الأمامي». A name the staff typed (Arabic, or one word) stays as it is.
- `where`, `meters` — the place and distance from `w.place.describe` (w_lib 4.5.0), the region name on an older w_lib.
- `names` — jobs / gangs with their grades (w_core / RSG) and items with their labels (w_inventory / RSG), asked once
  per session (`w_doorlock:admin:names`, staff only). Without a list the fields are typed as before.

The world mode (TAB) needs w_lib's `lib.worldEdit` (4.5.0). On an older w_lib the board shows no TAB key and works as
before; the door is chosen after «اختيار الباب» as in 2.3. Door ids, the exports and `w_doorlock:stateChanged` are
untouched (w_heists reads the board's doors by id). The world mode's lock / unlock goes through `DoorSetState` like
every other change, with the staff member as the source.

## Check of the saved doors (read-only SELECT, 2026-11-12)

Both servers hold the same 33 doors (ids 1–34, 29 missing): 29 police doors, `gun_val`, `test`, `bank_val`,
«الاسطبل», «تجربة». Each row went through the board's own code (`formOf` → `validate` → readiness → sentence):

| | Studio (`wraith_studio`) | Red River (`wraith_core`) |
|---|---|---|
| doors | 33 | 33 |
| open with an error | 0 | 0 |
| readiness blocks the save | 0 | 0 |
| «لا يفتحه أحد» (a note, not a block) | #32 bank_val, #33 الاسطبل, #34 تجربة | the same |

- Opening and saving a door unchanged sends the same payload the 2.3 board sent (the form's shape, e.g. `groups`
  as a list); the server stores it as before.
- **#32 `bank_val`** (the Valentine bank door the heists' check flagged): locked, locks itself after 3 s, no job,
  item or code — only the scripts (w_heists) and the staff open it. The board now says so on its readiness line.
  If players of a job should open it, add the job on the board.
- `test` and «تجربة» look like test doors; the owner may delete them on the board.

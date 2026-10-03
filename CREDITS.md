# w_doorlock credits

## The code

w_doorlock is a port of **ox_doorlock** 1.18.0 (RedM build) by Overextended,
<https://github.com/overextended/ox_doorlock>, licensed GPL-3.0-or-later. The port keeps its door
data, its rules of access and its export names, and rewrites everything else on w_lib. As a
derivative work it stays under the GNU General Public License v3.0 or later (`LICENSE`).

The previous w_doorlock (Wraith Studio, after rsg-doorlock) contributed its door list
(`data/legacy.lua`), its always-open doors (`Config.UnlockedDoors`) and its key-turn animation.

## The look (`web/public/`)

Everything is local to the resource (RedM's CEF runs offline), served from `web/build/` and declared
in `fxmanifest.lua` (`web/build/**/*`).

| Files | What | Where it comes from | Licence |
|---|---|---|---|
| `fonts/EBGaramond-*.woff2` | EB Garamond | w_pausemenu (Google Fonts subset) | SIL OFL 1.1 (`fonts/OFL-EBGaramond.txt`) |
| `fonts/Amiri-*.woff2` | Amiri | w_pausemenu (Google Fonts subset) | SIL OFL 1.1 (`fonts/OFL-Amiri.txt`) |
| `fonts/Lalezar-400-arabic.woff2` | Lalezar | w_pausemenu (Google Fonts subset) | SIL OFL 1.1 (`fonts/OFL-Lalezar.txt`) |
| `fonts/tajawal-*.woff2`, `fonts/NotoSansArabic.woff2` | Tajawal, Noto Sans Arabic | w_pausemenu | SIL OFL 1.1 |
| `fonts/RDRLino-Regular.woff2` | RDR Lino | w_pausemenu (the game's face, already shipped by the server) | Not verified; see w_loading/CREDITS.md |
| `tex/tear.png`, `tex/grain.png` | the torn edge and the paper grain | w_pausemenu's own procedural textures | Wraith Studio |
| `tex/band.png`, `tex/band-sm.png` | the brushed selection band | w_lib's theme (`nui/theme/tex/selection_box_bg_1a/1c.png`): the game's own UI art | the game's |
| `sounds/*.ogg` | the door sounds | shipped with ox_doorlock | as distributed with ox_doorlock |

The line icons (door, padlocks, lock pick, the small glyphs) are drawn by hand for this resource
(`web/src/ui/icons.tsx`), in the manner of the pause menu's. The board's menu sounds are the game's
own (`Config.Sounds`, the pause menu's pairs); no sound file is added for them.

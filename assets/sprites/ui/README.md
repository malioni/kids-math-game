# UI sprites

Art for the level HUD (`scenes/ui/level_hud.tscn`), the main menu (`scenes/ui/main_menu.tscn`) and the
world carousel (`scenes/ui/world_carousel.tscn`). Hand-drawn SVGs, imported as scalable textures (run
`tools/import_svgs.sh` after adding one). Keep each file's name and size; `tests/test_sprites.gd` checks
the sizes.

| File | Size | Use |
|---|---|---|
| `icon_world_forest.svg` | 128×128 | Forest Bridge world icon (the level badge and its card on the menu) |
| `icon_world_sky.svg` | 128×128 | Sky Balloons world icon |
| `icon_world_market.svg` | 128×128 | Market world icon |
| `icon_world_picnic.svg` | 128×128 | Picnic world icon |
| `icon_world_memory.svg` | 128×128 | Memory Meadow world icon |
| `icon_shuffle.svg` | 128×128 | Shuffle: the menu's Shuffle card and the badge's sticker. The world icons double as the shuffle setup's on/off toggles |
| `icon_easy.svg` | 128×128 | Easy difficulty button on the menu (a hill) |
| `icon_hard.svg` | 128×128 | Hard difficulty button on the menu, and the world-complete screen's button to go on to hard (a mountain) |
| `icon_music_on.svg`, `icon_music_off.svg` | 128×128 | Background sound toggle; the "off" icon is the "on" icon with a red slash |
| `icon_effects_on.svg`, `icon_effects_off.svg` | 128×128 | Sound effects toggle |
| `icon_close.svg` | 128×128 | Close the pause panel |
| `icon_replay.svg` | 128×128 | Replay this level, in the pause panel (a circular arrow around a green play triangle) |
| `icon_new_round.svg` | 128×128 | Start a new shuffle round, in the menu's shuffle setup (the replay arrow around small shuffle arrows) |
| `icon_home.svg` | 128×128 | Home button in the pause panel and on the world-complete screen |
| `icon_star.svg` | 200×200 | World-complete screen |
| `icon_arrow.svg` | 128×128 | Carousel arrows; points right, flipped for left |
| `icon_play.svg` | 200×200 | Main menu Play button |
| `card_frame.svg` | 96×96 | Card frame for the world carousel and the level wheel, drawn through a `StyleBoxTexture` with 24-unit margins; plain white so the carousel can tint it |
| `bg_menu.svg` | 1800×1000 | Main menu background, with the 1280×720 play area centred |

Style: a `#3D2617` outline 3 units wide with round joins, one highlight (top left) and one shade (bottom
right) per shape, no text. World icons are free-standing objects on a transparent background. Use only
shapes, paths, gradients and transforms; Godot's SVG renderer does not handle filters, masks, text or
embedded images reliably.

The world icons are shown larger than they are drawn on the menu's centre card (about 1.8 times), where
they are slightly soft; everywhere else they are shown at or below their size.

The restart button reuses `forest_bridge/retry_icon.svg` with a "1" on its corner.

# UI sprites

Programmer-art placeholders for the level HUD (`scenes/ui/level_hud.tscn`), the main menu
(`scenes/ui/main_menu.tscn`) and the world carousel (`scenes/ui/world_carousel.tscn`). Replace with final
art at the same filenames and sizes.

| File | Size | Use |
|---|---|---|
| `icon_world_forest.png` | 128×128 | Forest Bridge world icon (badge, and its card on the menu, picker and world-complete screen) |
| `icon_world_sky.png` | 128×128 | Sky Balloons world icon |
| `icon_world_market.png` | 128×128 | Market world icon (drawn by `tools/make_market_placeholders.gd`) |
| `icon_world_picnic.png` | 128×128 | Picnic world icon (drawn by `tools/make_picnic_placeholders.gd`) |
| `icon_shuffle.png` | 128×128 | Shuffle tab in the picker and the badge's shuffle sticker (drawn by `tools/make_mode_icons.gd`) |
| `icon_easy.png` | 128×128 | Easy difficulty button (a hill; `tools/make_mode_icons.gd`) |
| `icon_hard.png` | 128×128 | Hard difficulty button (a mountain; `tools/make_mode_icons.gd`) |
| `icon_close.png` | 128×128 | Close the level picker |
| `icon_star.png` | 200×200 | World-complete screen |
| `icon_home.png` | 128×128 | Home button in the picker and on the world-complete screen (a house; `tools/make_menu_placeholders.gd`) |
| `icon_arrow.png` | 128×128 | Carousel arrows; points right, flipped for left (`tools/make_menu_placeholders.gd`) |
| `icon_play.png` | 200×200 | Main menu Play button (`tools/make_menu_placeholders.gd`) |
| `card_frame.png` | 96×96 | World card frame, a 9-patch with 24 px margins; white so the carousel can tint it (`tools/make_menu_placeholders.gd`) |
| `bg_menu.png` | 1800×1000 | Main menu background, with the 1280×720 play area centred (`tools/make_menu_placeholders.gd`) |

The restart button reuses `forest_bridge/retry_icon.png` with a "1" drawn on top.

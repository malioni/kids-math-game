# Picnic sprites

Hand-drawn SVGs, imported as scalable textures (run `tools/import_svgs.sh` after adding one). Keep each
file's name and size: the scenes are laid out around them, and `tests/test_sprites.gd` checks the sizes.

| File | Size | Notes |
|---|---|---|
| `bg_picnic.svg` | 1800×1000 | Meadow and blanket; the 1280×720 play area is centred. The blanket covers x 330–1480, y 420–920, and the tray and plates are laid out on it |
| `tray.svg` | 640×260 | The fox's plate the child fills (drawn as a `NinePatchRect`, 16-unit margins) |
| `guest_plate.svg` | 170×100 | Each friend's plate; dealt fruit is drawn on top |
| `basket.svg` | 120×80 | Basket each fruit comes from; one per fruit, its total is drawn beside it |
| `icon_strawberry.svg` | 64×64 | Strawberry; the pieces the child places and the small fruit on friends' plates |
| `icon_apple.svg` | 64×64 | Apple (green, so it reads differently from the strawberry) |
| `icon_banana.svg` | 64×64 | Banana |

Style: a `#3D2617` outline 3 units wide with round joins, one highlight (top left) and one shade (bottom
right) per shape, no text. In the background only the blanket is outlined. Use only shapes, paths, gradients
and transforms; Godot's SVG renderer does not handle filters, masks, text or embedded images reliably.

The fox and its friends use the shared sheets in `assets/sprites/fox/` (idle, celebrate, sad). The friends
are tinted copies of the fox; later art could give them their own animals.

The Go and retry buttons reuse `forest_bridge/go_icon.svg` and `forest_bridge/retry_icon.svg`.

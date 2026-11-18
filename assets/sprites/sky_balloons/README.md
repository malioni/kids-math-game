# Sky Balloons sprites

Hand-drawn SVGs, imported as scalable textures (run `tools/import_svgs.sh` after adding one). Keep each
file's name and size: the scenes are laid out around them, and `tests/test_sprites.gd` checks the sizes.

| File | Size | Notes |
|---|---|---|
| `bg_sky.svg` | 1800×1000 | Sky; the 1280×720 play area is centred, like the other worlds' backgrounds |
| `cloud.svg` | 300×140 | Scrolls past to show rising and falling; one see-through shape with no outline |
| `balloon.svg` | 128×150 | White and grey only: each balloon is tinted through `self_modulate`. The round body is centred at (64, 62) with radius 60, and the knot is below it. The number is a Label on top |
| `basket.svg` | 150×90 | The rim runs along the top edge; the fox sits behind it |
| `sandbag.svg` | 120×120 | The weight; the face stays blank (the target is a Label) |
| `lift_badge.svg` | 120×120 | Where the strings meet; the face stays blank (the lift total is a Label) |

Style: a `#3D2617` outline 3 units wide with round joins, one highlight (top left) and one shade (bottom
right) per shape, no text. The background and the cloud have no dark outline. Use only shapes, paths,
gradients and transforms; Godot's SVG renderer does not handle filters, masks, text or embedded images
reliably.

The fox uses the shared sheets in `assets/sprites/fox/` (idle, celebrate, fall). The retry button reuses
`forest_bridge/retry_icon.svg`.

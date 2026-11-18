# Forest Bridge sprites

Hand-drawn SVGs, imported as scalable textures (run `tools/import_svgs.sh` after adding one). Keep each
file's name and size: the scenes are laid out around them, and `tests/test_sprites.gd` checks the sizes.

| File | Size | Notes |
|---|---|---|
| `bg_river.svg` | 1800×1000 | River between two banks; the 1280×720 play area is centred. The ground starts at y = 500 and the water runs between x = 601 and x = 1200, which is where the platforms end |
| `bridge_platform.svg` | 400×80 | The deck on each bank. Its top line is at y = 10; the fox walks on it |
| `plank.svg` | 100×40 | A plank, drawn as a nine-patch (12 units left and right, 8 top and bottom) and stretched to its length. Keep the ends and nails inside the outer 12 units and only straight grain between them |
| `plank_shadow.svg` | 100×20 | Shown under a plank while it is dragged (nine-patch, 12 units left and right) |
| `gap_slot_empty.svg` | 80×80 | The gap in the bridge (nine-patch, 12-unit margins, tiled middle). The dots on each edge are 14 units apart so the tiles join |
| `target_sign.svg` | 120×100 | The bridge-length sign; the face stays blank (the number is a Label on top) |
| `home.svg` | 120×120 | The fox's home on the far bank |
| `go_icon.svg` | 80×80 | The Go button, in every world that has one |
| `retry_icon.svg` | 80×80 | The retry button, in every world; with a "1" drawn in its middle it is the restart button on the world-complete screen |

Style: a `#3D2617` outline 3 units wide with round joins, one highlight (top left) and one shade (bottom
right) per shape, no text. The background has no dark outline and keeps its shapes pale, so the planks and
the fox stand out. Use only shapes, paths, gradients and transforms; Godot's SVG renderer does not handle
filters, masks, text or embedded images reliably.

The fox uses the shared sheets in `assets/sprites/fox/` (idle, walk, celebrate, fall). The bridge's collapse
is an `AnimationPlayer` fade, and the celebration is a `GPUParticles2D`; neither has a sprite.

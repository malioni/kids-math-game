# Market sprites

Hand-drawn SVGs, imported as scalable textures (run `tools/import_svgs.sh` after adding one). Keep each
file's name and size: the scenes are laid out around them, and `tests/test_sprites.gd` checks the sizes.

| File | Size | Notes |
|---|---|---|
| `bg_market.svg` | 1800×1000 | Market stall; the 1280×720 play area is centred, like the other worlds' backgrounds |
| `table.svg` | 760×330 | Table top the bags are placed on (drawn as a `NinePatchRect`, 12-unit margins) |
| `crate.svg` | 150×110 | Crate each item's bags come from; one per ordered item |
| `bag.svg` | 96×96 | Paper bag; the face stays blank (the bag size and item icon are drawn on top) |
| `bag_shadow.svg` | 96×96 | Shown under a bag while it is dragged |
| `order_slip.svg` | 200×230 | The fox's order; blank (amounts and icons are drawn on top) |
| `icon_tomato.svg` | 64×64 | Tomato icon on bags and the order slip; also the thrown tomato |
| `icon_potato.svg` | 64×64 | Potato icon |
| `icon_carrot.svg` | 64×64 | Carrot icon |
| `splat.svg` | 200×200 | Tomato splat shown over the table after a throw |

Style: a `#3D2617` outline 3 units wide with round joins, one highlight (top left) and one shade (bottom
right) per shape, no text. Use only shapes, paths, gradients and transforms; Godot's SVG renderer does not
handle filters, masks, text or embedded images reliably.

The fox uses the shared sheets in `assets/sprites/fox/` (idle, celebrate, throw). The tomato in its paw
during the throw is drawn by `tools/make_fox_sheets.gd` to match `icon_tomato.svg`.

The Go and retry buttons reuse `forest_bridge/go_icon.png` and `forest_bridge/retry_icon.png`.

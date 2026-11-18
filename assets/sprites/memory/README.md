# Memory Meadow sprites

Hand-drawn SVGs, imported as scalable textures (run `tools/import_svgs.sh` after adding one). Keep each
file's name and size: the scenes are laid out around them, and `tests/test_sprites.gd` checks the sizes.

| File | Size | Notes |
|---|---|---|
| `bg_memory.svg` | 1800×1000 | Meadow with a lighter, plain clearing behind the cards; the 1280×720 play area is centred |
| `card_back.svg` | 160×160 | The face-down side of every card |
| `card_front.svg` | 160×160 | The face-up side; the animal is drawn on top, so the inside stays plain |
| `animal_<name>.svg` | 128×128 | One face per animal: fox, rabbit, bear, owl, frog, hedgehog, mouse, duck, pig, cat, deer, squirrel. Each has its own outer shape and its own main colour, so pairs are easy to tell apart at a glance |

Cards are scaled to fit the board, from 200 px (4 cards) down to about 155 px (20 cards), so a card is
sometimes shown a little larger than it is drawn and is slightly soft there.

Style: a `#3D2617` outline 3 units wide with round joins, one highlight (top left) and one shade (bottom
right) per shape, no text. The background has no dark outline. Every face is a head seen from the front
with the same round eyes. Use only shapes, paths, gradients and transforms; Godot's SVG renderer does not
handle filters, masks, text or embedded images reliably.

The fox beside the board uses the shared sheets in `assets/sprites/fox/` (idle and celebrate). The retry
button reuses `forest_bridge/retry_icon.svg`, though this world never shows it.

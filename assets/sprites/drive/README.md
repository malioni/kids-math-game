# Country Drive sprites

Hand-drawn SVGs, imported as scalable textures (run `tools/import_svgs.sh` after adding one). Keep each
file's name and size: the scenes are laid out around them, and `tests/test_sprites.gd` checks the sizes.
Everything is seen from straight above, except the fox's head in the car (from above and a little behind).

| File | Size | Notes |
|---|---|---|
| `bg_drive.svg` | 1800×1000 | Quiet meadow with soft patches, tufts and flowers, and a pale dirt path down the far left and far right edges, outside the centred 1280×720 play area. A shade darker than the field squares, so the board stands out |
| `grass_light.svg`, `grass_dark.svg` | 128×128 | Field squares (`#9CCB6B`, `#88BC5A`) with a few blade strokes and no outline, so neighbours join into a checkerboard |
| `tree.svg` | 128×128 | Obstacle: a dark green canopy of three overlapping circles with a shadow |
| `rock.svg` | 128×128 | Obstacle: a grey boulder with a highlight and two cracks |
| `bush.svg` | 128×128 | Obstacle: a lower, lumpy, lighter green bush with three red berries |
| `pond.svg` | 128×128 | Obstacle: a blue pond with a sandy bank, shine, reeds and a lily pad |
| `garage.svg` | 128×128 | The goal: a clay-tile roof with the fox's head as a sign, and the open doorway and tyre tracks on the left, where the car drives in |
| `cmd_up.svg`, `cmd_down.svg`, `cmd_left.svg`, `cmd_right.svg` | 96×96 | Easy-mode commands: a fat cream arrow pointing that way |
| `cmd_forward.svg` | 96×96 | Hard-mode command: a small car (from above, pointing up) with an arrow ahead of it |
| `cmd_turn_left.svg`, `cmd_turn_right.svg` | 96×96 | Hard-mode commands: a fat arrow bending 90° from up to left / right |
| `tile_frame.svg` | 96×96 | The frame behind every button and program tile |
| `car_<animation>.svg`, `car_frames.tres` | 160 px cells | The fox's car; written by a tool, see below |

The world icon is `ui/icon_world_drive.svg` (128×128): the car on a patch of grass with a pale path.

`tile_frame.svg` is tinted in code (lit: warm yellow, marked: soft red), so it must stay white and grey
inside its dark outline.

Style: a `#3D2617` outline about 3 units wide (3.5 on the car and the buttons) with round joins, one
highlight (top left) and one shade (bottom right) per shape, no text. Use only shapes, paths, gradients
and transforms; Godot's SVG renderer does not handle filters, masks, text or embedded images reliably.

## The car sheets

The car's animation sheets are SVGs written by `tools/make_car_sheets.gd`, which builds the car from
parts and takes each frame from a table of poses (`SHEETS` in that file), like the fox's tool. To change
how the car looks or moves, edit the tool and run:

    Godot --path . --headless -s tools/make_car_sheets.gd
    tools/import_svgs.sh

Do not edit the SVGs by hand; the next run overwrites them.

| Sheet | Frames | Speed (fps) | Loops | Shows |
|---|---|---|---|---|
| `car_idle.svg` | 4 | 6 | yes | a small engine bob; the open-eyed frames are held 4 times as long, so the fox blinks about every 2 s |
| `car_drive.svg` | 4 | 10 | yes | wheel treads sliding round, a slight bounce |
| `car_celebrate.svg` | 4 | 8 | yes | hops, ears up |
| `car_bump.svg` | 4 | 10 | no | knocked back, dizzy eyes, three stars circling the head |
| `car_sad.svg` | 4 | 4 | yes | ears drooped back, sad eyes |

The car faces right in a 160×160 cell, centred on (80, 80). The game scales the cell to the square size
and rotates it to face up, down and left, so every pose must leave the two outermost rows and columns of
its cell empty; `tests/test_car_frames.gd` checks this. `car_frames.tres` is the car's `SpriteFrames`;
the tool writes it too, so it always matches the sheets.

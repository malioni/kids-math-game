# Fox sprites

The fox is the main character in every world. Its animation sheets are SVGs written by
`tools/make_fox_sheets.gd`, which builds the fox from parts and takes each frame from a table of poses
(`SHEETS` in that file). To change how the fox looks or moves, edit the tool and run:

    Godot --path . --headless -s tools/make_fox_sheets.gd
    tools/import_svgs.sh

Do not edit the SVGs by hand; the next run overwrites them.

| Sheet | Frames | Speed (fps) | Loops | Used by |
|---|---|---|---|---|
| `character_idle.svg` | 4 | 6 | yes | every world; the three open-eyed frames are held 4 times as long, so it blinks about every 2 s |
| `character_walk.svg` | 6 | 10 | yes | Forest Bridge |
| `character_celebrate.svg` | 4 | 8 | yes | every world |
| `character_fall.svg` | 3 | 8 | no | Forest Bridge, Sky Balloons |
| `character_sad.svg` | 4 | 4 | yes | Picnic (the fox and its friends) |
| `character_throw.svg` | 6 | 10 | no | Market; the paw lets go on frame 3 |

The fox faces right, turned a little towards the viewer. In the tool, `SHOULDER_FRONT` is the near arm,
drawn over the body and hung from the tail side of the belly; `SHOULDER_BACK` is the far arm, drawn behind
the body at the chest: it is hidden at rest (`idle`, `sad`, `throw`) and seen when it is raised or swung
(`walk`, `celebrate`, `fall`). Moving the near shoulder to the chest side makes the body look turned away
under the head. In `celebrate` the near arm rises on the tail side and the far arm on the nose side, so a paw shows on
each side of the head.

After any edit to throw frame 3's pose, the tool prints the paw position ("Throw release, paw from the
cell centre: ..."). Copy that value into `_HAND_OFFSET` in `scripts/worlds/market.gd`, which starts the
tomato's flight from it; `_RELEASE_FRAME` there must match `RELEASE_FRAME` in the tool.

Each sheet is a horizontal strip of 160×160 cells. Every pose must leave the two outermost columns of its
cell empty, or it shows at the edge of the neighbouring frame; `tests/test_fox_frames.gd` checks this.

`fox_frames.tres` is the `SpriteFrames` resource every world's `Character` uses. The tool writes it too, so
it always matches the sheets. The cells are 2.5 times the size of the old 64 px ones, so a scene shows the
fox at 0.4 times the scale it used before (1.0 in the market, picnic and memory worlds).

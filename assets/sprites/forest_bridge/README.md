# Forest Bridge sprites

**Every PNG in this folder is a programmer-art placeholder** generated to the
filenames and sizes in PLAN.md (issue #7), so the scenes run end to end.

Replace each file with final art using the **same filename and dimensions** and
Godot will pick it up with no scene changes. Character sheets are horizontal
strips of 64×64 frames: idle 4, walk 6, celebrate 4, fall 3, sad 4. Keep each pose inside
its own 64 px cell, tail tip included, or it shows at the edge of the neighbouring frame.
`character_sad.png` (drooping head, worried brows, tears; used by the Picnic world) is drawn from
the first idle frame by `tools/make_fox_sad_placeholder.gd`. If a final sheet
uses a different frame count, update the `SpriteFrames` on `Character` in
`scenes/worlds/forest_bridge/forest_bridge.tscn`.

`plank.png`, `plank_shadow.png` and `gap_slot_empty.png` are drawn as 9-patches
(stretched to each plank's length and the full gap width), so keep their end
caps within the outer 12 px. `target_sign.png` is the bridge-length sign; leave
its face blank, because the number is drawn on top by a Label.

Not yet created (optional per PLAN.md): `bridge_collapse.png`,
`plank_splash.png`. The collapse currently uses the AnimationPlayer fade
fallback, and the celebration uses `GPUParticles2D`.

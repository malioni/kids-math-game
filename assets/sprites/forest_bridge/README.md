# Forest Bridge sprites

**Every PNG in this folder is a programmer-art placeholder** generated to the
filenames and sizes in PLAN.md (issue #7), so the scenes run end to end.

Replace each file with final art using the **same filename and dimensions** and
Godot will pick it up with no scene changes. Character sheets are horizontal
strips of 64×64 frames: idle 4, walk 6, celebrate 4, fall 3. If a final sheet
uses a different frame count, update the `SpriteFrames` on `Character` in
`scenes/worlds/forest_bridge/forest_bridge.tscn`.

Not yet created (optional per PLAN.md): `bridge_collapse.png`,
`plank_splash.png`. The collapse currently uses the AnimationPlayer fade
fallback, and the celebration uses `GPUParticles2D`.

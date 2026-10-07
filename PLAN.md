# PLAN.md — Issue #7: Visuals, character, bridge, and feedback animations

## Feature
Add the full visual layer for the Forest Bridge world: background, draggable plank mechanic, character, and success/failure animations.

> **Revision (2026-10-07) — Go button.** As first written, `incorrect` could never fire in play: planks only snap into empty slots, there are exactly `target_count` slots, and `correct` fired on the last placement with nothing calling `confirm()`. Decision: add an icon-only **Go button** to `PlacementMechanic`. `place()` no longer emits `correct`; pressing Go calls `confirm()`, which emits `correct` when the count matches and `incorrect` otherwise. A child can send the creature across with gaps still open, and the bridge collapses. Sections below are updated to match.

---

## Scope

**Included:**
- All sprite assets for the Forest Bridge world
- Drag-and-drop plank interaction wired into `PlacementMechanic`
- Character walk and celebration animation on `correct`
- Bridge collapse and plank bounce-back animation on `incorrect`
- Go button (icon-only) that confirms the placement and sends the creature across
- Retry prompt (icon-only, no text)
- Background and bridge gap visuals at 1280×720

**Out of scope:**
- Audio (issue #8)
- Main menu or level transition UI (issue #9)
- Any mechanic beyond PlacementMechanic
- Parent dashboard / analytics view

---

## Assets to Create

This is the primary deliverable of this issue. All assets go in `assets/sprites/forest_bridge/`.

> **Suggested tools:** Midjourney, DALL-E 3, Adobe Firefly, or Stable Diffusion for initial generation. Post-process in Aseprite (pixel art) or GIMP/Photoshop to trim, resize, and export as PNG. Target style: 2D hand-drawn, warm earthy palette (greens, browns, soft yellows).

### Static Sprites

| File | Size | Description | Notes |
|------|------|-------------|-------|
| `bg_river.png` | 1280×720 | River scene background — water flowing left-to-right, grassy banks, soft sky | Warmest asset; sets the entire mood |
| `bridge_platform.png` | ~400×80 | Solid wooden bridge section (used for left bank, right bank, middle segments) | Can be used as a 9-patch or repeating tile |
| `gap_slot_empty.png` | ~80×80 | Visual indicator of an empty gap (dark opening or subtle shimmer) | Shows where a plank should go |
| `gap_slot_filled.png` | ~80×80 | Gap slot with a plank locked in — slightly highlighted/warm tint | Swapped in after snap |
| `plank.png` | ~100×40 | Single wooden plank, worn grain texture | Draggable item |
| `plank_shadow.png` | ~100×20 | Drop shadow shown while plank is being dragged | Optional but adds tactile feel |
| `home.png` | ~120×120 | Small cozy home or burrow on the right bank — the destination | Warm, glowing window |
| `retry_icon.png` | ~80×80 | Circular arrow or gentle "redo" icon, no text | Tapped to retry the level |
| `go_icon.png` | ~80×80 | Round "go" icon (e.g. a right-pointing arrow), no text | Tapped to send the creature across |

### Character Spritesheets

All character sheets use the same frame size (e.g., 64×64 or 96×96 — pick one and keep it consistent across all sheets).

| File | Frames | Description |
|------|--------|-------------|
| `character_idle.png` | 2–4 frames | Character standing still with a gentle breathing cycle or tail flick |
| `character_walk.png` | 6–8 frames | Walk cycle — used when crossing the bridge on success |
| `character_celebrate.png` | 4–6 frames | Happy jump or spin at the destination |
| `character_fall.png` | 3–4 frames | Surprised tumble/flail when the bridge collapses |

> **Tip for spritesheets:** Export as a single horizontal strip (all frames left-to-right, same width per frame). Godot's `SpriteFrames` resource handles the rest. 64×64 px per frame is sufficient at 1280×720.

### Animation Frames

| File | Frames | Description | Alternative |
|------|--------|-------------|-------------|
| `bridge_collapse.png` | 4–6 frames | Bridge planks cracking and falling into the river | Frame-by-frame spritesheet |
| `plank_splash.png` | 3–4 frames | Small water splash when a plank lands in the river | Can skip if bridge collapse frames include splash |
| `celebration_sparkle.png` | 4–6 frames | Background sparkle / confetti burst over character | **Recommended: use `GPUParticles2D` instead — easier, looks better, no sprite needed** |

---

## Architecture Impact

**Layers touched:** `scenes/mechanics`, `scenes/worlds`, `scripts/mechanics`, `scripts/worlds`

### New files to create

```
assets/sprites/forest_bridge/          ← all sprites listed above
scenes/mechanics/gap_slot.tscn         ← reusable Area2D gap slot
scripts/mechanics/gap_slot.gd          ← occupy()/vacate(); textures exported so other worlds can reskin
scenes/mechanics/plank_drag.tscn       ← reusable draggable plank node
scripts/mechanics/plank_drag.gd        ← drag-and-drop input script
```

### Existing files to modify

| File | Change |
|------|--------|
| `scenes/mechanics/placement_mechanic.tscn` | Add `GapContainer`, `PlankSource`, `AnimationPlayer` nodes |
| `scripts/mechanics/placement_mechanic.gd` | Add dynamic gap layout, plank supply, snap logic, bounce-back |
| `scenes/worlds/forest_bridge/forest_bridge.tscn` | Add `Background`, `BridgeLayer`, `Character`, `AnimationPlayer`, `RetryPrompt` nodes |
| `scripts/worlds/forest_bridge.gd` | Await animation before advancing level; show/hide retry prompt |

### New signals required

None — existing `correct`, `incorrect`, and `count_changed` signals are sufficient. **Behaviour change:** `correct` is now emitted only by `confirm()` (via the Go button), never by `place()`. One internal signal added to `plank_drag.gd`:

- `dropped(global_position: Vector2)` — emitted by `PlankDrag` when the player releases a drag; `PlacementMechanic` listens to determine which slot (if any) was hit.

---

## Implementation Steps

### Step 1 — Create all sprite assets

Create and export all PNGs listed in "Assets to Create" above. Place them in `assets/sprites/forest_bridge/`. Godot auto-imports them when they appear in the FileSystem.

Verify: open Godot editor and confirm each file shows in the FileSystem dock with no import errors.

_Files touched:_ `assets/sprites/forest_bridge/*`

---

### Step 2 — Build `gap_slot.tscn`

Create a reusable `Area2D` scene:
- `CollisionShape2D` — `RectangleShape2D` matching `gap_slot_empty.png` dimensions
- `Sprite2D` — shows `gap_slot_empty.png` by default, swapped to `gap_slot_filled.png` when occupied
- Export `var is_occupied: bool = false`
- Method `occupy()`: sets `is_occupied = true`, swaps texture
- Method `vacate()`: sets `is_occupied = false`, restores texture

_Files touched:_ `scenes/mechanics/gap_slot.tscn`

---

### Step 3 — Build `plank_drag.tscn` + `plank_drag.gd`

Scene (`Node2D`):
- `Sprite2D` — `plank.png`
- `Sprite2D` (child, named `Shadow`) — `plank_shadow.png`, offset `(4, 8)`, hidden by default

Script responsibilities:
- Track `_origin: Vector2` (position before drag starts)
- On pointer press over sprite: begin drag, raise `z_index`, show `Shadow`
- On pointer motion: follow `global_position` of pointer
- On pointer release: emit `dropped(global_position)`, hide `Shadow`, restore `z_index`
- `bounce_back() -> void`: tween `position` back to `_origin` over 0.25 s (ease-out)

Signal: `dropped(release_position: Vector2)`

_Files touched:_ `scenes/mechanics/plank_drag.tscn`, `scripts/mechanics/plank_drag.gd`

---

### Step 4 — Update `PlacementMechanic` scene and script

**Scene additions (`placement_mechanic.tscn`):**
- `GapContainer: Node2D` — parent for dynamically instantiated `gap_slot.tscn` nodes
- `PlankSource: Node2D` — parent for dynamically instantiated `plank_drag.tscn` nodes
- `AnimationPlayer` — for any mechanic-level animations (optional; bounce-back is handled by `PlankDrag`)
- `GoButton: TextureButton` — `go_icon.png`, beside the plank supply; `pressed` → `confirm()`

**Script additions to `placement_mechanic.gd`:**

```
const GAP_SLOT_SCENE := preload("res://scenes/mechanics/gap_slot.tscn")
const PLANK_DRAG_SCENE := preload("res://scenes/mechanics/plank_drag.tscn")
const BRIDGE_WIDTH := 600.0   # pixels available for gap layout
const PLANK_SOURCE_Y := 200.0 # y-offset below bridge for the plank supply row
```

- `reset()` extension: clear all children of `GapContainer` and `PlankSource`, then call `_layout_gaps()` and `_spawn_planks()`
- `_layout_gaps()`: instantiate `target_count` gap slots, spaced evenly across `BRIDGE_WIDTH`, centered at x=0
- `_spawn_planks()`: instantiate `target_count + 1` planks in `PlankSource`, spaced evenly at `PLANK_SOURCE_Y`
- Connect each plank's `dropped` signal to `_on_plank_dropped(release_pos, plank_node)`
- `_on_plank_dropped(pos, plank)`: find nearest unoccupied gap slot within a snap radius (e.g., 60 px); if found, snap plank to slot center, lock it, call `slot.occupy()`, call `place()`; if not found, call `plank.bounce_back()`
- `place()` no longer emits `correct`; `confirm()` emits `correct` on an exact match, `incorrect` otherwise
- `set_interactive(enabled)`: enables/disables plank dragging and the Go button (the world calls this during animations — `set_process_input` on the mechanic would not reach the planks)

_Files touched:_ `scenes/mechanics/placement_mechanic.tscn`, `scripts/mechanics/placement_mechanic.gd`

---

### Step 5 — Build `ForestBridge` visual scene

Replace the minimal `forest_bridge.tscn` with a fully laid out scene:

```
ForestBridge (Node2D)
├── Background (Sprite2D)              ← bg_river.png, position (640, 360)
├── BridgeLayer (Node2D)
│   ├── LeftPlatform (Sprite2D)        ← bridge_platform.png, left bank
│   ├── RightPlatform (Sprite2D)       ← bridge_platform.png, right bank
│   └── PlacementMechanic (instance)   ← existing; positioned at bridge center y
├── Home (Sprite2D)                    ← home.png, right edge of screen
├── Character (AnimatedSprite2D)       ← SpriteFrames resource with idle/walk/celebrate/fall
│   └── (SpriteFrames defined inline)
├── AnimationPlayer                    ← orchestrates walk-across tween and celebration
├── CelebrationParticles (GPUParticles2D) ← one-shot confetti burst, process_mode = DISABLED at start
└── RetryPrompt (CanvasLayer)
    └── RetryIcon (TextureButton)      ← retry_icon.png, centered, hidden by default
```

_Files touched:_ `scenes/worlds/forest_bridge/forest_bridge.tscn`

---

### Step 6 — Update `forest_bridge.gd` for animation flow

Add `@onready` references:
```gdscript
@onready var _character: AnimatedSprite2D = $Character
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _particles: GPUParticles2D = $CelebrationParticles
@onready var _retry_prompt: Control = $RetryPrompt/RetryIcon
```

Rewrite `_on_correct()` as async:
```gdscript
func _on_correct() -> void:
    _mechanic.set_interactive(false)     # disable dragging and Go during animation
    _anim.play("walk_across")
    await _anim.animation_finished
    _character.play("celebrate")
    _particles.restart()
    await get_tree().create_timer(1.5).timeout
    if _current_index >= _levels.size() - 1:
        SaveManager.reset_progress("forest")
        world_complete.emit()
    else:
        SaveManager.save_progress("forest", _current_index + 2)
        _load_level(_current_index + 1)
```

Rewrite `_on_incorrect()`:
```gdscript
func _on_incorrect() -> void:
    _mechanic.set_interactive(false)
    _anim.play("bridge_collapse")
    await _anim.animation_finished
    _retry_prompt.visible = true
```

Add handler for retry button (connected in `_ready()`):
```gdscript
func _on_retry_pressed() -> void:
    _retry_prompt.visible = false
    _restore_stage()          # plays RESET: character back to start, bridge visible again
    _mechanic.reset()
    _mechanic.set_interactive(true)
```

`_load_level()` also calls `_restore_stage()` and `set_interactive(true)`, so each level starts with the creature on the left bank.

_Files touched:_ `scripts/worlds/forest_bridge.gd`

---

### Step 7 — Define AnimationPlayer tracks

In `forest_bridge.tscn`'s `AnimationPlayer`, define three animations:

**`RESET`**
- `PlacementMechanic:modulate` back to opaque, `Character.position` back to the left-bank start

**`walk_across`**
- `Character.position:x` — tween from left-bank start to right-bank end over ~2 s, ease-in-out
- `Character.animation` — set to `"walk"` at t=0, `"idle"` at tween end

**`bridge_collapse`**
- `PlacementMechanic:modulate.a` — fade planks and slots to 0 over 0.5 s (cheap collapse stand-in until collapse spritesheet is ready)
- `Character.animation` — set to `"fall"` at t=0
- `Character.position:y` — drop character off screen over 0.4 s
- Can be replaced with a proper `AnimatedSprite2D` collapse animation once the spritesheet asset is done

_Files touched:_ `scenes/worlds/forest_bridge/forest_bridge.tscn`

---

## Data Changes

No changes to `data/levels/` JSON files. The visual layout is driven entirely by `target_count` already present in each level's JSON. Gap slots and plank supply are instantiated dynamically from `target_count` at runtime.

---

## Test Plan

```
test_plank_drag_bounce_back_when_dropped_with_no_snap_target
test_plank_drag_dropped_signal_emitted_with_correct_position
test_placement_mechanic_snap_calls_place_when_plank_dropped_on_empty_slot
test_placement_mechanic_snap_does_not_call_place_when_slot_already_occupied
test_placement_mechanic_plank_bounces_back_when_no_slot_within_snap_radius
test_placement_mechanic_correct_emitted_after_all_slots_filled   (on confirm, not before)
test_go_button_press_calls_confirm
test_confirm_exact_target_emits_correct
test_place_exact_target_does_not_emit_correct_before_confirm
test_placement_mechanic_reset_clears_slots_and_respawns_planks
test_placement_mechanic_gap_layout_creates_n_slots_for_target_count_1
test_placement_mechanic_gap_layout_creates_n_slots_for_target_count_5
test_placement_mechanic_spawns_n_plus_1_planks_in_source
test_forest_bridge_retry_prompt_hidden_on_start
test_forest_bridge_retry_prompt_visible_after_incorrect
test_forest_bridge_retry_prompt_hidden_and_mechanic_reset_on_retry_pressed
test_forest_bridge_level_does_not_advance_until_walk_animation_finishes
test_forest_bridge_world_complete_emitted_after_last_level_animation
```

---

## Definition of Done

### Assets
- [ ] `bg_river.png` renders at 1280×720 with no stretching or seams
- [ ] `bridge_platform.png`, `gap_slot_empty.png`, `gap_slot_filled.png`, `plank.png`, `home.png`, `retry_icon.png` all present in `assets/sprites/forest_bridge/`
- [ ] All four character spritesheets (`idle`, `walk`, `celebrate`, `fall`) present and correctly framed in `SpriteFrames`
- [ ] Bridge collapse visuals present (spritesheet or AnimationPlayer tween fallback)
- [ ] Celebration effect present (`GPUParticles2D` or `celebration_sparkle.png`)

### Mechanic
- [ ] Plank follows pointer/finger while dragged
- [ ] Plank snaps visibly to nearest empty gap slot within snap radius on release
- [ ] Plank bounces back smoothly when dropped outside all slots
- [ ] `correct` signal emits only when Go is pressed with all N gaps filled (not before)
- [ ] Go pressed with gaps still open emits `incorrect`
- [ ] Gap slots render at correct positions for `target_count` = 1 through 5

### World / Animations
- [ ] Character walk animation plays on `correct` and completes before level advances
- [ ] Celebration animation + particles play after character reaches home
- [ ] Bridge collapse (or tween fallback) plays on `incorrect`
- [ ] Retry prompt (icon only, no text) appears on `incorrect`
- [ ] Tapping retry resets the mechanic and hides the prompt
- [ ] No score, stars, or difficulty labels appear anywhere on screen

### Tests & Quality
- [ ] All 15 GUT test cases pass
- [ ] `gdlint scripts/ scenes/` reports no errors
- [ ] Game runs headless without errors: `Godot --path . --headless --quit`

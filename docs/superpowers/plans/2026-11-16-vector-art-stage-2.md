# Vector Art, Stage 2 (Forest, Sky, Picnic, Memory, UI) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redraw the 55 remaining pixel-drawn sprites as sharp vector art in the style approved in stage 1,
turn the fox a little towards the viewer, and make the forest fox celebrate after it crosses the bridge.

**Architecture:** Each PNG is replaced by a hand-written SVG with the same name, folder and size, imported
as a scalable texture (`DPITexture`), so no layout changes. References in scenes, scripts and tests switch
from `.png` to `.svg`, and the PNGs and the scripts that drew them are deleted. The fox's pose changes in its
generator (`tools/make_fox_sheets.gd`), which rewrites all six sheets. The forest celebration is a one-key
fix in the forest scene's `walk_across` animation.

**Tech Stack:** Godot 4.6.2 (GDScript), GUT 9.6 for tests, SVG (rendered by Godot's built-in ThorVG), bash.

**Spec:** `docs/superpowers/specs/2026-11-16-vector-art-design.md`. This plan covers the spec's Stage 2,
including the two changes from the style checkpoint (see the spec's Context, "The fox, Pose" and "Forest
Bridge world"). Stage 1 is merged (#43); its plan is `docs/superpowers/plans/2026-11-16-vector-art-stage-1.md`.

## Global Constraints

- Every SVG has the same file name, folder and size (in SVG units) as the PNG it replaces.
- Outline: `#3D2617`, `stroke-width="3"` at natural size, `stroke-linejoin="round"`,
  `stroke-linecap="round"`.
- One highlight and one shade per shape (lighter towards the top left, darker towards the bottom right).
- No text or numbers in the art. Faces that take a label (target sign, balloon, sandbag, lift badge, card
  front) stay blank, and the blank area is at least as large as in the PNG.
- SVG features: shapes, paths, `linearGradient`, `radialGradient`, group `transform`s only. No `filter`,
  `mask`, `clipPath`, `<image>`, `<text>`, `<use>` or CSS `<style>`.
- Nine-patch pieces (`plank`, `plank_shadow`, `gap_slot_empty`, `tray`, `card_frame`) keep their end caps
  inside the current margins, and their stretched or tiled middle carries no detail that would smear or
  break at a join.
- Backgrounds use gradients and pale, soft, low-contrast distant shapes without the dark outline, so
  nothing competes with the play area. Their landmarks stay where the PNG has them (given per task).
- Sprites the game tints (`balloon`, `card_frame`) have white and grey fills only, inside the usual outline.
- World icons are free-standing objects on a transparent background, like `ui/icon_world_market.svg`.
- Fox frames are 160×160 cells in a horizontal strip; every pose leaves the two outermost columns of its
  cell empty. Frame counts, speeds and loop settings do not change.
- Not changed: gameplay, layouts, level data, sounds, the confetti, `icon.svg`, and the picnic's rule for
  when a friend is sad.
- Layer rules from `CLAUDE.md`: scenes are presentation only; mechanics get no world-specific code. The
  only script edits in this plan are sprite paths and one constant (`_HAND_OFFSET`).
- GDScript conventions from `CLAUDE.md`: type hints everywhere, `_` prefix for private members.
- Historical documents are left alone: `PLAN.md` and everything already in `docs/superpowers/plans/` and
  `docs/superpowers/specs/` except this stage's spec.
- Every commit message ends with the line `Co-Authored-By: Claude <noreply@anthropic.com>`.

## Review Focus

Conditions the spec implies and a player or a later contributor is likely to hit. Each has a test or a
named check in the task that owns it.

1. **A redrawn sprite at a different size.** Layouts would shift without any error. Test in Tasks 3–7
   (`test_sprites_redrawn_sprites_keep_their_sizes`, one entry per sprite), and Task 8 makes a sprite
   without a recorded size fail (`test_sprites_every_svg_has_a_recorded_size`).
2. **The fox goes back to idle on the next level after it celebrates.** Removing the `idle` call from
   `walk_across` must not leave the fox celebrating or walking on the next level. Test in Task 2
   (`test_forest_bridge_fox_is_idle_again_on_the_next_level`).
3. **The tomato leaves from the wrong place after the fox's arm moves.** `_HAND_OFFSET` in the market must
   follow the new release pose. Check in Task 1, Step 6 (the release screenshot).
4. **A number that no longer fits its blank face.** Two-digit bridge lengths, balloon values, sandbag
   targets and lift totals are drawn on top of the art. Check in Tasks 3 and 4 (in-game screenshots; the
   blank faces have minimum rectangles).
5. **A stretched or tiled piece that smears.** Planks of every length, the gap slot across the whole gap,
   the tray, the card frame. Check in Tasks 3, 5 and 7 (in-game screenshots).
6. **A tinted sprite drawn in colour.** A coloured balloon or card frame turns muddy when the game tints
   it. Check in Tasks 4 and 7 (in-game screenshots).
7. **A PNG or a reference to one left behind.** Test in Task 8 (`test_sprites_no_png_is_left`); a scene
   that still points at a deleted PNG fails to load, which every world's tests catch.

## Shared commands

```bash
GODOT=/Applications/Godot-2.app/Contents/MacOS/Godot
SCRATCH=/private/tmp/claude-501/-Users-matiss-Documents-kids-math-game/ba2c8d21-20fa-49f0-a7a4-08f8479f4be1/scratchpad

# Full test suite (about 95 s; -gtest is ignored by this project's config, so every run is the whole suite)
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json

# Lint and format check (gdtoolkit 4.5.0, in ~/.local/bin). gdformat reports only
# scripts/systems/level_loader.gd, as it does on main; anything else it reports is new.
gdlint scripts/ scenes/ && gdformat --check scripts/ scenes/

# Mark new SVGs as scalable and import them
tools/import_svgs.sh
```

CI (`.github/workflows/test.yml`) imports the assets and runs the tests on Linux, so every new SVG's
`.import` file must be committed with it.

Stage 1 has 536 passing tests on `main`. Each task says how many it adds.

### Helpers in the scratchpad

These throwaway scripts live in `$SCRATCH`, not the repo. They already exist; recreate one from its listing
only if it is missing. Run Godot helpers from the repo root.

| Helper | Use |
|---|---|
| `render_svg.gd` | `$GODOT --headless -s $SCRATCH/render_svg.gd -- <in.svg> <out.png> [scale]` renders one SVG on a plain green background (listing in the stage 1 plan, "Shared commands"). Paths must be absolute. |
| `contact.gd` | `$GODOT --headless -s $SCRATCH/contact.gd -- <out.png> <scale> <a.svg> [<b.svg> ...]` renders several SVGs side by side, to judge a set together. Paths must be absolute. |
| `render_fox.sh` | `$SCRATCH/render_fox.sh [scale] [suffix]` renders the six fox sheets to `$SCRATCH/fox/<animation><suffix>.png`. |
| `shot2.gd` | `$GODOT --path . -s $SCRATCH/shot2.gd -- <scene> <out_dir> [picker\|complete\|win\|share\|faces]` screenshots a world in the real game. |
| `shot.gd` | `$GODOT --path . -s $SCRATCH/shot.gd -- res://scenes/worlds/market/market.tscn <out_dir> wrong` gives a wrong answer in the market and saves a frame every 0.1 s (`wrong_00.png` …). The out dir must exist. Listing in the stage 1 plan. |
| `menu_shot.gd` | `$GODOT --path . -s $SCRATCH/menu_shot.gd -- <world_id> <out_dir>` screenshots the main menu with that world's card in the centre. Ids: `forest`, `sky`, `market`, `picnic`, `memory`. The out dir must exist. |
| `web_shot.mjs` | Screenshots the web build through headless Chrome (Task 8). |

Screenshots always come out 1920×954: the project opens maximised, and the 1280×720 play area is centred
and scaled by about 1.325. Measure positions in the SVGs, not in screenshots.

Before-screenshots, taken on `main` at f898919, are in `$SCRATCH/old/`:
`forest_bridge/{still,picker,complete,win}.png`, `sky_balloons/still.png`, `picnic/{still,share}.png`,
`memory/{still,faces}.png`, `menu/still.png`, and contact sheets of the old sprites
(`sheet_forest.png`, `sheet_sky.png`, `sheet_ui1.png`, `sheet_ui2.png`). The approved style reference is
`$SCRATCH/checkpoint/market/still.png`.

`$SCRATCH/contact.gd`:

```gdscript
extends SceneTree

# Usage: Godot --headless -s contact.gd -- <out.png> <scale> <a.svg> [<b.svg> ...]
# Renders the SVGs side by side on a plain background, to judge a set together.


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var zoom: float = float(args[1])
	var arts: Array[Image] = []
	var width: int = 8
	var height: int = 0
	for i in range(2, args.size()):
		var art := Image.new()
		if art.load_svg_from_string(FileAccess.get_file_as_string(args[i]), zoom) != OK:
			push_error("Could not render %s" % args[i])
			quit(1)
			return
		arts.append(art)
		width += art.get_width() + 8
		height = maxi(height, art.get_height())
	var out := Image.create(width, height + 16, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.6, 0.78, 0.66))
	var x: int = 8
	for art: Image in arts:
		out.blend_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), Vector2i(x, 8))
		x += art.get_width() + 8
	out.save_png(args[0])
	quit()
```

`$SCRATCH/shot2.gd`:

```gdscript
extends SceneTree

# Usage: Godot --path . --resolution 1280x720 -s shot2.gd -- <scene> <out_dir> [picker|complete|win|share|faces]
# Saves <out_dir>/still.png, or with a third argument <out_dir>/<argument>.png after:
#   picker    opening the level picker
#   complete  showing the world-complete screen
#   win       a right answer in the forest, once the fox has crossed
#   share     a share in the picnic that is one too big, once the fruit is dealt
#   faces     turning every memory card face up


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[2] if args.size() > 2 else "still"
	DirAccess.make_dir_recursive_absolute(args[1])
	change_scene_to_file(args[0])
	await create_timer(1.0).timeout
	var world: Node = current_scene
	match mode:
		"picker":
			world.get_node("LevelHud").open_picker()
			await create_timer(0.5).timeout
		"complete":
			world.get_node("LevelHud").show_world_complete()
			await create_timer(0.5).timeout
		"win":
			world.get_node("BridgeLayer/PlacementMechanic").correct.emit()
			await create_timer(2.6).timeout
		"share":
			var mechanic: Node = world.get_node("SharingMechanic")
			for order: Dictionary in mechanic.get("_orders"):
				var fair: int = int(order["total"]) / int(mechanic.get("_plates"))
				for i in fair + 1:
					var spot: Vector2 = mechanic.global_position + Vector2(-70, 100)
					mechanic.get_ready_piece(order["item"]).dropped.emit(spot)
			mechanic.confirm()
			await create_timer(1.2).timeout
		"faces":
			for card: Node in world.get_node("MemoryMechanic").get_cards():
				card.show_face(false)
			await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [args[1], mode])
	quit()
```

`$SCRATCH/menu_shot.gd`:

```gdscript
extends SceneTree

# Usage: Godot --path . --resolution 1280x720 -s menu_shot.gd -- <world_id> <out_dir>


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await create_timer(0.5).timeout
	current_scene.get_carousel().scroll_to(args[0], false)
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[1] + "/still.png")
	quit()
```

### How to draw and judge art (used by every drawing step)

Before drawing, read the style references: `assets/sprites/market/icon_tomato.svg` (the pattern for a small
object), `assets/sprites/market/crate.svg` (wood), `assets/sprites/market/bg_market.svg` (a background) and
`assets/sprites/ui/icon_world_market.svg` (a world icon). The pattern: gradients in `<defs>`; one outlined
group `<g stroke="#3D2617" stroke-width="3" stroke-linejoin="round" stroke-linecap="round">` holding the
filled shapes; highlights last, outside that group, as white shapes with `fill-opacity` about 0.35.

Then, for each sprite: render it, open the PNG with the Read tool, and check:

1. no shape is cut off by the canvas edge (an outline needs 1.5 units of room);
2. the outline is even and closed;
3. the highlight is top-left and the shade bottom-right;
4. it is recognisable at a glance at natural size (render at scale 1 as well as 4);
5. it sits with the sprites already drawn (same outline weight, same colour family);
6. everything in its row of the task's table under "Must hold" is true.

Adjust the SVG and render again until all six hold. Coordinates given in this plan are starting points
unless the table says "must hold"; the checks are the requirement. Each sprite keeps what the PNG shows
(look at the old sprite first), drawn better, not a new idea.

Backgrounds are judged in the game, not alone: after importing, take the world's screenshot and check that
every sprite still sits on its landmark and nothing in the background draws the eye away from the play area.

Background coordinates: a world's background is an 1800×1000 sprite centred on the 1280×720 play area, so
background x = scene x + 260 and background y = scene y + 140. The play area is x 260–1540, y 140–860.

## File structure

| File | Responsibility |
|---|---|
| `tools/make_fox_sheets.gd` | The fox's shoulders and the celebrate and throw poses (Task 1) |
| `assets/sprites/fox/character_*.svg` | Regenerated by the tool (Task 1) |
| `scripts/worlds/market.gd` | `_HAND_OFFSET` follows the new release pose (Task 1) |
| `scenes/worlds/forest_bridge/forest_bridge.tscn` | `walk_across` no longer plays `idle` at its end (Task 2); sprite paths (Task 3) |
| `tests/test_forest_bridge.gd` | The fox celebrates after crossing and is idle on the next level (Task 2) |
| `assets/sprites/{forest_bridge,sky_balloons,picnic,memory,ui}/*.svg` (new, 55) | The redrawn art (Tasks 3–7) |
| `tests/test_sprites.gd` | One size per redrawn sprite (Tasks 3–7); no PNG left, no SVG without a size (Task 8) |
| Scenes, scripts and tests that name a sprite | `.png` → `.svg` (Tasks 3–7; listed in each task) |
| `assets/sprites/*/README.md` | Describe the new art (Tasks 1, 3–7) |
| `docs/kids-math-game-context.md` | Art status, test count, next steps (Task 8) |
| Deleted | The 55 PNGs with their `.import` files; `tools/make_picnic_placeholders.gd`, `tools/make_memory_placeholders.gd`, `tools/make_menu_placeholders.gd`, `tools/make_mode_icons.gd`, each with its `.uid` |

Tasks 3–7 are one world's folder each and follow the same ten steps. They are independent of each other
except for three shared things, which is why the order matters: Task 3 renames the size table in
`tests/test_sprites.gd` that Tasks 4–7 append to; Task 3 draws `go_icon` and `retry_icon`, which every world
shows; Task 7 rewrites `assets/sprites/ui/README.md` in full after Tasks 3–6 have each changed one row.

---

### Task 1: The fox turned towards the viewer

**Files:**
- Modify: `tools/make_fox_sheets.gd` (constants at lines 18–19, the `celebrate` and `throw` poses, `_arm`, `_paw`)
- Modify (regenerated): `assets/sprites/fox/character_{idle,walk,celebrate,fall,sad,throw}.svg`
- Modify: `scripts/worlds/market.gd:7` (`_HAND_OFFSET`)
- Modify: `assets/sprites/fox/README.md`
- Test: `tests/test_fox_frames.gd` (existing; must stay green)

**Interfaces:**
- Consumes: the generator from stage 1. A pose is a dictionary merged over `REST`; `arm_front` and
  `arm_back` are angles in degrees ("0 hangs down, 90 points forward, 180 up; negative reaches back"),
  `reach_front` and `reach_back` lengthen an arm past `ARM_LENGTH`, and `front_arm_behind_head` draws the
  front arm under the head. In the code "front" means the near arm (drawn over the body) and "back" the far
  arm (drawn behind the body).
- Produces: sheets with the same names, cell size and frame counts. `fox_frames.tres` does not change.
  `_HAND_OFFSET` in `scripts/worlds/market.gd` holds the new release position.

**Why:** the user's note at the style checkpoint: "fox's arm looks a little bit in a weird position, maybe
it should be a little to the left on the screen, as if fox is turned a little bit towards the screen, right
now there's a sense the fox is turned away from the screen with a twisted head." The near arm hangs from
`SHOULDER_FRONT = (98, 102)`, on the chest side of a body centred at x = 78. Moving it to the tail side
turns the body towards the viewer. A trial with the shoulders swapped to (72, 102) and (100, 102) fixed the
standing pose (`$SCRATCH/arm/A/idle.png`) but broke two others, which this task retunes: in `celebrate` both
raised arms hid behind the head (`$SCRATCH/arm/A/celebrate.png`), and in the `throw` wind-up the tomato sat
on the tail (`$SCRATCH/arm/A/throw.png`).

- [ ] **Step 1: Keep the current sheets to compare against**

```bash
$SCRATCH/render_fox.sh 3 _before
```

Expected: `$SCRATCH/fox/{idle,walk,celebrate,fall,sad,throw}_before.png`. Open `idle_before.png` and
`throw_before.png` to see the pose the user described.

- [ ] **Step 2: Move the shoulders**

In `tools/make_fox_sheets.gd`, replace lines 18–19:

```gdscript
# The fox faces right, turned a little towards the viewer: the near arm (drawn over the body) hangs
# from the tail side of the belly, and the far arm (drawn behind the body) shows at the chest.
const SHOULDER_FRONT := Vector2(72, 102)
const SHOULDER_BACK := Vector2(100, 102)
```

- [ ] **Step 3: Let a held item and the measured paw follow a stretched arm**

The throw's release pose below stretches the arm with `reach_front`. Today the held tomato and `_paw` ignore
the reach. In `_arm`, change the tomato's position:

```gdscript
	if held == "tomato":
		arm += _tomato(shoulder + Vector2(0, HOLD_REACH + reach))
```

and in `_paw`, the paw's distance from the shoulder:

```gdscript
	var paw: Vector2 = (
		SHOULDER_FRONT + Vector2(sin(arm), cos(arm)) * (HOLD_REACH + pose["reach_front"])
	)
```

Both are unchanged for a pose whose reach is 0.

- [ ] **Step 4: Retune the celebrate and throw poses**

Starting values (tune them in Step 5). In `celebrate`, frames 1–3, the arms swap sides: the near arm now
rises on the tail side and the far arm on the nose side, so one paw shows on each side of the head.

| Frame | `arm_front` | `reach_front` | `front_arm_behind_head` | `arm_back` | `reach_back` |
|---|---|---|---|---|---|
| 1 | -150.0 | 28.0 | true | 150.0 | 38.0 |
| 2 | -155.0 | 30.0 | true | 148.0 | 40.0 |
| 3 | -148.0 | 26.0 | true | 147.0 | 40.0 |

Leave every other key of those frames, and frame 0, as they are.

In `throw`, the six poses become:

```gdscript
			{"lean": -4.0, "arm_front": 25.0, "held": "tomato", "brows": "cross"},
			{
				"lean": -10.0,
				"arm_front": -10.0,
				"held": "tomato",
				"brows": "cross",
				"tail": 10.0,
				"leg_back": -4.0
			},
			{"arm_front": 50.0, "held": "tomato", "brows": "cross", "leg_front": 4.0},
			{
				"lean": 8.0,
				"arm_front": 90.0,
				"reach_front": 10.0,
				"mouth": "open",
				"leg_front": 6.0
			},
			{
				"lean": 10.0,
				"head": -6.0,
				"arm_front": 115.0,
				"reach_front": 10.0,
				"mouth": "open",
				"leg_front": 6.0
			},
			{"lean": 4.0, "arm_front": 60.0},
```

- [ ] **Step 5: Generate, look at every frame, and tune**

```bash
$GODOT --path . --headless -s tools/make_fox_sheets.gd
tools/import_svgs.sh
$SCRATCH/render_fox.sh 3
```

The first command prints `Throw release, paw from the cell centre: (x, y)`; note it for Step 6. Open each of
`$SCRATCH/fox/{idle,walk,celebrate,fall,sad,throw}.png` next to its `_before` render and tune the poses
until all of these hold:

1. **Every sheet:** the fox reads as facing right with its body turned a little towards the viewer; the
   near arm hangs from the left half of the belly, and no frame looks as if the head is twisted round.
2. **Idle, walk, sad:** nothing but the arms has changed from the `_before` render, and in the walk the
   arms still swing opposite to the legs.
3. **Celebrate:** in frames 1–3 both raised paws are visible, one on each side of the head, and neither
   covers the face.
4. **Fall:** both arms still read as flung up or out; neither covers the face.
5. **Throw:** in frames 0–2 the whole tomato is visible and does not touch the tail; frames 0–1 read as a
   wind-up (leaning back, tomato low) and frame 2 as the swing; in frame 3 the paw is empty and clearly in
   front of the chest (right of the body's outline); frames 4–5 follow through and settle.
6. **Every frame:** nothing is cut off at a cell edge.

Change only pose values in `SHEETS` (and, if a paw cannot be made visible any other way, the two shoulder
x positions by a few units). Do not change `REST`'s other keys, frame counts or speeds. Regenerate and
render after each change.

- [ ] **Step 6: Point the tomato's flight at the new paw**

Copy the printed release position into `scripts/worlds/market.gd` line 7, rounded to whole units:

```gdscript
const _HAND_OFFSET := Vector2(<x>, <y>)
```

(today `Vector2(60, 36)`; the printed value is the one to use). Then watch the throw in the game:

```bash
mkdir -p $SCRATCH/shots/s2_throw
$GODOT --path . -s $SCRATCH/shot.gd -- res://scenes/worlds/market/market.tscn $SCRATCH/shots/s2_throw wrong
```

Open `wrong_00.png` to `wrong_08.png`. Expected: the tomato is in the paw during the wind-up, and on the
first frame where it flies it starts at the paw, not beside it; it then arcs to the table and the splat
shows. If it starts away from the paw, the offset was copied wrong.

- [ ] **Step 7: Run the tests**

Run the full suite. Expected: 536 pass. `test_fox_frames_every_pose_stays_inside_its_cell` fails if a raised
paw reaches a cell edge; lower that frame's reach or angle and regenerate.

- [ ] **Step 8: Look at the fox in every world**

```bash
for w in forest_bridge sky_balloons market picnic memory; do
  $GODOT --path . -s $SCRATCH/shot2.gd -- res://scenes/worlds/$w/$w.tscn $SCRATCH/shots/s2_fox_$w
done
mkdir -p $SCRATCH/shots/s2_fox_menu && $GODOT --path . -s $SCRATCH/menu_shot.gd -- forest $SCRATCH/shots/s2_fox_menu
```

Open the six `still.png` files. Expected: the fox stands where it did, the same size, turned a little
towards the viewer; in the sky world it still sits behind the basket's rim.

- [ ] **Step 9: Describe the pose in the fox README**

In `assets/sprites/fox/README.md`, add this paragraph after the sheets table (before "After any edit to
throw frame 3's pose"):

```markdown
The fox faces right, turned a little towards the viewer. In the tool, `SHOULDER_FRONT` is the near arm,
drawn over the body and hung from the tail side of the belly; `SHOULDER_BACK` is the far arm, drawn behind
the body at the chest. Moving the near shoulder to the chest side makes the body look turned away under the
head. In `celebrate` the near arm rises on the tail side and the far arm on the nose side, so a paw shows on
each side of the head.
```

- [ ] **Step 10: Lint and commit**

```bash
gdlint scripts/ scenes/ && gdformat --check scripts/ scenes/
gdformat --check tools/make_fox_sheets.gd
git add tools/make_fox_sheets.gd assets/sprites/fox scripts/worlds/market.gd
git commit -m "Turn the fox a little towards the viewer

Co-Authored-By: Claude <noreply@anthropic.com>"
```

Expected: `gdformat --check tools/make_fox_sheets.gd` is clean (run `gdformat tools/make_fox_sheets.gd` if
not). `git status` shows nothing else changed; in particular `fox_frames.tres` and the `.import` files are
unchanged.

---

### Task 2: The forest fox celebrates after crossing

**Files:**
- Modify: `scenes/worlds/forest_bridge/forest_bridge.tscn` (the `walk_across` animation,
  `[sub_resource type="Animation" id="Animation_g1bp4"]`, its `tracks/1/keys`)
- Test: `tests/test_forest_bridge.gd`

**Interfaces:**
- Consumes: `WorldBase._on_correct()` (in `scripts/worlds/world_base.gd`), which awaits the world's
  `_play_win()`, then plays `celebrate` on `Character`, waits `celebrate_duration`, and loads the next
  level; and `ForestBridge._restore_stage()`, which plays `idle` when a level loads. Neither changes.
- Produces: nothing other tasks use.

**Why:** the user's note: "at the end of crossing the bridge, the fox should celebrate, similar to other
worlds." The `walk_across` animation has a method track on `Character` with two keys: `play("walk")` at 0 s
and `play("idle")` at 2 s, the animation's end. `_play_win()` awaits `animation_finished`, and `WorldBase`
then plays `celebrate`, but the `idle` call from the last key lands after it, so the fox stands idle through
the celebration. The fix removes the second key; `WorldBase` and `_restore_stage()` already cover what it
did.

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_forest_bridge.gd`, after `test_forest_bridge_mechanic_not_interactive_during_walk`:

```gdscript
func test_forest_bridge_fox_celebrates_after_crossing() -> void:
	# A long celebration, so the check is sure to land inside it.
	_world.celebrate_duration = 5.0
	_fill_and_confirm(_mechanic)
	await wait_seconds(_SETTLE)
	assert_eq(_level_index(_world), 0, "the next level loaded before the check")
	assert_eq(_world.get_node("Character").animation, &"celebrate")


func test_forest_bridge_fox_is_idle_again_on_the_next_level() -> void:
	_fill_and_confirm(_mechanic)
	await wait_seconds(_SETTLE)
	assert_eq(_level_index(_world), 1)
	assert_eq(_world.get_node("Character").animation, &"idle")
```

- [ ] **Step 2: Run the suite to verify the first one fails**

Run the full suite. Expected: `test_forest_bridge_fox_celebrates_after_crossing` fails with the animation
being `idle`, not `celebrate`; `test_forest_bridge_fox_is_idle_again_on_the_next_level` passes (it guards
the fix, not the bug). 537 pass, 1 fails. If the first test passes before the fix, the test is not
catching the bug: stop and report that rather than changing the scene.

- [ ] **Step 3: Remove the `idle` call from the end of `walk_across`**

In `scenes/worlds/forest_bridge/forest_bridge.tscn`, inside `Animation_g1bp4`, replace:

```
tracks/1/keys = {
"times": PackedFloat32Array(0, 2),
"transitions": PackedFloat32Array(1, 1),
"values": [{
"args": [&"walk"],
"method": &"play"
}, {
"args": [&"idle"],
"method": &"play"
}]
}
```

with:

```
tracks/1/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"values": [{
"args": [&"walk"],
"method": &"play"
}]
}
```

Change nothing else in the scene. `bridge_collapse` and `RESET` keep their keys.

- [ ] **Step 4: Run the suite to verify both pass**

Run the full suite. Expected: 538 pass.

- [ ] **Step 5: Watch it**

```bash
$GODOT --path . -s $SCRATCH/shot2.gd -- res://scenes/worlds/forest_bridge/forest_bridge.tscn $SCRATCH/shots/s2_forest_win win
```

Open `$SCRATCH/shots/s2_forest_win/win.png`. Expected: the fox is on the right bank with its arms up and
the confetti showing (`$SCRATCH/old/forest_bridge/win.png` shows it standing idle there).

- [ ] **Step 6: Commit**

```bash
gdlint scripts/ scenes/ && gdformat --check tests/test_forest_bridge.gd
git add scenes/worlds/forest_bridge/forest_bridge.tscn tests/test_forest_bridge.gd
git commit -m "Make the forest fox celebrate after it crosses the bridge

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: Forest Bridge sprites

**Files:**
- Create: `assets/sprites/forest_bridge/{bg_river,bridge_platform,plank,plank_shadow,gap_slot_empty,target_sign,home,go_icon,retry_icon}.svg`,
  `assets/sprites/ui/icon_world_forest.svg`, each with its `.svg.import`
- Delete: the ten PNGs of the same names, each with its `.png.import`
- Modify (paths only): `scenes/mechanics/placement_mechanic.tscn`, `scenes/mechanics/plank_drag.tscn`,
  `scenes/ui/level_hud.tscn`, `scenes/worlds/forest_bridge/forest_bridge.tscn`,
  `scenes/worlds/market/market.tscn`, `scenes/worlds/memory/memory.tscn`, `scenes/worlds/picnic/picnic.tscn`,
  `scenes/worlds/sky_balloons/sky_balloons.tscn`, `scripts/autoloads/game_registry.gd`,
  `tests/test_world_carousel.gd`
- Modify: `tests/test_sprites.gd`, `assets/sprites/forest_bridge/README.md`, and one line each in
  `assets/sprites/{market,picnic,memory,ui}/README.md`

**Interfaces:**
- Consumes: `tools/import_svgs.sh`; `tests/test_sprites.gd` from stage 1 (`MARKET_SIZES` and
  `test_sprites_market_sprites_keep_their_sizes`).
- Produces: in `tests/test_sprites.gd`, the constant `SIZES` (a `Dictionary` from a path under
  `assets/sprites/` to its `Vector2` size) and `test_sprites_redrawn_sprites_keep_their_sizes()`. Tasks 4–7
  append entries to `SIZES`. `forest_bridge/go_icon.svg` and `forest_bridge/retry_icon.svg`, which every
  world and the HUD show.

- [ ] **Step 1: Write the failing test**

In `tests/test_sprites.gd`, rename `MARKET_SIZES` to `SIZES`, replace its comment, and add the forest
entries after the market ones:

```gdscript
# Every redrawn sprite and the size its scene was laid out around.
const SIZES := {
	"market/bg_market.svg": Vector2(1800, 1000),
	"market/table.svg": Vector2(760, 330),
	"market/crate.svg": Vector2(150, 110),
	"market/bag.svg": Vector2(96, 96),
	"market/bag_shadow.svg": Vector2(96, 96),
	"market/order_slip.svg": Vector2(200, 230),
	"market/icon_tomato.svg": Vector2(64, 64),
	"market/icon_potato.svg": Vector2(64, 64),
	"market/icon_carrot.svg": Vector2(64, 64),
	"market/splat.svg": Vector2(200, 200),
	"ui/icon_world_market.svg": Vector2(128, 128),
	"forest_bridge/bg_river.svg": Vector2(1800, 1000),
	"forest_bridge/bridge_platform.svg": Vector2(400, 80),
	"forest_bridge/plank.svg": Vector2(100, 40),
	"forest_bridge/plank_shadow.svg": Vector2(100, 20),
	"forest_bridge/gap_slot_empty.svg": Vector2(80, 80),
	"forest_bridge/target_sign.svg": Vector2(120, 100),
	"forest_bridge/home.svg": Vector2(120, 120),
	"forest_bridge/go_icon.svg": Vector2(80, 80),
	"forest_bridge/retry_icon.svg": Vector2(80, 80),
	"ui/icon_world_forest.svg": Vector2(128, 128),
}
```

and replace the market test with:

```gdscript
func test_sprites_redrawn_sprites_keep_their_sizes() -> void:
	for file: String in SIZES:
		assert_true(ResourceLoader.exists(SPRITES + file), "%s is missing" % file)
		if ResourceLoader.exists(SPRITES + file):
			var texture: Texture2D = load(SPRITES + file)
			assert_eq(texture.get_size(), SIZES[file], file)
```

- [ ] **Step 2: Run the suite to verify it fails**

Expected: `test_sprites_redrawn_sprites_keep_their_sizes` fails with ten "… is missing" messages, one per
forest file. Everything else passes.

- [ ] **Step 3: Draw the ten sprites**

Look at the old ones first (`$SCRATCH/old/sheet_forest.png`, `$SCRATCH/old/sheet_ui1.png`,
`$SCRATCH/old/forest_bridge/still.png`). Palette (base / light / dark):

| Colour | Values |
|---|---|
| Wood (as the market's) | `#9E6B3D` / `#B98552` / `#6B4524` |
| Grass | `#7A9E52` / `#96B96A` / `#5C803E` |
| Water | `#60A0B0` / `#96C8CD` / `#3F7F92` |
| Evening sky | `#FAE4AA` at the top to `#FDEFC9` at the hills |
| Far hills | `#A8BE78`, and one paler layer behind |
| Cream face | `#FFF4D6` / `#FFFBEA` / `#E8D5A8` |
| Door glow | `#FFD278` |
| Retry arrow | `#6E4828` |

| File | Size | What it shows | Must hold |
|---|---|---|---|
| `bg_river.svg` | 1800×1000 | A warm evening sky, soft far hills with a few pale trees, grass on both banks, and a river running towards the viewer between them, with a few pale ripples | The ground starts at y = 500 across the whole width. The water's edges are at x = 601 and x = 1200 (within 4 units) from y = 570 to the bottom; between them, y 500–570 is far-bank grass (the bridge sits in front of it). Darker bank strips outside the water's edges may widen towards the bottom, as now. No dark outline anywhere |
| `bridge_platform.svg` | 400×80 | A wooden deck seen from the side: a row of boards with seams | The top outline of the deck is at y = 10 (the fox walks on it); the deck ends by y = 70 and the canvas is empty below. It spans the full width |
| `plank.svg` | 100×40 | One plank with straight grain lines and a nail at each end | Nine-patch, margins 12 left and right, 8 top and bottom: the rounded ends and the nails are inside the outer 12 units; between x = 12 and x = 88 there are only horizontal lines that run the whole way across |
| `plank_shadow.svg` | 100×20 | A soft dark shadow under a dragged plank; no outline | Nine-patch, margins 12 left and right: a bar with round ends (not an ellipse), about 30% black, so the middle is the same all along |
| `gap_slot_empty.svg` | 80×80 | The empty gap in the bridge: a translucent dark panel (`#284650` at about 47%) with a pale dotted edge; no dark outline | Nine-patch, margins 12, with a tiled middle (`axis_stretch` 2): round corners inside the 12-unit corners; the dots along each edge are at 19, 33, 47 and 61, so tiles join without a gap or a double dot |
| `target_sign.svg` | 120×100 | A wooden sign on a post, with a blank cream face | The board is within x 4–115, y 4–61; the blank face covers at least x 14–105, y 12–56; the post reaches y = 99 |
| `home.svg` | 120×120 | The fox's home: a mossy mound with a round door glowing warm and a small round window | Its base is at y ≈ 119 (it stands on the platform); the door faces the viewer |
| `go_icon.svg` | 80×80 | A round green button (grass colours) with a cream triangle pointing right | The circle fills the canvas (radius about 37, centred) |
| `retry_icon.svg` | 80×80 | A round cream button with a brown arrow going round in a circle | The circle fills the canvas; the middle of the arrow's ring is empty for at least 12 units around the centre (a "1" is drawn there on the world-complete screen) |
| `ui/icon_world_forest.svg` | 128×128 | The forest world in one picture: a plank bridge over a patch of blue water, with a fir tree at each end | Free-standing shapes on a transparent background, filling the canvas to within about 4 units |

Render each one as it is drawn, at scale 4 and at scale 1:

```bash
A=$PWD/assets/sprites
$GODOT --headless -s $SCRATCH/render_svg.gd -- $A/forest_bridge/home.svg $SCRATCH/s2_home.png 4
$GODOT --headless -s $SCRATCH/render_svg.gd -- $A/forest_bridge/home.svg $SCRATCH/s2_home_1.png 1
```

and the set together, next to the market's art:

```bash
$GODOT --headless -s $SCRATCH/contact.gd -- $SCRATCH/s2_forest_set.png 2 \
  $A/forest_bridge/home.svg $A/forest_bridge/target_sign.svg $A/forest_bridge/go_icon.svg \
  $A/forest_bridge/retry_icon.svg $A/forest_bridge/plank.svg $A/forest_bridge/plank_shadow.svg \
  $A/forest_bridge/gap_slot_empty.svg $A/forest_bridge/bridge_platform.svg \
  $A/ui/icon_world_forest.svg $A/ui/icon_world_market.svg $A/market/crate.svg
```

Judge each with "How to draw and judge art" above.

- [ ] **Step 4: Import and point everything at the SVGs**

```bash
tools/import_svgs.sh
grep -rlE 'sprites/forest_bridge/[a-z_]+\.png|icon_world_forest\.png' scenes scripts tests \
  | xargs sed -i '' -E 's#(sprites/forest_bridge/[a-z_]+|icon_world_forest)\.png#\1.svg#g'
sed -i '' -E 's#forest_bridge/(go_icon|retry_icon)\.png#forest_bridge/\1.svg#g; s#icon_world_forest\.png#icon_world_forest.svg#g' \
  assets/sprites/market/README.md assets/sprites/picnic/README.md assets/sprites/memory/README.md assets/sprites/ui/README.md
grep -rnE 'uid="[^"]+" path="res://assets/sprites/(forest_bridge/|ui/icon_world_forest)' scenes
```

Expected: `import_svgs.sh` prints "Marked … as scalable" ten times. If the last `grep` prints any line,
delete the `uid="uid://…" ` attribute from that line: it is the deleted PNG's id.

- [ ] **Step 5: Delete the old sprites**

```bash
git rm -q assets/sprites/forest_bridge/*.png assets/sprites/forest_bridge/*.png.import \
  assets/sprites/ui/icon_world_forest.png assets/sprites/ui/icon_world_forest.png.import
grep -rnE 'forest_bridge/[a-z_]+\.png|icon_world_forest\.png' scenes scripts tests data assets CLAUDE.md docs/kids-math-game-context.md
```

Expected: the `grep` prints only lines from `assets/sprites/forest_bridge/README.md`, which Step 8 rewrites.

- [ ] **Step 6: Run the full suite**

```bash
$GODOT --path . --headless --import
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json
```

Expected: 538 pass, and the import prints no error about a missing resource.

- [ ] **Step 7: Look at the forest in the game**

```bash
S=res://scenes/worlds/forest_bridge/forest_bridge.tscn
for m in still picker complete win; do
  $GODOT --path . -s $SCRATCH/shot2.gd -- $S $SCRATCH/shots/s2_forest $m
done
$GODOT --path . -s $SCRATCH/shot2.gd -- res://scenes/worlds/market/market.tscn $SCRATCH/shots/s2_forest_market
mkdir -p $SCRATCH/shots/s2_forest_menu && $GODOT --path . -s $SCRATCH/menu_shot.gd -- forest $SCRATCH/shots/s2_forest_menu
```

Open each next to its before-shot in `$SCRATCH/old/forest_bridge/` and check:

1. the platforms meet the river's banks, the fox stands on the deck (feet on the top line, not in it or
   above it), and the home stands on the right platform;
2. the gap between the platforms shows the gap slot as one even panel with an unbroken dotted edge;
3. planks of different lengths in the pile have clean ends and straight grain, with no smeared nail;
4. the bridge length on the sign is fully on the cream face;
5. the Go button reads clearly on the forest and on the market (`s2_forest_market/still.png`);
6. on the world-complete screen (`complete.png`) the "1" sits inside the retry arrow's ring;
7. the forest icon reads in the badge (small), in the picker's tab and on the menu card (large);
8. nothing in the background is as strong as the planks, the sign or the fox.

Fix the SVG and repeat from `tools/import_svgs.sh` until all eight hold.

- [ ] **Step 8: Rewrite the forest README**

Replace `assets/sprites/forest_bridge/README.md` with:

```markdown
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
```

- [ ] **Step 9: Lint**

```bash
gdlint scripts/ scenes/ && gdformat --check scripts/ scenes/ && gdformat --check tests/test_sprites.gd
```

- [ ] **Step 10: Commit**

```bash
git add -A scenes scripts tests assets/sprites
git status --short
git commit -m "Redraw the Forest Bridge sprites as vector art

Co-Authored-By: Claude <noreply@anthropic.com>"
```

Expected before committing: `git status --short` lists only files under `scenes/`, `scripts/`, `tests/` and
`assets/sprites/`, with ten new `.svg` and ten new `.svg.import` files.

---

### Task 4: Sky Balloons sprites

**Files:**
- Create: `assets/sprites/sky_balloons/{bg_sky,cloud,balloon,basket,sandbag,lift_badge}.svg`,
  `assets/sprites/ui/icon_world_sky.svg`, each with its `.svg.import`
- Delete: the seven PNGs of the same names, each with its `.png.import`
- Modify (paths only): `scenes/mechanics/balloon_pop_mechanic.tscn`, `scenes/mechanics/balloon.tscn`,
  `scenes/worlds/sky_balloons/sky_balloons.tscn`, `scripts/autoloads/game_registry.gd`
- Modify: `tests/test_sprites.gd`, `assets/sprites/sky_balloons/README.md`, one row of
  `assets/sprites/ui/README.md`

**Interfaces:**
- Consumes: `SIZES` and `test_sprites_redrawn_sprites_keep_their_sizes()` in `tests/test_sprites.gd`
  (Task 3).
- Produces: nothing other tasks use.

- [ ] **Step 1: Write the failing test**

Append to `SIZES` in `tests/test_sprites.gd`:

```gdscript
	"sky_balloons/bg_sky.svg": Vector2(1800, 1000),
	"sky_balloons/cloud.svg": Vector2(300, 140),
	"sky_balloons/balloon.svg": Vector2(128, 150),
	"sky_balloons/basket.svg": Vector2(150, 90),
	"sky_balloons/sandbag.svg": Vector2(120, 120),
	"sky_balloons/lift_badge.svg": Vector2(120, 120),
	"ui/icon_world_sky.svg": Vector2(128, 128),
```

- [ ] **Step 2: Run the suite to verify it fails**

Expected: `test_sprites_redrawn_sprites_keep_their_sizes` fails with seven "… is missing" messages.

- [ ] **Step 3: Draw the seven sprites**

Look at the old ones first (`$SCRATCH/old/sheet_sky.png`, `$SCRATCH/old/sheet_ui1.png`,
`$SCRATCH/old/sky_balloons/still.png`). Palette (base / light / dark):

| Colour | Values |
|---|---|
| Sky | `#78B4EB` at the top, `#A5CFF2` in the middle, `#D1EAF9` at the bottom |
| Cloud | `#FFFFFF` with a `#DCEAF5` shade underneath |
| Balloon | `#FFFFFF` to `#CFCFCF` (grey only: the game tints it) |
| Wicker | `#B07840` / `#C99658` / `#825428` |
| Sack | `#C4A06E` / `#E6D0A7` (the blank face) / `#9A7A4C` |
| Badge blue | `#468CD7` / `#6FA9E6` / `#286EBE`; face `#E1F0FF` |
| Icon balloons | Tomato red `#E0382E`, leaf green `#4D9E40`, banana yellow `#F9D63F` |

| File | Size | What it shows | Must hold |
|---|---|---|---|
| `bg_sky.svg` | 1800×1000 | Open sky: the gradient, a pale sun glow in the top right corner, and a few very faint far cloud bands | No dark outline; nothing with more contrast than the old background's clouds, since the moving clouds, the balloons and the labels sit on top |
| `cloud.svg` | 300×140 | One puffy cloud, white with a pale shade along the bottom; no dark outline | Drawn as one path (not overlapping circles), with `fill-opacity` about 0.85, so it stays see-through without seams |
| `balloon.svg` | 128×150 | A white balloon with a knot below it, a white highlight top left and a grey shade bottom right | White and grey fills only. The round body is centred at (64, 62) with radius 60 including the outline; the knot is centred on x = 64 between y = 124 and y = 138 |
| `basket.svg` | 150×90 | A wicker basket, wider at the top, with a thick rim | The rim runs the full width along the top (about y 2–18): the fox sits behind it. The body ends by y = 88 |
| `sandbag.svg` | 120×120 | A tied sack hanging from a point at the top, with a lighter blank face | The sack is within x 8–112, y 6–117; the blank face covers at least x 22–98, y 28–90 |
| `lift_badge.svg` | 120×120 | A round blue badge with a point at the top, where the balloon strings meet, and a pale blank face | The ring is within x 10–110, y 2–114; the blank face covers at least x 23–98, y 26–102 |
| `ui/icon_world_sky.svg` | 128×128 | Three balloons (red, green, yellow) on strings above a small wicker basket | Free-standing shapes on a transparent background, filling the canvas to within about 4 units |

Render each at scale 4 and scale 1 with `render_svg.gd`, and the set together:

```bash
A=$PWD/assets/sprites
$GODOT --headless -s $SCRATCH/contact.gd -- $SCRATCH/s2_sky_set.png 2 \
  $A/sky_balloons/balloon.svg $A/sky_balloons/basket.svg $A/sky_balloons/cloud.svg \
  $A/sky_balloons/lift_badge.svg $A/sky_balloons/sandbag.svg $A/ui/icon_world_sky.svg \
  $A/ui/icon_world_market.svg $A/market/crate.svg
```

Judge each with "How to draw and judge art" above.

- [ ] **Step 4: Import and point everything at the SVGs**

```bash
tools/import_svgs.sh
grep -rlE 'sprites/sky_balloons/[a-z_]+\.png|icon_world_sky\.png' scenes scripts tests \
  | xargs sed -i '' -E 's#(sprites/sky_balloons/[a-z_]+|icon_world_sky)\.png#\1.svg#g'
sed -i '' -E 's#icon_world_sky\.png#icon_world_sky.svg#g' assets/sprites/ui/README.md
grep -rnE 'uid="[^"]+" path="res://assets/sprites/(sky_balloons/|ui/icon_world_sky)' scenes
```

Expected: "Marked … as scalable" seven times. Delete the `uid="uid://…" ` attribute from any line the last
`grep` prints.

- [ ] **Step 5: Delete the old sprites**

```bash
git rm -q assets/sprites/sky_balloons/*.png assets/sprites/sky_balloons/*.png.import \
  assets/sprites/ui/icon_world_sky.png assets/sprites/ui/icon_world_sky.png.import
grep -rnE 'sky_balloons/[a-z_]+\.png|icon_world_sky\.png' scenes scripts tests data assets CLAUDE.md docs/kids-math-game-context.md
```

Expected: the `grep` prints only lines from `assets/sprites/sky_balloons/README.md`.

- [ ] **Step 6: Run the full suite**

```bash
$GODOT --path . --headless --import
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json
```

Expected: 538 pass, and no error about a missing resource.

- [ ] **Step 7: Look at the sky world in the game**

```bash
S=res://scenes/worlds/sky_balloons/sky_balloons.tscn
$GODOT --path . -s $SCRATCH/shot2.gd -- $S $SCRATCH/shots/s2_sky
$GODOT --path . -s $SCRATCH/shot2.gd -- $S $SCRATCH/shots/s2_sky picker
mkdir -p $SCRATCH/shots/s2_sky_menu && $GODOT --path . -s $SCRATCH/menu_shot.gd -- sky $SCRATCH/shots/s2_sky_menu
```

Open each next to `$SCRATCH/old/sky_balloons/still.png` and check:

1. every balloon shows its own clear colour (no muddy or brown balloon), with the highlight still visible;
2. each balloon's number is fully on the balloon, and the strings still end at the knots;
3. the sandbag's target and the lift badge's total are fully on their blank faces;
4. the fox sits behind the basket's rim, as before;
5. the clouds are soft and behind everything, and nothing in the background competes with the balloons;
6. the sky icon reads in the badge, in the picker's tab and on the menu card.

Fix the SVG and repeat from `tools/import_svgs.sh` until all six hold.

- [ ] **Step 8: Rewrite the sky README**

Replace `assets/sprites/sky_balloons/README.md` with:

```markdown
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
```

- [ ] **Step 9: Lint**

```bash
gdlint scripts/ scenes/ && gdformat --check scripts/ scenes/ && gdformat --check tests/test_sprites.gd
```

- [ ] **Step 10: Commit**

```bash
git add -A scenes scripts tests assets/sprites
git status --short
git commit -m "Redraw the Sky Balloons sprites as vector art

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 5: Picnic sprites

**Files:**
- Create: `assets/sprites/picnic/{bg_picnic,tray,guest_plate,basket,icon_strawberry,icon_apple,icon_banana}.svg`,
  `assets/sprites/ui/icon_world_picnic.svg`, each with its `.svg.import`
- Delete: the eight PNGs of the same names, each with its `.png.import`;
  `tools/make_picnic_placeholders.gd` and `tools/make_picnic_placeholders.gd.uid`
- Modify (paths only): `scenes/mechanics/sharing_mechanic.tscn`, `scenes/worlds/picnic/picnic.tscn`,
  `scripts/autoloads/game_registry.gd`, `tests/test_fruit_drag.gd`, `tests/test_sharing_mechanic.gd`
- Modify: `tests/test_sprites.gd`, `assets/sprites/picnic/README.md`, one row of
  `assets/sprites/ui/README.md`

**Interfaces:**
- Consumes: `SIZES` and `test_sprites_redrawn_sprites_keep_their_sizes()` in `tests/test_sprites.gd`
  (Task 3).
- Produces: nothing other tasks use.

- [ ] **Step 1: Write the failing test**

Append to `SIZES` in `tests/test_sprites.gd`:

```gdscript
	"picnic/bg_picnic.svg": Vector2(1800, 1000),
	"picnic/tray.svg": Vector2(640, 260),
	"picnic/guest_plate.svg": Vector2(170, 100),
	"picnic/basket.svg": Vector2(120, 80),
	"picnic/icon_strawberry.svg": Vector2(64, 64),
	"picnic/icon_apple.svg": Vector2(64, 64),
	"picnic/icon_banana.svg": Vector2(64, 64),
	"ui/icon_world_picnic.svg": Vector2(128, 128),
```

- [ ] **Step 2: Run the suite to verify it fails**

Expected: `test_sprites_redrawn_sprites_keep_their_sizes` fails with eight "… is missing" messages.

- [ ] **Step 3: Draw the eight sprites**

Look at the old ones first (`$SCRATCH/old/sheet_sky.png`, `$SCRATCH/old/sheet_ui1.png`,
`$SCRATCH/old/picnic/still.png`). Palette (base / light / dark):

| Colour | Values |
|---|---|
| Sky | `#ADD8F2`, paler towards the horizon |
| Meadow | `#8CC160` / `#A6D47C` / `#72A84C` |
| Blanket | red `#DB5147`, cream `#F9EDD6` |
| Plate | `#F9F7ED` inside, rim `#CCC1AD`, shade `#B5A88F` |
| Wicker | `#CC9951` / `#E0B470` / `#996B33` |
| Strawberry | `#E53338` / `#F4665E` / `#B81F2B`; leaves `#4C9E3F`; seeds `#F9D63F` |
| Apple (green) | `#84CC42` / `#BFEA7F` / `#5EA32B`; stalk `#6B4524`; leaf `#4C9E3F` |
| Banana | `#F9D63F` / `#FFE97A` / `#D9A91E`; tips `#6B4524` |

| File | Size | What it shows | Must hold |
|---|---|---|---|
| `bg_picnic.svg` | 1800×1000 | A sunny meadow under a pale sky, with soft far trees or hills, a few grass tufts and flowers, and a red and cream gingham blanket spread on the grass | The horizon is at y = 300. The blanket covers x 330–1480, y 420–920 (within 4 units) in 50-unit checks. The blanket may take the dark outline, like the stall in `bg_market.svg`; nothing else does. The checks can be drawn as translucent red bands crossing on cream, which gives gingham's three tones with few shapes |
| `tray.svg` | 640×260 | The fox's big plate: a cream inside with a rim | Nine-patch, margins 16: the outline and the rim are inside the outer 16 units; the inside (x 16–624, y 16–244) is plain cream with at most one soft gradient |
| `guest_plate.svg` | 170×100 | A friend's oval plate, seen from above at an angle: rim and cream inside | The outline is within x 2–168; the cream inside covers at least x 19–151, y 16–84 (the dealt fruit is drawn there) |
| `basket.svg` | 120×80 | An open wicker basket | The body is within y 12–76 |
| `icon_strawberry.svg` | 64×64 | A strawberry with a leafy top and seeds | Built like `market/icon_tomato.svg`; fills the canvas to within about 3 units; a clean outer shape (the game shows it black and see-through as a drag shadow, and small on the friends' plates) |
| `icon_apple.svg` | 64×64 | A green apple with a stalk and a leaf | As above; green, so it does not read as the strawberry or the market's tomato |
| `icon_banana.svg` | 64×64 | A banana, curved like a smile | As above |
| `ui/icon_world_picnic.svg` | 128×128 | A square of gingham blanket with a strawberry and a green apple on it | Free-standing on a transparent background, filling the canvas to within about 4 units |

Render each at scale 4 and scale 1 with `render_svg.gd`, and the set together:

```bash
A=$PWD/assets/sprites
$GODOT --headless -s $SCRATCH/contact.gd -- $SCRATCH/s2_picnic_set.png 2 \
  $A/picnic/icon_strawberry.svg $A/picnic/icon_apple.svg $A/picnic/icon_banana.svg \
  $A/market/icon_tomato.svg $A/market/icon_carrot.svg $A/picnic/basket.svg \
  $A/picnic/guest_plate.svg $A/ui/icon_world_picnic.svg $A/ui/icon_world_market.svg
```

Judge each with "How to draw and judge art" above. The three fruits must look like one family with the
market's three vegetables.

- [ ] **Step 4: Import and point everything at the SVGs**

```bash
tools/import_svgs.sh
grep -rlE 'sprites/picnic/[a-z_]+\.png|icon_world_picnic\.png' scenes scripts tests \
  | xargs sed -i '' -E 's#(sprites/picnic/[a-z_]+|icon_world_picnic)\.png#\1.svg#g'
grep -rnE 'uid="[^"]+" path="res://assets/sprites/(picnic/|ui/icon_world_picnic)' scenes
```

Expected: "Marked … as scalable" eight times. Delete the `uid="uid://…" ` attribute from any line the last
`grep` prints.

- [ ] **Step 5: Delete the old sprites and their tool**

```bash
git rm -q assets/sprites/picnic/*.png assets/sprites/picnic/*.png.import \
  assets/sprites/ui/icon_world_picnic.png assets/sprites/ui/icon_world_picnic.png.import \
  tools/make_picnic_placeholders.gd tools/make_picnic_placeholders.gd.uid
sed -i '' -E 's#\| `icon_world_picnic\.png` \| 128×128 \| Picnic world icon.*#| `icon_world_picnic.svg` | 128×128 | Picnic world icon |#' assets/sprites/ui/README.md
grep -rnE 'picnic/[a-z_]+\.png|icon_world_picnic\.png|make_picnic_placeholders' scenes scripts tests data assets tools CLAUDE.md docs/kids-math-game-context.md
```

Expected: the `grep` prints only lines from `assets/sprites/picnic/README.md`, and a comment in
`tools/make_memory_placeholders.gd` if it names the picnic tool (Task 6 deletes that file).

- [ ] **Step 6: Run the full suite**

```bash
$GODOT --path . --headless --import
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json
```

Expected: 538 pass, and no error about a missing resource.

- [ ] **Step 7: Look at the picnic in the game**

```bash
S=res://scenes/worlds/picnic/picnic.tscn
$GODOT --path . -s $SCRATCH/shot2.gd -- $S $SCRATCH/shots/s2_picnic
$GODOT --path . -s $SCRATCH/shot2.gd -- $S $SCRATCH/shots/s2_picnic share
mkdir -p $SCRATCH/shots/s2_picnic_menu && $GODOT --path . -s $SCRATCH/menu_shot.gd -- picnic $SCRATCH/shots/s2_picnic_menu
```

Open each next to `$SCRATCH/old/picnic/still.png` and `share.png` and check:

1. the tray, the plates and the friends all sit on the blanket, as before;
2. the tray's rim is even all round, with clean corners;
3. the fruit pieces in the tray and the small fruit on the friends' plates (`share.png`) are easy to tell
   apart, and each fits on its plate;
4. the baskets and the totals beside them read clearly on the blanket;
5. the same friends are sad in `share.png` as in the before-shot (the rule has not changed);
6. the picnic icon reads on the menu card and in the badge.

Fix the SVG and repeat from `tools/import_svgs.sh` until all six hold.

- [ ] **Step 8: Rewrite the picnic README**

Replace `assets/sprites/picnic/README.md` with:

```markdown
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
```

- [ ] **Step 9: Lint**

```bash
gdlint scripts/ scenes/ && gdformat --check scripts/ scenes/ && gdformat --check tests/test_sprites.gd
```

- [ ] **Step 10: Commit**

```bash
git add -A scenes scripts tests assets/sprites tools
git status --short
git commit -m "Redraw the Picnic sprites as vector art

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 6: Memory Meadow sprites

**Files:**
- Create: `assets/sprites/memory/{bg_memory,card_back,card_front}.svg`,
  `assets/sprites/memory/animal_{fox,rabbit,bear,owl,frog,hedgehog,mouse,duck,pig,cat,deer,squirrel}.svg`,
  `assets/sprites/ui/icon_world_memory.svg`, each with its `.svg.import`
- Delete: the sixteen PNGs of the same names, each with its `.png.import`;
  `tools/make_memory_placeholders.gd` and `tools/make_memory_placeholders.gd.uid`
- Modify (paths only): `scenes/mechanics/memory_card.tscn`, `scenes/worlds/memory/memory.tscn`,
  `scripts/autoloads/game_registry.gd`, `tests/test_memory_card.gd`, `tests/test_memory_mechanic.gd`
- Modify: `tests/test_sprites.gd`, `assets/sprites/memory/README.md`

**Interfaces:**
- Consumes: `SIZES` and `test_sprites_redrawn_sprites_keep_their_sizes()` in `tests/test_sprites.gd`
  (Task 3).
- Produces: nothing other tasks use.

- [ ] **Step 1: Write the failing test**

Append to `SIZES` in `tests/test_sprites.gd`:

```gdscript
	"memory/bg_memory.svg": Vector2(1800, 1000),
	"memory/card_back.svg": Vector2(160, 160),
	"memory/card_front.svg": Vector2(160, 160),
	"memory/animal_fox.svg": Vector2(128, 128),
	"memory/animal_rabbit.svg": Vector2(128, 128),
	"memory/animal_bear.svg": Vector2(128, 128),
	"memory/animal_owl.svg": Vector2(128, 128),
	"memory/animal_frog.svg": Vector2(128, 128),
	"memory/animal_hedgehog.svg": Vector2(128, 128),
	"memory/animal_mouse.svg": Vector2(128, 128),
	"memory/animal_duck.svg": Vector2(128, 128),
	"memory/animal_pig.svg": Vector2(128, 128),
	"memory/animal_cat.svg": Vector2(128, 128),
	"memory/animal_deer.svg": Vector2(128, 128),
	"memory/animal_squirrel.svg": Vector2(128, 128),
	"ui/icon_world_memory.svg": Vector2(128, 128),
```

- [ ] **Step 2: Run the suite to verify it fails**

Expected: `test_sprites_redrawn_sprites_keep_their_sizes` fails with sixteen "… is missing" messages.

- [ ] **Step 3: Draw the background, the two card sides and the fox's face**

Look at the old ones first (`$SCRATCH/old/sheet_sky.png` for the cards, `$SCRATCH/old/memory/still.png` and
`faces.png`). Palette (base / light / dark):

| Colour | Values |
|---|---|
| Sky | `#B2DBF2`, paler towards the horizon |
| Meadow | `#8CC160` / `#A6D47C` / `#72A84C`; clearing `#A8D67A`; flowers `#F9EA7F` |
| Card back | `#549351` / `#7FBF66` / `#3B7240` |
| Card front | face `#FCF4DD`, border `#D8C69E` |
| Eyes, noses | `#3D2617`, with a white glint in each eye |

| File | Size | What it shows | Must hold |
|---|---|---|---|
| `bg_memory.svg` | 1800×1000 | A meadow under a pale sky, with a lighter clearing where the cards lie and small yellow flowers around it | The board covers x 560–1510, y 170–830; the clearing covers all of it (an ellipse centred near (1040, 520) with radii about (555, 380), as now) and is plain inside: no flowers, tufts or lines under the cards. The horizon is at about y = 260 at the left and right edges and may rise as a low hill behind the clearing. No dark outline |
| `card_back.svg` | 160×160 | The face-down side: a green card with round corners and a simple leaf pattern | The outline fills the canvas (inset 1.5); the pattern is the same whichever way up the card is |
| `card_front.svg` | 160×160 | The face-up side: a cream card with a border | The same outer shape as the back; the border is inside the outer 12 units; x 12–148, y 12–148 is plain cream (the animal is drawn on top) |
| `animal_fox.svg` | 128×128 | The fox's face from the front, in the colours of the game's fox (see `assets/sprites/fox/character_idle.svg`): pointed ears, cream cheeks, dark nose | The style reference for the other eleven: a head only, facing the viewer, filling the canvas to within about 4 units, with round dark eyes with a white glint |

Render each at scale 4 and scale 1 with `render_svg.gd`.

- [ ] **Step 4: Draw the other eleven faces and the world icon**

Each animal is a head only, from the front, in the same construction as the fox's face (same eye style,
same outline, one highlight and one shade), with its own outer shape and its own main colour, so that a
child can tell any two apart by shape alone and by colour alone.

| File | Main colour (base / light / dark) | Shape that sets it apart |
|---|---|---|
| `animal_rabbit.svg` | `#EAEAF2` / `#FFFFFF` / `#C4C4D4`; inner ear `#F9B2C1` | Two long upright ears |
| `animal_bear.svg` | `#72492D` / `#8E6242` / `#553420`; muzzle `#CDA273` | Small round ears on a wide round head |
| `animal_owl.svg` | `#727FAD` / `#919CC4` / `#56628C`; beak `#F9B733` | Ear tufts, very large round eyes in pale discs, a small beak |
| `animal_frog.svg` | `#66BF4C` / `#8DD672` / `#4A9A36` | Eyes on bumps on top of a wide flat head, a long smiling mouth |
| `animal_hedgehog.svg` | spikes `#604433` / `#7A5A45` / `#49321F`; face `#EDD3A3` | A zigzag crown of spikes around a pale pointed face |
| `animal_mouse.svg` | `#B2B2B7` / `#CFCFD3` / `#8F8F96`; inner ear `#F9B2C1` | Two very large round ears, a small pink nose |
| `animal_duck.svg` | `#F9DB3F` / `#FFEC80` / `#DBB21F`; bill `#F98C26` | A round head with a wide flat orange bill and a tuft on top |
| `animal_pig.svg` | `#F9B2C1` / `#FFD0DA` / `#E08EA1` | Folded triangular ears and a big oval snout with two nostrils |
| `animal_cat.svg` | `#474751` / `#62626E` / `#33333B`; eyes `#8CD859` | Sharp triangular ears, green eyes with slit pupils, whiskers |
| `animal_deer.svg` | `#CC9960` / `#E0B47E` / `#A87842`; antlers `#8A6238` | Small antlers and leaf-shaped ears held out to the sides, a long face |
| `animal_squirrel.svg` | `#9E542D` / `#BC6E43` / `#7C3F20`; cheeks `#F8ECD0` | Tufted ears and puffed cream cheeks, with the tip of a bushy tail curling up beside the head |
| `ui/icon_world_memory.svg` | card back and card front colours | Two overlapping cards, tilted a little apart: one face down, one face up showing the fox's face. Free-standing on a transparent background |

The fox and the squirrel are both orange-brown and both have pointed ears, and the rabbit and the mouse are
both pale with big ears: make sure those two pairs differ clearly in both shape and colour.

Render all twelve faces together, on the cream of the card front, and look at them at the size a 20-card
board shows them:

```bash
A=$PWD/assets/sprites/memory
$GODOT --headless -s $SCRATCH/contact.gd -- $SCRATCH/s2_memory_set.png 1 \
  $A/animal_fox.svg $A/animal_squirrel.svg $A/animal_rabbit.svg $A/animal_mouse.svg \
  $A/animal_bear.svg $A/animal_owl.svg $A/animal_frog.svg $A/animal_hedgehog.svg \
  $A/animal_duck.svg $A/animal_pig.svg $A/animal_cat.svg $A/animal_deer.svg
```

Judge each with "How to draw and judge art" above, and the set with one more check: glance at the sheet for
a second, look away, and name all twelve.

- [ ] **Step 5: Import and point everything at the SVGs**

```bash
tools/import_svgs.sh
grep -rlE 'sprites/memory/[a-z_]+\.png|icon_world_memory\.png' scenes scripts tests \
  | xargs sed -i '' -E 's#(sprites/memory/[a-z_]+|icon_world_memory)\.png#\1.svg#g'
grep -rnE 'uid="[^"]+" path="res://assets/sprites/(memory/|ui/icon_world_memory)' scenes
```

Expected: "Marked … as scalable" sixteen times. Delete the `uid="uid://…" ` attribute from any line the
last `grep` prints.

- [ ] **Step 6: Delete the old sprites and their tool**

```bash
git rm -q assets/sprites/memory/*.png assets/sprites/memory/*.png.import \
  assets/sprites/ui/icon_world_memory.png assets/sprites/ui/icon_world_memory.png.import \
  tools/make_memory_placeholders.gd tools/make_memory_placeholders.gd.uid
grep -rnE 'memory/[a-z_]+\.png|icon_world_memory\.png|make_memory_placeholders' scenes scripts tests data assets tools CLAUDE.md docs/kids-math-game-context.md
```

Expected: the `grep` prints only lines from `assets/sprites/memory/README.md`.

- [ ] **Step 7: Run the full suite**

```bash
$GODOT --path . --headless --import
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json
```

Expected: 538 pass, and no error about a missing resource.

- [ ] **Step 8: Look at the memory world in the game**

```bash
S=res://scenes/worlds/memory/memory.tscn
$GODOT --path . -s $SCRATCH/shot2.gd -- $S $SCRATCH/shots/s2_memory
$GODOT --path . -s $SCRATCH/shot2.gd -- $S $SCRATCH/shots/s2_memory faces
mkdir -p $SCRATCH/shots/s2_memory_menu && $GODOT --path . -s $SCRATCH/menu_shot.gd -- memory $SCRATCH/shots/s2_memory_menu
```

Open each next to `$SCRATCH/old/memory/still.png` and `faces.png` and check:

1. every card lies on the clearing, and the clearing is plain behind them;
2. face-down cards (`still.png`) all look the same, with clean round corners;
3. face-up cards (`faces.png`) show each animal fully inside the card's border, and the pairs are easy to
   find at a glance;
4. the fox beside the board and the fox's face on a card look like the same animal;
5. the memory icon reads on the menu card and in the badge.

Fix the SVG and repeat from `tools/import_svgs.sh` until all five hold.

- [ ] **Step 9: Rewrite the memory README**

Replace `assets/sprites/memory/README.md` with:

```markdown
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
```

and add the memory icon's row to the table in `assets/sprites/ui/README.md`, after the picnic icon's row:

```markdown
| `icon_world_memory.svg` | 128×128 | Memory Meadow world icon |
```

- [ ] **Step 10: Lint and commit**

```bash
gdlint scripts/ scenes/ && gdformat --check scripts/ scenes/ && gdformat --check tests/test_sprites.gd
git add -A scenes scripts tests assets/sprites tools
git status --short
git commit -m "Redraw the Memory Meadow sprites as vector art

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 7: Menu and HUD sprites

**Files:**
- Create: `assets/sprites/ui/{bg_menu,card_frame,icon_arrow,icon_close,icon_easy,icon_hard,icon_home,icon_play,icon_shuffle,icon_star,icon_music_on,icon_music_off,icon_effects_on,icon_effects_off}.svg`,
  each with its `.svg.import`
- Delete: the fourteen PNGs of the same names, each with its `.png.import`;
  `tools/make_menu_placeholders.gd`, `tools/make_mode_icons.gd`, each with its `.uid`
- Modify (paths only): `scenes/ui/level_hud.tscn`, `scenes/ui/main_menu.tscn`,
  `scenes/ui/world_carousel.tscn`, `scripts/ui/level_hud.gd`, `scripts/ui/world_carousel.gd`,
  `tests/test_level_hud.gd`
- Modify: `tests/test_sprites.gd`, `assets/sprites/ui/README.md`

**Interfaces:**
- Consumes: `SIZES` and `test_sprites_redrawn_sprites_keep_their_sizes()` in `tests/test_sprites.gd`
  (Task 3); the four world icons drawn in Tasks 3–6.
- Produces: nothing other tasks use. After this task no PNG is left under `assets/sprites/`.

- [ ] **Step 1: Write the failing test**

Append to `SIZES` in `tests/test_sprites.gd`:

```gdscript
	"ui/bg_menu.svg": Vector2(1800, 1000),
	"ui/card_frame.svg": Vector2(96, 96),
	"ui/icon_arrow.svg": Vector2(128, 128),
	"ui/icon_close.svg": Vector2(128, 128),
	"ui/icon_easy.svg": Vector2(128, 128),
	"ui/icon_hard.svg": Vector2(128, 128),
	"ui/icon_home.svg": Vector2(128, 128),
	"ui/icon_play.svg": Vector2(200, 200),
	"ui/icon_shuffle.svg": Vector2(128, 128),
	"ui/icon_star.svg": Vector2(200, 200),
	"ui/icon_music_on.svg": Vector2(128, 128),
	"ui/icon_music_off.svg": Vector2(128, 128),
	"ui/icon_effects_on.svg": Vector2(128, 128),
	"ui/icon_effects_off.svg": Vector2(128, 128),
```

- [ ] **Step 2: Run the suite to verify it fails**

Expected: `test_sprites_redrawn_sprites_keep_their_sizes` fails with fourteen "… is missing" messages.

- [ ] **Step 3: Draw the fourteen sprites**

Look at the old ones first (`$SCRATCH/old/sheet_ui1.png`, `$SCRATCH/old/sheet_ui2.png`,
`$SCRATCH/old/menu/still.png`, `$SCRATCH/old/forest_bridge/picker.png` and `complete.png`). Palette
(base / light / dark):

| Colour | Values |
|---|---|
| Menu sky | `#9ED6F7` at the top to `#DCF0F9` at the hills |
| Menu hills | far `#A3D175`, near `#84C160` |
| Cream disc | `#FFF4DB` / `#FFFBEE` / `#EBD9B0` |
| Orange | `#F28C33` / `#FFA95C` / `#D06F1B` |
| Close red | `#EB6E5A` / `#F58E7D` / `#CC4F3D` |
| Pale blue disc | `#CCEAF9` / `#E6F5FC` / `#A9D3EA` |
| Hill green | `#7FBF59` / `#9BD476` / `#5E9C3C` |
| Mountain grey | `#8C847F` / `#A8A19C` / `#6B6460`; snow `#FFFFFF` |
| Note purple | `#6654B2` / `#8573CC` / `#4B3C8C` |
| Speaker grey | `#72727F` / `#9090A0` / `#55555F`; waves `#5999D8` |
| Off slash | `#D84C3F` |
| House | walls `#FFEFCC`, roof `#CC5133`, door `#8C5933` |
| Play green | `#5BB751` / `#7DCE72` / `#3F9636` |
| Shuffle blue | `#5999D8` / `#7FB4E8` / `#3D78B5` |
| Star gold | `#FFCD3C` / `#FFE27A` / `#E0A41E` |

| File | Size | What it shows | Must hold |
|---|---|---|---|
| `bg_menu.svg` | 1800×1000 | Rolling green hills under a bright sky with a few soft clouds | The far hill's top line runs between about y = 572 and y = 638 and the near hill's between about y = 680 and y = 709, as now; no dark outline; nothing with strong contrast behind the carousel (the upper half) |
| `card_frame.svg` | 96×96 | A white panel with round corners and the dark outline | Drawn through a `StyleBoxTexture` with 24-unit margins and tinted by the carousel: plain white fill (no gradient, no highlight), corners inside the outer 24 units, the outline 3 to 4 units wide |
| `icon_arrow.svg` | 128×128 | A cream disc with an orange triangle pointing right | The disc fills the canvas; the game flips it for the left arrow, so no detail that reads wrong mirrored |
| `icon_close.svg` | 128×128 | A red disc with a white cross | The disc fills the canvas |
| `icon_easy.svg` | 128×128 | A pale blue disc with a low green hill | The same disc as the other five mode icons |
| `icon_hard.svg` | 128×128 | The same disc with a steep grey mountain with a snow cap | Clearly taller and sharper than the hill |
| `icon_music_on.svg` | 128×128 | The same disc with a purple music note | |
| `icon_music_off.svg` | 128×128 | The same picture as `icon_music_on.svg` with a red slash across it from top left to bottom right | The note is the same shape and place as in the "on" icon |
| `icon_effects_on.svg` | 128×128 | The same disc with a grey speaker and blue sound waves | |
| `icon_effects_off.svg` | 128×128 | The same speaker without waves, with the same red slash | The speaker is the same shape and place as in the "on" icon |
| `icon_home.svg` | 128×128 | A little house: cream walls, a red roof, a brown door | Free-standing on a transparent background (no disc) |
| `icon_play.svg` | 200×200 | A green disc with a white triangle pointing right | The disc fills the canvas |
| `icon_shuffle.svg` | 128×128 | Two arrows crossing, one orange and one blue | Free-standing on a transparent background; reads at 40 px (it is also a small sticker on the level badge) |
| `icon_star.svg` | 200×200 | A gold five-pointed star with slightly rounded points | Fills the canvas to within about 6 units |

Render each at scale 2 and scale 0.5 with `render_svg.gd` (the HUD shows most of these small), and the sets
together:

```bash
A=$PWD/assets/sprites/ui
$GODOT --headless -s $SCRATCH/contact.gd -- $SCRATCH/s2_ui_set1.png 1 \
  $A/icon_easy.svg $A/icon_hard.svg $A/icon_music_on.svg $A/icon_music_off.svg \
  $A/icon_effects_on.svg $A/icon_effects_off.svg $A/icon_arrow.svg $A/icon_close.svg
$GODOT --headless -s $SCRATCH/contact.gd -- $SCRATCH/s2_ui_set2.png 1 \
  $A/icon_home.svg $A/icon_shuffle.svg $A/icon_play.svg $A/icon_star.svg $A/card_frame.svg \
  $A/icon_world_forest.svg $A/icon_world_sky.svg $A/icon_world_market.svg \
  $A/icon_world_picnic.svg $A/icon_world_memory.svg
```

Judge each with "How to draw and judge art" above.

- [ ] **Step 4: Import and point everything at the SVGs**

```bash
tools/import_svgs.sh
grep -rlE 'sprites/ui/[a-z_]+\.png' scenes scripts tests \
  | xargs sed -i '' -E 's#(sprites/ui/[a-z_]+)\.png#\1.svg#g'
grep -rnE 'uid="[^"]+" path="res://assets/sprites/ui/' scenes
```

Expected: "Marked … as scalable" fourteen times. Delete the `uid="uid://…" ` attribute from any line the
last `grep` prints that names one of this task's fourteen files.

- [ ] **Step 5: Delete the old sprites and their tools**

```bash
git rm -q assets/sprites/ui/*.png assets/sprites/ui/*.png.import \
  tools/make_menu_placeholders.gd tools/make_menu_placeholders.gd.uid \
  tools/make_mode_icons.gd tools/make_mode_icons.gd.uid
find assets/sprites -name '*.png' -o -name '*.png.import'
grep -rnE 'sprites/[a-z_/]+\.png|make_menu_placeholders|make_mode_icons' scenes scripts tests data tools CLAUDE.md docs/kids-math-game-context.md
```

Expected: `find` prints nothing, and the `grep` prints nothing.

- [ ] **Step 6: Run the full suite**

```bash
$GODOT --path . --headless --import
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json
```

Expected: 538 pass, and no error about a missing resource.

- [ ] **Step 7: Look at the menu and the HUD in the game**

```bash
for w in forest sky market picnic memory; do
  mkdir -p $SCRATCH/shots/s2_menu_$w && $GODOT --path . -s $SCRATCH/menu_shot.gd -- $w $SCRATCH/shots/s2_menu_$w
done
S=res://scenes/worlds/forest_bridge/forest_bridge.tscn
$GODOT --path . -s $SCRATCH/shot2.gd -- $S $SCRATCH/shots/s2_hud
$GODOT --path . -s $SCRATCH/shot2.gd -- $S $SCRATCH/shots/s2_hud picker
$GODOT --path . -s $SCRATCH/shot2.gd -- $S $SCRATCH/shots/s2_hud complete
```

Open each next to `$SCRATCH/old/menu/still.png`, `$SCRATCH/old/forest_bridge/picker.png` and `complete.png`
and check:

1. the menu's card frame is cream with clean round corners and an even outline, and the picker's current
   world tab is orange, not muddy;
2. the arrows, the Play button and the shuffle button read clearly on the hills, and the left arrow is the
   mirror of the right one;
3. the fox and the world card stand out against the menu background;
4. in the picker, easy and hard are told apart at a glance, and so are music and effects, on and off;
5. the home and close buttons, and the star on the world-complete screen, sit with the rest;
6. the level badge (top left of `still.png`) shows the world icon clearly at its small size;
7. all five world icons look like one set on the menu and in the picker's tabs.

Fix the SVG and repeat from `tools/import_svgs.sh` until all seven hold.

- [ ] **Step 8: Rewrite the UI README**

Replace `assets/sprites/ui/README.md` with:

```markdown
# UI sprites

Art for the level HUD (`scenes/ui/level_hud.tscn`), the main menu (`scenes/ui/main_menu.tscn`) and the
world carousel (`scenes/ui/world_carousel.tscn`). Hand-drawn SVGs, imported as scalable textures (run
`tools/import_svgs.sh` after adding one). Keep each file's name and size; `tests/test_sprites.gd` checks
the sizes.

| File | Size | Use |
|---|---|---|
| `icon_world_forest.svg` | 128×128 | Forest Bridge world icon (the level badge, and its card on the menu, in the picker and on the world-complete screen) |
| `icon_world_sky.svg` | 128×128 | Sky Balloons world icon |
| `icon_world_market.svg` | 128×128 | Market world icon |
| `icon_world_picnic.svg` | 128×128 | Picnic world icon |
| `icon_world_memory.svg` | 128×128 | Memory Meadow world icon |
| `icon_shuffle.svg` | 128×128 | Shuffle: the menu's button, the picker's tab and the badge's sticker |
| `icon_easy.svg` | 128×128 | Easy difficulty button (a hill) |
| `icon_hard.svg` | 128×128 | Hard difficulty button (a mountain) |
| `icon_music_on.svg`, `icon_music_off.svg` | 128×128 | Background sound toggle; the "off" icon is the "on" icon with a red slash |
| `icon_effects_on.svg`, `icon_effects_off.svg` | 128×128 | Sound effects toggle |
| `icon_close.svg` | 128×128 | Close the level picker |
| `icon_home.svg` | 128×128 | Home button in the picker and on the world-complete screen |
| `icon_star.svg` | 200×200 | World-complete screen |
| `icon_arrow.svg` | 128×128 | Carousel arrows; points right, flipped for left |
| `icon_play.svg` | 200×200 | Main menu Play button |
| `card_frame.svg` | 96×96 | World card frame, drawn through a `StyleBoxTexture` with 24-unit margins; plain white so the carousel can tint it |
| `bg_menu.svg` | 1800×1000 | Main menu background, with the 1280×720 play area centred |

Style: a `#3D2617` outline 3 units wide with round joins, one highlight (top left) and one shade (bottom
right) per shape, no text. World icons are free-standing objects on a transparent background. Use only
shapes, paths, gradients and transforms; Godot's SVG renderer does not handle filters, masks, text or
embedded images reliably.

The world icons are shown larger than they are drawn on the menu's centre card (about 1.8 times), where
they are slightly soft; everywhere else they are shown at or below their size.

The restart button reuses `forest_bridge/retry_icon.svg` with a "1" drawn on top.
```

- [ ] **Step 9: Lint**

```bash
gdlint scripts/ scenes/ && gdformat --check scripts/ scenes/ && gdformat --check tests/test_sprites.gd
```

- [ ] **Step 10: Commit**

```bash
git add -A scenes scripts tests assets/sprites tools
git status --short
git commit -m "Redraw the menu and HUD sprites as vector art

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 8: Guard tests, the web build and the docs

**Files:**
- Modify: `tests/test_sprites.gd`
- Modify: `docs/kids-math-game-context.md`

**Interfaces:**
- Consumes: `SIZES` in `tests/test_sprites.gd` with every sprite from Tasks 3–7; the finished art.
- Produces: nothing.

- [ ] **Step 1: Write the guard tests**

In `tests/test_sprites.gd`, replace `_svg_paths` with a helper that takes the extension, and use it in
`test_sprites_every_svg_is_scalable`:

```gdscript
func _paths(dir_path: String, extension: String) -> Array[String]:
	var paths: Array[String] = []
	for dir_name: String in DirAccess.get_directories_at(dir_path):
		paths.append_array(_paths(dir_path + dir_name + "/", extension))
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(extension):
			paths.append(dir_path + file_name)
	return paths


func test_sprites_every_svg_is_scalable() -> void:
	var paths: Array[String] = _paths(SPRITES, ".svg")
	assert_gt(paths.size(), 0, "no SVG sprites found")
	for path: String in paths:
		assert_true(load(path) is DPITexture, "%s: run tools/import_svgs.sh" % path)
```

and add two tests at the end of the file:

```gdscript
func test_sprites_no_png_is_left() -> void:
	var left: Array[String] = _paths(SPRITES, ".png")
	assert_eq(left.size(), 0, "sprites are SVGs (see the READMEs), but found %s" % [left])


func test_sprites_every_svg_has_a_recorded_size() -> void:
	for path: String in _paths(SPRITES, ".svg"):
		var file: String = path.trim_prefix(SPRITES)
		# The fox's sheets are checked frame by frame in test_fox_frames.gd.
		if not file.begins_with("fox/"):
			assert_true(SIZES.has(file), "%s: add its size to SIZES" % file)
```

Also update the file's top comment to:

```gdscript
## Checks on the sprite files themselves. Every sprite is an SVG imported as a scalable texture, or
## it turns soft when the window is stretched (tools/import_svgs.sh sets that up for a new file),
## and each keeps the size its scene was laid out around.
```

- [ ] **Step 2: Prove the guards can fail, then run the suite**

```bash
cp assets/sprites/market/icon_tomato.svg assets/sprites/market/stray.svg
touch assets/sprites/market/stray.png
tools/import_svgs.sh
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json
```

Expected: `test_sprites_no_png_is_left` fails naming `stray.png`, and
`test_sprites_every_svg_has_a_recorded_size` fails naming `market/stray.svg`. Then remove the strays and run
again:

```bash
rm -f assets/sprites/market/stray.svg assets/sprites/market/stray.svg.import assets/sprites/market/stray.png assets/sprites/market/stray.png.import
$GODOT --path . --headless --import
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json
git status --short
```

Expected: 540 pass, and `git status` shows only `tests/test_sprites.gd` changed.

- [ ] **Step 3: Run every check**

```bash
gdlint scripts/ scenes/ && gdformat --check scripts/ scenes/
gdformat --check tests/test_sprites.gd tests/test_forest_bridge.gd
$GODOT --path . --headless --quit
```

Expected: lint is clean; `gdformat` reports only `scripts/systems/level_loader.gd`; the headless run prints
no errors or missing-resource warnings.

- [ ] **Step 4: Look at every screen once more**

```bash
for w in forest_bridge sky_balloons market picnic memory; do
  $GODOT --path . -s $SCRATCH/shot2.gd -- res://scenes/worlds/$w/$w.tscn $SCRATCH/shots/s2_final_$w
done
mkdir -p $SCRATCH/shots/s2_final_menu && $GODOT --path . -s $SCRATCH/menu_shot.gd -- forest $SCRATCH/shots/s2_final_menu
```

Open the six `still.png` files together with `$SCRATCH/checkpoint/market/still.png`. Expected: the five
worlds and the menu look like one game: the same outline weight, the same softness of background, the same
fox turned a little towards the viewer. Note anything that does not in the report; fix only what is clearly
broken (a sprite off its landmark, a missing texture).

- [ ] **Step 5: Check the web build**

```bash
tools/export_web.sh
python3 -m http.server 8765 --directory build/web >/dev/null 2>&1 &
SRV=$!
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --remote-debugging-port=9333 \
  --user-data-dir=$SCRATCH/chrome-s2 about:blank >/dev/null 2>&1 &
CHROME=$!
sleep 3
mkdir -p $SCRATCH/shots/s2_web
for n in 0 1 2 3 4; do node $SCRATCH/web_shot.mjs $SCRATCH/shots/s2_web $n; done
kill $SRV $CHROME
```

`$SCRATCH/web_shot.mjs` (needs Node 22 or later):

```js
// Usage: node web_shot.mjs <out_dir> [arrow_presses]
// Needs the web build served on :8765 and headless Chrome listening on :9333.
// Saves <out_dir>/menu_<n>.png (the menu after n presses of the right arrow) and
// <out_dir>/world_<n>.png (the world the centre card starts).
import {writeFileSync} from 'node:fs';
const dir = process.argv[2], steps = Number(process.argv[3] || 0);
const tab = await (await fetch('http://localhost:9333/json/new?http://localhost:8765', {method: 'PUT'})).json();
const ws = new WebSocket(tab.webSocketDebuggerUrl);
await new Promise(r => ws.onopen = r);
let id = 0;
const pending = {};
ws.onmessage = e => { const m = JSON.parse(e.data); if (m.id && pending[m.id]) pending[m.id](m.result); };
const send = (method, params = {}) => new Promise(r => { pending[++id] = r; ws.send(JSON.stringify({id, method, params})); });
const sleep = t => new Promise(r => setTimeout(r, t));
const shot = async name => {
  const s = await send('Page.captureScreenshot', {format: 'png'});
  writeFileSync(`${dir}/${name}.png`, Buffer.from(s.data, 'base64'));
};
const press = async (x, y) => {
  for (const type of ['mousePressed', 'mouseReleased'])
    await send('Input.dispatchMouseEvent', {type, x, y, button: 'left', clickCount: 1});
};
await send('Emulation.setDeviceMetricsOverride', {width: 1280, height: 720, deviceScaleFactor: 2, mobile: false});
await sleep(20000); // the build takes a while to load
for (let i = 0; i < steps; i++) { await press(1190, 220); await sleep(1500); }
await shot(`menu_${steps}`);
await press(640, 330); // the centre card starts its world
await sleep(4000);
await shot(`world_${steps}`);
process.exit(0);
```

Open the ten screenshots. Expected: the same pictures as the desktop run, with crisp outlines at double
density, and all five worlds seen (the menu may open on the world played last, so the five runs may not
start from the forest; what matters is that every world appears once). If `tools/export_web.sh` fails
because the export templates are missing, or Chrome cannot be driven, report that the web check was not
done; do not skip it silently.

- [ ] **Step 6: Update the context doc**

In `docs/kids-math-game-context.md`:

1. In "Current state", replace the bullet that starts "Art is being redrawn as vector art" with:

   ```markdown
   - All art is vector art (issue #7; spec `docs/superpowers/specs/2026-11-16-vector-art-design.md`): hand-drawn SVGs under `assets/sprites/`, imported as scalable textures, at the sizes the scenes were laid out around. The fox's six sheets and the shared `fox_frames.tres` are written by `tools/make_fox_sheets.gd` from a table of poses; everything else is drawn by hand. Each sprite folder's README lists its files and what must not move.
   ```

2. In the bullet that starts "536 GUT tests passing", change the count to the number the suite reports now
   (540 if no task added others) and keep the date `2026-11-16`.

3. In the bullet that starts "Not yet done:", remove "the rest of the final art (issue #7, stage 2), ".

4. In "Gotchas learned", add after the bullet about sprites being SVGs imported as `DPITexture`:

   ```markdown
   - A sprite shown larger than it is drawn is slightly soft even as a scalable texture (the world icons on the menu's centre card, the memory cards on a small board). A sprite the game tints (`sky_balloons/balloon.svg`, `ui/card_frame.svg`) must stay white and grey inside its outline.
   - `tests/test_sprites.gd` fails for a PNG under `assets/sprites/`, for an SVG without the scalable import, and for an SVG whose size is not in its `SIZES` table.
   ```

5. In "Open ideas and next steps", change the bullet "Stage 2 of the vector art (#7): forest, sky, picnic,
   memory and UI. Real sounds to replace the placeholders." to "Real sounds to replace the placeholders."

6. Search the file for any other sentence that calls the art placeholders, programmer art or PNGs
   (`grep -n -i 'placeholder\|programmer\|\.png\|pixel' docs/kids-math-game-context.md`) and correct those
   that are about sprites. Leave the ones about sounds.

- [ ] **Step 7: Commit**

```bash
git add tests/test_sprites.gd docs/kids-math-game-context.md
git commit -m "Guard against stray PNGs and unsized sprites; describe the finished art

Co-Authored-By: Claude <noreply@anthropic.com>"
```

After this task the branch is ready for the whole-branch review. The pull request (title: "Vector art,
stage 2: the forest, sky, picnic, memory and menu art") is opened only when the user says to.

# Vector Art, Stage 1 (Fox, Market, Throw) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fox's and the market's pixel-drawn sprites with sharp vector art, and give the market
a real throw animation with the tomato flying in an arc.

**Architecture:** Sprites become hand-written SVG files that Godot imports as scalable textures
(`DPITexture`), at the same sizes as the PNGs they replace. The fox's six animation sheets and one shared
`SpriteFrames` resource are written by a headless tool from a table of poses, and all five worlds use that
one resource. The throw lives in the market's world script.

**Tech Stack:** Godot 4.6.2 (GDScript), GUT 9.6 for tests, SVG (rendered by Godot's built-in ThorVG),
bash for the import tool.

**Spec:** `docs/superpowers/specs/2026-11-16-vector-art-design.md`. This plan covers the spec's Stage 1
only. Stage 2 (forest, sky, picnic, memory and UI art) gets its own plan after the user's style checkpoint,
because the checkpoint may change the style rules.

## Global Constraints

- Every SVG has the same file name, folder and size (in SVG units) as the PNG it replaces.
- Outline: `#3D2617`, `stroke-width="3"` at natural size, `stroke-linejoin="round"`,
  `stroke-linecap="round"`.
- One highlight and one shade per shape (lighter towards the top left, darker towards the bottom right).
- No text or numbers in the art. Label faces (order slip, bag) stay blank.
- SVG features: shapes, paths, `linearGradient`, `radialGradient`, group `transform`s only. No `filter`,
  `mask`, `clipPath`, `<image>`, `<text>`, `<use>` or CSS `<style>`.
- Nine-patch pieces keep their end caps inside the current margins (`table.svg`: 12 units).
- Fox frames are 160×160 cells in a horizontal strip; every pose leaves the two outermost columns of its
  cell empty.
- Existing fox animations keep their frame counts, speeds and loop settings: idle 4 @ 6 fps loop, walk 6 @
  10 loop, celebrate 4 @ 8 loop, fall 3 @ 8 once, sad 4 @ 4 loop. New: throw 6 @ 10 once.
- Layer rules from `CLAUDE.md`: the throw lives in `scripts/worlds/market.gd`; mechanics are not touched
  beyond sprite paths and one default value.
- GDScript conventions from `CLAUDE.md`: type hints everywhere, `_` prefix for private members, `##` doc
  comments on public members.
- Not changed: gameplay, layouts, level data, sounds, the confetti, `icon.svg`.
- Every commit message ends with the line `Co-Authored-By: Claude <noreply@anthropic.com>`.

## Review Focus

Conditions the spec implies and a player or a later contributor is likely to hit. Each has a test or check
in the task named.

1. **A second wrong answer after a retry.** The fox must throw again from the start, and the splat must
   show again. Test in Task 5 (`test_market_wrong_again_after_retry_throws_again`).
2. **A level change while the tomato is in the air.** No tomato, splat or retry prompt may be left on the
   new level. Test in Task 5 (`test_market_level_change_during_flight_leaves_nothing_behind`).
3. **A slow frame that skips past the release frame.** The tomato must still leave the paw. Test in Task 5
   (`test_market_tomato_still_flies_if_the_release_frame_is_skipped`).
4. **A new SVG added without the scalable import.** It would look soft on a phone and nobody would notice
   on a laptop. Test in Task 2 (`test_sprites_every_svg_is_scalable`).
5. **A redrawn sprite at a different size.** Layouts would shift without any error. Test in Task 4
   (`test_sprites_market_sprites_keep_their_sizes`).

## Shared commands

```bash
GODOT=/Applications/Godot-2.app/Contents/MacOS/Godot
SCRATCH=/private/tmp/claude-501/-Users-matiss-Documents-kids-math-game/ba2c8d21-20fa-49f0-a7a4-08f8479f4be1/scratchpad

# Full test suite
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json

# One test file
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json -gtest=res://tests/test_market.gd

# Lint and format check. Neither tool is installed on this machine yet; install the version CI uses
# once with: pipx install "gdtoolkit==4.5.0"
gdlint scripts/ scenes/ && gdformat --check scripts/ scenes/
```

CI (`.github/workflows/test.yml`) imports the assets and runs the tests on Linux, so every new SVG's
`.import` file must be committed with it.

Two throwaway helpers live in the scratchpad, not the repo. Create them once, before Task 2.

`$SCRATCH/render_svg.gd` turns an SVG into a PNG on a plain background, so the art can be looked at without
opening the game:

```gdscript
extends SceneTree

# Usage: Godot --headless -s render_svg.gd -- <in.svg> <out.png> [scale]


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var zoom: float = float(args[2]) if args.size() > 2 else 2.0
	var art := Image.new()
	var err: Error = art.load_svg_from_string(FileAccess.get_file_as_string(args[0]), zoom)
	if err != OK:
		push_error("Could not render %s (error %d)" % [args[0], err])
		quit(1)
		return
	var out := Image.create(art.get_width(), art.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(Color(0.6, 0.78, 0.66))
	out.blend_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), Vector2i.ZERO)
	out.save_png(args[1])
	quit()
```

`$SCRATCH/shot.gd` opens a scene in the real game and saves screenshots; with a third argument it also gives
a wrong answer in the market and saves a frame every 0.1 s:

```gdscript
extends SceneTree

# Usage: Godot --path . --resolution 1280x720 -s shot.gd -- <scene> <out_dir> [wrong]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	change_scene_to_file(args[0])
	await create_timer(1.0).timeout
	await _shot(args[1] + "/still.png")
	if args.size() > 2:
		current_scene.get_node("MarketMechanic").confirm()
		for i in 14:
			await create_timer(0.1).timeout
			await _shot("%s/wrong_%02d.png" % [args[1], i])
	quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
```

**How to judge art (used by every drawing step):** render it, open the PNG with the Read tool, and check:
no shape is cut off by the canvas edge; the outline is even and closed; the highlight is top-left and the
shade bottom-right; it is recognisable at a glance at natural size (render at scale 1 as well as 4); it sits
with the sprites already drawn (same outline weight, same colour family). Adjust the SVG and render again
until all five hold. Coordinates given in this plan are starting points; the checks are the requirement.

## File structure

| File | Responsibility |
|---|---|
| `tools/import_svgs.sh` (new) | Marks every SVG under `assets/sprites/` as a scalable texture and runs Godot's import |
| `tools/make_fox_sheets.gd` (new) | Writes the six fox sheets and `fox_frames.tres` from a pose table |
| `assets/sprites/fox/` (new) | `character_<animation>.svg` ×6, `fox_frames.tres`, `README.md` |
| `assets/sprites/market/*.svg`, `assets/sprites/ui/icon_world_market.svg` (new) | Redrawn market art |
| `tests/test_sprites.gd` (new) | Every SVG is scalable; market sprites keep their sizes |
| `tests/test_fox_frames.gd` (new) | Shared frames match the spec; poses stay in their cells; every world uses them |
| `scripts/worlds/market.gd` | The throw: release frame, arc, splat pop |
| `scenes/worlds/*/*.tscn` (five) | Use `fox_frames.tres`; rescale the fox |
| `scripts/mechanics/sharing_mechanic.gd` | `guest_scale` default 2.0 → 0.8 |
| Deleted | `assets/sprites/forest_bridge/character_*.png`, `assets/sprites/market/*.png`, `assets/sprites/ui/icon_world_market.png` (each with its `.import`), `tools/make_fox_sad_placeholder.gd`, `tools/make_market_placeholders.gd` (each with its `.uid`) |

---

### Task 1: Import tool and the web check

**Files:**
- Create: `tools/import_svgs.sh`
- Modify: `docs/kids-math-game-context.md` (one gotcha line)

**Interfaces:**
- Produces: `tools/import_svgs.sh` — run after adding any SVG; later tasks call it instead of
  `Godot --headless --import`.
- Produces: the import decision (scalable everywhere, or a fallback) that Tasks 2–4 follow.

The desktop half of the spec's import test is done (see the spec). This task finishes it in the web build.

- [ ] **Step 1: Export the probe project for the web**

The probe project from the desktop test is at `$SCRATCH/probe/proj` (two rows of the same six nodes: top row
scalable import, bottom row normal import). Give it the game's web preset and export it:

```bash
cp export_presets.cfg "$SCRATCH/probe/proj/export_presets.cfg"
sed -i '' 's/^window\/stretch\/scale=2.0$//' "$SCRATCH/probe/proj/project.godot"
sed -i '' '/save_png/d; /get_tree().quit()/d' "$SCRATCH/probe/proj/main.gd"
mkdir -p "$SCRATCH/probe/web"
$GODOT --path "$SCRATCH/probe/proj" --headless --export-release "Web" "$SCRATCH/probe/web/index.html"
```

Expected: `index.html`, `index.wasm` and `index.pck` in `$SCRATCH/probe/web`. If the export fails because
of a preset option that names a file from the game (an icon or a custom shell), blank that option in the
copied preset and export again.

- [ ] **Step 2: Look at it in a browser**

```bash
python3 -m http.server 8765 --directory "$SCRATCH/probe/web"
```

Run that in the background, open `http://localhost:8765` with the browser tools (or ask the user to open it
if no browser tool is available), take a screenshot at the browser's normal zoom on the Retina display, then
stop the server.

Expected: both rows show every shape; the top row's outlines are crisp and the bottom row's are slightly
soft. Record which of these happened:

- **Top row sharp:** scalable import everywhere. Continue as written.
- **Top row shows but is as soft as the bottom row:** scalable import still everywhere (nothing is lost on
  the web, and desktop gains). Note it in the context doc line below.
- **Top row missing or broken:** use the normal import everywhere. In Step 3, make the tool write nothing
  and only run the import, and in Task 2 Step 1 change the test to expect `CompressedTexture2D`. Tell the
  user before continuing.

- [ ] **Step 3: Write the import tool**

Create `tools/import_svgs.sh`:

```bash
#!/usr/bin/env bash
# Marks every SVG under assets/sprites/ as a scalable texture (DPITexture), then runs Godot's import.
# Godot imports a new SVG as a fixed-size texture, which turns soft when the window is stretched, unless
# an .import file says otherwise. This writes that file for any SVG that has none yet. Run it after
# adding an SVG; tests/test_sprites.gd fails if one was missed.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot-2.app/Contents/MacOS/Godot}"
find assets/sprites -name '*.svg' | while read -r svg; do
	if [ ! -f "$svg.import" ]; then
		printf '[remap]\n\nimporter="svg"\ntype="DPITexture"\n' > "$svg.import"
		echo "Marked $svg as scalable"
	fi
done
"$GODOT" --path . --headless --import
```

```bash
chmod +x tools/import_svgs.sh
tools/import_svgs.sh
```

Expected: no "Marked" lines yet (there are no SVGs under `assets/sprites/`), and the import finishes
without errors.

- [ ] **Step 4: Record the outcome**

In `docs/kids-math-game-context.md`, add to the gotchas list (the list that ends with the fox frame cell
rule), using the sentence that matches Step 2's result:

```markdown
- Sprites are SVGs imported as `DPITexture` (importer `svg`), which re-renders them at the screen's real resolution. A new SVG imports as a fixed-size texture by default, so run `tools/import_svgs.sh` after adding one; `tests/test_sprites.gd` fails otherwise. Checked sharp at double zoom on desktop and in the web build (2026-11-16) for `Sprite2D`, `AtlasTexture`, `AnimatedSprite2D`, `NinePatchRect`, `TextureRect` and `TextureButton`.
```

- [ ] **Step 5: Commit**

```bash
git add tools/import_svgs.sh docs/kids-math-game-context.md
git commit -m "Add the SVG import tool"
```

---

### Task 2: Fox sheets and shared frames

**Files:**
- Create: `tools/make_fox_sheets.gd`
- Create (generated): `assets/sprites/fox/character_{idle,walk,celebrate,fall,sad,throw}.svg` and their
  `.import` files, `assets/sprites/fox/fox_frames.tres`
- Create: `assets/sprites/fox/README.md`
- Test: `tests/test_sprites.gd`, `tests/test_fox_frames.gd`

**Interfaces:**
- Consumes: `tools/import_svgs.sh` (Task 1).
- Produces: `res://assets/sprites/fox/fox_frames.tres`, a `SpriteFrames` with animations `idle`, `walk`,
  `celebrate`, `fall`, `sad`, `throw`. Each frame is an `AtlasTexture` over
  `res://assets/sprites/fox/character_<animation>.svg` with region `Rect2(i * 160, 0, 160, 160)`.
- Produces: the throw's release frame is frame 3; the paw's offset from the cell centre on that frame is
  printed by the tool and used as `_HAND_OFFSET` in Task 5.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_sprites.gd`:

```gdscript
extends GutTest

## Checks on the sprite files themselves. Every SVG must be imported as a scalable texture, or it turns
## soft when the window is stretched; tools/import_svgs.sh sets that up for a new file.

const SPRITES := "res://assets/sprites/"


func _svg_paths(dir_path: String) -> Array[String]:
	var paths: Array[String] = []
	for dir_name: String in DirAccess.get_directories_at(dir_path):
		paths.append_array(_svg_paths(dir_path + dir_name + "/"))
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".svg"):
			paths.append(dir_path + file_name)
	return paths


func test_sprites_every_svg_is_scalable() -> void:
	var paths: Array[String] = _svg_paths(SPRITES)
	assert_gt(paths.size(), 0, "no SVG sprites found")
	for path: String in paths:
		assert_true(load(path) is DPITexture, "%s: run tools/import_svgs.sh" % path)
```

Create `tests/test_fox_frames.gd`:

```gdscript
extends GutTest

## The fox's animations, shared by every world (assets/sprites/fox/fox_frames.tres) and built by
## tools/make_fox_sheets.gd.

const FRAMES_PATH := "res://assets/sprites/fox/fox_frames.tres"
const SHEET_PATH := "res://assets/sprites/fox/character_%s.svg"
const CELL := 160
# animation -> [frame count, frames per second, loops]
const EXPECTED := {
	"idle": [4, 6.0, true],
	"walk": [6, 10.0, true],
	"celebrate": [4, 8.0, true],
	"fall": [3, 8.0, false],
	"sad": [4, 4.0, true],
	"throw": [6, 10.0, false],
}

var _frames: SpriteFrames


func before_each() -> void:
	_frames = load(FRAMES_PATH)


func test_fox_frames_has_every_animation() -> void:
	for animation: String in EXPECTED:
		assert_true(_frames.has_animation(animation), "missing %s" % animation)
		assert_eq(_frames.get_frame_count(animation), EXPECTED[animation][0], animation)
		assert_eq(_frames.get_animation_speed(animation), EXPECTED[animation][1], animation)
		assert_eq(_frames.get_animation_loop(animation), EXPECTED[animation][2], animation)


func test_fox_frames_each_frame_is_one_cell_of_its_sheet() -> void:
	for animation: String in EXPECTED:
		var count: int = EXPECTED[animation][0]
		for i in count:
			var frame: AtlasTexture = _frames.get_frame_texture(animation, i)
			assert_eq(frame.atlas.resource_path, SHEET_PATH % animation)
			assert_eq(frame.region, Rect2(i * CELL, 0, CELL, CELL))
		var sheet: Texture2D = load(SHEET_PATH % animation)
		assert_eq(sheet.get_size(), Vector2(count * CELL, CELL), animation)


func test_fox_frames_every_pose_stays_inside_its_cell() -> void:
	# A pose that reaches its cell's edge shows up at the edge of the neighbouring frame (the stray
	# tail tip fixed in #24), so the two outermost columns of every cell must be empty.
	for animation: String in EXPECTED:
		var image := Image.new()
		var svg: String = FileAccess.get_file_as_string(SHEET_PATH % animation)
		assert_eq(image.load_svg_from_string(svg, 1.0), OK, animation)
		for i: int in EXPECTED[animation][0]:
			for x: int in [i * CELL, i * CELL + 1, (i + 1) * CELL - 2, (i + 1) * CELL - 1]:
				assert_false(
					_column_has_paint(image, x), "%s frame %d reaches column %d" % [animation, i, x]
				)


func _column_has_paint(image: Image, x: int) -> bool:
	for y in image.get_height():
		if image.get_pixel(x, y).a > 0.0:
			return true
	return false
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json -gtest=res://tests/test_sprites.gd
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json -gtest=res://tests/test_fox_frames.gd
```

Expected: `test_sprites_every_svg_is_scalable` fails with "no SVG sprites found"; the fox tests fail
because `fox_frames.tres` does not exist (a load error and null-instance failures).

- [ ] **Step 3: Write the generator**

Create `tools/make_fox_sheets.gd`:

```gdscript
extends SceneTree

## Draws the fox's animation sheets as SVG into assets/sprites/fox/, and the SpriteFrames every world
## shares (fox_frames.tres). Run from the project root:
##   Godot --path . --headless -s tools/make_fox_sheets.gd
## then tools/import_svgs.sh to import them.
##
## The fox is built from parts, and each frame is one row of pose values in SHEETS, so the frames can't
## drift apart. The fox faces right. Each frame is a CELL-sized square in a horizontal strip, and every
## pose must leave the two outermost columns of its cell empty (tests/test_fox_frames.gd checks).

const OUT := "res://assets/sprites/fox/"
const CELL := 160
# The lowest point of the feet. The feet sat on the bottom edge of the old 64 px cells, so this keeps
# the fox standing where it stood.
const BASELINE := 157.0
const SHOULDER_FRONT := Vector2(98, 102)
const SHOULDER_BACK := Vector2(64, 102)
const ARM_LENGTH := 30.0
# How far past the shoulder a held item's centre sits.
const HOLD_REACH := 36.0
# The throw frame on which the paw lets go; scripts/worlds/market.gd uses the same number.
const RELEASE_FRAME := 3

const OUTLINE := "#3D2617"
const DARK := "#4A2C1A"
const MOUTH := "#7A2B22"
const TEAR := "#7CC4F0"

# Every value a pose can set, with the fox standing at rest. Lengths are in SVG units, angles in
# degrees.
const REST := {
	"hop": 0.0,  # whole fox lifted off the ground
	"squash": 0.0,  # body and head sinking as it breathes out
	"lean": 0.0,  # whole fox tipped about its feet; positive tips forward
	"head": 0.0,  # head tilted about the neck; positive nods down
	"arm_front": 15.0,  # 0 hangs down, 90 points forward, 180 up; negative reaches back
	"arm_back": -10.0,
	"leg_front": 0.0,  # foot moved forward (+) or back (-)
	"leg_back": 0.0,
	"tail": 0.0,  # positive lifts the tail
	"eyes": "open",  # open, closed, happy, wide
	"brows": "",  # "", worried, cross
	"mouth": "smile",  # smile, open, frown
	"tears": 0.0,  # 0 for none, up to 1 as the tears run down
	"held": "",  # "" or tomato, in the front paw
}

# Each animation's speed (frames per second), whether it loops, and one pose per frame. A pose lists
# only what differs from REST.
const SHEETS := {
	"idle":
	{
		"speed": 6.0,
		"loop": true,
		"poses":
		[
			{},
			{"squash": 1.0, "tail": 3.0},
			{"squash": 2.0, "tail": 6.0},
			{"squash": 1.0, "tail": 3.0},
		],
	},
	"walk":
	{
		"speed": 10.0,
		"loop": true,
		"poses":
		[
			{"leg_front": 9.0, "leg_back": -9.0, "arm_front": -25.0, "arm_back": 30.0, "tail": 4.0},
			{
				"leg_front": 5.0,
				"leg_back": -5.0,
				"arm_front": -10.0,
				"arm_back": 15.0,
				"hop": 3.0,
				"tail": 8.0
			},
			{"arm_front": 10.0, "arm_back": 0.0, "hop": 1.0, "tail": 4.0},
			{"leg_front": -9.0, "leg_back": 9.0, "arm_front": 35.0, "arm_back": -25.0},
			{
				"leg_front": -5.0,
				"leg_back": 5.0,
				"arm_front": 20.0,
				"arm_back": -10.0,
				"hop": 3.0,
				"tail": -4.0
			},
			{"arm_front": 10.0, "arm_back": 0.0, "hop": 1.0},
		],
	},
	"celebrate":
	{
		"speed": 8.0,
		"loop": true,
		"poses":
		[
			{
				"arm_front": 105.0,
				"arm_back": -115.0,
				"eyes": "happy",
				"mouth": "open",
				"tail": 10.0
			},
			{
				"hop": 10.0,
				"arm_front": 115.0,
				"arm_back": -125.0,
				"eyes": "happy",
				"mouth": "open",
				"tail": 18.0
			},
			{
				"hop": 16.0,
				"arm_front": 120.0,
				"arm_back": -130.0,
				"eyes": "happy",
				"mouth": "open",
				"tail": 22.0
			},
			{
				"hop": 8.0,
				"arm_front": 110.0,
				"arm_back": -120.0,
				"eyes": "happy",
				"mouth": "open",
				"tail": 14.0
			},
		],
	},
	"fall":
	{
		"speed": 8.0,
		"loop": false,
		"poses":
		[
			{"eyes": "wide", "mouth": "open", "arm_front": 60.0, "arm_back": -60.0},
			{
				"lean": -8.0,
				"eyes": "wide",
				"mouth": "open",
				"arm_front": 115.0,
				"arm_back": -120.0,
				"tail": 20.0,
				"leg_front": 5.0,
				"leg_back": -5.0
			},
			{
				"lean": 6.0,
				"eyes": "wide",
				"mouth": "open",
				"arm_front": 100.0,
				"arm_back": -100.0,
				"tail": 30.0,
				"leg_front": -4.0,
				"leg_back": 4.0
			},
		],
	},
	"sad":
	{
		"speed": 4.0,
		"loop": true,
		"poses":
		[
			{
				"head": 12.0,
				"eyes": "closed",
				"brows": "worried",
				"mouth": "frown",
				"tail": -12.0,
				"arm_front": 5.0,
				"arm_back": 0.0,
				"tears": 0.15
			},
			{
				"head": 12.0,
				"squash": 1.5,
				"eyes": "closed",
				"brows": "worried",
				"mouth": "frown",
				"tail": -12.0,
				"arm_front": 5.0,
				"arm_back": 0.0,
				"tears": 0.4
			},
			{
				"head": 12.0,
				"squash": 2.5,
				"eyes": "closed",
				"brows": "worried",
				"mouth": "frown",
				"tail": -12.0,
				"arm_front": 5.0,
				"arm_back": 0.0,
				"tears": 0.7
			},
			{
				"head": 12.0,
				"squash": 1.5,
				"eyes": "closed",
				"brows": "worried",
				"mouth": "frown",
				"tail": -12.0,
				"arm_front": 5.0,
				"arm_back": 0.0,
				"tears": 1.0
			},
		],
	},
	# An underhand lob: an overarm swing would cross the fox's face.
	"throw":
	{
		"speed": 10.0,
		"loop": false,
		"poses":
		[
			{"lean": -4.0, "arm_front": -70.0, "held": "tomato", "brows": "cross"},
			{
				"lean": -10.0,
				"arm_front": -95.0,
				"held": "tomato",
				"brows": "cross",
				"tail": 10.0,
				"leg_back": -4.0
			},
			{"arm_front": 10.0, "held": "tomato", "brows": "cross"},
			{"lean": 8.0, "arm_front": 80.0, "mouth": "open", "leg_front": 6.0},
			{"lean": 10.0, "arm_front": 125.0, "mouth": "open", "leg_front": 6.0},
			{"lean": 4.0, "arm_front": 60.0},
		],
	},
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for sheet_name: String in SHEETS:
		_write("character_%s.svg" % sheet_name, _sheet(SHEETS[sheet_name]["poses"]))
	_write("fox_frames.tres", _sprite_frames())
	var release: Dictionary = REST.merged(SHEETS["throw"]["poses"][RELEASE_FRAME], true)
	print("Throw release, paw from the cell centre: ", _paw(release) - Vector2(CELL, CELL) / 2.0)
	quit()


func _write(file_name: String, text: String) -> void:
	var file := FileAccess.open(OUT + file_name, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % (OUT + file_name))
		return
	file.store_string(text)


func _n(value: float) -> String:
	return String.num(value, 2)


func _sheet(poses: Array) -> String:
	var width: int = CELL * poses.size()
	var svg: String = (
		'<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n'
		% [width, CELL, width, CELL]
	)
	svg += _defs()
	for i in poses.size():
		var pose: Dictionary = REST.merged(poses[i], true)
		svg += '<g transform="translate(%d 0)">\n%s</g>\n' % [i * CELL, _fox(pose)]
	return svg + "</svg>\n"


# Each gradient runs from a highlight at the top left to a shade at the bottom right of whatever shape
# it fills.
func _defs() -> String:
	var defs := "<defs>\n"
	for gradient: Array in [
		["fur", "#F7A058", "#D96B28"],
		["cream", "#FFF6E3", "#EFD3A8"],
		["dark", "#5E3A24", "#3A2113"],
		["tomato", "#F26B55", "#C92F22"],
	]:
		defs += (
			'<radialGradient id="%s" cx="0.35" cy="0.3" r="0.9">' % gradient[0]
			+ '<stop offset="0" stop-color="%s"/>' % gradient[1]
			+ '<stop offset="1" stop-color="%s"/>' % gradient[2]
			+ "</radialGradient>\n"
		)
	return defs + "</defs>\n"


func _fox(pose: Dictionary) -> String:
	return (
		(
			'<g transform="translate(0 %s) rotate(%s %s %s)" stroke="%s" stroke-width="3"'
			% [_n(-pose["hop"]), _n(pose["lean"]), _n(CELL / 2.0), _n(BASELINE), OUTLINE]
		)
		+ ' stroke-linejoin="round" stroke-linecap="round">\n'
		+ _tail(pose["tail"])
		+ _leg(66.0 + pose["leg_back"])
		+ _arm(SHOULDER_BACK, pose["arm_back"], "")
		+ _body(pose["squash"])
		+ _leg(90.0 + pose["leg_front"])
		+ _head(pose)
		+ _arm(SHOULDER_FRONT, pose["arm_front"], pose["held"])
		+ "</g>\n"
	)


# A fat teardrop from the lower back, swept up to the left, with a cream tip.
func _tail(lift: float) -> String:
	return (
		'<g transform="rotate(%s 56 128)">\n' % _n(lift)
		+ '<path d="M60 134 C44 142 22 136 17 116 C14 102 22 92 32 95 C30 106 42 116 60 114 Z"'
		+ ' fill="url(#fur)"/>\n'
		+ '<path d="M17 116 C14 102 22 92 32 95 C30 102 33 108 38 112 C31 119 22 120 17 116 Z"'
		+ ' fill="url(#cream)"/>\n'
		+ "</g>\n"
	)


func _leg(x: float) -> String:
	return (
		'<rect x="%s" y="134" width="13" height="%s" rx="5" fill="url(#dark)"/>\n'
		% [_n(x - 6.5), _n(BASELINE - 1.5 - 134.0)]
	)


# The body keeps its feet on the ground as it squashes: it gets shorter and a little wider.
func _body(squash: float) -> String:
	return (
		(
			'<ellipse cx="78" cy="%s" rx="%s" ry="%s" fill="url(#fur)"/>\n'
			% [_n(112.0 + squash), _n(30.0 + squash * 0.5), _n(34.0 - squash)]
		)
		+ (
			'<ellipse cx="86" cy="%s" rx="15" ry="%s" fill="url(#cream)" stroke="none"/>\n'
			% [_n(118.0 + squash), _n(19.0 - squash)]
		)
	)


func _head(pose: Dictionary) -> String:
	return (
		'<g transform="translate(0 %s) rotate(%s 84 90)">\n' % [_n(pose["squash"]), _n(pose["head"])]
		+ '<path d="M62 44 L66 12 L88 34 Z" fill="url(#fur)"/>\n'
		+ '<path d="M68 37 L70 22 L80 33 Z" fill="%s" stroke="none"/>\n' % DARK
		+ '<path d="M98 32 L116 10 L124 42 Z" fill="url(#fur)"/>\n'
		+ '<path d="M105 33 L114 21 L118 38 Z" fill="%s" stroke="none"/>\n' % DARK
		+ '<ellipse cx="92" cy="62" rx="35" ry="30" fill="url(#fur)"/>\n'
		+ '<path d="M72 78 C80 63 104 61 124 66 C130 76 122 90 104 92 C90 93 78 88 72 78 Z"'
		+ ' fill="url(#cream)" stroke="none"/>\n'
		+ '<ellipse cx="126" cy="70" rx="5.5" ry="4.5" fill="%s" stroke="none"/>\n' % OUTLINE
		+ _eyes(pose["eyes"])
		+ _brows(pose["brows"])
		+ _mouth(pose["mouth"])
		+ _tears(pose["tears"])
		+ "</g>\n"
	)


func _eyes(kind: String) -> String:
	var eyes := ""
	for at: Vector2 in [Vector2(86, 58), Vector2(109, 56)]:
		match kind:
			"closed":
				eyes += '<path d="M%s %s q5 4 10 0" fill="none"/>\n' % [_n(at.x - 5.0), _n(at.y)]
			"happy":
				eyes += (
					'<path d="M%s %s q5 -7 10 0" fill="none"/>\n' % [_n(at.x - 5.0), _n(at.y + 2.0)]
				)
			"wide":
				eyes += (
					'<circle cx="%s" cy="%s" r="7" fill="#FFFFFF" stroke-width="2"/>\n'
					% [_n(at.x), _n(at.y)]
				)
				eyes += (
					'<circle cx="%s" cy="%s" r="3" fill="%s" stroke="none"/>\n'
					% [_n(at.x + 1.0), _n(at.y), OUTLINE]
				)
			_:
				eyes += (
					'<ellipse cx="%s" cy="%s" rx="4.5" ry="5.5" fill="%s" stroke="none"/>\n'
					% [_n(at.x), _n(at.y), OUTLINE]
				)
				eyes += (
					'<circle cx="%s" cy="%s" r="1.6" fill="#FFFFFF" stroke="none"/>\n'
					% [_n(at.x + 1.5), _n(at.y - 2.0)]
				)
	return eyes


func _brows(kind: String) -> String:
	match kind:
		"worried":
			return '<path d="M79 50 L91 45 M104 44 L116 49" fill="none"/>\n'
		"cross":
			return '<path d="M79 45 L91 50 M104 49 L116 44" fill="none"/>\n'
	return ""


func _mouth(kind: String) -> String:
	match kind:
		"open":
			return '<ellipse cx="110" cy="83" rx="6" ry="5" fill="%s" stroke-width="2"/>\n' % MOUTH
		"frown":
			return '<path d="M102 85 q8 -6 16 0" fill="none"/>\n'
	return '<path d="M102 80 q8 7 16 0" fill="none"/>\n'


func _tears(amount: float) -> String:
	if amount <= 0.0:
		return ""
	var tears := ""
	for x: float in [84.0, 111.0]:
		tears += (
			'<path d="M%s %s q-4 7 0 9 q4 -2 0 -9 Z" fill="%s" stroke="none"/>\n'
			% [_n(x), _n(64.0 + amount * 16.0), TEAR]
		)
	return tears


# An arm hanging from a shoulder, turned by `angle`, with anything it holds drawn at the paw.
func _arm(shoulder: Vector2, angle: float, held: String) -> String:
	var arm: String = (
		'<g transform="rotate(%s %s %s)">\n' % [_n(-angle), _n(shoulder.x), _n(shoulder.y)]
	)
	if held == "tomato":
		arm += _tomato(shoulder + Vector2(0, HOLD_REACH))
	arm += (
		'<rect x="%s" y="%s" width="12" height="%s" rx="6" fill="url(#fur)"/>\n'
		% [_n(shoulder.x - 6.0), _n(shoulder.y - 5.0), _n(ARM_LENGTH + 5.0)]
	)
	arm += (
		'<ellipse cx="%s" cy="%s" rx="6" ry="5" fill="url(#dark)" stroke="none"/>\n'
		% [_n(shoulder.x), _n(shoulder.y + ARM_LENGTH - 5.0)]
	)
	return arm + "</g>\n"


# The tomato in the paw: the same colours as market/icon_tomato.svg, which takes over once it flies.
func _tomato(at: Vector2) -> String:
	return (
		'<circle cx="%s" cy="%s" r="14" fill="url(#tomato)"/>\n' % [_n(at.x), _n(at.y)]
		+ (
			'<path d="M%s %s l-6 -4 l5 -1 l1 -5 l1 5 l5 1 Z" fill="#4D9E40" stroke-width="2"/>\n'
			% [_n(at.x), _n(at.y - 9.0)]
		)
	)


# Where an item held in the front paw sits in the cell, for a pose.
func _paw(pose: Dictionary) -> Vector2:
	var arm: float = deg_to_rad(pose["arm_front"])
	var paw: Vector2 = SHOULDER_FRONT + Vector2(sin(arm), cos(arm)) * HOLD_REACH
	var feet := Vector2(CELL / 2.0, BASELINE)
	return feet + (paw - feet).rotated(deg_to_rad(pose["lean"])) - Vector2(0, pose["hop"])


# The shared SpriteFrames, as a text resource: one AtlasTexture per frame of every sheet.
func _sprite_frames() -> String:
	var sheets := ""
	var cells := ""
	var animations: PackedStringArray = []
	for sheet_name: String in SHEETS:
		var sheet: Dictionary = SHEETS[sheet_name]
		sheets += (
			'[ext_resource type="Texture2D" path="%scharacter_%s.svg" id="%s"]\n'
			% [OUT, sheet_name, sheet_name]
		)
		var frames: PackedStringArray = []
		for i: int in sheet["poses"].size():
			cells += (
				'[sub_resource type="AtlasTexture" id="%s_%d"]\natlas = ExtResource("%s")\n'
				% [sheet_name, i, sheet_name]
			)
			cells += "region = Rect2(%d, 0, %d, %d)\n\n" % [i * CELL, CELL, CELL]
			frames.append(
				'{\n"duration": 1.0,\n"texture": SubResource("%s_%d")\n}' % [sheet_name, i]
			)
		animations.append(
			(
				'{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
				% [", ".join(frames), str(sheet["loop"]), sheet_name, sheet["speed"]]
			)
		)
	return (
		'[gd_resource type="SpriteFrames" format=3]\n\n%s\n%s[resource]\nanimations = [%s]\n'
		% [sheets, cells, ", ".join(animations)]
	)
```

- [ ] **Step 4: Generate, import, and run the tests**

```bash
$GODOT --path . --headless -s tools/make_fox_sheets.gd
tools/import_svgs.sh
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json -gtest=res://tests/test_fox_frames.gd
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json -gtest=res://tests/test_sprites.gd
```

Expected: the tool prints `Throw release, paw from the cell centre: (59.7, 36.2)` or close to it;
`import_svgs.sh` prints six "Marked" lines; all four tests pass. If
`test_fox_frames_every_pose_stays_inside_its_cell` names a frame, pull that pose in (a smaller `lean`,
`tail` or arm angle) rather than widening the cell.

- [ ] **Step 5: Look at every frame and tune the drawing**

```bash
mkdir -p "$SCRATCH/fox"
for a in idle walk celebrate fall sad throw; do
  $GODOT --headless -s "$SCRATCH/render_svg.gd" -- "$PWD/assets/sprites/fox/character_$a.svg" "$SCRATCH/fox/$a.png" 3
done
```

Open each PNG with the Read tool and apply "How to judge art", plus these, which are specific to the fox:

- It is recognisably the same character as before: an orange fox facing right, cream muzzle, belly and tail
  tip, dark legs and ear insides. The old sheets are in `git show main:assets/sprites/forest_bridge/`.
- The face is never covered by an arm or the tomato.
- `idle` breathes gently; `walk` alternates its legs and arms; `celebrate` hops with arms out and happy
  eyes; `fall` flails with wide eyes; `sad` droops with closed eyes, worried brows and tears that run down.
- `throw` reads frame by frame as: draw back, draw back further and lean, swing through low, let go with the
  paw forward and empty, follow through, settle. The tomato is in the paw on frames 0–2 only.
- Parts join without gaps: no background showing between head and body, arm and shoulder, or tail and back.

Edit the part functions and pose values in `tools/make_fox_sheets.gd`, then re-run Step 4's commands and
this step's render, until every point holds. Keep `RELEASE_FRAME` at 3, the frame counts, speeds and loop
flags as they are, and the tests passing. Note the final "Throw release" value the tool prints for Task 5.

- [ ] **Step 6: Write the fox README**

Create `assets/sprites/fox/README.md`:

```markdown
# Fox sprites

The fox is the main character in every world. Its animation sheets are SVGs written by
`tools/make_fox_sheets.gd`, which builds the fox from parts and takes each frame from a table of poses
(`SHEETS` in that file). To change how the fox looks or moves, edit the tool and run:

    Godot --path . --headless -s tools/make_fox_sheets.gd
    tools/import_svgs.sh

Do not edit the SVGs by hand; the next run overwrites them.

| Sheet | Frames | Speed (fps) | Loops | Used by |
|---|---|---|---|---|
| `character_idle.svg` | 4 | 6 | yes | every world |
| `character_walk.svg` | 6 | 10 | yes | Forest Bridge |
| `character_celebrate.svg` | 4 | 8 | yes | every world |
| `character_fall.svg` | 3 | 8 | no | Forest Bridge, Sky Balloons |
| `character_sad.svg` | 4 | 4 | yes | Picnic (the fox and its friends) |
| `character_throw.svg` | 6 | 10 | no | Market; the paw lets go on frame 3 |

Each sheet is a horizontal strip of 160×160 cells. Every pose must leave the two outermost columns of its
cell empty, or it shows at the edge of the neighbouring frame; `tests/test_fox_frames.gd` checks this.

`fox_frames.tres` is the `SpriteFrames` resource every world's `Character` uses. The tool writes it too, so
it always matches the sheets. The cells are 2.5 times the size of the old 64 px ones, so a scene shows the
fox at 0.4 times the scale it used before (1.0 in the market, picnic and memory worlds).
```

- [ ] **Step 7: Lint and commit**

```bash
gdformat tools/make_fox_sheets.gd tests/test_sprites.gd tests/test_fox_frames.gd
gdlint tests/test_sprites.gd tests/test_fox_frames.gd
git add tools/make_fox_sheets.gd tools/make_fox_sheets.gd.uid assets/sprites/fox tests/test_sprites.gd tests/test_sprites.gd.uid tests/test_fox_frames.gd tests/test_fox_frames.gd.uid
git commit -m "Draw the fox as vector sheets built from a pose table"
```

---

### Task 3: The new fox in all five worlds

**Files:**
- Modify: `scenes/worlds/forest_bridge/forest_bridge.tscn`, `scenes/worlds/sky_balloons/sky_balloons.tscn`,
  `scenes/worlds/market/market.tscn`, `scenes/worlds/picnic/picnic.tscn`, `scenes/worlds/memory/memory.tscn`
- Modify: `scripts/mechanics/sharing_mechanic.gd:33-34` (`guest_scale` default)
- Modify: `tests/test_picnic.gd:95`, `tests/test_fox_frames.gd`
- Modify: `assets/sprites/forest_bridge/README.md`, `assets/sprites/sky_balloons/README.md`,
  `assets/sprites/picnic/README.md`, `assets/sprites/memory/README.md`
- Delete: `assets/sprites/forest_bridge/character_*.png` and `.png.import`,
  `tools/make_fox_sad_placeholder.gd` and `.uid`

**Interfaces:**
- Consumes: `res://assets/sprites/fox/fox_frames.tres` (Task 2).
- Produces: every world's `Character` (`Rig/Character` in Sky Balloons) has
  `sprite_frames = fox_frames.tres`, including the `throw` animation Task 5 plays.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_fox_frames.gd`, below `EXPECTED`:

```gdscript
# World id -> the fox's height on screen in px, which the redraw must not change.
const FOX_SIZE := {
	"forest": 64.0,
	"sky": 83.2,
	"market": 160.0,
	"picnic": 160.0,
	"memory": 160.0,
}
```

and at the end of the file:

```gdscript
func test_fox_frames_every_world_uses_the_shared_frames_at_its_old_size() -> void:
	for world: Dictionary in GameRegistry.get_worlds():
		var id: String = world["id"]
		var root: Node = load(world["scene"]).instantiate()
		var fox: AnimatedSprite2D = root.find_child("Character", true, false)
		assert_eq(fox.sprite_frames, _frames, "%s has its own copy of the fox's frames" % id)
		assert_true(FOX_SIZE.has(id), "add %s to FOX_SIZE" % id)
		assert_almost_eq(fox.scale.y * CELL, float(FOX_SIZE.get(id, 0.0)), 0.01, id)
		root.free()
```

In `tests/test_picnic.gd`, change the sad sheet's expected path:

```gdscript
	assert_eq(first.atlas.resource_path, "res://assets/sprites/fox/character_sad.svg")
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json -gtest=res://tests/test_fox_frames.gd
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json -gtest=res://tests/test_picnic.gd
```

Expected: the new fox test fails five times with "has its own copy of the fox's frames" and on the sizes;
`test_picnic_sad_animation_uses_sad_sheet_and_loops` fails on the path.

- [ ] **Step 3: Swap each scene's frames for the shared resource**

Each world scene carries its own `AtlasTexture` and `SpriteFrames` sub-resources for the fox (they are the
only `AtlasTexture`s in those scenes). Create `$SCRATCH/share_fox.py`:

```python
"""Swaps each world scene's own copy of the fox's frames for the shared fox_frames.tres."""
import re
import sys

FOX = '[ext_resource type="SpriteFrames" path="res://assets/sprites/fox/fox_frames.tres" id="fox_frames"]\n'

for path in sys.argv[1:]:
    with open(path) as scene:
        text = scene.read()
    text = re.sub(
        r'\[ext_resource type="Texture2D"[^\]\n]*forest_bridge/character_\w+\.png"[^\]\n]*\]\n', "", text
    )
    text = re.sub(
        r'\[sub_resource type="(?:AtlasTexture|SpriteFrames)"[^\]\n]*\]\n.*?\n\n', "", text, flags=re.S
    )
    text = re.sub(
        r'(sprite_frames|guest_frames) = SubResource\("[^"]+"\)', r'\1 = ExtResource("fox_frames")', text
    )
    last = list(re.finditer(r"^\[ext_resource[^\n]*\]\n", text, flags=re.M))[-1]
    text = text[: last.end()] + FOX + text[last.end() :]
    assert "AtlasTexture" not in text and "character_" not in text, path
    with open(path, "w") as scene:
        scene.write(text)
    print("Updated", path)
```

```bash
python3 "$SCRATCH/share_fox.py" scenes/worlds/forest_bridge/forest_bridge.tscn scenes/worlds/sky_balloons/sky_balloons.tscn scenes/worlds/market/market.tscn scenes/worlds/picnic/picnic.tscn scenes/worlds/memory/memory.tscn
git diff --stat scenes/
```

Expected: five "Updated" lines, and each scene loses a few hundred lines. In `git diff`, confirm nothing
other than fox ext-resources, `AtlasTexture`/`SpriteFrames` sub-resources and the `sprite_frames` /
`guest_frames` lines changed. If a scene's first line has a `load_steps=` count, delete that attribute
(Godot recomputes it).

- [ ] **Step 4: Rescale the fox**

The cells grew from 64 to 160, so each scale is multiplied by 0.4.

In `market.tscn`, `picnic.tscn` and `memory.tscn`, delete this line from the `Character` node (1.0 is the
default):

```
scale = Vector2(2.5, 2.5)
```

In `forest_bridge.tscn`, add a scale to the `Character` node, after its `position` line:

```
position = Vector2(150, 340)
scale = Vector2(0.4, 0.4)
```

In `sky_balloons.tscn`, change the `Character` node's scale:

```
scale = Vector2(0.52, 0.52)
```

In `scripts/mechanics/sharing_mechanic.gd`, change the friends' default scale:

```gdscript
## Scale of each friend's sprite.
@export var guest_scale: float = 0.8
```

Then check nothing else scales or offsets the fox in old-cell units:

```bash
grep -n 'guest_scale' scenes/ -r
grep -n 'Character:scale\|Character:offset' scenes/ -r
```

Expected: no output from either. If `guest_scale` is set in a scene, multiply that value by 0.4 too.

- [ ] **Step 5: Delete the old sheets and the sad-sheet tool**

```bash
git rm -q assets/sprites/forest_bridge/character_*.png assets/sprites/forest_bridge/character_*.png.import tools/make_fox_sad_placeholder.gd tools/make_fox_sad_placeholder.gd.uid
grep -rn 'forest_bridge/character_\|make_fox_sad' scenes scripts tests tools
```

Expected: no output from `grep`.

- [ ] **Step 6: Run the full suite**

```bash
$GODOT --path . --headless --import
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json
```

Expected: every test passes, with no "Failed loading resource" errors in the output.

- [ ] **Step 7: Look at the fox in each world**

```bash
for w in forest_bridge/forest_bridge sky_balloons/sky_balloons market/market picnic/picnic memory/memory; do
  mkdir -p "$SCRATCH/shots/$(dirname $w)"
  $GODOT --path . --resolution 1280x720 -s "$SCRATCH/shot.gd" -- "res://scenes/worlds/$w.tscn" "$SCRATCH/shots/$(dirname $w)"
done
```

Open each `still.png`. In each world the fox must be the same size as before and stand where it stood: feet on the bank in the forest, inside the basket with the rim
in front in the sky, on the ground left of the table in the market, and beside the plate and the board in
the picnic and memory worlds. The picnic's friends must be the same size relative to their plates, each
tinted its own colour.

If the feet float or sink, change `BASELINE` in `tools/make_fox_sheets.gd` (and re-run Task 2 Step 4), not
the scenes: the scenes' positions are shared with other nodes' layouts.

- [ ] **Step 8: Update the READMEs that mention the old sheets**

`assets/sprites/forest_bridge/README.md`: replace everything from "Character sheets are horizontal strips"
through "update the `SpriteFrames` on `Character` in `scenes/worlds/forest_bridge/forest_bridge.tscn`."
(lines 7–13), and remove the fox sheets' rows from the file table if it lists them, with:

```markdown
The fox is no longer in this folder: its sheets and shared animations are in `assets/sprites/fox/` (see
the README there).
```

`assets/sprites/sky_balloons/README.md`: replace "The fox reuses the Forest Bridge character sheets (idle,
celebrate, fall)." with:

```markdown
The fox uses the shared sheets in `assets/sprites/fox/` (idle, celebrate, fall).
```

`assets/sprites/picnic/README.md`: replace the sentence that starts "The fox and its friends reuse the
Forest Bridge character sheets" and the one after it about the friends being tinted copies (lines 17–19)
with:

```markdown
The fox and its friends use the shared sheets in `assets/sprites/fox/` (idle, celebrate, sad). The friends
are tinted copies of the fox; later art could give them their own animals.
```

`assets/sprites/memory/README.md`: replace "The fox beside the board reuses the Forest Bridge character
sheets (idle and celebrate)." with:

```markdown
The fox beside the board uses the shared sheets in `assets/sprites/fox/` (idle and celebrate).
```

- [ ] **Step 9: Lint and commit**

```bash
gdlint scripts/ scenes/ && gdformat --check scripts/ scenes/
git add -A scenes scripts tests assets/sprites tools
git commit -m "Use the shared vector fox in every world"
```

---

### Task 4: Market sprites

**Files:**
- Create: `assets/sprites/market/{bg_market,table,crate,bag,bag_shadow,order_slip,icon_tomato,icon_potato,icon_carrot,splat}.svg`,
  `assets/sprites/ui/icon_world_market.svg` (and their `.import` files)
- Modify: every reference to those sprites' `.png` paths (scenes, `scripts/autoloads/game_registry.gd`,
  tests)
- Modify: `tests/test_sprites.gd`, `assets/sprites/market/README.md`, `assets/sprites/ui/README.md`
- Delete: `assets/sprites/market/*.png` and `.png.import`, `assets/sprites/ui/icon_world_market.png` and
  `.import`, `tools/make_market_placeholders.gd` and `.uid`

**Interfaces:**
- Consumes: `tools/import_svgs.sh` (Task 1); the fox's tomato colours (Task 2) so the held and the flying
  tomato match.
- Produces: `res://assets/sprites/market/icon_tomato.svg` (64×64), which Task 5's flying tomato uses, and
  `res://assets/sprites/market/splat.svg` (200×200).

- [ ] **Step 1: Write the failing test**

Add to `tests/test_sprites.gd`, below `SPRITES`:

```gdscript
# The market's sprites and the sizes its layout was built around.
const MARKET_SIZES := {
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
}
```

and at the end of the file:

```gdscript
func test_sprites_market_sprites_keep_their_sizes() -> void:
	for file: String in MARKET_SIZES:
		assert_true(ResourceLoader.exists(SPRITES + file), "%s is missing" % file)
		if ResourceLoader.exists(SPRITES + file):
			var texture: Texture2D = load(SPRITES + file)
			assert_eq(texture.get_size(), MARKET_SIZES[file], file)
```

- [ ] **Step 2: Run it to verify it fails**

```bash
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json -gtest=res://tests/test_sprites.gd
```

Expected: `test_sprites_market_sprites_keep_their_sizes` fails with eleven "is missing" messages.

- [ ] **Step 3: Draw the tomato, the style reference**

Before drawing, open each PNG in `assets/sprites/market/` with the Read tool to see what it replaces.

Create `assets/sprites/market/icon_tomato.svg`. Every other sprite follows its structure: gradients in
`<defs>`, one outlined group, highlights last.

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
<defs>
<radialGradient id="skin" cx="0.36" cy="0.32" r="0.85">
<stop offset="0" stop-color="#F26B55"/>
<stop offset="1" stop-color="#C92F22"/>
</radialGradient>
</defs>
<g stroke="#3D2617" stroke-width="3" stroke-linejoin="round" stroke-linecap="round">
<path d="M32 16 C46 12 58 22 58 36 C58 50 46 59 32 59 C18 59 6 50 6 36 C6 22 18 12 32 16 Z" fill="url(#skin)"/>
<path d="M32 18 C28 13 22 11 17 13 C21 16 23 19 27 20 C24 23 23 26 24 29 C28 27 31 24 32 21 C33 24 36 27 40 29 C41 26 40 23 37 20 C41 19 43 16 47 13 C42 11 36 13 32 18 Z" fill="#4D9E40"/>
<path d="M32 18 L33 7" fill="none"/>
</g>
<ellipse cx="20" cy="31" rx="5" ry="8" fill="#FFFFFF" fill-opacity="0.35" transform="rotate(25 20 31)"/>
</svg>
```

```bash
mkdir -p "$SCRATCH/market"
$GODOT --headless -s "$SCRATCH/render_svg.gd" -- "$PWD/assets/sprites/market/icon_tomato.svg" "$SCRATCH/market/icon_tomato.png" 4
```

Apply "How to judge art" and adjust.

- [ ] **Step 4: Draw the other ten sprites**

Palette (the old placeholders' colours, plus a highlight and a shade of each):

| Name | Base | Highlight | Shade |
|---|---|---|---|
| Wood | `#9E6B3D` | `#B98552` | `#6B4524` |
| Paper | `#EDDBB3` | `#F8ECD0` | `#B8996B` |
| Tomato | `#E0382E` | `#F26B55` | `#C92F22` |
| Leaf | `#4D9E40` | `#6CBB57` | `#357A2D` |
| Potato | `#B38552` | `#CDA273` | `#8A6238` |
| Carrot | `#F2851F` | `#FFA44A` | `#D0660F` |
| Awning red | `#D93F3A` | `#EC6058` | `#B02B28` |
| Awning cream | `#FAF2E0` | `#FFFFFF` | `#E3D5B4` |
| Sky | `#ABD8F0` | `#CDEBFA` | `#8FCBEF` |

Draw each file, render it as in Step 3 (scale 4 for the small ones, 1 for the background and table), and
judge it. One file at a time, in this order, so the shared look settles on the small pieces first.

| File | Size | What to draw |
|---|---|---|
| `icon_potato.svg` | 64×64 | A lumpy oval potato, slightly tilted, with three or four small dark "eyes". Clearly brown and wider than tall, so it can't be mistaken for the tomato at bag size |
| `icon_carrot.svg` | 64×64 | A carrot pointing down-left with a tuft of green leaves top-right and two or three short creases across it |
| `bag.svg` | 96×96 | A paper bag seen from the front: a folded, slightly zig-zag top edge, a soft crease down one side. The face is blank from x 10 to 86 and y 16 to 86, because the bag's number and the item icon are drawn on top |
| `bag_shadow.svg` | 96×96 | The bag's silhouette as one flat shape, `#000000` at `fill-opacity="0.25"`, no outline. Same outer shape as `bag.svg` |
| `crate.svg` | 150×110 | A wooden crate seen from the front and slightly above: three horizontal slats with gaps showing a dark inside, two corner posts, nail dots. Its top edge is open, since bags come out of it |
| `order_slip.svg` | 200×230 | A sheet of paper with a torn or curled bottom edge, a small clip or pin at the top centre, and a soft shade down the right side. Blank from x 20 to 180 and y 30 to 210 for the order's lines |
| `splat.svg` | 200×200 | A tomato splat: an irregular red blob with five to seven rounded lobes of different lengths, a few separate droplets, a lighter pulp centre and four or five pale seeds. No outline on the droplets |
| `table.svg` | 760×330 | A table top seen from above: planks running left to right with thin shade lines between them and a darker rim. It is a nine-patch with 12-unit margins that is shown at exactly this size today, so the rim and its rounded corners must sit inside the outer 12 units, and plank lines must be straight and horizontal so stretching can't bend them |
| `bg_market.svg` | 1800×1000 | A market stall. Sky gradient from top to y 640. A striped red and cream awning hanging from a wooden beam: beam at y 110–122, stripes 120 units wide ending in scallops at about y 255, with a shade under each scallop. Behind the play area, soft out-of-focus shapes only (two or three distant stalls or bunting in pale colours), so nothing competes with the table and crates. From y 640 down, a wooden boardwalk with plank lines and a darker band at its top edge. The 1280×720 play area is the centre (x 260–1540, y 140–860); the outer band is only seen on wide or tall screens, so keep it plain continuation, nothing essential |
| `ui/icon_world_market.svg` | 128×128 | The market's badge: a small striped awning over a crate with a tomato in front. It is shown as small as 48 px on the level badge, so use few, large shapes |

Checks specific to this set, on top of "How to judge art":

- The three produce icons are told apart by silhouette and colour at 32 px (render at scale 0.5).
- `bag.svg` and `order_slip.svg` have nothing drawn in their blank areas.
- `icon_tomato.svg` matches the tomato the fox holds in `character_throw.svg` in colour and leaf.
- `bg_market.svg`: the awning and the boardwalk's top edge are at the same heights as in the old PNG, so
  the table, crates and fox sit on the scene the way they did.

- [ ] **Step 5: Import and point everything at the SVGs**

```bash
tools/import_svgs.sh
grep -rlE 'sprites/market/[a-z_]+\.png|icon_world_market\.png' scenes scripts tests \
  | xargs sed -i '' -E 's#(sprites/market/[a-z_]+|icon_world_market)\.png#\1.svg#g'
grep -rnE 'uid="[^"]+" path="res://assets/sprites/(market/|ui/icon_world_market)' scenes
```

Expected: eleven "Marked" lines. If the last `grep` prints any lines, delete the `uid="uid://…" ` attribute
from each (it is the deleted PNG's id; Godot falls back to the path, but warns).

- [ ] **Step 6: Delete the old sprites and their tool**

```bash
git rm -q assets/sprites/market/*.png assets/sprites/market/*.png.import assets/sprites/ui/icon_world_market.png assets/sprites/ui/icon_world_market.png.import tools/make_market_placeholders.gd tools/make_market_placeholders.gd.uid
grep -rnE 'sprites/market/[a-z_]+\.png|icon_world_market\.png|make_market_placeholders' scenes scripts tests tools
```

Expected: no output from `grep`.

- [ ] **Step 7: Run the full suite**

```bash
$GODOT --path . --headless --import
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json
```

Expected: every test passes, including both tests in `test_sprites.gd`, with no load errors.

- [ ] **Step 8: Look at the market in the game**

```bash
$GODOT --path . --resolution 1280x720 -s "$SCRATCH/shot.gd" -- res://scenes/worlds/market/market.tscn "$SCRATCH/shots/market"
mkdir -p "$SCRATCH/shots/market2x"
$GODOT --path . --resolution 2560x1440 -s "$SCRATCH/shot.gd" -- res://scenes/worlds/market/market.tscn "$SCRATCH/shots/market2x"
```

Open both `still.png` files. Check: the bags' numbers and icons are readable on the bag face; the order
slip's lines fit on the paper; crates, table and fox sit on the background as before; nothing in the
background pulls the eye from the table; and in the 2× shot (crop a region around the fox and a bag with
`sips -c`) the outlines are crisp, not soft. If the display can't fit 2560×1440, use
`--resolution 1920x1080`. Also open the level picker's market card in the main menu to see
`icon_world_market.svg` small:

```bash
mkdir -p "$SCRATCH/shots/menu"
$GODOT --path . --resolution 1280x720 -s "$SCRATCH/shot.gd" -- res://scenes/ui/main_menu.tscn "$SCRATCH/shots/menu"
```

- [ ] **Step 9: Update the READMEs**

Rewrite `assets/sprites/market/README.md` as:

```markdown
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
```

In `assets/sprites/ui/README.md`, change the market icon's row to:

```markdown
| `icon_world_market.svg` | 128×128 | Market world icon (hand-drawn SVG; see `assets/sprites/market/README.md` for the style) |
```

and, if a later line in that file names `icon_world_market.png` or `make_market_placeholders.gd`, update it
the same way.

- [ ] **Step 10: Lint and commit**

```bash
gdlint scripts/ scenes/ && gdformat --check scripts/ scenes/
git add -A scenes scripts tests assets/sprites tools
git commit -m "Redraw the market's sprites as vector art"
```

---

### Task 5: The throw

**Files:**
- Modify: `scripts/worlds/market.gd`
- Modify: `scenes/worlds/market/market.tscn` (one signal connection)
- Test: `tests/test_market.gd`

**Interfaces:**
- Consumes: the `throw` animation in `fox_frames.tres` (6 frames, 10 fps, no loop, release on frame 3) and
  the paw offset printed by `tools/make_fox_sheets.gd` (Task 2); `icon_tomato.svg` and `splat.svg` (Task 4).
- Produces: nothing other tasks use. `throw_duration` and `splat_duration` keep their names and meanings.

- [ ] **Step 1: Write the failing tests**

In `tests/test_market.gd`, update the comment above `_THROW_SETTLE` (the value still fits):

```gdscript
# The paw lets go on frame 3 of the throw at 10 fps (0.3 s), then the tomato flies and the splat
# shows.
const _THROW_SETTLE := 0.9
```

Add these tests after `test_market_incorrect_fox_throws`:

```gdscript
func test_market_throw_animation_uses_its_own_sheet() -> void:
	var frames: SpriteFrames = _world.get_node("Character").sprite_frames
	assert_eq(frames.get_frame_count("throw"), 6)
	assert_false(frames.get_animation_loop("throw"))
	var first: AtlasTexture = frames.get_frame_texture("throw", 0)
	assert_eq(first.atlas.resource_path, "res://assets/sprites/fox/character_throw.svg")


func test_market_tomato_leaves_the_paw_on_the_release_frame() -> void:
	var fox: AnimatedSprite2D = _world.get_node("Character")
	var tomato: Sprite2D = _world.get_node("FlyingTomato")
	# Long enough that a slow frame can't land the tomato before the last check.
	_world.throw_duration = 1.0
	_mechanic.confirm()
	for i in 120:
		if fox.frame >= 3:
			break
		assert_false(tomato.visible, "tomato flying on frame %d, before the paw lets go" % fox.frame)
		await wait_process_frames(1)
	assert_true(tomato.visible, "the tomato leaves the paw on frame 3")


func test_market_tomato_still_flies_if_the_release_frame_is_skipped() -> void:
	var fox: AnimatedSprite2D = _world.get_node("Character")
	_world.throw_duration = 1.0
	_mechanic.confirm()
	fox.frame = 5
	assert_true(_world.get_node("FlyingTomato").visible)


func test_market_tomato_flies_in_an_arc() -> void:
	var tomato: Sprite2D = _world.get_node("FlyingTomato")
	var splat: Sprite2D = _world.get_node("Splat")
	# Long enough that the check below lands mid-flight even after a slow frame.
	_world.throw_duration = 1.0
	_mechanic.confirm()
	await wait_until(func() -> bool: return tomato.visible, 2.0)
	var from: Vector2 = tomato.position
	await wait_seconds(0.5)
	assert_true(tomato.visible, "still in the air")
	var along: float = inverse_lerp(from.x, splat.position.x, tomato.position.x)
	var straight_y: float = lerpf(from.y, splat.position.y, along)
	assert_lt(tomato.position.y, straight_y - 50.0, "the tomato rises above the straight line")


func test_market_fox_goes_back_to_idle_after_the_throw() -> void:
	var fox: AnimatedSprite2D = _world.get_node("Character")
	_mechanic.confirm()
	await wait_until(func() -> bool: return fox.animation == &"idle", 2.0)
	assert_eq(fox.animation, &"idle")
```

Add these after `test_market_level_change_during_throw_does_not_show_retry`, and add one line to that
existing test, after its `Splat` assertion:

```gdscript
	assert_false(_world.get_node("FlyingTomato").visible)
```

```gdscript
func test_market_level_change_during_flight_leaves_nothing_behind() -> void:
	var tomato: Sprite2D = _world.get_node("FlyingTomato")
	_world.throw_duration = 1.0
	_mechanic.confirm()
	await wait_until(func() -> bool: return tomato.visible, 2.0)
	_hud.level_chosen.emit("market", 7)
	assert_false(tomato.visible)
	await wait_seconds(1.0 + _SETTLE)
	assert_false(tomato.visible)
	assert_false(_world.get_node("Splat").visible)
	assert_false(_retry.visible)
	assert_eq(_world.get_node("Character").animation, &"idle")


func test_market_wrong_again_after_retry_throws_again() -> void:
	_mechanic.confirm()
	await wait_seconds(_THROW_SETTLE)
	_retry.pressed.emit()
	_mechanic.confirm()
	assert_eq(_world.get_node("Character").animation, &"throw")
	assert_eq(_world.get_node("Character").frame, 0)
	assert_false(_world.get_node("FlyingTomato").visible)
	await wait_seconds(_THROW_SETTLE)
	assert_true(_world.get_node("Splat").visible)
	assert_true(_retry.visible)
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json -gtest=res://tests/test_market.gd
```

Expected: three tests fail. `..._leaves_the_paw_on_the_release_frame` fails at its last assertion and
`..._still_flies_if_the_release_frame_is_skipped` fails (today the tomato waits for the whole animation to
finish), and `..._flies_in_an_arc` fails (it flies straight). The rest pass, including the other new ones:
they pin behaviour the old code already had and the new code must keep.

- [ ] **Step 3: Implement the throw**

Replace `scripts/worlds/market.gd` from its first line through the end of `_play_lose()` (the whole file)
with:

```gdscript
extends WorldBase

## World 3: the fox orders an amount of produce, and the child fills the order with equal-sized
## bags. A right order makes the fox cheer; a wrong one gets a tomato lobbed at the table.

# Where the tomato leaves the fox's paw, relative to the fox. tools/make_fox_sheets.gd prints it.
const _HAND_OFFSET := Vector2(60, 36)
# The throw animation's frame on which the paw lets go.
const _RELEASE_FRAME := 3
# How far above the straight line from paw to table the tomato peaks, in px.
const _ARC_HEIGHT := 120.0
# Seconds the splat takes to pop to full size.
const _SPLAT_POP := 0.15

## Seconds the thrown tomato takes to reach the table.
@export var throw_duration: float = 0.5
## Seconds the splat stays before the retry prompt appears.
@export var splat_duration: float = 0.6

var _throw_tween: Tween
var _splat_tween: Tween
var _throw_from: Vector2

@onready var _mechanic: MarketMechanic = $MarketMechanic
@onready var _flying_tomato: Sprite2D = $FlyingTomato
@onready var _splat: Sprite2D = $Splat


func _world_id() -> String:
	return "market"


func _get_mechanic() -> Mechanic:
	return _mechanic


func _setup_level(level: Dictionary) -> void:
	_mechanic.setup(MarketPuzzleGenerator.generate(level, _rng))


func _restore_stage() -> void:
	if _throw_tween != null:
		_throw_tween.kill()
	if _splat_tween != null:
		_splat_tween.kill()
	_flying_tomato.visible = false
	_splat.visible = false
	super()


func _play_lose() -> void:
	_character.play("throw")
	# A slow frame can skip past the release frame, so wait for it or any later one. A level change
	# or a retry plays idle, which ends the wait.
	while _character.animation == &"throw" and _character.frame < _RELEASE_FRAME:
		await _character.frame_changed
	if _character.animation != &"throw":
		return
	_throw_from = _character.position + _HAND_OFFSET
	_set_flight(0.0)
	_flying_tomato.visible = true
	_throw_tween = create_tween()
	_throw_tween.tween_method(_set_flight, 0.0, 1.0, throw_duration)
	await _throw_tween.finished
	_flying_tomato.visible = false
	_splat.scale = Vector2(0.6, 0.6)
	_splat.visible = true
	_splat_tween = create_tween()
	_splat_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_splat_tween.tween_property(_splat, "scale", Vector2.ONE, _SPLAT_POP)
	AudioManager.play_sfx("market/splat")
	await get_tree().create_timer(splat_duration).timeout


# Puts the thrown tomato at `progress` along its arc: 0 at the paw, 1 at the table.
func _set_flight(progress: float) -> void:
	var hump: float = _ARC_HEIGHT * 4.0 * progress * (1.0 - progress)
	_flying_tomato.position = _throw_from.lerp(_splat.position, progress) + Vector2.UP * hump
	_flying_tomato.scale = Vector2.ONE * lerpf(0.6, 1.6, progress)
	_flying_tomato.rotation = TAU * progress


func _on_character_animation_finished() -> void:
	if _character.animation == &"throw":
		_character.play("idle")
```

Set `_HAND_OFFSET` to the value Task 2 Step 5 noted, rounded to whole pixels.

At the end of `scenes/worlds/market/market.tscn`, add the connection (after any existing `[connection]`
lines, or as the last block if there are none):

```
[connection signal="animation_finished" from="Character" to="." method="_on_character_animation_finished"]
```

Notes for the implementer:

- `_restore_stage()` ends by calling `super()`, which plays `idle`. That is what stops a wind-up: the
  `while` loop wakes on idle's next frame change, sees the animation is no longer `throw`, and returns.
  `WorldBase` then sees its load count changed and does not show the retry prompt.
- A killed tween never emits `finished`, so a coroutine waiting on it simply never resumes. That is how the
  flight is cancelled, and it is how the old code worked too.
- The fox goes back to idle from the signal, not from `_play_lose()`, so the coroutine never has to wait on
  an animation that a level change might have replaced.

- [ ] **Step 4: Run the market tests**

```bash
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json -gtest=res://tests/test_market.gd
```

Expected: every test in the file passes. Run it three times; a test that passes only sometimes has a timing
assumption to fix (lengthen the duration it sets, as `docs/kids-math-game-context.md` advises, rather than
shortening a wait).

- [ ] **Step 5: Watch the throw**

```bash
mkdir -p "$SCRATCH/shots/throw"
$GODOT --path . --resolution 1280x720 -s "$SCRATCH/shot.gd" -- res://scenes/worlds/market/market.tscn "$SCRATCH/shots/throw" wrong
```

Open `wrong_00.png` to `wrong_13.png` in order. Check: the tomato in the paw on the last wind-up frame and
the flying tomato on the first flight frame are in the same place and about the same size (if not, correct
`_HAND_OFFSET`, or the held tomato's radius in `tools/make_fox_sheets.gd`); the tomato rises, peaks about
half-way and comes down onto the table; the splat appears where it lands; the fox ends in idle; the retry
button appears.

- [ ] **Step 6: Lint and commit**

```bash
gdformat scripts/worlds/market.gd tests/test_market.gd
gdlint scripts/ scenes/
git add scripts/worlds/market.gd scenes/worlds/market/market.tscn tests/test_market.gd
git commit -m "Give the market fox a real throw: release frame, arc and splat pop"
```

---

### Task 6: Docs, full verification and the style checkpoint

**Files:**
- Modify: `docs/kids-math-game-context.md`
- Modify: `docs/superpowers/specs/2026-11-16-vector-art-design.md` (only if the style rules changed while
  drawing)

**Interfaces:**
- Consumes: everything above.
- Produces: a branch ready for the user's style checkpoint.

- [ ] **Step 1: Update the context doc**

In `docs/kids-math-game-context.md`:

- World 3's fail line: replace "the fox throws a tomato at the table (a splat; until the fox has throw
  frames its fall lurch stands in)" with "the fox lobs a tomato at the table (a six-frame underhand throw;
  the tomato leaves the paw on frame 3, flies in an arc and splats)".
- The art paragraph that begins "All art is programmer-art placeholder": replace it with:

```markdown
- Art is being redrawn as vector art (issue #7; spec `docs/superpowers/specs/2026-11-16-vector-art-design.md`). Done: the fox (`assets/sprites/fox/`, six sheets and the shared `fox_frames.tres`, all written by `tools/make_fox_sheets.gd` from a table of poses) and the market (`assets/sprites/market/`, hand-drawn SVGs). Still programmer-art PNGs, drawn by the remaining `tools/make_*_placeholders.gd` scripts: `forest_bridge/`, `sky_balloons/`, `picnic/`, `memory/` and `ui/` (stage 2).
```

- The "Not yet done" line: change "final art (issue #7)" to "the rest of the final art (issue #7, stage 2)".
- The `scripts/worlds/market.gd` row of the file table: replace its description with "Market flow: fox
  cheer, or the underhand throw (tomato released on frame 3 of `throw`, arcing `_ARC_HEIGHT` px above the
  straight line), splat pop with `market/splat`, and retry. Exports `throw_duration`, `splat_duration`."
- The gotcha "Each fox frame must stay inside its own 64 px cell…": replace with "Each fox frame must leave
  the two outermost columns of its 160-unit cell empty, or a neighbour's pixels bleed in (the stray tail tip
  fixed in #24); `tests/test_fox_frames.gd` checks every frame."
- "Open ideas": delete "Market: throw frames for the fox (the fall lurch stands in now)." and change "Final
  art (#7) and real sounds to replace the placeholders." to "Stage 2 of the vector art (#7): forest, sky,
  picnic, memory and UI. Real sounds to replace the placeholders."
- Update the "Last updated" line's date to 2026-11-16 and add "vector fox, market art and the throw" to its
  list.

Confirm `CLAUDE.md` needs no change: `grep -n '\.png\|placeholder' CLAUDE.md` should show only the audio
placeholder line in "Adding a New World".

- [ ] **Step 2: Run everything**

```bash
$GODOT --path . --headless --import
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json
gdlint scripts/ scenes/ && gdformat --check scripts/ scenes/
$GODOT --path . --headless --quit
```

Expected: all tests pass; lint and format are clean; the headless run prints no errors or missing-resource
warnings.

- [ ] **Step 3: Check the web build**

```bash
tools/export_web.sh
python3 -m http.server 8765 --directory build/web
```

With the server in the background, open `http://localhost:8765`, go to the market, give a wrong answer, and
take screenshots of the still scene and the throw. Stop the server. Expected: the same picture as the
desktop run, with crisp outlines on a Retina display, and no errors in the browser console.

- [ ] **Step 4: Commit**

```bash
git add docs
git commit -m "Describe the vector fox, the market art and the throw"
```

- [ ] **Step 5: Style checkpoint with the user**

Show the user: the market still (`$SCRATCH/shots/market/still.png`), the throw frames
(`$SCRATCH/fox/throw.png`), the throw in play (`$SCRATCH/shots/throw/`), and one other world with the new
fox on its old background. Give the command to play it (`$GODOT --path .`). Ask what to change in the style.

Apply any changes, write changed style rules back into the spec's "Style rules" section, re-run Step 2, and
commit. Open the pull request (title: "Vector art, stage 1: the fox, the market and a real throw") only when
the user says to. Stage 2 then gets its own plan.

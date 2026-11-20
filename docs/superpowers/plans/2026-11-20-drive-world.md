# World 6: Country Drive Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add World 6, Country Drive: the fox drives a top-down car across a grid of obstacles to its garage by following a program of commands the child builds first.

**Architecture:** Three pure-logic classes (`DriveProgram`, `DriveSimulator`, `DrivePuzzleGenerator`) hold all the rules and are tested without scenes. `DriveMechanic` (extends `Mechanic`) draws the field, the command buttons, the program strip and Go, and animates the simulator's result. The world script `drive.gd` extends `WorldBase` and uses the mechanic's car as its character.

**Tech Stack:** Godot 4.6.2, GDScript, GUT 9.6.0, gdtoolkit (`gdlint`, `gdformat`), hand-written SVG art.

**Spec:** `docs/superpowers/specs/2026-11-20-drive-world-design.md` (read it before starting).

**Branch:** `drive-world` (already exists, holds the spec). Commit as
`malioni <47998755+malioni@users.noreply.github.com>` (`git -c user.name=malioni -c user.email=47998755+malioni@users.noreply.github.com commit ...`), ending every message with
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Refinements to the spec

Decided while planning; they don't change anything the child sees.

- `DriveSimulator.run(field, moves)` takes no `mode`: the command names already differ between modes.
- `DriveSimulator.run()` returns a pose for the bumping move too (cell unchanged, new facing), so the car turns towards what it hits before it bumps.
- `fewest_tiles()` also returns `program` (the shortest program's tiles), which the world test uses to solve every level.
- `DriveMechanic` gets one more signal, `stepped`, emitted for each square driven; the world plays `drive/step` from it, so the mechanic plays no sounds itself.
- `DriveMechanic.can_add(command)` dims each command button separately: when the strip is full, the button for the last tile's command still works because it only raises that tile's count.
- Tiles are `TextureButton`s and use the built-in `pressed` signal instead of a new `tapped` signal.
- Textures, the Go texture and the car's `SpriteFrames` are exports on `DriveMechanic`, set in the world scene (like `MemoryMechanic.card_textures`), so the mechanic holds no world art.
- The generator tests use 100 seeds per level, not 200, to keep the suite fast. Each generation runs up to 500 searches.

## Global Constraints

- Godot binary: `/Applications/Godot-2.app/Contents/MacOS/Godot` (written `$GODOT` below; run `export GODOT=/Applications/Godot-2.app/Contents/MacOS/Godot` first).
- Run one test file: `$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gpre_run_script=res://tests/pre_run_hook.gd -gexit -gtest=res://tests/<file>.gd`
- Run every test: `$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json`
- After creating any script with a new `class_name`, run `$GODOT --path . --headless --import` before running tests, so Godot registers the class and writes the script's `.uid` file. Commit the `.uid` files.
- After adding any SVG, run `tools/import_svgs.sh`.
- Conventions (CLAUDE.md): `snake_case`, `PascalCase` classes, `UPPER_SNAKE_CASE` constants, signals first, type hints on every parameter and return, `@onready` node references, `_private` names, `##` doc comments on every public method. Lint with `~/.local/bin/gdlint scripts/ scenes/`.
- Layers: no world-specific code or art paths in `scripts/mechanics/`; level content only in `data/levels/world_drive/`.
- Commands: global `"up"`, `"down"`, `"left"`, `"right"`; relative `"forward"`, `"turn_left"`, `"turn_right"`. Modes: `"global"`, `"relative"`.
- Facing is a `Vector2i` screen direction; the car starts facing `Vector2i(1, 0)` (right). Screen y points down, so turn left maps `(x, y)` to `(y, -x)` and turn right maps it to `(-y, x)`.
- Field dictionary: `{"cols": int, "rows": int, "start": Vector2i, "garage": Vector2i, "obstacles": Array[Dictionary] of {"cell": Vector2i, "kind": String}, "fallback": bool}`. Kinds: `"tree"`, `"rock"`, `"bush"`, `"pond"`.
- The strip holds at most 12 tiles (`DriveProgram.MAX_TILES`).
- The car must finish exactly on the garage with the program's last move; passing through it earlier is not a win.
- JSON numbers load as floats: wrap every level value in `int()` / `float()` / `str()`.

## Review Focus

These conditions are not obvious from the spec's examples. Each has a test in the task that owns it.

1. **A level change or Home while the car is driving.** The old drive must stop: no `correct`/`incorrect`, no sound, the car back at the new start. Tested in Task 6 (`setup()` mid-drive) and Task 7 (level change mid-drive and mid-bump).
2. **Tapping buttons, tiles or Go while the car drives, or twice on Go.** Must be ignored. Tested in Task 6.
3. **A program that drives through the garage and on.** Must be a lose, not a win. Tested in Task 2 (simulator) and Task 7 (world).
4. **A full strip.** The last tile's command can still raise its count; every other button does nothing and looks dimmed. Tested in Tasks 1 and 6.
5. **Retry after a bump, then editing.** The program is kept and the failed tile marked; any edit or Go clears the mark. Tested in Tasks 6 and 7.

---

### Task 1: DriveProgram (the tile list)

**Files:**
- Create: `scripts/mechanics/drive_program.gd`
- Test: `tests/test_drive_program.gd`

**Interfaces:**
- Produces: `class_name DriveProgram extends RefCounted`; `const MAX_TILES := 12`; `add(command: String) -> bool`; `can_add(command: String) -> bool`; `take_step(index: int) -> void`; `get_tiles() -> Array[Dictionary]` (each `{"command": String, "count": int}`, a deep copy); `is_full() -> bool`; `is_empty() -> bool`; `clear() -> void`; `expand() -> Array[Dictionary]` (each `{"command": String, "tile": int}`).

- [ ] **Step 1: Write the failing tests**

`tests/test_drive_program.gd`:

```gdscript
extends GutTest

var _program: DriveProgram


func before_each() -> void:
	_program = DriveProgram.new()


func _summary() -> Array:
	return _program.get_tiles().map(
		func(tile: Dictionary) -> String: return "%s%d" % [tile["command"], tile["count"]]
	)


func test_drive_program_starts_empty() -> void:
	assert_true(_program.is_empty())
	assert_eq(_program.get_tiles(), [])


func test_drive_program_same_command_merges_into_one_tile() -> void:
	_program.add("right")
	_program.add("right")
	_program.add("down")
	assert_eq(_summary(), ["right2", "down1"])


func test_drive_program_turns_merge_too() -> void:
	_program.add("turn_left")
	_program.add("turn_left")
	assert_eq(_summary(), ["turn_left2"])


func test_drive_program_take_step_lowers_count() -> void:
	_program.add("right")
	_program.add("right")
	_program.take_step(0)
	assert_eq(_summary(), ["right1"])


func test_drive_program_take_step_at_one_removes_tile() -> void:
	_program.add("right")
	_program.add("down")
	_program.add("right")
	_program.take_step(1)
	# The two "right" tiles are now neighbours but stay separate.
	assert_eq(_summary(), ["right1", "right1"])


func test_drive_program_add_after_removal_merges_with_new_last_tile() -> void:
	_program.add("right")
	_program.add("down")
	_program.take_step(1)
	_program.add("right")
	assert_eq(_summary(), ["right2"])


func test_drive_program_take_step_out_of_range_does_nothing() -> void:
	_program.add("up")
	_program.take_step(5)
	_program.take_step(-1)
	assert_eq(_summary(), ["up1"])


func test_drive_program_holds_at_most_12_tiles() -> void:
	for i in DriveProgram.MAX_TILES:
		assert_true(_program.add("up" if i % 2 == 0 else "down"))
	assert_true(_program.is_full())
	assert_false(_program.add("left"), "a 13th tile is refused")
	assert_eq(_program.get_tiles().size(), 12)


func test_drive_program_full_strip_still_raises_last_tile() -> void:
	for i in DriveProgram.MAX_TILES:
		_program.add("up" if i % 2 == 0 else "down")
	assert_true(_program.can_add("down"), "the last tile is down")
	assert_false(_program.can_add("up"))
	assert_true(_program.add("down"))
	assert_eq(_program.get_tiles()[-1]["count"], 2)


func test_drive_program_expand_unrolls_with_tile_index() -> void:
	_program.add("forward")
	_program.add("forward")
	_program.add("turn_right")
	_program.add("forward")
	assert_eq(
		_program.expand(),
		[
			{"command": "forward", "tile": 0},
			{"command": "forward", "tile": 0},
			{"command": "turn_right", "tile": 1},
			{"command": "forward", "tile": 2},
		]
	)


func test_drive_program_get_tiles_is_a_copy() -> void:
	_program.add("up")
	_program.get_tiles()[0]["count"] = 9
	assert_eq(_summary(), ["up1"])


func test_drive_program_clear_empties() -> void:
	_program.add("up")
	_program.clear()
	assert_true(_program.is_empty())
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gpre_run_script=res://tests/pre_run_hook.gd -gexit -gtest=res://tests/test_drive_program.gd`
Expected: errors, because `DriveProgram` is not defined.

- [ ] **Step 3: Write the implementation**

`scripts/mechanics/drive_program.gd`:

```gdscript
class_name DriveProgram
extends RefCounted

## The program the player builds for the car: a row of tiles, each a command and how many times to
## run it. Adding the same command as the last tile raises that tile's count instead of adding one.

## Most tiles the program holds.
const MAX_TILES := 12

var _tiles: Array[Dictionary] = []


## Adds one step of command. Raises the last tile's count if it holds the same command; otherwise
## adds a tile. Returns false, changing nothing, if a new tile is needed and the program is full.
func add(command: String) -> bool:
	if not _tiles.is_empty() and _tiles[-1]["command"] == command:
		_tiles[-1]["count"] += 1
		return true
	if is_full():
		return false
	_tiles.append({"command": command, "count": 1})
	return true


## Returns true if add(command) would change the program.
func can_add(command: String) -> bool:
	return not is_full() or _tiles[-1]["command"] == command


## Takes one step off the tile at index; a tile at count 1 is removed. Neighbours left holding the
## same command stay separate tiles. An index out of range does nothing.
func take_step(index: int) -> void:
	if index < 0 or index >= _tiles.size():
		return
	_tiles[index]["count"] -= 1
	if _tiles[index]["count"] <= 0:
		_tiles.remove_at(index)


## Returns a copy of the tiles in order, each {"command": String, "count": int}.
func get_tiles() -> Array[Dictionary]:
	return _tiles.duplicate(true)


## Returns true when no new tile fits.
func is_full() -> bool:
	return _tiles.size() >= MAX_TILES


## Returns true when the program has no tiles.
func is_empty() -> bool:
	return _tiles.is_empty()


## Removes every tile.
func clear() -> void:
	_tiles.clear()


## Returns the program as single moves in order, each {"command": String, "tile": int}, where
## tile is the index of the tile the move came from.
func expand() -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	for i in _tiles.size():
		for step in int(_tiles[i]["count"]):
			moves.append({"command": _tiles[i]["command"], "tile": i})
	return moves
```

- [ ] **Step 4: Register the class and run the tests**

Run: `$GODOT --path . --headless --import`, then the test command from Step 2.
Expected: all `test_drive_program` tests pass.

- [ ] **Step 5: Lint and commit**

```bash
~/.local/bin/gdlint scripts/mechanics/drive_program.gd tests/test_drive_program.gd
git add scripts/mechanics/drive_program.gd scripts/mechanics/drive_program.gd.uid tests/test_drive_program.gd tests/test_drive_program.gd.uid
git -c user.name=malioni -c user.email=47998755+malioni@users.noreply.github.com commit -m "Drive: add DriveProgram, the tile list the child builds

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: DriveSimulator (playing a program on a field)

**Files:**
- Create: `scripts/mechanics/drive_simulator.gd`
- Test: `tests/test_drive_simulator.gd`

**Interfaces:**
- Consumes: the moves format from `DriveProgram.expand()` (`{"command", "tile"}`; only `command` is read).
- Produces: `class_name DriveSimulator extends RefCounted`; `const RIGHT := Vector2i(1, 0)`; `const DIRECTIONS: Dictionary` (global command → `Vector2i`); `static step(cell: Vector2i, facing: Vector2i, command: String) -> Dictionary` (`{"cell", "facing"}`); `static blocker(field: Dictionary, cell: Vector2i) -> String` (`"edge"`, an obstacle kind, or `""`); `static run(field: Dictionary, moves: Array[Dictionary]) -> Dictionary` with `poses: Array[Dictionary]` (`{"cell", "facing"}` per move run, the bumping move included with its cell unchanged), `outcome: String` (`"garage"`, `"bump"`, `"short"`), `fail_move: int` (bumping move's index; the last move's index for `short`; −1 for `garage`), `bump_kind: String` (`""` unless `bump`).

- [ ] **Step 1: Write the failing tests**

`tests/test_drive_simulator.gd`:

```gdscript
extends GutTest

# A 4×3 field: start at (0, 1), garage at (3, 1), a tree at (2, 1) and a pond at (1, 0).
#   . P . .
#   S . T G
#   . . . .
var _field := {
	"cols": 4,
	"rows": 3,
	"start": Vector2i(0, 1),
	"garage": Vector2i(3, 1),
	"obstacles": [
		{"cell": Vector2i(2, 1), "kind": "tree"},
		{"cell": Vector2i(1, 0), "kind": "pond"},
	],
	"fallback": false,
}


func _moves(commands: Array) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	for command: String in commands:
		moves.append({"command": command, "tile": 0})
	return moves


func test_drive_simulator_global_route_reaches_garage() -> void:
	var result := DriveSimulator.run(_field, _moves(["down", "right", "right", "right", "up"]))
	assert_eq(result["outcome"], "garage")
	assert_eq(result["fail_move"], -1)
	assert_eq(result["poses"].size(), 5)
	assert_eq(result["poses"][-1]["cell"], Vector2i(3, 1))


func test_drive_simulator_global_car_faces_the_way_it_moved() -> void:
	var result := DriveSimulator.run(_field, _moves(["down", "right"]))
	assert_eq(result["poses"][0]["facing"], Vector2i(0, 1))
	assert_eq(result["poses"][1]["facing"], Vector2i(1, 0))


func test_drive_simulator_relative_route_reaches_garage() -> void:
	var commands := [
		"turn_right", "forward", "turn_left", "forward", "forward", "forward", "turn_left", "forward"
	]
	var result := DriveSimulator.run(_field, _moves(commands))
	assert_eq(result["outcome"], "garage")
	assert_eq(result["poses"][0], {"cell": Vector2i(0, 1), "facing": Vector2i(0, 1)})


func test_drive_simulator_turns_follow_screen_directions() -> void:
	var left := DriveSimulator.step(Vector2i.ZERO, Vector2i(1, 0), "turn_left")
	var right := DriveSimulator.step(Vector2i.ZERO, Vector2i(1, 0), "turn_right")
	assert_eq(left["facing"], Vector2i(0, -1), "left of right is up")
	assert_eq(right["facing"], Vector2i(0, 1), "right of right is down")


func test_drive_simulator_bump_into_obstacle() -> void:
	var result := DriveSimulator.run(_field, _moves(["right", "right", "right"]))
	assert_eq(result["outcome"], "bump")
	assert_eq(result["fail_move"], 1)
	assert_eq(result["bump_kind"], "tree")
	assert_eq(result["poses"].size(), 2)
	assert_eq(result["poses"][1]["cell"], Vector2i(1, 1), "the bumping move doesn't move the car")


func test_drive_simulator_bump_turns_car_towards_obstacle() -> void:
	var result := DriveSimulator.run(_field, _moves(["right", "up"]))
	assert_eq(result["bump_kind"], "pond")
	assert_eq(result["poses"][1]["facing"], Vector2i(0, -1))


func test_drive_simulator_bump_into_each_edge() -> void:
	for command: String in ["left", "up", "down"]:
		var commands: Array = ["up"] if command == "up" else []
		commands.append(command)
		commands.append(command)
		var result := DriveSimulator.run(_field, _moves(commands))
		assert_eq(result["outcome"], "bump", command)
		assert_eq(result["bump_kind"], "edge", command)
	var off_right := DriveSimulator.run(
		_field, _moves(["down", "right", "right", "right", "right"])
	)
	assert_eq(off_right["bump_kind"], "edge")
	assert_eq(off_right["fail_move"], 4)


func test_drive_simulator_through_garage_and_on_is_not_a_win() -> void:
	var result := DriveSimulator.run(
		_field, _moves(["down", "right", "right", "right", "up", "up"])
	)
	assert_eq(result["outcome"], "short")
	assert_eq(result["fail_move"], 5)
	assert_eq(result["poses"][-1]["cell"], Vector2i(3, 0))


func test_drive_simulator_stopping_short() -> void:
	var result := DriveSimulator.run(_field, _moves(["down", "right"]))
	assert_eq(result["outcome"], "short")
	assert_eq(result["fail_move"], 1)
	assert_eq(result["bump_kind"], "")


func test_drive_simulator_turning_on_the_spot_never_bumps() -> void:
	var result := DriveSimulator.run(_field, _moves(["turn_left", "turn_left", "turn_left"]))
	assert_eq(result["outcome"], "short")
	assert_eq(result["poses"][-1]["facing"], Vector2i(0, 1))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gpre_run_script=res://tests/pre_run_hook.gd -gexit -gtest=res://tests/test_drive_simulator.gd`
Expected: errors, because `DriveSimulator` is not defined.

- [ ] **Step 3: Write the implementation**

`scripts/mechanics/drive_simulator.gd`:

```gdscript
class_name DriveSimulator
extends RefCounted

## Plays a drive program on a field, without animation, and reports every pose and how it ended.
## Global commands turn the car to face their screen direction and drive one square; relative
## commands drive forward one square or turn 90° on the spot. The car starts facing right.

## The way the car faces at the start.
const RIGHT := Vector2i(1, 0)
## Screen direction of each global command.
const DIRECTIONS := {
	"up": Vector2i(0, -1),
	"down": Vector2i(0, 1),
	"left": Vector2i(-1, 0),
	"right": Vector2i(1, 0),
}


## Returns {"cell", "facing"} after command from cell and facing. The cell may be off the field or
## on an obstacle; check it with blocker().
static func step(cell: Vector2i, facing: Vector2i, command: String) -> Dictionary:
	match command:
		"forward":
			return {"cell": cell + facing, "facing": facing}
		"turn_left":
			return {"cell": cell, "facing": Vector2i(facing.y, -facing.x)}
		"turn_right":
			return {"cell": cell, "facing": Vector2i(-facing.y, facing.x)}
	var direction: Vector2i = DIRECTIONS[command]
	return {"cell": cell + direction, "facing": direction}


## Returns what stops the car entering cell: "edge" off the field, an obstacle's kind, or "" if the
## cell is free.
static func blocker(field: Dictionary, cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= int(field["cols"]) or cell.y >= int(field["rows"]):
		return "edge"
	for obstacle: Dictionary in field["obstacles"]:
		if obstacle["cell"] == cell:
			return obstacle["kind"]
	return ""


## Runs moves ({"command", ...} each) from the field's start. Returns "poses" (one
## {"cell", "facing"} per move run; a bumping move keeps the cell and takes the new facing),
## "outcome" ("garage" if the last move ends on the garage, "bump", or "short"), "fail_move" (the
## bumping move, or the last move when short; -1 on garage) and "bump_kind" ("edge" or an obstacle
## kind when the outcome is bump, else "").
static func run(field: Dictionary, moves: Array[Dictionary]) -> Dictionary:
	var cell: Vector2i = field["start"]
	var facing := RIGHT
	var poses: Array[Dictionary] = []
	for i in moves.size():
		var next := step(cell, facing, moves[i]["command"])
		var kind := blocker(field, next["cell"])
		if kind != "":
			poses.append({"cell": cell, "facing": next["facing"]})
			return {"poses": poses, "outcome": "bump", "fail_move": i, "bump_kind": kind}
		cell = next["cell"]
		facing = next["facing"]
		poses.append({"cell": cell, "facing": facing})
	if not moves.is_empty() and cell == field["garage"]:
		return {"poses": poses, "outcome": "garage", "fail_move": -1, "bump_kind": ""}
	return {"poses": poses, "outcome": "short", "fail_move": moves.size() - 1, "bump_kind": ""}
```

- [ ] **Step 4: Register the class and run the tests**

Run: `$GODOT --path . --headless --import`, then the test command from Step 2.
Expected: all `test_drive_simulator` tests pass.

- [ ] **Step 5: Lint and commit**

```bash
~/.local/bin/gdlint scripts/mechanics/drive_simulator.gd tests/test_drive_simulator.gd
git add scripts/mechanics/drive_simulator.gd* tests/test_drive_simulator.gd*
git -c user.name=malioni -c user.email=47998755+malioni@users.noreply.github.com commit -m "Drive: add DriveSimulator, which plays a program on a field

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: DrivePuzzleGenerator (fields and the shortest program)

**Files:**
- Create: `scripts/mechanics/drive_puzzle_generator.gd`
- Test: `tests/test_drive_puzzle_generator.gd`

**Interfaces:**
- Consumes: `DriveSimulator.step()`, `DriveSimulator.blocker()`, `DriveSimulator.RIGHT`.
- Produces: `class_name DrivePuzzleGenerator extends RefCounted`; `const COMMANDS: Dictionary` (mode → `Array[String]` of commands); `const KINDS: Array[String]`; `const MAX_ATTEMPTS := 500`; `static generate(params: Dictionary, rng: RandomNumberGenerator) -> Dictionary` (a field, see Global Constraints); `static fewest_tiles(field: Dictionary, mode: String) -> Dictionary` returning `{"tiles": int, "turns": int, "program": Array[Dictionary]}` (`program` tiles are `{"command", "count"}`; `tiles` is −1 and `program` empty when the garage can't be reached).

- [ ] **Step 1: Write the failing tests**

`tests/test_drive_puzzle_generator.gd`. The per-level checks come in Task 4, once the level files exist.

```gdscript
extends GutTest

const _PARAMS := {
	"mode": "global",
	"cols": 6,
	"rows": 4,
	"obstacles": {"min": 5, "max": 7},
	"turns": {"min": 2, "max": 3},
	"max_tiles": 4,
}


func _field(cols: int, rows: int, start: Vector2i, garage: Vector2i, blocked: Array) -> Dictionary:
	var obstacles: Array[Dictionary] = []
	for cell: Vector2i in blocked:
		obstacles.append({"cell": cell, "kind": "rock"})
	return {
		"cols": cols,
		"rows": rows,
		"start": start,
		"garage": garage,
		"obstacles": obstacles,
		"fallback": false,
	}


func test_drive_generator_straight_road_is_one_tile() -> void:
	var field := _field(4, 3, Vector2i(0, 1), Vector2i(3, 1), [])
	var best := DrivePuzzleGenerator.fewest_tiles(field, "global")
	assert_eq(best["tiles"], 1)
	assert_eq(best["turns"], 0)
	assert_eq(best["program"], [{"command": "right", "count": 3}])


func test_drive_generator_relative_needs_turn_tiles() -> void:
	var field := _field(4, 3, Vector2i(0, 0), Vector2i(3, 2), [])
	var best := DrivePuzzleGenerator.fewest_tiles(field, "relative")
	assert_eq(best["tiles"], 3, "forward, turn, forward")
	assert_eq(best["turns"], 1)


func test_drive_generator_counts_tiles_not_squares() -> void:
	# The fewest squares (6) zigzag through the gaps and need 5 tiles; going round the wall takes
	# 8 squares but only 3 tiles.
	#   S . # . . .
	#   . . . # . .
	#   . # . . . G
	#   . . . . . .
	var field := _field(
		6, 4, Vector2i(0, 0), Vector2i(5, 2), [Vector2i(2, 0), Vector2i(3, 1), Vector2i(1, 2)]
	)
	var best := DrivePuzzleGenerator.fewest_tiles(field, "global")
	assert_eq(best["tiles"], 3)
	assert_eq(
		best["program"],
		[
			{"command": "down", "count": 3},
			{"command": "right", "count": 5},
			{"command": "up", "count": 1},
		]
	)


func test_drive_generator_shortest_program_really_reaches_the_garage() -> void:
	var field := _field(
		6, 4, Vector2i(0, 0), Vector2i(5, 2), [Vector2i(2, 0), Vector2i(3, 1), Vector2i(1, 2)]
	)
	for mode: String in ["global", "relative"]:
		var program := DriveProgram.new()
		for tile: Dictionary in DrivePuzzleGenerator.fewest_tiles(field, mode)["program"]:
			for step in int(tile["count"]):
				program.add(tile["command"])
		assert_eq(DriveSimulator.run(field, program.expand())["outcome"], "garage", mode)


func test_drive_generator_unreachable_garage() -> void:
	var field := _field(3, 3, Vector2i(0, 1), Vector2i(2, 1), [
		Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)
	])
	var best := DrivePuzzleGenerator.fewest_tiles(field, "global")
	assert_eq(best["tiles"], -1)
	assert_eq(best["program"], [])


func test_drive_generator_field_shape() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var field := DrivePuzzleGenerator.generate(_PARAMS, rng)
	assert_eq(field["cols"], 6)
	assert_eq(field["rows"], 4)
	assert_eq(field["start"].x, 0)
	assert_eq(field["garage"].x, 5)
	assert_between(field["obstacles"].size(), 5, 7)
	for obstacle: Dictionary in field["obstacles"]:
		assert_ne(obstacle["cell"], field["start"])
		assert_ne(obstacle["cell"], field["garage"])
		assert_has(DrivePuzzleGenerator.KINDS, obstacle["kind"])


func test_drive_generator_obstacles_never_share_a_cell() -> void:
	var rng := RandomNumberGenerator.new()
	for seed_value in 50:
		rng.seed = seed_value
		var seen := {}
		for obstacle: Dictionary in DrivePuzzleGenerator.generate(_PARAMS, rng)["obstacles"]:
			assert_false(seen.has(obstacle["cell"]), "seed %d" % seed_value)
			seen[obstacle["cell"]] = true


func test_drive_generator_same_seed_same_field() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	assert_eq(DrivePuzzleGenerator.generate(_PARAMS, a), DrivePuzzleGenerator.generate(_PARAMS, b))


func test_drive_generator_impossible_params_fall_back_to_open_field() -> void:
	var params := _PARAMS.duplicate(true)
	params["turns"] = {"min": 9, "max": 9}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var field := DrivePuzzleGenerator.generate(params, rng)
	assert_true(field["fallback"])
	assert_eq(field["obstacles"], [])
	assert_ne(DrivePuzzleGenerator.fewest_tiles(field, "global")["tiles"], -1)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gpre_run_script=res://tests/pre_run_hook.gd -gexit -gtest=res://tests/test_drive_puzzle_generator.gd`
Expected: errors, because `DrivePuzzleGenerator` is not defined.

- [ ] **Step 3: Write the implementation**

`scripts/mechanics/drive_puzzle_generator.gd`:

```gdscript
class_name DrivePuzzleGenerator
extends RefCounted

## Generates drive fields from level ranges, and finds the shortest program for a field. The start
## is in the left column and the garage in the right column; obstacles fill other squares. A field
## is kept only if its shortest program fits the level's turns and max_tiles.

## The commands each mode offers.
const COMMANDS := {
	"global": ["up", "down", "left", "right"],
	"relative": ["forward", "turn_left", "turn_right"],
}
## Obstacle kinds, picked at random for each obstacle.
const KINDS: Array[String] = ["tree", "rock", "bush", "pond"]
## Fields tried before falling back to one with no obstacles.
const MAX_ATTEMPTS := 500


## Returns a field for params (mode, cols, rows, obstacles {min, max}, turns {min, max}, max_tiles)
## using rng. If no field fits within MAX_ATTEMPTS, returns the last attempt's start and garage with
## no obstacles and "fallback" true; it can always be solved.
static func generate(params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var mode := str(params["mode"])
	var field := {}
	for attempt in MAX_ATTEMPTS:
		field = _random_field(params, rng)
		var best := fewest_tiles(field, mode)
		if (
			best["tiles"] != -1
			and best["tiles"] <= int(params["max_tiles"])
			and best["turns"] >= int(params["turns"]["min"])
			and best["turns"] <= int(params["turns"]["max"])
		):
			return field
	var open: Array[Dictionary] = []
	field["obstacles"] = open
	field["fallback"] = true
	return field


## Returns the shortest program, in tiles, that ends on the garage: {"tiles", "turns", "program"}.
## turns is tiles − 1 in global mode (direction changes) and the number of turn tiles in relative
## mode. tiles is -1 and program empty when the garage can't be reached.
##
## A 0-1 breadth-first search over (square, facing, current command): a move that repeats the
## current command merges into its tile and costs 0; any other command starts a tile and costs 1.
static func fewest_tiles(field: Dictionary, mode: String) -> Dictionary:
	var start := {"cell": field["start"], "facing": DriveSimulator.RIGHT, "command": ""}
	var start_key := _key(start)
	var states := {start_key: start}
	var cost := {start_key: 0}
	var parent := {start_key: ""}
	var done := {}
	var queue: Array[String] = [start_key]
	while not queue.is_empty():
		var key: String = queue.pop_front()
		if done.has(key):
			continue
		done[key] = true
		var here: Dictionary = states[key]
		if here["command"] != "" and here["cell"] == field["garage"]:
			return _result(key, states, parent, mode)
		for command: String in COMMANDS[mode]:
			var next := DriveSimulator.step(here["cell"], here["facing"], command)
			if DriveSimulator.blocker(field, next["cell"]) != "":
				continue
			var state := {"cell": next["cell"], "facing": next["facing"], "command": command}
			var next_key := _key(state)
			var weight: int = 0 if command == here["command"] else 1
			var next_cost: int = cost[key] + weight
			if cost.has(next_key) and cost[next_key] <= next_cost:
				continue
			cost[next_key] = next_cost
			parent[next_key] = key
			states[next_key] = state
			if weight == 0:
				queue.push_front(next_key)
			else:
				queue.push_back(next_key)
	var none: Array[Dictionary] = []
	return {"tiles": -1, "turns": 0, "program": none}


static func _random_field(params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cols := int(params["cols"])
	var rows := int(params["rows"])
	var start := Vector2i(0, rng.randi_range(0, rows - 1))
	var garage := Vector2i(cols - 1, rng.randi_range(0, rows - 1))
	var free: Array[Vector2i] = []
	for y in rows:
		for x in cols:
			var cell := Vector2i(x, y)
			if cell != start and cell != garage:
				free.append(cell)
	# Array.shuffle() uses the global random numbers, so a seeded world would get other fields.
	for i in range(free.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := free[i]
		free[i] = free[j]
		free[j] = swap
	var count := rng.randi_range(int(params["obstacles"]["min"]), int(params["obstacles"]["max"]))
	var obstacles: Array[Dictionary] = []
	for i in mini(count, free.size()):
		obstacles.append({"cell": free[i], "kind": KINDS[rng.randi_range(0, KINDS.size() - 1)]})
	return {
		"cols": cols,
		"rows": rows,
		"start": start,
		"garage": garage,
		"obstacles": obstacles,
		"fallback": false,
	}


static func _key(state: Dictionary) -> String:
	var cell: Vector2i = state["cell"]
	var facing: Vector2i = state["facing"]
	return "%d,%d,%d,%d,%s" % [cell.x, cell.y, facing.x, facing.y, state["command"]]


static func _result(goal_key: String, states: Dictionary, parent: Dictionary, mode: String) -> Dictionary:
	var commands: Array[String] = []
	var key := goal_key
	while parent[key] != "":
		commands.push_front(states[key]["command"])
		key = parent[key]
	var program := DriveProgram.new()
	for command in commands:
		program.add(command)
	var tiles := program.get_tiles()
	var turns := tiles.size() - 1
	if mode == "relative":
		turns = tiles.filter(
			func(tile: Dictionary) -> bool: return str(tile["command"]).begins_with("turn")
		).size()
	return {"tiles": tiles.size(), "turns": turns, "program": tiles}
```

Note: `_result` builds tiles with `DriveProgram`, so a shortest program longer than 12 tiles would be cut short by `add()`. No level allows more than 7, so this never matters; don't add a special case.

- [ ] **Step 4: Register the class and run the tests**

Run: `$GODOT --path . --headless --import`, then the test command from Step 2.
Expected: all `test_drive_puzzle_generator` tests pass. If `test_drive_generator_counts_tiles_not_squares` fails on `program` only (a different 3-tile route), check by hand that the route found is also 3 tiles and valid, then relax that assertion to the tile count plus the "really reaches" test. Don't change the search.

- [ ] **Step 5: Format, lint and commit**

```bash
gdformat scripts/mechanics/drive_puzzle_generator.gd
~/.local/bin/gdlint scripts/mechanics/drive_puzzle_generator.gd tests/test_drive_puzzle_generator.gd
git add scripts/mechanics/drive_puzzle_generator.gd* tests/test_drive_puzzle_generator.gd*
git -c user.name=malioni -c user.email=47998755+malioni@users.noreply.github.com commit -m "Drive: add DrivePuzzleGenerator with a 0-1 breadth-first shortest program

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Level files

**Files:**
- Create: `data/levels/world_drive/levels.json`, `data/levels/world_drive/world_drive_01.json` … `world_drive_20.json`
- Create: `tests/test_world_drive_levels.gd`
- Modify: `tests/test_drive_puzzle_generator.gd` (per-level generation checks)

**Interfaces:**
- Consumes: `LevelLoader.get_levels_for_world("drive")`, `LevelLoader.get_difficulty_range()`, `DrivePuzzleGenerator.generate()` / `fewest_tiles()`, `DriveProgram.MAX_TILES`.
- Produces: 20 level dictionaries with `id`, `world`, `mode`, `cols`, `rows`, `obstacles {min, max}`, `turns {min, max}`, `max_tiles`.

- [ ] **Step 1: Write the failing level tests**

`tests/test_world_drive_levels.gd`:

```gdscript
extends GutTest

const REQUIRED_FIELDS := ["id", "world", "mode", "cols", "rows", "obstacles", "turns", "max_tiles"]

var _levels: Array[Dictionary]


func before_all() -> void:
	_levels = LevelLoader.get_levels_for_world("drive")


func test_world_drive_has_20_levels_in_order() -> void:
	assert_eq(_levels.size(), 20)
	for i in _levels.size():
		assert_eq(_levels[i]["id"], "world_drive_%02d" % (i + 1))


func test_world_drive_all_levels_have_required_fields() -> void:
	for level in _levels:
		for field in REQUIRED_FIELDS:
			assert_true(level.has(field), "%s missing %s" % [level.get("id", "?"), field])
		assert_eq(level["world"], "drive")


func test_world_drive_easy_is_global_and_hard_is_relative() -> void:
	var easy: Vector2i = LevelLoader.get_difficulty_range("easy")
	for i in _levels.size():
		assert_eq(_levels[i]["mode"], "global" if i <= easy.y else "relative", _levels[i]["id"])


func test_world_drive_fields_fit_the_screen() -> void:
	for level in _levels:
		assert_between(int(level["cols"]), 4, 7, level["id"])
		assert_between(int(level["rows"]), 3, 5, level["id"])


func test_world_drive_max_tiles_leaves_room_in_the_strip() -> void:
	for level in _levels:
		assert_lt(int(level["max_tiles"]), DriveProgram.MAX_TILES, level["id"])


func test_world_drive_ranges_are_ordered() -> void:
	for level in _levels:
		assert_lte(int(level["obstacles"]["min"]), int(level["obstacles"]["max"]), level["id"])
		assert_lte(int(level["turns"]["min"]), int(level["turns"]["max"]), level["id"])


func test_world_drive_field_never_shrinks_within_difficulty() -> void:
	for difficulty in LevelLoader.DIFFICULTIES:
		var level_range: Vector2i = LevelLoader.get_difficulty_range(difficulty)
		for i in range(level_range.x + 1, level_range.y + 1):
			var area: int = int(_levels[i]["cols"]) * int(_levels[i]["rows"])
			var before: int = int(_levels[i - 1]["cols"]) * int(_levels[i - 1]["rows"])
			assert_gte(area, before, _levels[i]["id"])
```

- [ ] **Step 2: Run them to verify they fail**

Run: `$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gpre_run_script=res://tests/pre_run_hook.gd -gexit -gtest=res://tests/test_world_drive_levels.gd`
Expected: FAIL (`_levels.size()` is 0).

- [ ] **Step 3: Write the level files**

`data/levels/world_drive/levels.json`: a JSON array of `"world_drive_01"` … `"world_drive_20"` in order, formatted like `data/levels/world_memory/levels.json`.

Each level file has this shape (level 7 shown):

```json
{
  "id": "world_drive_07",
  "world": "drive",
  "mode": "global",
  "cols": 6,
  "rows": 4,
  "obstacles": { "min": 5, "max": 7 },
  "turns": { "min": 2, "max": 3 },
  "max_tiles": 4
}
```

Values for every level (from the spec's curve):

| Levels | mode | cols | rows | obstacles | turns | max_tiles |
|---|---|---|---|---|---|---|
| 01, 02 | global | 4 | 3 | 0–1 | 0–1 | 2 |
| 03, 04 | global | 5 | 3 | 2–3 | 1–1 | 3 |
| 05, 06 | global | 5 | 4 | 3–5 | 1–2 | 3 |
| 07, 08 | global | 6 | 4 | 5–7 | 2–3 | 4 |
| 09, 10 | global | 7 | 5 | 7–9 | 2–3 | 4 |
| 11, 12 | relative | 4 | 3 | 1–2 | 1–1 | 3 |
| 13, 14 | relative | 5 | 4 | 3–4 | 1–2 | 5 |
| 15, 16 | relative | 6 | 4 | 5–6 | 2–2 | 5 |
| 17, 18 | relative | 6 | 5 | 6–8 | 2–3 | 7 |
| 19, 20 | relative | 7 | 5 | 8–10 | 3–3 | 7 |

- [ ] **Step 4: Run the level tests**

Run the command from Step 2. Expected: all pass.

- [ ] **Step 5: Add the per-level generator checks**

Append to `tests/test_drive_puzzle_generator.gd`:

```gdscript
const _SEEDS_PER_LEVEL := 100


func test_drive_generator_every_level_fits_its_ranges_without_fallback() -> void:
	var rng := RandomNumberGenerator.new()
	for level: Dictionary in LevelLoader.get_levels_for_world("drive"):
		for seed_value in _SEEDS_PER_LEVEL:
			rng.seed = seed_value
			var field := DrivePuzzleGenerator.generate(level, rng)
			var label := "%s seed %d" % [level["id"], seed_value]
			assert_false(field["fallback"], label)
			var best := DrivePuzzleGenerator.fewest_tiles(field, level["mode"])
			assert_ne(best["tiles"], -1, label)
			assert_lte(best["tiles"], int(level["max_tiles"]), label)
			assert_between(
				best["turns"], int(level["turns"]["min"]), int(level["turns"]["max"]), label
			)
			assert_eq(field["start"].x, 0, label)
			assert_eq(field["garage"].x, int(level["cols"]) - 1, label)
```

- [ ] **Step 6: Run the generator tests**

Run: `$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gpre_run_script=res://tests/pre_run_hook.gd -gexit -gtest=res://tests/test_drive_puzzle_generator.gd`
Expected: all pass, in under about 30 s. If a level falls back for some seeds, its ranges are too tight: widen that level's `obstacles` range by one in the direction that helps (fewer obstacles if routes are blocked, more if too few turns are forced), rerun, and record the change in the spec's curve table. If the test takes more than about 60 s, lower `_SEEDS_PER_LEVEL` to 50.

- [ ] **Step 7: Commit**

```bash
git add data/levels/world_drive tests/test_world_drive_levels.gd* tests/test_drive_puzzle_generator.gd
git -c user.name=malioni -c user.email=47998755+malioni@users.noreply.github.com commit -m "Drive: add the 20 level files and per-level generation checks

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Art

**Files:**
- Create: `tools/make_car_sheets.gd`
- Create (written by the tool): `assets/sprites/drive/car_idle.svg`, `car_drive.svg`, `car_celebrate.svg`, `car_bump.svg`, `car_sad.svg`, `car_frames.tres`
- Create (hand-drawn): `assets/sprites/drive/bg_drive.svg`, `grass_light.svg`, `grass_dark.svg`, `tree.svg`, `rock.svg`, `bush.svg`, `pond.svg`, `garage.svg`, `cmd_up.svg`, `cmd_down.svg`, `cmd_left.svg`, `cmd_right.svg`, `cmd_forward.svg`, `cmd_turn_left.svg`, `cmd_turn_right.svg`, `tile_frame.svg`, `assets/sprites/ui/icon_world_drive.svg`
- Create: `assets/sprites/drive/README.md`
- Create: `tests/test_car_frames.gd`
- Modify: `tests/test_sprites.gd` (sizes; skip the car sheets like the fox's)

**Interfaces:**
- Produces: `res://assets/sprites/drive/car_frames.tres`, a `SpriteFrames` with animations `idle` (4 frames, 6 fps, loops), `drive` (4, 10, loops), `celebrate` (4, 8, loops), `bump` (4, 10, no loop), `sad` (4, 4, loops), each frame one 160×160 cell. The car faces right, centred in its cell. Every texture path listed above, at the sizes in Step 1.

**Style** (match the existing art; open `assets/sprites/memory/animal_fox.svg`, `assets/sprites/picnic/bg_picnic.svg` and `tools/make_fox_sheets.gd` first): rounded shapes, a dark brown outline `#3D2617` about 3–4 px wide, radial-gradient fills from a highlight at the top left to a shade at the bottom right (the fox tool's `_defs()` pattern), warm earthy palette. Fox colours: fur `#F7A058`→`#D96B28`, cream `#FFF6E3`→`#EFD3A8`, dark `#5E3A24`→`#3A2113`. Grass greens about `#9CCB6B` / `#88BC5A`. Everything is seen from straight above except the fox's head, which is drawn as seen from above and slightly behind (ears, top of head, a bit of the face looking right).

- [ ] **Step 1: Record the sizes and the car checks first**

In `tests/test_sprites.gd`, add these entries to `SIZES` (after the memory entries):

```gdscript
	"drive/bg_drive.svg": Vector2(1800, 1000),
	"drive/grass_light.svg": Vector2(128, 128),
	"drive/grass_dark.svg": Vector2(128, 128),
	"drive/tree.svg": Vector2(128, 128),
	"drive/rock.svg": Vector2(128, 128),
	"drive/bush.svg": Vector2(128, 128),
	"drive/pond.svg": Vector2(128, 128),
	"drive/garage.svg": Vector2(128, 128),
	"drive/cmd_up.svg": Vector2(96, 96),
	"drive/cmd_down.svg": Vector2(96, 96),
	"drive/cmd_left.svg": Vector2(96, 96),
	"drive/cmd_right.svg": Vector2(96, 96),
	"drive/cmd_forward.svg": Vector2(96, 96),
	"drive/cmd_turn_left.svg": Vector2(96, 96),
	"drive/cmd_turn_right.svg": Vector2(96, 96),
	"drive/tile_frame.svg": Vector2(96, 96),
	"ui/icon_world_drive.svg": Vector2(128, 128),
```

and change the skip in `test_sprites_every_svg_has_a_recorded_size` to:

```gdscript
		# The fox's and the car's sheets are checked frame by frame in test_fox_frames.gd and
		# test_car_frames.gd.
		if not file.begins_with("fox/") and not file.begins_with("drive/car_"):
```

Create `tests/test_car_frames.gd`:

```gdscript
extends GutTest

## The fox's car in Country Drive (assets/sprites/drive/car_frames.tres), built by
## tools/make_car_sheets.gd.

const FRAMES_PATH := "res://assets/sprites/drive/car_frames.tres"
const SHEET_PATH := "res://assets/sprites/drive/car_%s.svg"
const CELL := 160
# animation -> [frame count, frames per second, loops]
const EXPECTED := {
	"idle": [4, 6.0, true],
	"drive": [4, 10.0, true],
	"celebrate": [4, 8.0, true],
	"bump": [4, 10.0, false],
	"sad": [4, 4.0, true],
}

var _frames: SpriteFrames


func before_each() -> void:
	_frames = load(FRAMES_PATH)


func test_car_frames_has_every_animation() -> void:
	for animation: String in EXPECTED:
		assert_true(_frames.has_animation(animation), "missing %s" % animation)
		assert_eq(_frames.get_frame_count(animation), EXPECTED[animation][0], animation)
		assert_eq(_frames.get_animation_speed(animation), EXPECTED[animation][1], animation)
		assert_eq(_frames.get_animation_loop(animation), EXPECTED[animation][2], animation)


func test_car_frames_each_frame_is_one_cell_of_its_sheet() -> void:
	for animation: String in EXPECTED:
		var count: int = EXPECTED[animation][0]
		for i in count:
			var frame: AtlasTexture = _frames.get_frame_texture(animation, i)
			assert_eq(frame.atlas.resource_path, SHEET_PATH % animation)
			assert_eq(frame.region, Rect2(i * CELL, 0, CELL, CELL))
		var sheet: Texture2D = load(SHEET_PATH % animation)
		assert_true(sheet is DPITexture, "%s: run tools/import_svgs.sh" % animation)
		assert_eq(sheet.get_size(), Vector2(count * CELL, CELL), animation)


func test_car_frames_every_pose_stays_inside_its_cell() -> void:
	# The car is rotated in all four directions, so it must also stay clear of the top and bottom.
	for animation: String in EXPECTED:
		var image := Image.new()
		var svg: String = FileAccess.get_file_as_string(SHEET_PATH % animation)
		assert_eq(image.load_svg_from_string(svg, 1.0), OK, animation)
		for i: int in EXPECTED[animation][0]:
			for x: int in [i * CELL, i * CELL + 1, (i + 1) * CELL - 2, (i + 1) * CELL - 1]:
				assert_false(_column_has_paint(image, x), "%s frame %d col %d" % [animation, i, x])
		for y: int in [0, 1, CELL - 2, CELL - 1]:
			assert_false(_row_has_paint(image, y), "%s row %d" % [animation, y])


func _column_has_paint(image: Image, x: int) -> bool:
	for y in image.get_height():
		if image.get_pixel(x, y).a > 0.0:
			return true
	return false


func _row_has_paint(image: Image, y: int) -> bool:
	for x in image.get_width():
		if image.get_pixel(x, y).a > 0.0:
			return true
	return false
```

Run: `$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gpre_run_script=res://tests/pre_run_hook.gd -gexit -gtest=res://tests/test_car_frames.gd` and the same for `test_sprites.gd`.
Expected: FAIL (files missing).

- [ ] **Step 2: Write the car sheet tool**

`tools/make_car_sheets.gd` follows `tools/make_fox_sheets.gd`: `extends SceneTree`, a `REST` pose dictionary, a `SHEETS` table (`{"frames": Array of pose overrides, "speed": float, "loop": bool}` per animation), and `_init()` writes `car_<name>.svg` for every sheet plus `car_frames.tres`, then `quit()`. Copy `_write()`, `_n()` and `_sprite_frames()` from the fox tool, changing the sheet file name pattern to `car_%s.svg`, the output folder to `res://assets/sprites/drive/` and the resource id prefix to the sheet name.

The car, drawn facing right in a 160×160 cell centred on (80, 80), roughly 120 long and 84 wide, leaving at least 10 px clear on every side:
- Four dark wheels (`dark` gradient, rounded rects 26×14) poking out at the corners; in `drive` their tread lines (3 short light strokes) shift by 4 px per frame.
- A rounded body (`rx` about 30) in a red body gradient `#E8604A`→`#B8382A` with the outline; a lighter bonnet panel towards the right (front); two small yellow headlights `#FFE08A` on the front edge; a grey bumper at the back.
- The open seat in the middle-back with the fox's head seen from above: an orange oval (fur gradient) with two pointed ears with cream insides pointing back-left and back-right, and the snout (cream) and a dark nose pointing right (forward). Two dark eye dots near the snout; the blink frame draws them as short lines.

Pose keys and what each animation does (`REST` values in brackets):
- `bob` [0]: body and head shift up by this many px (the bounce).
- `ears` [0]: ear angle in degrees; positive lifts them, negative droops them.
- `eyes` ["open"]: `"open"`, `"closed"` (blink), `"dizzy"` (small spirals) or `"sad"` (drooped arcs).
- `tread` [0]: wheel tread offset in px.
- `jolt` [0]: whole car shifted left by this many px (the knock-back).
- `stars` [-1]: −1 for none, otherwise the rotation in degrees of three small yellow stars circling over the head.
- `hold` [1.0]: frame duration, as in the fox tool.

| Sheet | Frames (overrides from `REST`) | fps | Loops |
|---|---|---|---|
| idle | {hold 4}, {bob 1, hold 4}, {hold 4}, {eyes closed} | 6 | yes |
| drive | {tread 0, bob 1}, {tread 4}, {tread 8, bob 1}, {tread 12} | 10 | yes |
| celebrate | {bob 4, ears 10}, {bob 8, ears 20}, {bob 4, ears 10}, {bob 0, ears 0} | 8 | yes |
| bump | {jolt 6, eyes dizzy, stars 0}, {jolt 3, eyes dizzy, stars 40}, {jolt 1, eyes dizzy, stars 80}, {eyes dizzy, stars 120} | 10 | no |
| sad | {ears -15, eyes sad}, {ears -18, eyes sad, bob -1}, {ears -15, eyes sad}, {ears -12, eyes sad} | 4 | yes |

Run: `$GODOT --path . --headless -s tools/make_car_sheets.gd`, then `tools/import_svgs.sh`.

- [ ] **Step 3: Draw the field and button SVGs**

Each file is a plain SVG with `width`, `height` and a matching `viewBox` at the size from Step 1:
- `bg_drive.svg` (1800×1000): a soft meadow seen from above: a green base with lighter and darker grass patches, a few small flower dots and a pale dirt path along the far left and far right edges (outside the 1280×720 play area, which is centred). Keep it quiet: the field squares sit on top.
- `grass_light.svg`, `grass_dark.svg` (128×128): a flat square of grass (`#9CCB6B` and `#88BC5A`), with three or four tiny blade strokes in a slightly darker green, no outline, so neighbouring squares join into a checkerboard.
- `tree.svg` (128×128): a round canopy seen from above (three overlapping green circles, darker shade at the bottom right), a hint of trunk shadow.
- `rock.svg` (128×128): a grey rounded boulder with a highlight and two cracks.
- `bush.svg` (128×128): a lower, lumpier green shape than the tree, with three red berries.
- `pond.svg` (128×128): a blue rounded pond with a lighter shine, a reed tuft and a lily pad.
- `garage.svg` (128×128): the fox's little garage seen from above: a red-brown roof with ridge line and an open door side facing left (the side the car drives in from), a small orange fox-ear shape on the roof as a sign.
- `cmd_up/down/left/right.svg` (96×96): a fat rounded arrow in cream with the brown outline, pointing that way, on a transparent background.
- `cmd_forward.svg` (96×96): a small car seen from above (the car's body colours) with a fat arrow ahead of it, pointing up.
- `cmd_turn_left.svg`, `cmd_turn_right.svg` (96×96): a fat arrow curving 90° from pointing up to pointing left / right, same style.
- `tile_frame.svg` (96×96): a rounded square (rx 16), white fill, light grey `#D0D0D0` inner border, dark outline. It is tinted in code (lit: warm yellow, marked: soft red), so it must stay white and grey inside the outline.
- `ui/icon_world_drive.svg` (128×128): the car (from the right-facing sheet style) on a bit of grass with a pale path, matching the other world icons' framing.

Run: `tools/import_svgs.sh`.

- [ ] **Step 4: Run the art tests**

Run: the `test_car_frames.gd` and `test_sprites.gd` commands from Step 1.
Expected: all pass. If a car pose touches its cell's edge, shrink the car slightly in the tool.

- [ ] **Step 5: Look at the art**

Write a throwaway viewer at `/private/tmp/claude-501/-Users-matiss-Documents-kids-math-game/<session>/scratchpad/art_sheet.gd` (an `extends SceneTree` script that adds a `Node2D` with Sprite2Ds for every new texture, scale 1, in a grid on a 1280×720 window, waits two frames, saves `get_root().get_texture().get_image()` to a PNG next to it, and quits). Run it with `$GODOT --path . -s <that path>` (not headless; the window opens briefly). Open the PNG with the Read tool and check: outlines and gradients match the other worlds, the car reads as a car with the fox in it, every obstacle is clearly different at 90 px, the arrows are unmistakable. Fix what's off and rerun.

- [ ] **Step 6: README and commit**

`assets/sprites/drive/README.md`: a table of every file with its size and use, as in `assets/sprites/memory/README.md`; a section on the car sheets copying the fox README's "edit the tool, don't edit the SVGs" rule with the run commands; and the note that `tile_frame.svg` is tinted, so it must stay white and grey inside.

```bash
~/.local/bin/gdlint tools/make_car_sheets.gd tests/test_car_frames.gd tests/test_sprites.gd
git add tools/make_car_sheets.gd* assets/sprites/drive assets/sprites/ui/icon_world_drive.svg* tests/test_car_frames.gd* tests/test_sprites.gd
git -c user.name=malioni -c user.email=47998755+malioni@users.noreply.github.com commit -m "Drive: add the car sheets, field, command and world icon art

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: DriveTile and DriveMechanic

**Files:**
- Create: `scenes/mechanics/drive_tile.tscn`, `scripts/mechanics/drive_tile.gd`
- Create: `scenes/mechanics/drive_mechanic.tscn`, `scripts/mechanics/drive_mechanic.gd`
- Test: `tests/test_drive_mechanic.gd`

**Interfaces:**
- Consumes: `DriveProgram`, `DriveSimulator.run()`, `DrivePuzzleGenerator.COMMANDS`, `Mechanic`, the art from Task 5.
- Produces:
  - `class_name DriveTile extends TextureButton`: `setup(icon: Texture2D, count: int) -> void`, `set_lit(lit: bool) -> void`, `set_marked(marked: bool) -> void`, `is_lit() -> bool`, `is_marked() -> bool`; `const LIT_TINT`, `MARKED_TINT`.
  - `class_name DriveMechanic extends Mechanic`: signals `bumped(kind: String)`, `stopped_short`, `stepped`; exports `command_textures: Dictionary` (command → Texture2D), `obstacle_textures: Dictionary` (kind → Texture2D), `grass_textures: Array[Texture2D]` (two shades), `garage_texture: Texture2D`, `tile_texture: Texture2D`, `go_texture: Texture2D`, `car_frames: SpriteFrames`, `field_rect := Rect2(190, 110, 1060, 450)`, `max_square_size := 110.0`, `buttons_origin := Vector2(30, 120)`, `strip_origin := Vector2(30, 592)`, `step_duration := 0.35`, `turn_duration := 0.2`; methods `setup(field: Dictionary, mode: String)`, `reset()`, `set_interactive(enabled: bool)`, `press_command(command: String)`, `tap_tile(index: int)`, `go()`, `get_program() -> DriveProgram`, `get_car() -> AnimatedSprite2D`, `get_field() -> Dictionary`, `get_mode() -> String`, `get_tiles() -> Array[DriveTile]`, `get_command_buttons() -> Dictionary` (command → TextureButton), `get_lit_tile() -> int`, `get_marked_tile() -> int`, `is_driving() -> bool`, `cell_position(cell: Vector2i) -> Vector2`.

Layout, in the world's 1280×720 coordinates (the mechanic sits at (0, 0)); the level badge occupies about x 20–220, y 10–96:
- Command buttons: 90×90, stacked from `buttons_origin` with 12 px gaps (4 buttons reach y 516).
- Field: squares of `min(max_square_size, field_rect.size.x / cols, field_rect.size.y / rows)`, the grid centred in `field_rect` (7×5 gives 90 px).
- Strip: 76×76 tiles from `strip_origin` with 6 px gaps (12 tiles end at x 1008).
- Go: a 120×120 `TextureButton` at offsets (1080, 570)–(1200, 690).

- [ ] **Step 1: Write DriveTile**

`scripts/mechanics/drive_tile.gd`:

```gdscript
class_name DriveTile
extends TextureButton

## One tile in the drive program strip: a command icon and, above 1, how many times it runs. Lit
## while the car runs it; marked where the last run went wrong.

## Tint of the frame while the car runs this tile.
const LIT_TINT := Color(1.0, 0.86, 0.45)
## Tint of the frame where the last run went wrong.
const MARKED_TINT := Color(1.0, 0.6, 0.55)

var _lit: bool = false
var _marked: bool = false

@onready var _icon: TextureRect = $Icon
@onready var _count: Label = $Count


## Shows icon, and count when it is above 1.
func setup(icon: Texture2D, count: int) -> void:
	_icon.texture = icon
	_count.text = str(count)
	_count.visible = count > 1


## Lights the tile, or turns the light off.
func set_lit(lit: bool) -> void:
	_lit = lit
	_tint()


## Marks the tile as where the last run went wrong, or clears the mark.
func set_marked(marked: bool) -> void:
	_marked = marked
	_tint()


## Returns true while the tile is lit.
func is_lit() -> bool:
	return _lit


## Returns true while the tile is marked.
func is_marked() -> bool:
	return _marked


func _tint() -> void:
	if _lit:
		self_modulate = LIT_TINT
	elif _marked:
		self_modulate = MARKED_TINT
	else:
		self_modulate = Color.WHITE
```

`scenes/mechanics/drive_tile.tscn`: a `TextureButton` root named `DriveTile` with the script, `texture_normal = tile_frame.svg`, `ignore_texture_size = true`, `stretch_mode = 0` (scale), size 76×76 (`offset_right = 76`, `offset_bottom = 76`); child `Icon` (`TextureRect`, anchors full rect with 10 px margins, `expand_mode = 1`, `stretch_mode = 5`, `mouse_filter = 2`); child `Count` (`Label`, anchored to the bottom-right corner, 30×30, the plank label's style: font colour `Color(0.24, 0.15, 0.09)`, outline `Color(1, 0.96, 0.86)` size 8, font size 26, centred, `mouse_filter = 2`). The frame texture is the mechanic's resource path, which is art, not world code: `res://assets/sprites/drive/tile_frame.svg`; it may be overridden through `DriveMechanic.tile_texture`.

- [ ] **Step 2: Write the failing mechanic tests**

`tests/test_drive_mechanic.gd`:

```gdscript
extends GutTest

const SCENE := preload("res://scenes/mechanics/drive_mechanic.tscn")
const CAR_FRAMES := preload("res://assets/sprites/drive/car_frames.tres")
const _FAST := 0.01

# 4×3, start (0, 1), garage (3, 1), a tree at (2, 1).
var _field := {
	"cols": 4,
	"rows": 3,
	"start": Vector2i(0, 1),
	"garage": Vector2i(3, 1),
	"obstacles": [{"cell": Vector2i(2, 1), "kind": "tree"}],
	"fallback": false,
}
var _mechanic: DriveMechanic


func before_each() -> void:
	_mechanic = SCENE.instantiate()
	_mechanic.car_frames = CAR_FRAMES
	_mechanic.step_duration = _FAST
	_mechanic.turn_duration = _FAST
	add_child_autofree(_mechanic)
	_mechanic.setup(_field, "global")


func _press(commands: Array) -> void:
	for command: String in commands:
		_mechanic.press_command(command)


func _win_route() -> Array:
	return ["down", "right", "right", "right", "up"]


func test_drive_mechanic_buttons_match_the_mode() -> void:
	assert_eq(_mechanic.get_command_buttons().keys(), ["up", "down", "left", "right"])
	_mechanic.setup(_field, "relative")
	assert_eq(_mechanic.get_command_buttons().keys(), ["forward", "turn_left", "turn_right"])


func test_drive_mechanic_pressing_builds_merged_tiles() -> void:
	watch_signals(_mechanic)
	_press(["right", "right", "down"])
	assert_eq(_mechanic.get_tiles().size(), 2)
	assert_eq(_mechanic.get_program().get_tiles()[0]["count"], 2)
	assert_signal_emit_count(_mechanic, "piece_placed", 3)


func test_drive_mechanic_command_buttons_press_commands() -> void:
	_mechanic.get_command_buttons()["down"].pressed.emit()
	assert_eq(_mechanic.get_program().get_tiles(), [{"command": "down", "count": 1}])


func test_drive_mechanic_tapping_a_tile_takes_a_step_off() -> void:
	watch_signals(_mechanic)
	_press(["right", "right", "down"])
	_mechanic.tap_tile(0)
	_mechanic.tap_tile(1)
	assert_eq(_mechanic.get_program().get_tiles(), [{"command": "right", "count": 1}])
	assert_signal_emit_count(_mechanic, "piece_removed", 2)


func test_drive_mechanic_full_strip_dims_other_buttons() -> void:
	for i in DriveProgram.MAX_TILES:
		_mechanic.press_command("up" if i % 2 == 0 else "down")
	var buttons: Dictionary = _mechanic.get_command_buttons()
	assert_false(buttons["down"].disabled, "the last tile is down")
	assert_true(buttons["up"].disabled)
	assert_true(buttons["left"].disabled)
	_mechanic.press_command("left")
	assert_eq(_mechanic.get_tiles().size(), DriveProgram.MAX_TILES)


func test_drive_mechanic_go_with_empty_program_does_nothing() -> void:
	watch_signals(_mechanic)
	_mechanic.go()
	assert_false(_mechanic.is_driving())
	await wait_seconds(0.1)
	assert_signal_not_emitted(_mechanic, "incorrect")


func test_drive_mechanic_win_route_emits_correct_once() -> void:
	watch_signals(_mechanic)
	_press(_win_route())
	_mechanic.go()
	assert_true(_mechanic.is_driving())
	await wait_for_signal(_mechanic.correct, 2.0)
	await wait_seconds(0.1)
	assert_signal_emit_count(_mechanic, "correct", 1)
	assert_signal_not_emitted(_mechanic, "incorrect")
	assert_signal_emit_count(_mechanic, "stepped", 5)
	assert_eq(_mechanic.get_car().position, _mechanic.cell_position(Vector2i(3, 1)))
	assert_false(_mechanic.is_driving())


func test_drive_mechanic_tiles_light_in_order() -> void:
	_mechanic.step_duration = 0.2
	_press(["down", "right"])
	_mechanic.go()
	await wait_process_frames(2)
	assert_eq(_mechanic.get_lit_tile(), 0)
	await wait_seconds(0.3)
	assert_eq(_mechanic.get_lit_tile(), 1)
	await wait_for_signal(_mechanic.incorrect, 2.0)
	assert_eq(_mechanic.get_lit_tile(), -1)


func test_drive_mechanic_bump_reports_kind_then_incorrect_and_marks_tile() -> void:
	watch_signals(_mechanic)
	_press(["right", "right"])
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	assert_signal_emitted_with_parameters(_mechanic, "bumped", ["tree"])
	assert_signal_not_emitted(_mechanic, "stopped_short")
	assert_eq(_mechanic.get_marked_tile(), 0)
	assert_true(_mechanic.get_tiles()[0].is_marked())


func test_drive_mechanic_short_stop_reports_and_marks_last_tile() -> void:
	watch_signals(_mechanic)
	_press(["down", "right"])
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	assert_signal_emitted(_mechanic, "stopped_short")
	assert_signal_not_emitted(_mechanic, "bumped")
	assert_eq(_mechanic.get_marked_tile(), 1)


func test_drive_mechanic_through_the_garage_and_on_is_incorrect() -> void:
	watch_signals(_mechanic)
	_press(_win_route() + ["up"])
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	assert_signal_not_emitted(_mechanic, "correct")


func test_drive_mechanic_input_ignored_while_driving() -> void:
	_mechanic.step_duration = 0.2
	watch_signals(_mechanic)
	_press(["down", "right"])
	_mechanic.go()
	_mechanic.press_command("up")
	_mechanic.tap_tile(0)
	_mechanic.go()
	assert_eq(_mechanic.get_program().get_tiles().size(), 2)
	assert_true(_mechanic.get_command_buttons()["up"].disabled)
	await wait_for_signal(_mechanic.incorrect, 2.0)
	await wait_seconds(0.3)
	assert_signal_emit_count(_mechanic, "incorrect", 1)


func test_drive_mechanic_not_interactive_ignores_input() -> void:
	_mechanic.set_interactive(false)
	_mechanic.press_command("up")
	assert_true(_mechanic.get_program().is_empty())
	assert_true(_mechanic.get_command_buttons()["up"].disabled)


func test_drive_mechanic_reset_keeps_program_and_mark_and_returns_car() -> void:
	_press(["right", "right"])
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	_mechanic.reset()
	assert_eq(_mechanic.get_program().get_tiles(), [{"command": "right", "count": 2}])
	assert_eq(_mechanic.get_marked_tile(), 0)
	assert_eq(_mechanic.get_car().position, _mechanic.cell_position(Vector2i(0, 1)))
	assert_eq(_mechanic.get_car().rotation, 0.0)


func test_drive_mechanic_editing_clears_the_mark() -> void:
	_press(["right", "right"])
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	_mechanic.reset()
	_mechanic.press_command("up")
	assert_eq(_mechanic.get_marked_tile(), -1)


func test_drive_mechanic_go_clears_the_mark() -> void:
	_mechanic.step_duration = 0.2
	_press(["right", "right"])
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	_mechanic.reset()
	_mechanic.go()
	assert_eq(_mechanic.get_marked_tile(), -1)


func test_drive_mechanic_setup_clears_program_and_mark() -> void:
	_press(["right", "right"])
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	_mechanic.setup(_field, "global")
	assert_true(_mechanic.get_program().is_empty())
	assert_eq(_mechanic.get_marked_tile(), -1)


func test_drive_mechanic_setup_mid_drive_stops_the_old_drive() -> void:
	_mechanic.step_duration = 0.1
	watch_signals(_mechanic)
	_press(_win_route())
	_mechanic.go()
	await wait_seconds(0.15)
	_mechanic.setup(_field, "global")
	await wait_seconds(1.0)
	assert_signal_not_emitted(_mechanic, "correct")
	assert_signal_not_emitted(_mechanic, "incorrect")
	assert_false(_mechanic.is_driving())
	assert_eq(_mechanic.get_car().position, _mechanic.cell_position(Vector2i(0, 1)))


func test_drive_mechanic_relative_route_wins() -> void:
	_mechanic.setup(_field, "relative")
	watch_signals(_mechanic)
	_press(["turn_right", "forward", "turn_left", "forward", "forward", "forward"])
	_press(["turn_left", "forward"])
	_mechanic.go()
	await wait_for_signal(_mechanic.correct, 2.0)
	assert_signal_emitted(_mechanic, "correct")


func test_drive_mechanic_draws_field() -> void:
	assert_eq(_mechanic.get_node("Field/Grass").get_child_count(), 12)
	assert_eq(_mechanic.get_node("Field/Obstacles").get_child_count(), 1)
	assert_eq(
		_mechanic.get_node("Field/Garage").position, _mechanic.cell_position(Vector2i(3, 1))
	)
```

Run: `$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gpre_run_script=res://tests/pre_run_hook.gd -gexit -gtest=res://tests/test_drive_mechanic.gd`
Expected: errors (scene missing).

- [ ] **Step 3: Write the mechanic scene**

`scenes/mechanics/drive_mechanic.tscn`: root `DriveMechanic` (`Node2D`, script `drive_mechanic.gd`) with children:
- `Field` (`Node2D`) with `Grass` (`Node2D`), `Obstacles` (`Node2D`), `Garage` (`Sprite2D`) and `Car` (`AnimatedSprite2D`, `z_index = 1`), in that order so the car draws on top.
- `Buttons` (`Node2D`).
- `Strip` (`Node2D`).
- `GoButton` (`TextureButton`, `offset_left = 1080`, `offset_top = 570`, `offset_right = 1200`, `offset_bottom = 690`, `ignore_texture_size = true`, `stretch_mode = 5`).

- [ ] **Step 4: Write the mechanic script**

`scripts/mechanics/drive_mechanic.gd`:

```gdscript
class_name DriveMechanic
extends Mechanic

## A driving puzzle. The car starts on the left of a grid, its garage is on the right and obstacles
## stand between. The player builds a program from command buttons (screen arrows in "global" mode;
## forward and turns in "relative" mode), then presses Go: the car runs it square by square, the
## running tile lit. correct is emitted when the last move ends on the garage; a bump into an
## obstacle or the field's edge, or a program that ends anywhere else, emits incorrect and marks
## the tile where it went wrong.

## Emitted before incorrect when the car bumps; kind is "edge" or the obstacle's kind.
signal bumped(kind: String)
## Emitted before incorrect when the program ends without reaching the garage.
signal stopped_short
## Emitted each time the car drives one square.
signal stepped

const TILE_SCENE := preload("res://scenes/mechanics/drive_tile.tscn")
## Width and height of a car frame and of the obstacle and garage textures, in pixels.
const CAR_CELL := 160.0
const ART_SIZE := 128.0
const BUTTON_SIZE := 90.0
const BUTTON_GAP := 12.0
const TILE_SIZE := 76.0
const TILE_GAP := 6.0

## Icon of each command (String → Texture2D), used on its button and on its tiles.
@export var command_textures: Dictionary = {}
## Texture of each obstacle kind (String → Texture2D).
@export var obstacle_textures: Dictionary = {}
## The two grass shades, laid as a checkerboard.
@export var grass_textures: Array[Texture2D] = []
## The garage's texture.
@export var garage_texture: Texture2D
## The frame behind every tile; null keeps the tile scene's own.
@export var tile_texture: Texture2D
## The Go button's texture.
@export var go_texture: Texture2D
## The car's animations: idle, drive, celebrate, bump and sad.
@export var car_frames: SpriteFrames
## Area the grid is centred in, in local pixels.
@export var field_rect: Rect2 = Rect2(190, 110, 1060, 450)
## Largest a square is drawn, so small fields don't look huge.
@export var max_square_size: float = 110.0
## Top-left of the command button column.
@export var buttons_origin: Vector2 = Vector2(30, 120)
## Top-left of the program strip.
@export var strip_origin: Vector2 = Vector2(30, 592)
## Seconds the car takes to drive one square.
@export var step_duration: float = 0.35
## Seconds the car takes to turn 90°.
@export var turn_duration: float = 0.2

var _program := DriveProgram.new()
var _field: Dictionary = {}
var _mode: String = "global"
var _square: float = 0.0
var _origin: Vector2 = Vector2.ZERO
var _interactive: bool = true
var _driving: bool = false
var _lit: int = -1
var _marked: int = -1
# Bumped by setup() and reset(); a drive checks it after every wait and stops if it changed.
var _run: int = 0
var _tween: Tween
var _command_buttons: Dictionary = {}

@onready var _grass: Node2D = $Field/Grass
@onready var _obstacles: Node2D = $Field/Obstacles
@onready var _garage: Sprite2D = $Field/Garage
@onready var _car: AnimatedSprite2D = $Field/Car
@onready var _buttons: Node2D = $Buttons
@onready var _strip: Node2D = $Strip
@onready var _go_button: TextureButton = $GoButton


func _ready() -> void:
	if car_frames != null:
		_car.sprite_frames = car_frames
	if go_texture != null:
		_go_button.texture_normal = go_texture
	_go_button.pressed.connect(go)


## Lays out field (see DrivePuzzleGenerator.generate()) and the buttons for mode ("global" or
## "relative"), empties the program and puts the car on the start.
func setup(field: Dictionary, mode: String) -> void:
	_field = field
	_mode = mode
	_program.clear()
	_marked = -1
	_draw_field()
	_make_buttons()
	reset()


## Stops any drive and puts the car back on the start, facing right. The program and the mark
## stay, so the player can fix the program.
func reset() -> void:
	_run += 1
	if _tween != null:
		_tween.kill()
	_driving = false
	_lit = -1
	if not _field.is_empty():
		_car.position = cell_position(_field["start"])
	_car.rotation = 0.0
	_play_car("idle")
	_refresh()


## Enables or disables the buttons, the tiles and Go.
func set_interactive(enabled: bool) -> void:
	_interactive = enabled
	_refresh()


## Adds one step of command to the program, as if its button was pressed.
func press_command(command: String) -> void:
	if not _can_edit() or not _program.can_add(command):
		return
	_program.add(command)
	_marked = -1
	_refresh()
	piece_placed.emit()


## Takes one step off the tile at index, as if it was tapped.
func tap_tile(index: int) -> void:
	if not _can_edit() or index < 0 or index >= _program.get_tiles().size():
		return
	_program.take_step(index)
	_marked = -1
	_refresh()
	piece_removed.emit()


## Runs the program, as if Go was pressed. Does nothing while driving, when not interactive, or
## when the program is empty.
func go() -> void:
	if not _can_edit() or _program.is_empty():
		return
	_marked = -1
	_drive(_run)


## Returns the program.
func get_program() -> DriveProgram:
	return _program


## Returns the car, which is also the world's character.
func get_car() -> AnimatedSprite2D:
	return $Field/Car


## Returns the field passed to setup().
func get_field() -> Dictionary:
	return _field


## Returns the mode passed to setup().
func get_mode() -> String:
	return _mode


## Returns the strip's tiles in order.
func get_tiles() -> Array[DriveTile]:
	var tiles: Array[DriveTile] = []
	for tile: DriveTile in _strip.get_children():
		if not tile.is_queued_for_deletion():
			tiles.append(tile)
	return tiles


## Returns the command buttons for the current mode (command → TextureButton), in button order.
func get_command_buttons() -> Dictionary:
	return _command_buttons


## Returns the index of the tile the car is running, or -1.
func get_lit_tile() -> int:
	return _lit


## Returns the index of the tile where the last run went wrong, or -1.
func get_marked_tile() -> int:
	return _marked


## Returns true while the car is running the program.
func is_driving() -> bool:
	return _driving


## Returns the centre of cell in local pixels.
func cell_position(cell: Vector2i) -> Vector2:
	return _origin + (Vector2(cell) + Vector2(0.5, 0.5)) * _square


func _can_edit() -> bool:
	return _interactive and not _driving


func _drive(run_id: int) -> void:
	var moves := _program.expand()
	var result := DriveSimulator.run(_field, moves)
	var poses: Array = result["poses"]
	_driving = true
	_refresh()
	var facing := DriveSimulator.RIGHT
	for i in poses.size():
		_lit = moves[i]["tile"]
		_refresh()
		var pose: Dictionary = poses[i]
		if pose["facing"] != facing:
			facing = pose["facing"]
			await _turn_to(facing)
			if run_id != _run:
				return
		if i == result["fail_move"] and result["outcome"] == "bump":
			await _nudge(facing)
		elif pose["cell"] != _cell_of_car():
			_play_car("drive")
			stepped.emit()
			await _move_to(cell_position(pose["cell"]))
		if run_id != _run:
			return
	_driving = false
	_lit = -1
	_play_car("idle")
	if result["outcome"] == "garage":
		_refresh()
		correct.emit()
		return
	_marked = moves[result["fail_move"]]["tile"]
	_refresh()
	if result["outcome"] == "bump":
		bumped.emit(result["bump_kind"])
	else:
		stopped_short.emit()
	incorrect.emit()


func _turn_to(facing: Vector2i) -> Signal:
	var target: float = Vector2(facing).angle()
	_tween = create_tween()
	_tween.tween_method(
		func(weight: float) -> void: _car.rotation = lerp_angle(_car.rotation, target, weight),
		0.0,
		1.0,
		turn_duration
	)
	return _tween.finished


func _move_to(target: Vector2) -> Signal:
	_tween = create_tween()
	_tween.tween_property(_car, "position", target, step_duration)
	return _tween.finished


# Drives a third of a square towards whatever is in the way, and back.
func _nudge(facing: Vector2i) -> Signal:
	var home: Vector2 = _car.position
	_tween = create_tween()
	_tween.tween_property(_car, "position", home + Vector2(facing) * _square / 3.0, step_duration / 2.0)
	_tween.tween_property(_car, "position", home, step_duration / 2.0)
	return _tween.finished


func _cell_of_car() -> Vector2i:
	return Vector2i(((_car.position - _origin) / _square).floor())


func _play_car(animation: String) -> void:
	if _car.sprite_frames != null and _car.sprite_frames.has_animation(animation):
		_car.play(animation)


func _draw_field() -> void:
	var cols := int(_field["cols"])
	var rows := int(_field["rows"])
	_square = minf(max_square_size, minf(field_rect.size.x / cols, field_rect.size.y / rows))
	_origin = field_rect.get_center() - Vector2(cols, rows) * _square / 2.0
	for child in _grass.get_children() + _obstacles.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	for y in rows:
		for x in cols:
			var grass := Sprite2D.new()
			if grass_textures.size() == 2:
				grass.texture = grass_textures[(x + y) % 2]
			grass.position = cell_position(Vector2i(x, y))
			grass.scale = Vector2.ONE * _square / ART_SIZE
			_grass.add_child(grass)
	for obstacle: Dictionary in _field["obstacles"]:
		var sprite := Sprite2D.new()
		sprite.texture = obstacle_textures.get(obstacle["kind"])
		sprite.position = cell_position(obstacle["cell"])
		sprite.scale = Vector2.ONE * _square / ART_SIZE
		_obstacles.add_child(sprite)
	_garage.texture = garage_texture
	_garage.position = cell_position(_field["garage"])
	_garage.scale = Vector2.ONE * _square / ART_SIZE
	_car.scale = Vector2.ONE * _square / CAR_CELL


func _make_buttons() -> void:
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	_command_buttons.clear()
	var commands: Array = DrivePuzzleGenerator.COMMANDS[_mode]
	for i in commands.size():
		var command: String = commands[i]
		var button := TextureButton.new()
		button.texture_normal = command_textures.get(command)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.position = buttons_origin + Vector2(0, i * (BUTTON_SIZE + BUTTON_GAP))
		button.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
		button.pressed.connect(press_command.bind(command))
		_buttons.add_child(button)
		_command_buttons[command] = button


# Rebuilds the strip from the program and updates every button's state.
func _refresh() -> void:
	for child in _strip.get_children():
		_strip.remove_child(child)
		child.queue_free()
	var tiles := _program.get_tiles()
	for i in tiles.size():
		var tile: DriveTile = TILE_SCENE.instantiate()
		if tile_texture != null:
			tile.texture_normal = tile_texture
		tile.position = strip_origin + Vector2(i * (TILE_SIZE + TILE_GAP), 0)
		_strip.add_child(tile)
		tile.setup(command_textures.get(tiles[i]["command"]), int(tiles[i]["count"]))
		tile.set_lit(i == _lit)
		tile.set_marked(i == _marked)
		tile.disabled = not _can_edit()
		tile.pressed.connect(tap_tile.bind(i))
	for command: String in _command_buttons:
		var button: TextureButton = _command_buttons[command]
		button.disabled = not _can_edit() or not _program.can_add(command)
		button.modulate.a = 0.4 if button.disabled else 1.0
	_go_button.disabled = not _can_edit()
```

Notes for the implementer:
- `_refresh()` uses `remove_child` before `queue_free`, so `get_tiles()` never sees an old tile (the memory mechanic does the same).
- `_cell_of_car()` only decides whether a pose moved the car; a turn keeps the cell, so it doesn't step.
- `gdformat` may rewrap long lines; run it, then lint.

- [ ] **Step 5: Register and run the tests**

Run: `$GODOT --path . --headless --import`, then the command from Step 2.
Expected: all `test_drive_mechanic` tests pass.

- [ ] **Step 6: Format, lint and commit**

```bash
gdformat scripts/mechanics/drive_mechanic.gd scripts/mechanics/drive_tile.gd tests/test_drive_mechanic.gd
~/.local/bin/gdlint scripts/mechanics scenes/mechanics tests/test_drive_mechanic.gd
git add scenes/mechanics/drive_*.tscn scripts/mechanics/drive_mechanic.gd* scripts/mechanics/drive_tile.gd* tests/test_drive_mechanic.gd*
git -c user.name=malioni -c user.email=47998755+malioni@users.noreply.github.com commit -m "Drive: add DriveMechanic and DriveTile

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: The world, its sounds and its registration

**Files:**
- Create: `scripts/worlds/drive.gd`, `scenes/worlds/drive/drive.tscn`, `tests/test_drive.gd`
- Modify: `scripts/autoloads/game_registry.gd` (add the world)
- Modify: `tools/make_audio_placeholders.gd`; create (written by it) `assets/audio/drive/ambience.wav`, `place.wav`, `remove.wav`, `step.wav`, `bump.wav`, `honk.wav`
- Modify: `tests/test_game_registry.gd`, `tests/test_world_modes.gd`, `tests/test_fox_frames.gd` (world lists)

**Interfaces:**
- Consumes: `DriveMechanic` (Task 6), `DrivePuzzleGenerator.generate()` / `fewest_tiles()`, `WorldBase`, `AudioManager.play_sfx()`.
- Produces: the `drive` world: `GameRegistry.WORLDS` entry `{"id": "drive", "scene": "res://scenes/worlds/drive/drive.tscn", "icon": "res://assets/sprites/ui/icon_world_drive.svg"}` after `memory`; `drive.gd` exports `honk_duration := 0.4`, `lose_duration := 0.8`.

- [ ] **Step 1: Write the failing world tests**

`tests/test_drive.gd`:

```gdscript
extends GutTest

const SCENE := preload("res://scenes/worlds/drive/drive.tscn")
const _SEED := 1234
const _FAST := 0.01

var _world: Node2D
var _mechanic: DriveMechanic
var _retry: BaseButton
var _hud: LevelHud


func before_each() -> void:
	SaveFixture.clear()
	_world = _make_world()
	add_child(_world)
	_mechanic = _world.get_node("DriveMechanic")
	_retry = _world.get_node("RetryPrompt/RetryIcon")
	_hud = _world.get_node("LevelHud")


func after_each() -> void:
	_world.queue_free()
	SaveFixture.clear()


func _make_world() -> Node2D:
	var world: Node2D = SCENE.instantiate()
	world.celebrate_duration = 0.01
	world.honk_duration = _FAST
	world.lose_duration = _FAST
	world.puzzle_seed = _SEED
	var mechanic: DriveMechanic = world.get_node("DriveMechanic")
	mechanic.step_duration = _FAST
	mechanic.turn_duration = _FAST
	return world


## Enters the shortest program for the current field.
func _enter_solution() -> void:
	var best := DrivePuzzleGenerator.fewest_tiles(_mechanic.get_field(), _mechanic.get_mode())
	for tile: Dictionary in best["program"]:
		for step in int(tile["count"]):
			_mechanic.press_command(tile["command"])


## Enters a program that stops short without bumping: the shortest program's first step only.
## Every field needs at least three squares, so one step never reaches the garage.
func _enter_short() -> void:
	var best := DrivePuzzleGenerator.fewest_tiles(_mechanic.get_field(), _mechanic.get_mode())
	_mechanic.press_command(best["program"][0]["command"])


func _sfx_played() -> Array:
	var sounds: Array = []
	for i in get_signal_emit_count(AudioManager, "sfx_played"):
		sounds.append(get_signal_parameters(AudioManager, "sfx_played", i)[0])
	return sounds


func test_drive_world_id_is_drive() -> void:
	assert_eq(_world._world_id(), "drive")
	assert_eq(SaveManager.load_last_world(), "drive")


func test_drive_character_is_the_car() -> void:
	assert_eq(_world._character, _mechanic.get_car())
	assert_eq(_world._character.sprite_frames.resource_path, "res://assets/sprites/drive/car_frames.tres")


func test_drive_level_1_is_a_global_4_by_3_field() -> void:
	assert_eq(_mechanic.get_mode(), "global")
	assert_eq(_mechanic.get_field()["cols"], 4)
	assert_eq(_mechanic.get_command_buttons().size(), 4)


func test_drive_reaching_the_garage_honks_and_advances() -> void:
	watch_signals(AudioManager)
	_enter_solution()
	_mechanic.go()
	await wait_for_signal(_mechanic.correct, 3.0)
	await wait_seconds(0.3)
	assert_eq(_world._current_index, 1)
	assert_has(_sfx_played(), "drive/honk")
	assert_has(_sfx_played(), "drive/step")
	assert_true(_mechanic.get_program().is_empty(), "a new level starts with an empty program")


func test_drive_stopping_short_shows_retry_and_sad_car() -> void:
	_world.lose_duration = 0.5
	_enter_short()
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	await wait_process_frames(2)
	assert_eq(_mechanic.get_car().animation, &"sad")
	await wait_seconds(0.7)
	assert_true(_retry.visible)


func test_drive_bump_plays_bump_sound_and_animation() -> void:
	watch_signals(AudioManager)
	_world.lose_duration = 0.5
	# Driving up from the start runs off the top edge on any field within rows moves.
	for i in int(_mechanic.get_field()["rows"]):
		_mechanic.press_command("up")
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	await wait_process_frames(2)
	assert_eq(_mechanic.get_car().animation, &"bump")
	assert_has(_sfx_played(), "drive/bump")
	await wait_seconds(0.7)
	assert_true(_retry.visible)


func test_drive_retry_keeps_program_and_returns_car() -> void:
	_enter_short()
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	await wait_seconds(0.2)
	_retry.pressed.emit()
	assert_false(_retry.visible)
	assert_eq(_mechanic.get_program().get_tiles().size(), 1)
	assert_eq(_mechanic.get_marked_tile(), 0)
	assert_eq(
		_mechanic.get_car().position, _mechanic.cell_position(_mechanic.get_field()["start"])
	)
	_mechanic.press_command("up")
	assert_eq(_mechanic.get_program().get_tiles().size(), 2, "editing works after retry")


func test_drive_level_change_mid_drive_leaves_nothing_behind() -> void:
	_mechanic.step_duration = 0.2
	watch_signals(_mechanic)
	_enter_solution()
	_mechanic.go()
	await wait_seconds(0.1)
	_hud.level_chosen.emit("drive", 7)
	await wait_seconds(1.5)
	assert_eq(_world._current_index, 7)
	assert_signal_not_emitted(_mechanic, "correct")
	assert_false(_retry.visible)
	assert_true(_mechanic.get_program().is_empty())
	assert_eq(
		_mechanic.get_car().position, _mechanic.cell_position(_mechanic.get_field()["start"])
	)


func test_drive_level_change_mid_bump_leaves_nothing_behind() -> void:
	_world.lose_duration = 1.0
	_enter_short()
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	_hud.level_chosen.emit("drive", 3)
	await wait_seconds(1.3)
	assert_false(_retry.visible)
	assert_eq(_mechanic.get_car().animation, &"idle")


func test_drive_through_the_garage_and_on_is_not_a_win() -> void:
	watch_signals(_mechanic)
	_enter_solution()
	var last: String = _mechanic.get_program().get_tiles()[-1]["command"]
	# One more step the same way drives off the garage (it's in the last column) or onward.
	_mechanic.press_command(last if last != "turn_left" and last != "turn_right" else "forward")
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 3.0)
	assert_signal_not_emitted(_mechanic, "correct")


func test_drive_sounds_exist() -> void:
	for sound: String in ["ambience", "place", "remove", "step", "bump", "honk"]:
		assert_true(
			ResourceLoader.exists("res://assets/audio/drive/%s.wav" % sound), "drive/%s" % sound
		)


func test_drive_every_level_solvable_in_order() -> void:
	watch_signals(_mechanic)
	for difficulty in LevelLoader.DIFFICULTIES:
		_hud.difficulty_chosen.emit(difficulty)
		var level_range: Vector2i = LevelLoader.get_difficulty_range(difficulty)
		for index in range(level_range.x, level_range.y + 1):
			_hud.level_chosen.emit("drive", index)
			await wait_process_frames(1)
			assert_eq(_world._current_index, index)
			_enter_solution()
			_mechanic.go()
			await wait_for_signal(_mechanic.correct, 5.0)
			assert_signal_emitted(_mechanic, "correct", "level %d" % (index + 1))
```

Note: `_hud.level_chosen.emit` loads the level straight away because tests run with `Transition.enabled = false`. If an `assert_eq` between a typed array (`Array[Dictionary]`) and an untyped literal fails only on type, compare `.size()` and the entries instead.

Run: `$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gpre_run_script=res://tests/pre_run_hook.gd -gexit -gtest=res://tests/test_drive.gd`
Expected: errors (scene missing).

- [ ] **Step 2: Add the sounds**

In `tools/make_audio_placeholders.gd`:
- Add `"drive": 250.0` to `PLACE_HZ`.
- After the memory lines in `_init()`, add:

```gdscript
	_save("drive/step", _thud.bind(95.0, 80.0, 0.12, 0.45))
	_save("drive/bump", _boing)
	_save("drive/honk", _notes.bind([440.0, 554.37], 0.07, 0.2))
	_save("drive/ambience", func() -> PackedFloat32Array: return _seamless(_meadow()))
```

- Add the two generators next to `_birds()`:

```gdscript
# A soft, wobbly spring: a falling tone with a fast vibrato.
func _boing() -> PackedFloat32Array:
	var length := 0.35
	var samples := _empty(length)
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		var hz := lerpf(320.0, 140.0, t / length) * (1.0 + 0.08 * sin(TAU * 18.0 * t))
		phase += TAU * hz / RATE
		samples[i] = sin(phase) * exp(-6.0 * t) * 0.6
	return samples


# The picnic's birds over a light breeze.
func _meadow() -> PackedFloat32Array:
	var birds := _birds()
	var wind := _wind()
	for i in mini(birds.size(), wind.size()):
		birds[i] = birds[i] * 0.8 + wind[i] * 0.35
	return _normalize(birds, 0.5)
```

Before relying on `_empty`, `_birds`, `_wind` and `_normalize`, read their signatures in the file (lines ~88–290) and match them; adjust the calls if a signature differs.

- Update the doc comment at the top to mention the drive's step, bump and honk.

Run: `$GODOT --path . --headless -s tools/make_audio_placeholders.gd`, then `$GODOT --path . --headless --import`. Check `git status`: only `assets/audio/drive/*` should be new; the other sounds are seeded by name and must not change. If others changed, stop and find out why before going on.

- [ ] **Step 3: Write the world script**

`scripts/worlds/drive.gd`:

```gdscript
extends WorldBase

## World 6: the fox drives its car across a field to its garage, following the program the child
## builds first. A bump or a program that ends anywhere but the garage shows the retry button;
## retry keeps the program so it can be fixed.

## Seconds the horn plays before the celebration.
@export var honk_duration: float = 0.4
## Seconds the bump or sad animation plays before the retry button appears.
@export var lose_duration: float = 0.8

# "bump" or "short": how the last run went wrong, set just before the mechanic emits incorrect.
var _failure: String = ""

@onready var _mechanic: DriveMechanic = $DriveMechanic


func _ready() -> void:
	super()
	_mechanic.bumped.connect(_on_bumped)
	_mechanic.stopped_short.connect(_on_stopped_short)
	_mechanic.stepped.connect(AudioManager.play_sfx.bind("drive/step"))


func _world_id() -> String:
	return "drive"


func _get_mechanic() -> Mechanic:
	return _mechanic


# WorldBase reads this while its @onready variables are set, before this script's _mechanic is.
func _get_character() -> AnimatedSprite2D:
	return ($DriveMechanic as DriveMechanic).get_car()


func _setup_level(level: Dictionary) -> void:
	_mechanic.setup(DrivePuzzleGenerator.generate(level, _rng), str(level["mode"]))


func _restore_stage() -> void:
	_mechanic.reset()
	super()


func _play_win() -> void:
	AudioManager.play_sfx("drive/honk")
	await get_tree().create_timer(honk_duration).timeout


func _play_lose() -> void:
	if _failure == "bump":
		AudioManager.play_sfx("drive/bump")
		_character.play("bump")
	else:
		_character.play("sad")
	await get_tree().create_timer(lose_duration).timeout


func _on_bumped(_kind: String) -> void:
	_failure = "bump"


func _on_stopped_short() -> void:
	_failure = "short"
```

`_play_lose()` changes nothing after its `await`, so `WorldBase`'s `_load_count` check is enough. If you add anything after the `await`, check `_load_count` first, as `market.gd` does.

- [ ] **Step 4: Build the world scene**

`scenes/worlds/drive/drive.tscn`, modelled on `scenes/worlds/memory/memory.tscn` (copy its confetti sub-resources, `RetryPrompt` and `LevelHud` exactly):
- Root `Drive` (`Node2D`, script `drive.gd`).
- `Background` (`Sprite2D`, position (640, 360), `bg_drive.svg`).
- `Camera2D` at (640, 360).
- `DriveMechanic` (instance of `drive_mechanic.tscn`, position (0, 0)) with `command_textures` (all seven commands → their `cmd_*.svg`), `obstacle_textures` (`tree`, `rock`, `bush`, `pond`), `grass_textures` (`[grass_light, grass_dark]`), `garage_texture`, `tile_texture` (`tile_frame.svg`), `go_texture` (`res://assets/sprites/forest_bridge/go_icon.svg`) and `car_frames` (`car_frames.tres`).
- `CelebrationParticles` (copied from memory) at (1150, 300), over the right side of the field where the garage is.
- `RetryPrompt` / `RetryIcon` and `LevelHud`, copied from memory.
- No `Character` node.

- [ ] **Step 5: Register the world and update the world lists**

`scripts/autoloads/game_registry.gd`, append to `WORLDS` after the memory entry:

```gdscript
	{
		"id": "drive",
		"scene": "res://scenes/worlds/drive/drive.tscn",
		"icon": "res://assets/sprites/ui/icon_world_drive.svg",
	},
```

`tests/test_game_registry.gd`:
- Rename `test_game_registry_memory_world_registered_after_picnic` to `test_game_registry_drive_world_registered_after_memory` and expect `["forest", "sky", "market", "picnic", "memory", "drive"]`.
- In `test_game_registry_next_shuffle_world_skips_finished_worlds`, finish `["forest", "sky", "picnic", "memory", "drive"]`.

`tests/test_world_modes.gd`: add `"drive"` to every `_finish_shuffle([...])` list (lines ~159, 168, 177, 189, 276; `grep -n "_finish_shuffle(\[" tests/test_world_modes.gd` finds them all).

`tests/test_fox_frames.gd`, in `test_fox_frames_every_world_uses_the_shared_frames_at_its_old_size`, skip the world whose character is the car:

```gdscript
# Worlds whose character isn't the fox's own sprite (the drive's character is its car).
const OWN_CHARACTER := ["drive"]
```

and at the top of the loop body: `if world["id"] in OWN_CHARACTER: continue`.

- [ ] **Step 6: Run the world tests, then everything**

Run: `$GODOT --path . --headless --import`, the command from Step 1, then the full suite:
`$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json`
Expected: all pass. Then a headless boot: `$GODOT --path . --headless --quit` with no errors.

- [ ] **Step 7: See it running**

Run the game (`$GODOT --path .`), open Country Drive from the menu, and play an easy level and a hard level: win once, bump once, stop short once, retry and fix the program. Take a screenshot of the world (reuse the Task 5 viewer approach, loading `drive.tscn` instead) and check with the Read tool: nothing overlaps the level badge, the strip and Go fit inside the screen, the 7×5 field fits above the strip. Adjust `field_rect`, `buttons_origin`, `strip_origin` or the Go offsets in the scene if needed, and rerun the tests.

- [ ] **Step 8: Lint and commit**

```bash
gdformat scripts/worlds/drive.gd tests/test_drive.gd
~/.local/bin/gdlint scripts/ scenes/ tests/test_drive.gd
git add scripts/worlds/drive.gd* scenes/worlds/drive tests/test_drive.gd* scripts/autoloads/game_registry.gd tools/make_audio_placeholders.gd assets/audio/drive tests/test_game_registry.gd tests/test_world_modes.gd tests/test_fox_frames.gd
git -c user.name=malioni -c user.email=47998755+malioni@users.noreply.github.com commit -m "Drive: add the Country Drive world, its sounds and registration

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Docs

**Files:**
- Modify: `DESIGN.md`, `data/levels/README.md`, `assets/audio/README.md`, `docs/kids-math-game-context.md`

- [ ] **Step 1: DESIGN.md**

- Mechanic library table: add `| DriveMechanic | Spatial reasoning | Build a program of driving commands, then watch the car follow it to its garage |`.
- After World 5, add a `### World 6: Country Drive` section in the same shape as World 5: a short paragraph (the fox's car seen from above, obstacles, the garage, build the program first, Go, the running tile lights up), then **Teaches** (spatial reasoning and sequencing: planning a route, left and right, counting squares), **Mechanic**, **Levels** (easy: screen arrows, 4×3 to 7×5 and up to 3 direction changes; hard: forward and turns relative to the car, 4×3 to 7×5 and up to 3 turns; generated from per-level ranges), **Win condition** (the program's last move ends exactly on the garage) and **Fail state** (a bump or a program that ends elsewhere; gentle retry that keeps the program and marks where it went wrong).
- Planned Future Worlds: the Garden becomes World 7 and the Kitchen World 8.

- [ ] **Step 2: data/levels/README.md**

Add a "Drive levels" section in the same format as the memory one: the example JSON from Task 4, each field explained (`mode`, `cols`, `rows`, `obstacles`, `turns`, `max_tiles`), how turns are counted in each mode, and that `max_tiles` must stay below the strip's 12.

- [ ] **Step 3: assets/audio/README.md**

List the six `drive/` sounds with one line each, as for the other worlds.

- [ ] **Step 4: Context doc**

In `docs/kids-math-game-context.md`:
- A **World 6: Country Drive** paragraph after World 5, in the same style (what the child does, the win, the two ways to lose, retry keeping the program, easy vs hard commands).
- "Five worlds" → "Six worlds" under Current state.
- Key files rows for `drive_program.gd`, `drive_simulator.gd`, `drive_puzzle_generator.gd`, `drive_mechanic.gd` + `.tscn`, `drive_tile.gd` + `.tscn`, `drive.gd` + `scenes/worlds/drive/`, and `tools/make_car_sheets.gd`, each one line with its public methods.
- The `GameRegistry` row's world list gets `drive`.
- A "Drive generation" section after "Memory generation": the example JSON, the 0-1 breadth-first search in two sentences, and the curve table.
- The test count, from the last full run.

- [ ] **Step 5: Commit**

```bash
git add DESIGN.md data/levels/README.md assets/audio/README.md docs/kids-math-game-context.md
git -c user.name=malioni -c user.email=47998755+malioni@users.noreply.github.com commit -m "Drive: document World 6, Country Drive

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Final checks and pull request

- [ ] **Step 1: Everything green**

```bash
$GODOT --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json
~/.local/bin/gdlint scripts/ scenes/
gdformat --check scripts/ scenes/
$GODOT --path . --headless --quit
```

Expected: every test passes; lint clean; `gdformat --check` reports only `scripts/systems/level_loader.gd`, which it already reports on `main`; the boot prints no errors.

- [ ] **Step 2: Push and open the pull request**

```bash
git push -u origin drive-world
gh pr create --title "Add World 6, Country Drive (a programming puzzle with the fox's car)" --body "<summary of the world, the spec and plan paths, the test counts, and a screenshot note; end with the Claude Code line>"
```

Wait for CI and report the result to the user. Don't merge without the user's go-ahead.

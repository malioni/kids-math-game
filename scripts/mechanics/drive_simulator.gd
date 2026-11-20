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

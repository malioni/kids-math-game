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


static func _result(
	goal_key: String, states: Dictionary, parent: Dictionary, mode: String
) -> Dictionary:
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
		turns = (
			tiles
			. filter(
				func(tile: Dictionary) -> bool: return str(tile["command"]).begins_with("turn")
			)
			. size()
		)
	return {"tiles": tiles.size(), "turns": turns, "program": tiles}

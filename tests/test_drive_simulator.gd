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
	"obstacles":
	[
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
		"turn_right",
		"forward",
		"turn_left",
		"forward",
		"forward",
		"forward",
		"turn_left",
		"forward"
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

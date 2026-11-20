extends GutTest

const _PARAMS := {
	"mode": "global",
	"cols": 6,
	"rows": 4,
	"obstacles": {"min": 5, "max": 7},
	"turns": {"min": 2, "max": 3},
	"max_tiles": 4,
}
const _SEEDS_PER_LEVEL := 100


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
	var field := _field(
		3, 3, Vector2i(0, 1), Vector2i(2, 1), [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)]
	)
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


func test_drive_generator_garage_door_is_never_blocked() -> void:
	var rng := RandomNumberGenerator.new()
	for level: Dictionary in LevelLoader.get_levels_for_world("drive"):
		for seed_value in _SEEDS_PER_LEVEL:
			rng.seed = seed_value
			var field := DrivePuzzleGenerator.generate(level, rng)
			var door: Vector2i = field["garage"] + Vector2i(-1, 0)
			for obstacle: Dictionary in field["obstacles"]:
				assert_ne(obstacle["cell"], door, "%s seed %d" % [level["id"], seed_value])


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

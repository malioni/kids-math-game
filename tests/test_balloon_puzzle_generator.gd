extends GutTest

const SEEDS_PER_LEVEL := 200

var _levels: Array[Dictionary]


func before_all() -> void:
	_levels = LevelLoader.get_levels_for_world("sky")


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _sum(values: Array) -> int:
	var total: int = 0
	for v in values:
		total += v
	return total


## Calls check(level, puzzle) for SEEDS_PER_LEVEL puzzles on every sky level.
func _for_every_puzzle(check: Callable) -> void:
	for level in _levels:
		for s in SEEDS_PER_LEVEL:
			check.call(level, BalloonPuzzleGenerator.generate(level, _rng(s)))


func test_count_solutions_counts_distinct_pop_sets() -> void:
	# Extra lift 5: pop 5, or 2+3.
	assert_eq(BalloonPuzzleGenerator.count_solutions([2, 3, 5, 8], 5), 2)


func test_generate_same_seed_returns_same_puzzle() -> void:
	var a := BalloonPuzzleGenerator.generate(_levels[9], _rng(42))
	var b := BalloonPuzzleGenerator.generate(_levels[9], _rng(42))
	assert_eq(a, b)


func test_generate_different_seeds_return_different_puzzles() -> void:
	var seen := {}
	for s in 20:
		seen[BalloonPuzzleGenerator.generate(_levels[9], _rng(s))] = true
	assert_gt(seen.size(), 15)


func test_generate_returns_balloon_count_balloons_for_all_levels() -> void:
	_for_every_puzzle(
		func(level: Dictionary, puzzle: Dictionary) -> void:
			assert_eq(puzzle["balloon_values"].size(), int(level["balloon_count"]), level["id"])
	)


func test_generate_values_within_range_for_all_levels() -> void:
	_for_every_puzzle(
		func(level: Dictionary, puzzle: Dictionary) -> void:
			for v in puzzle["balloon_values"]:
				assert_between(
					v, int(level["balloon_value"]["min"]), int(level["balloon_value"]["max"])
				)
	)


func test_generate_total_lift_at_most_total_max_for_all_levels() -> void:
	_for_every_puzzle(
		func(level: Dictionary, puzzle: Dictionary) -> void:
			assert_lte(_sum(puzzle["balloon_values"]), int(level["total_max"]), level["id"])
	)


func test_generate_lift_starts_above_weight_for_all_levels() -> void:
	_for_every_puzzle(
		func(level: Dictionary, puzzle: Dictionary) -> void:
			assert_gt(_sum(puzzle["balloon_values"]), puzzle["target"], level["id"])
			assert_gt(puzzle["target"], 0, level["id"])
	)


func test_generate_has_between_1_and_max_solutions_for_all_levels() -> void:
	_for_every_puzzle(
		func(level: Dictionary, puzzle: Dictionary) -> void:
			var extra: int = _sum(puzzle["balloon_values"]) - puzzle["target"]
			var count: int = BalloonPuzzleGenerator.count_solutions(puzzle["balloon_values"], extra)
			assert_between(count, 1, int(level["max_solutions"]), level["id"])
	)


func test_generate_every_answer_pops_at_least_pop_count_min_for_all_levels() -> void:
	_for_every_puzzle(
		func(level: Dictionary, puzzle: Dictionary) -> void:
			var extra: int = _sum(puzzle["balloon_values"]) - puzzle["target"]
			var stats: Dictionary = SubsetSums.analyze(puzzle["balloon_values"], extra)
			assert_gte(stats["min_size"], int(level["pop_count"]["min"]), level["id"])
	)


func test_generate_impossible_params_falls_back_to_solvable_puzzle() -> void:
	var params := {
		"balloon_count": 3,
		"balloon_value": {"min": 5, "max": 5},
		"pop_count": {"min": 2, "max": 2},
		"total_max": 4,
		"max_solutions": 2,
	}
	var puzzle := BalloonPuzzleGenerator.generate(params, _rng(1))
	assert_push_error("no valid puzzle")
	var extra: int = _sum(puzzle["balloon_values"]) - puzzle["target"]
	assert_gt(extra, 0)
	assert_gt(BalloonPuzzleGenerator.count_solutions(puzzle["balloon_values"], extra), 0)

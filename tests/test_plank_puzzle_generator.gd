extends GutTest

const SEEDS_PER_LEVEL := 200

var _levels: Array[Dictionary]


func before_all() -> void:
	_levels = LevelLoader.get_levels_for_world("forest")


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _sum(values: Array) -> int:
	var total: int = 0
	for v in values:
		total += v
	return total


## Calls check(level, puzzle) for SEEDS_PER_LEVEL puzzles on every forest level.
func _for_every_puzzle(check: Callable) -> void:
	for level in _levels:
		for s in SEEDS_PER_LEVEL:
			check.call(level, PlankPuzzleGenerator.generate(level, _rng(s)))


func test_count_solutions_single_exact_pair_returns_1() -> void:
	assert_eq(PlankPuzzleGenerator.count_solutions([2, 3, 7], 5), 1)


func test_count_solutions_duplicate_lengths_counted_once() -> void:
	assert_eq(PlankPuzzleGenerator.count_solutions([2, 2, 3, 3], 5), 1)


func test_count_solutions_no_subset_sums_to_target_returns_0() -> void:
	assert_eq(PlankPuzzleGenerator.count_solutions([4, 6, 8], 5), 0)


func test_count_solutions_two_distinct_multisets_returns_2() -> void:
	assert_eq(PlankPuzzleGenerator.count_solutions([1, 4, 2, 3], 5), 2)


func test_generate_same_seed_returns_same_puzzle() -> void:
	var a := PlankPuzzleGenerator.generate(_levels[5], _rng(42))
	var b := PlankPuzzleGenerator.generate(_levels[5], _rng(42))
	assert_eq(a, b)


func test_generate_different_seeds_return_different_puzzles() -> void:
	var seen := {}
	for s in 20:
		seen[PlankPuzzleGenerator.generate(_levels[9], _rng(s))] = true
	assert_gt(seen.size(), 15)


func test_generate_returns_plank_count_planks() -> void:
	_for_every_puzzle(
		func(level: Dictionary, puzzle: Dictionary) -> void:
			assert_eq(puzzle["plank_lengths"].size(), int(level["plank_count"]))
	)


func test_generate_bridge_length_within_range_for_all_levels() -> void:
	_for_every_puzzle(
		func(level: Dictionary, puzzle: Dictionary) -> void:
			var length: int = puzzle["bridge_length"]
			assert_between(length, level["bridge_length"]["min"], level["bridge_length"]["max"])
	)


func test_generate_plank_lengths_within_range_for_all_levels() -> void:
	_for_every_puzzle(
		func(level: Dictionary, puzzle: Dictionary) -> void:
			for plank in puzzle["plank_lengths"]:
				assert_between(plank, level["plank_length"]["min"], level["plank_length"]["max"])
	)


func test_generate_has_between_1_and_max_solutions_for_all_levels() -> void:
	_for_every_puzzle(
		func(level: Dictionary, puzzle: Dictionary) -> void:
			var n := PlankPuzzleGenerator.count_solutions(
				puzzle["plank_lengths"], puzzle["bridge_length"]
			)
			assert_between(n, 1, int(level["max_solutions"]))
	)


func test_generate_no_single_plank_equals_bridge_length_for_all_levels() -> void:
	_for_every_puzzle(
		func(_level: Dictionary, puzzle: Dictionary) -> void:
			assert_false(puzzle["plank_lengths"].has(puzzle["bridge_length"]))
	)


func test_generate_pile_total_at_most_twice_bridge_length_for_all_levels() -> void:
	_for_every_puzzle(
		func(_level: Dictionary, puzzle: Dictionary) -> void:
			assert_lte(_sum(puzzle["plank_lengths"]), 2 * int(puzzle["bridge_length"]))
	)


func test_generate_at_least_a_third_of_pile_are_decoys_for_all_levels() -> void:
	_for_every_puzzle(
		func(level: Dictionary, puzzle: Dictionary) -> void:
			var max_used := _largest_solution_size(puzzle["plank_lengths"], puzzle["bridge_length"])
			var plank_count: int = level["plank_count"]
			assert_lte(max_used, plank_count - ceili(plank_count / 3.0))
	)


func _largest_solution_size(lengths: Array, target: int) -> int:
	var best: int = 0
	for mask in range(1, 1 << lengths.size()):
		var total: int = 0
		var used: int = 0
		for i in lengths.size():
			if mask & (1 << i):
				total += lengths[i]
				used += 1
		if total == target:
			best = maxi(best, used)
	return best


func test_generate_impossible_params_falls_back_to_solvable_puzzle() -> void:
	var params := {
		"bridge_length": {"min": 10, "max": 10},
		"plank_length": {"min": 1, "max": 9},
		"plank_count": 6,
		"max_solutions": 0,
	}
	var puzzle := PlankPuzzleGenerator.generate(params, _rng(1))
	assert_push_error("no valid puzzle")
	var n := PlankPuzzleGenerator.count_solutions(puzzle["plank_lengths"], puzzle["bridge_length"])
	assert_gte(n, 1)

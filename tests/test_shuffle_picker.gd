extends GutTest

const RUNS := 200

var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_rng.seed = 7


func test_shuffle_picker_returns_only_worlds_with_levels_left() -> void:
	var next_levels := {"forest": 10, "sky": 4, "market": 12, "picnic": 9}
	for run in RUNS:
		assert_has(["sky", "picnic"], ShufflePicker.pick(next_levels, 9, _rng))


func test_shuffle_picker_returns_empty_when_all_done() -> void:
	assert_eq(ShufflePicker.pick({"forest": 10, "sky": 10}, 9, _rng), "")
	assert_eq(ShufflePicker.pick({}, 9, _rng), "")


func test_shuffle_picker_eventually_picks_every_open_world() -> void:
	var seen := {}
	for run in RUNS:
		seen[ShufflePicker.pick({"forest": 0, "sky": 3, "market": 9}, 9, _rng)] = true
	assert_eq(seen.size(), 3)


func test_shuffle_picker_same_seed_same_pick() -> void:
	var first: String = ShufflePicker.pick({"forest": 0, "sky": 0, "market": 0}, 9, _rng)
	_rng.seed = 7
	assert_eq(ShufflePicker.pick({"market": 0, "sky": 0, "forest": 0}, 9, _rng), first)

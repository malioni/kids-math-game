extends GutTest

const RUNS := 200

var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_rng.seed = 7


func _worlds(ids: Array) -> Array[String]:
	var worlds: Array[String] = []
	worlds.assign(ids)
	return worlds


func test_shuffle_picker_picks_only_from_given_worlds() -> void:
	for run in RUNS:
		assert_has(["sky", "picnic"], ShufflePicker.pick(_worlds(["sky", "picnic"]), "", _rng))


func test_shuffle_picker_never_repeats_previous_when_others_exist() -> void:
	for run in RUNS:
		var pick: String = ShufflePicker.pick(_worlds(["forest", "sky", "market"]), "sky", _rng)
		assert_ne(pick, "sky")


func test_shuffle_picker_returns_previous_when_it_is_the_only_world() -> void:
	assert_eq(ShufflePicker.pick(_worlds(["forest"]), "forest", _rng), "forest")


func test_shuffle_picker_returns_empty_for_no_worlds() -> void:
	assert_eq(ShufflePicker.pick(_worlds([]), "forest", _rng), "")


func test_shuffle_picker_eventually_picks_every_world_but_previous() -> void:
	var seen := {}
	for run in RUNS:
		seen[ShufflePicker.pick(_worlds(["forest", "sky", "market", "drive"]), "drive", _rng)] = true
	assert_eq(seen.keys().size(), 3)
	assert_false(seen.has("drive"))


func test_shuffle_picker_same_seed_same_pick() -> void:
	var first: String = ShufflePicker.pick(_worlds(["forest", "sky", "market"]), "", _rng)
	_rng.seed = 7
	assert_eq(ShufflePicker.pick(_worlds(["market", "sky", "forest"]), "", _rng), first)

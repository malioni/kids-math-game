extends GutTest

const PARAMS := {
	"pairs": 6,
	"must_include": ["fox"],
	"pool": ["rabbit", "bear", "owl", "frog", "hedgehog", "mouse", "duck", "pig"],
}
const RUNS := 200

var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_rng.seed = 42


func _counts(deck: Array[String]) -> Dictionary:
	var counts := {}
	for animal in deck:
		counts[animal] = counts.get(animal, 0) + 1
	return counts


func test_memory_puzzle_generator_deck_size_is_twice_pairs() -> void:
	assert_eq(MemoryPuzzleGenerator.generate(PARAMS, _rng).size(), 12)


func test_memory_puzzle_generator_every_face_appears_exactly_twice() -> void:
	for run in RUNS:
		var counts: Dictionary = _counts(MemoryPuzzleGenerator.generate(PARAMS, _rng))
		assert_eq(counts.size(), 6)
		for animal: String in counts:
			assert_eq(counts[animal], 2, animal)


func test_memory_puzzle_generator_always_includes_fox() -> void:
	for run in RUNS:
		assert_eq(_counts(MemoryPuzzleGenerator.generate(PARAMS, _rng)).get("fox", 0), 2)


func test_memory_puzzle_generator_other_faces_come_from_pool() -> void:
	for run in RUNS:
		for animal: String in _counts(MemoryPuzzleGenerator.generate(PARAMS, _rng)):
			assert_true(animal == "fox" or animal in PARAMS["pool"], animal)


func test_memory_puzzle_generator_same_seed_same_deck() -> void:
	var other := RandomNumberGenerator.new()
	other.seed = 42
	assert_eq(
		MemoryPuzzleGenerator.generate(PARAMS, _rng), MemoryPuzzleGenerator.generate(PARAMS, other)
	)


func test_memory_puzzle_generator_different_seeds_vary_animals_and_order() -> void:
	var decks := {}
	var animal_sets := {}
	for run in 20:
		var deck: Array[String] = MemoryPuzzleGenerator.generate(PARAMS, _rng)
		decks[str(deck)] = true
		var animals: Array = _counts(deck).keys()
		animals.sort()
		animal_sets[str(animals)] = true
	assert_gt(decks.size(), 1)
	assert_gt(animal_sets.size(), 1)

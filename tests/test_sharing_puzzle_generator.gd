extends GutTest

const PARAMS := {
	"plates": {"min": 2, "max": 5},
	"items":
	[
		{"item": "strawberry", "share": {"min": 2, "max": 4}},
		{"item": "apple", "share": {"min": 5, "max": 7}},
		{"item": "banana", "share": {"min": 8, "max": 10}},
	],
}
const RUNS := 300

var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_rng.seed = 42


func test_sharing_puzzle_generator_one_order_per_item_in_order() -> void:
	var orders: Array = SharingPuzzleGenerator.generate(PARAMS, _rng)["orders"]
	assert_eq(
		orders.map(func(o: Dictionary) -> String: return o["item"]),
		["strawberry", "apple", "banana"]
	)


func test_sharing_puzzle_generator_plates_within_range() -> void:
	var seen := {}
	for run in RUNS:
		var plates: int = SharingPuzzleGenerator.generate(PARAMS, _rng)["plates"]
		assert_between(plates, 2, 5)
		seen[plates] = true
	assert_eq(seen.size(), 4, "plates 2-5 all appear")


func test_sharing_puzzle_generator_share_within_range() -> void:
	for run in RUNS:
		var orders: Array = SharingPuzzleGenerator.generate(PARAMS, _rng)["orders"]
		for i in orders.size():
			var share_range: Dictionary = PARAMS["items"][i]["share"]
			assert_between(
				int(orders[i]["share"]), int(share_range["min"]), int(share_range["max"])
			)


func test_sharing_puzzle_generator_total_is_plates_times_share() -> void:
	for run in RUNS:
		var puzzle: Dictionary = SharingPuzzleGenerator.generate(PARAMS, _rng)
		for order: Dictionary in puzzle["orders"]:
			assert_eq(order["total"], puzzle["plates"] * order["share"])


func test_sharing_puzzle_generator_same_seed_same_puzzle() -> void:
	var first: Dictionary = SharingPuzzleGenerator.generate(PARAMS, _rng)
	_rng.seed = 42
	assert_eq(SharingPuzzleGenerator.generate(PARAMS, _rng), first)

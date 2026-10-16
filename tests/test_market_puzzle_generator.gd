extends GutTest

const PARAMS := {
	"items":
	[
		{"item": "tomato", "bag_size": {"min": 1, "max": 3}, "bag_count": {"min": 2, "max": 4}},
		{"item": "potato", "bag_size": {"min": 4, "max": 6}, "bag_count": {"min": 3, "max": 5}},
		{"item": "carrot", "bag_size": {"min": 7, "max": 10}, "bag_count": {"min": 8, "max": 10}},
	]
}
const RUNS := 300

var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_rng.seed = 42


func test_market_generator_returns_one_order_per_item_in_order() -> void:
	var orders: Array[Dictionary] = MarketPuzzleGenerator.generate(PARAMS, _rng)
	assert_eq(
		orders.map(func(o: Dictionary) -> String: return o["item"]), ["tomato", "potato", "carrot"]
	)


func test_market_generator_bag_size_within_range() -> void:
	for run in RUNS:
		var orders: Array[Dictionary] = MarketPuzzleGenerator.generate(PARAMS, _rng)
		for i in orders.size():
			var size_range: Dictionary = PARAMS["items"][i]["bag_size"]
			assert_between(
				int(orders[i]["bag_size"]), int(size_range["min"]), int(size_range["max"])
			)


func test_market_generator_bag_count_within_range() -> void:
	for run in RUNS:
		var orders: Array[Dictionary] = MarketPuzzleGenerator.generate(PARAMS, _rng)
		for i in orders.size():
			var count_range: Dictionary = PARAMS["items"][i]["bag_count"]
			assert_between(
				int(orders[i]["bag_count"]), int(count_range["min"]), int(count_range["max"])
			)


func test_market_generator_quantity_is_size_times_count() -> void:
	for run in RUNS:
		for order in MarketPuzzleGenerator.generate(PARAMS, _rng):
			assert_eq(order["quantity"], order["bag_size"] * order["bag_count"])


func test_market_generator_same_seed_gives_same_orders() -> void:
	var first: Array[Dictionary] = MarketPuzzleGenerator.generate(PARAMS, _rng)
	_rng.seed = 42
	assert_eq(MarketPuzzleGenerator.generate(PARAMS, _rng), first)


func test_market_generator_covers_full_ranges_over_many_runs() -> void:
	var sizes := {}
	var counts := {}
	for run in RUNS:
		var carrot: Dictionary = MarketPuzzleGenerator.generate(PARAMS, _rng)[2]
		sizes[carrot["bag_size"]] = true
		counts[carrot["bag_count"]] = true
	assert_eq(sizes.keys().size(), 4, "carrot bag sizes 7-10 all appear")
	assert_eq(counts.keys().size(), 3, "carrot bag counts 8-10 all appear")

class_name BalloonPuzzleGenerator
extends RefCounted

## Generates balloon puzzles: a weight (the target) and a bunch of numbered balloons whose total
## lift is more than the weight. Popping balloons that add up to exactly the extra lift leaves the
## lift equal to the weight, so the child works out total − weight and pops that much.

## Attempts before giving up and returning a fallback puzzle.
const MAX_ATTEMPTS := 500


## Returns {"target": int, "balloon_values": Array[int]} for the given level params.
## params needs balloon_count, balloon_value {min, max}, pop_count {min, max}, total_max and
## max_solutions. The values always add up to more than target.
static func generate(params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var count: int = params["balloon_count"]
	var value_range: Dictionary = params["balloon_value"]
	var pop_range: Dictionary = params["pop_count"]
	var pop_min: int = pop_range["min"]
	var pop_max: int = mini(pop_range["max"], count - 1)
	var total_max: int = params["total_max"]
	var max_solutions: int = params["max_solutions"]
	var fallback: Array[int] = []

	for attempt in MAX_ATTEMPTS:
		var values: Array[int] = []
		for i in count:
			values.append(rng.randi_range(value_range["min"], value_range["max"]))
		var total: int = _sum(values)
		if total > total_max:
			continue
		fallback = values
		var extra: int = _sum(values.slice(0, rng.randi_range(pop_min, pop_max)))
		var stats: Dictionary = SubsetSums.analyze(values, extra)
		# min_size stops a single balloon (or too few) being the whole answer on levels meant to
		# need several pops.
		if stats["count"] > max_solutions or stats["min_size"] < pop_min:
			continue
		_shuffle(values, rng)
		return {"target": total - extra, "balloon_values": values}

	push_error("BalloonPuzzleGenerator: no valid puzzle after %d attempts" % MAX_ATTEMPTS)
	if fallback.is_empty():
		fallback = [2, 1]
	return {"target": _sum(fallback) - fallback[0], "balloon_values": fallback}


## Number of distinct sets of balloon values that add up to exactly extra, i.e. the distinct
## ways to pop balloons so the lift equals the weight.
static func count_solutions(balloon_values: Array[int], extra: int) -> int:
	return SubsetSums.analyze(balloon_values, extra)["count"]


static func _sum(values: Array[int]) -> int:
	var total: int = 0
	for v in values:
		total += v
	return total


# Array.shuffle() uses the global RNG; this keeps results reproducible from the seed.
static func _shuffle(values: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = values[i]
		values[i] = values[j]
		values[j] = tmp

class_name PlankPuzzleGenerator
extends RefCounted

## Generates plank-length puzzles: a bridge length and a pile of planks where at least one
## combination of planks sums exactly to the bridge length.

## Attempts before giving up and returning a fallback puzzle.
const MAX_ATTEMPTS := 500
## The pile's total length may be at most this multiple of the bridge length, so it fits on screen.
const MAX_PILE_RATIO := 2.0


## Returns {"bridge_length": int, "plank_lengths": Array[int]} for the given level params.
## params needs bridge_length {min, max}, plank_length {min, max}, plank_count and max_solutions.
static func generate(params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var bridge_range: Dictionary = params["bridge_length"]
	var plank_range: Dictionary = params["plank_length"]
	var plank_min: int = plank_range["min"]
	var plank_max: int = plank_range["max"]
	var plank_count: int = params["plank_count"]
	var max_solutions: int = params["max_solutions"]
	var fallback: Array[int] = []
	var fallback_length: int = 0

	for attempt in MAX_ATTEMPTS:
		var bridge_length: int = rng.randi_range(bridge_range["min"], bridge_range["max"])
		var k_min: int = maxi(2, ceili(float(bridge_length) / plank_max))
		# At least a third of the pile are decoys, so the child has to choose, not just leave one out.
		var min_decoys: int = ceili(plank_count / 3.0)
		var k_max: int = mini(plank_count - min_decoys, floori(float(bridge_length) / plank_min))
		if k_min > k_max:
			continue
		var solution: Array[int] = _split(
			bridge_length, rng.randi_range(k_min, k_max), plank_range, rng
		)
		fallback = solution
		fallback_length = bridge_length

		var planks: Array[int] = solution.duplicate()
		var decoy_max: int = mini(plank_max, bridge_length - 1)
		for i in plank_count - solution.size():
			planks.append(rng.randi_range(plank_min, decoy_max))

		if _sum(planks) > MAX_PILE_RATIO * bridge_length:
			continue
		var stats: Vector2i = _solution_stats(planks, bridge_length)
		if stats.x < 1 or stats.x > max_solutions or stats.y > k_max:
			continue
		_shuffle(planks, rng)
		return {"bridge_length": bridge_length, "plank_lengths": planks}

	push_error("PlankPuzzleGenerator: no valid puzzle after %d attempts" % MAX_ATTEMPTS)
	if fallback.is_empty():
		fallback_length = maxi(2, int(bridge_range["min"]))
		fallback = [fallback_length - 1, 1]
	return {"bridge_length": fallback_length, "plank_lengths": fallback}


## Number of distinct multisets of lengths from plank_lengths that sum exactly to target.
static func count_solutions(plank_lengths: Array[int], target: int) -> int:
	return _solution_stats(plank_lengths, target).x


# Returns (distinct solutions, most planks used by any one solution).
static func _solution_stats(plank_lengths: Array[int], target: int) -> Vector2i:
	var found := {}
	var largest: int = 0
	var n: int = plank_lengths.size()
	for mask in range(1, 1 << n):
		var subset: Array[int] = []
		var total: int = 0
		for i in n:
			if mask & (1 << i):
				subset.append(plank_lengths[i])
				total += plank_lengths[i]
		if total == target:
			subset.sort()
			found[subset] = true
			largest = maxi(largest, subset.size())
	return Vector2i(found.size(), largest)


# Picks each part uniformly within what keeps the rest feasible, which gives more varied
# lengths than spreading units one at a time (that clusters every part near the mean).
static func _split(
	total: int, parts: int, plank_range: Dictionary, rng: RandomNumberGenerator
) -> Array[int]:
	var plank_min: int = plank_range["min"]
	var plank_max: int = plank_range["max"]
	var result: Array[int] = []
	var remaining: int = total
	for i in parts - 1:
		var parts_left: int = parts - i - 1
		var low: int = maxi(plank_min, remaining - parts_left * plank_max)
		var high: int = mini(plank_max, remaining - parts_left * plank_min)
		var part: int = rng.randi_range(low, high)
		result.append(part)
		remaining -= part
	result.append(remaining)
	return result


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

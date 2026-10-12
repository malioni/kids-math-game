class_name SubsetSums
extends RefCounted

## Finds the distinct ways a pile of numbers can make a target total. Puzzle generators use it to
## check that a puzzle has an answer, but not too many.


## Returns {"count": int, "min_size": int, "max_size": int} for the distinct multisets of values
## that sum exactly to target. Two equal values count once, so [3, 3, 1] makes 4 one way, not two.
## min_size and max_size are the fewest and most values any one answer uses (0 when count is 0).
static func analyze(values: Array[int], target: int) -> Dictionary:
	var found := {}
	var min_size: int = 0
	var max_size: int = 0
	var n: int = values.size()
	for mask in range(1, 1 << n):
		var subset: Array[int] = []
		var total: int = 0
		for i in n:
			if mask & (1 << i):
				subset.append(values[i])
				total += values[i]
		if total != target:
			continue
		subset.sort()
		if found.has(subset):
			continue
		found[subset] = true
		min_size = subset.size() if found.size() == 1 else mini(min_size, subset.size())
		max_size = maxi(max_size, subset.size())
	return {"count": found.size(), "min_size": min_size, "max_size": max_size}

class_name ShufflePicker
extends RefCounted

## Chooses the next world in shuffle mode.


## Returns a random world id from next_levels (world id → 0-based index of its next shuffle level)
## whose next level is at most last_index, or "" if every world is done.
static func pick(next_levels: Dictionary, last_index: int, rng: RandomNumberGenerator) -> String:
	var open: Array = next_levels.keys().filter(
		func(world: String) -> bool: return int(next_levels[world]) <= last_index
	)
	if open.is_empty():
		return ""
	# Sorted so the same seed always gives the same world, whatever order the keys came in.
	open.sort()
	return open[rng.randi_range(0, open.size() - 1)]

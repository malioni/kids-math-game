class_name ShufflePicker
extends RefCounted

## Chooses the next world in shuffle mode.


## Returns a random world from worlds other than previous, or previous when it is the only one,
## or "" when worlds is empty.
static func pick(worlds: Array[String], previous: String, rng: RandomNumberGenerator) -> String:
	if worlds.is_empty():
		return ""
	var open: Array[String] = []
	open.assign(worlds.filter(func(world: String) -> bool: return world != previous))
	if open.is_empty():
		return previous
	# Sorted so the same seed always gives the same world, whatever order the worlds came in.
	open.sort()
	return open[rng.randi_range(0, open.size() - 1)]

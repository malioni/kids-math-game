class_name SharingPuzzleGenerator
extends RefCounted

## Generates picnic puzzles: how many plates there are, and for each fruit how many every plate
## should get and how many the basket holds (plates × share).


## Returns {"plates": int, "orders": Array[Dictionary]}, with one order per entry of
## params["items"] in the same order: {"item": String, "share": int, "total": int}.
## params needs plates {min, max} and items, each with item and share {min, max}.
static func generate(params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var plates: int = rng.randi_range(params["plates"]["min"], params["plates"]["max"])
	var orders: Array[Dictionary] = []
	for entry: Dictionary in params["items"]:
		var share: int = rng.randi_range(entry["share"]["min"], entry["share"]["max"])
		orders.append({"item": entry["item"], "share": share, "total": plates * share})
	return {"plates": plates, "orders": orders}

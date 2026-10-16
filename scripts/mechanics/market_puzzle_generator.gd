class_name MarketPuzzleGenerator
extends RefCounted

## Generates market orders: for each item, a bag size and how many bags the answer takes, and the
## quantity the customer asks for (bag size × bag count).


## Returns one order per entry of params["items"], in the same order:
## {"item": String, "bag_size": int, "bag_count": int, "quantity": int}.
## Each entry needs item, bag_size {min, max} and bag_count {min, max}.
static func generate(params: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var orders: Array[Dictionary] = []
	for entry: Dictionary in params["items"]:
		var bag_size: int = rng.randi_range(entry["bag_size"]["min"], entry["bag_size"]["max"])
		var bag_count: int = rng.randi_range(entry["bag_count"]["min"], entry["bag_count"]["max"])
		var order := {
			"item": entry["item"],
			"bag_size": bag_size,
			"bag_count": bag_count,
			"quantity": bag_size * bag_count,
		}
		orders.append(order)
	return orders

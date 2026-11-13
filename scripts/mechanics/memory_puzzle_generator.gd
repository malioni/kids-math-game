class_name MemoryPuzzleGenerator
extends RefCounted

## Generates memory decks: the animals that must be in the deck, the rest picked at random from a
## pool, each animal twice, shuffled.


## Returns a shuffled deck of params["pairs"] × 2 animal names, every animal exactly twice. Every
## animal in params["must_include"] is dealt; the rest are distinct random picks from
## params["pool"].
static func generate(params: Dictionary, rng: RandomNumberGenerator) -> Array[String]:
	var faces: Array[String] = []
	for animal: String in params["must_include"]:
		faces.append(animal)
	var pool: Array = params["pool"].filter(
		func(animal: String) -> bool: return animal not in faces
	)
	while faces.size() < int(params["pairs"]):
		faces.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	var deck: Array[String] = []
	deck.append_array(faces)
	deck.append_array(faces)
	# Array.shuffle() uses the global random numbers, so a seeded world would deal different decks.
	for i in range(deck.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: String = deck[i]
		deck[i] = deck[j]
		deck[j] = swap
	return deck

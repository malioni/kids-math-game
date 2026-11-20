class_name DriveProgram
extends RefCounted

## The program the player builds for the car: a row of tiles, each a command and how many times to
## run it. Adding the same command as the last tile raises that tile's count instead of adding one.

## Most tiles the program holds.
const MAX_TILES := 12

var _tiles: Array[Dictionary] = []


## Adds one step of command. Raises the last tile's count if it holds the same command; otherwise
## adds a tile. Returns false, changing nothing, if a new tile is needed and the program is full.
func add(command: String) -> bool:
	if not _tiles.is_empty() and _tiles[-1]["command"] == command:
		_tiles[-1]["count"] += 1
		return true
	if is_full():
		return false
	_tiles.append({"command": command, "count": 1})
	return true


## Returns true if add(command) would change the program.
func can_add(command: String) -> bool:
	return not is_full() or _tiles[-1]["command"] == command


## Takes one step off the tile at index; a tile at count 1 is removed. Neighbours left holding the
## same command stay separate tiles. An index out of range does nothing.
func take_step(index: int) -> void:
	if index < 0 or index >= _tiles.size():
		return
	_tiles[index]["count"] -= 1
	if _tiles[index]["count"] <= 0:
		_tiles.remove_at(index)


## Returns a copy of the tiles in order, each {"command": String, "count": int}.
func get_tiles() -> Array[Dictionary]:
	return _tiles.duplicate(true)


## Returns true when no new tile fits.
func is_full() -> bool:
	return _tiles.size() >= MAX_TILES


## Returns true when the program has no tiles.
func is_empty() -> bool:
	return _tiles.is_empty()


## Removes every tile.
func clear() -> void:
	_tiles.clear()


## Returns the program as single moves in order, each {"command": String, "tile": int}, where
## tile is the index of the tile the move came from.
func expand() -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	for i in _tiles.size():
		for step in int(_tiles[i]["count"]):
			moves.append({"command": _tiles[i]["command"], "tile": i})
	return moves

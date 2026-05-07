extends Node2D

## Emitted when the placed count reaches target_count exactly via place().
signal correct

## Emitted when confirm() is called and the placed count does not match target_count.
signal incorrect

## Emitted on every placement, removal, or reset with the new count value.
signal count_changed(new_count: int)

## The number of objects the player must place to satisfy this mechanic.
@export var target_count: int = 0

var _placed_count: int = 0


## Places one object, incrementing the count. Emits correct if target is now met.
func place() -> void:
	_placed_count += 1
	count_changed.emit(_placed_count)
	if _placed_count == target_count:
		correct.emit()


## Removes one object, decrementing the count. Count cannot go below zero.
func remove() -> void:
	if _placed_count > 0:
		_placed_count -= 1
	count_changed.emit(_placed_count)


## Checks the current count against target_count and emits incorrect if they differ.
func confirm() -> void:
	if _placed_count != target_count:
		incorrect.emit()


## Resets the placed count to zero.
func reset() -> void:
	_placed_count = 0
	count_changed.emit(_placed_count)


## Returns the current number of placed objects.
func get_placed_count() -> int:
	return _placed_count

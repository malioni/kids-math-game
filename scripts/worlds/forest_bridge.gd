extends Node2D

## Emitted when the player completes all levels in this world.
signal world_complete

@onready var _mechanic: Node2D = $PlacementMechanic

var _levels: Array[Dictionary] = []
var _current_index: int = 0


func _ready() -> void:
	_levels = LevelLoader.get_levels_for_world("forest")
	_mechanic.correct.connect(_on_correct)
	_mechanic.incorrect.connect(_on_incorrect)
	_load_level(0)


func _load_level(index: int) -> void:
	_current_index = index
	_mechanic.target_count = _levels[index]["target_count"]
	_mechanic.reset()


func _on_correct() -> void:
	if _current_index >= _levels.size() - 1:
		world_complete.emit()
	else:
		_load_level(_current_index + 1)


func _on_incorrect() -> void:
	_mechanic.reset()

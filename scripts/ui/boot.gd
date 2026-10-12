extends Node

## Main scene. Opens the world the player was last in.


func _ready() -> void:
	GameRegistry.start_last_world.call_deferred()

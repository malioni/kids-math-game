extends Node

## Main scene. Moves an old save to per-difficulty progress, then opens the world the player was
## last in.


func _ready() -> void:
	var world_ids: Array = GameRegistry.get_worlds().map(
		func(w: Dictionary) -> String: return w["id"]
	)
	SaveManager.migrate_progress(world_ids)
	GameRegistry.start_last_world.call_deferred()

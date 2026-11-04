extends Node

## Main scene. Moves an old save to per-difficulty progress, then opens the main menu.


func _ready() -> void:
	var world_ids: Array = GameRegistry.get_worlds().map(
		func(w: Dictionary) -> String: return w["id"]
	)
	SaveManager.migrate_progress(world_ids)
	GameRegistry.go_to_menu.call_deferred()

class_name SaveFixture
extends RefCounted

## Test helper: empties the save the suite is using (pre_run_hook.gd points it at a test file) and
## starts worlds at a chosen level.


## Deletes the test save file and makes SaveManager forget what it held.
static func clear() -> void:
	if FileAccess.file_exists(SaveManager.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.save_path))
	SaveManager.reload()


## Makes the next world_id scene that enters the tree start at level_index (0-based) at the given
## difficulty, the way the main menu starts it.
static func start_at(world_id: String, level_index: int, difficulty: String = "easy") -> void:
	GameRegistry.set_difficulty(difficulty)
	GameRegistry.request_level(world_id, level_index)

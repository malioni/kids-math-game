class_name SaveFixture
extends RefCounted

## Test helper: empties the save the suite is using (pre_run_hook.gd points it at a test file).


## Deletes the test save file and makes SaveManager forget what it held.
static func clear() -> void:
	if FileAccess.file_exists(SaveManager.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.save_path))
	SaveManager.reload()

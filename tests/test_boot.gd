extends GutTest

const SCENE := preload("res://scenes/ui/boot.tscn")
const _SAVE_PATH := "user://save.cfg"


func before_each() -> void:
	_clear_save()
	GameRegistry.change_scenes = false
	GameRegistry.last_scene_request = ""


func after_each() -> void:
	_clear_save()
	GameRegistry.change_scenes = true
	GameRegistry.last_scene_request = ""


func _clear_save() -> void:
	if FileAccess.file_exists(_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))


func test_boot_migrates_old_save_and_opens_main_menu() -> void:
	SaveManager.set_progress("forest", 14)
	add_child_autofree(SCENE.instantiate())
	await wait_process_frames(2)
	assert_eq(SaveManager.load_progress(SaveManager.progress_key("forest", "hard")), 14)
	assert_eq(GameRegistry.last_scene_request, GameRegistry.MENU_SCENE)

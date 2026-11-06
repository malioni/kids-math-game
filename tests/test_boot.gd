extends GutTest

const SCENE := preload("res://scenes/ui/boot.tscn")


func before_each() -> void:
	SaveFixture.clear()
	GameRegistry.change_scenes = false
	GameRegistry.last_scene_request = ""


func after_each() -> void:
	SaveFixture.clear()
	GameRegistry.change_scenes = true
	GameRegistry.last_scene_request = ""


func test_boot_migrates_old_save_and_opens_main_menu() -> void:
	SaveManager.set_progress("forest", 14)
	add_child_autofree(SCENE.instantiate())
	await wait_frames(2)
	assert_eq(SaveManager.load_progress(SaveManager.progress_key("forest", "hard")), 14)
	assert_eq(GameRegistry.last_scene_request, GameRegistry.MENU_SCENE)

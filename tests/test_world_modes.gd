extends GutTest

## Easy/hard difficulty and shuffle mode, played through the forest world.

const SCENE := preload("res://scenes/worlds/forest_bridge/forest_bridge.tscn")
const _SAVE_PATH := "user://save.cfg"
const _SETTLE := 0.3


func before_each() -> void:
	_clear_save()
	GameRegistry.change_scenes = false
	GameRegistry.last_world_request = ""


func after_each() -> void:
	_clear_save()
	GameRegistry.change_scenes = true
	GameRegistry.last_world_request = ""


func _clear_save() -> void:
	if FileAccess.file_exists(_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))


func _make_world() -> Node2D:
	var world: Node2D = SCENE.instantiate()
	world.celebrate_duration = 0.01
	world.puzzle_seed = 99
	world.walk_speed = 50000.0
	world.get_node("AnimationPlayer").speed_scale = 20.0
	return add_child_autofree(world)


func _mechanic(world: Node2D) -> Node2D:
	return world.get_node("BridgeLayer/PlacementMechanic")


func _hud(world: Node2D) -> LevelHud:
	return world.get_node("LevelHud")


## Drops a set of planks that adds up to the bridge length and presses Go, then waits for the win.
func _win(world: Node2D) -> void:
	var mechanic: Node2D = _mechanic(world)
	var planks: Array[Node] = mechanic.get_planks()
	var target: int = mechanic.get_target_length()
	for mask in range(1, 1 << planks.size()):
		var total: int = 0
		for i in planks.size():
			if mask & (1 << i):
				total += planks[i].length
		if total == target:
			for i in planks.size():
				if mask & (1 << i):
					planks[i].dropped.emit(mechanic.to_global(Vector2.ZERO))
			break
	mechanic.confirm()
	await wait_seconds(_SETTLE)


func _shuffle_key(world_id: String) -> String:
	return SaveManager.progress_key(world_id, GameRegistry.get_difficulty(), true)


## Marks shuffle as having played every level of the current difficulty in the given worlds.
func _finish_shuffle(world_ids: Array) -> void:
	for world_id: String in world_ids:
		SaveManager.set_progress(_shuffle_key(world_id), GameRegistry.get_level_range().y + 2)


func test_world_modes_easy_starts_at_level_1_and_completes_after_level_10() -> void:
	var world: Node2D = _make_world()
	watch_signals(world)
	for i in 10:
		assert_eq(world._current_index, i)
		await _win(world)
	assert_signal_emitted(world, "world_complete")
	assert_true(_hud(world).is_world_complete_shown())


func test_world_modes_easy_restart_goes_to_level_1() -> void:
	SaveManager.set_progress("forest:easy", 10)
	var world: Node2D = _make_world()
	await _win(world)
	_hud(world).restart_requested.emit()
	assert_eq(world._current_index, 0)
	assert_eq(SaveManager.load_progress("forest:easy"), 1)


func test_world_modes_hard_starts_at_level_11() -> void:
	GameRegistry.set_difficulty("hard")
	var world: Node2D = _make_world()
	assert_eq(world._current_index, 10)
	assert_eq(_hud(world).get_node("Root/LevelBadge/Row/LevelLabel").text, "11")


func test_world_modes_hard_completes_after_level_20_and_restart_goes_to_11() -> void:
	GameRegistry.set_difficulty("hard")
	SaveManager.set_progress("forest:hard", 20)
	var world: Node2D = _make_world()
	watch_signals(world)
	await _win(world)
	assert_signal_emitted(world, "world_complete")
	assert_eq(SaveManager.load_progress("forest:hard"), 11)
	_hud(world).restart_requested.emit()
	assert_eq(world._current_index, 10)


func test_world_modes_progress_is_saved_per_difficulty() -> void:
	var world: Node2D = _make_world()
	await _win(world)
	assert_eq(SaveManager.load_progress("forest:easy"), 2)
	assert_eq(SaveManager.load_progress("forest:hard"), 1)


func test_world_modes_difficulty_chosen_resumes_at_that_difficultys_level() -> void:
	SaveManager.set_progress("forest:easy", 4)
	SaveManager.set_progress("forest:hard", 16)
	var world: Node2D = _make_world()
	assert_eq(world._current_index, 3)
	_hud(world).difficulty_chosen.emit("hard")
	assert_eq(world._current_index, 15)
	assert_eq(GameRegistry.get_difficulty(), "hard")
	_hud(world).difficulty_chosen.emit("easy")
	assert_eq(world._current_index, 3)


func test_world_modes_picking_hard_level_on_easy_switches_difficulty() -> void:
	var world: Node2D = _make_world()
	_hud(world).level_chosen.emit("forest", 13)
	assert_eq(world._current_index, 13)
	assert_eq(GameRegistry.get_difficulty(), "hard")
	assert_eq(SaveManager.load_progress("forest:hard"), 14)


func test_world_modes_shuffle_win_saves_shuffle_progress_not_normal_progress() -> void:
	GameRegistry.set_shuffle(true)
	var world: Node2D = _make_world()
	assert_eq(world._current_index, 0)
	await _win(world)
	assert_eq(SaveManager.load_progress(_shuffle_key("forest")), 2)
	assert_eq(SaveManager.load_progress("forest:easy"), 1)


func test_world_modes_shuffle_resumes_at_shuffle_level() -> void:
	SaveManager.set_progress("forest:easy", 2)
	SaveManager.set_progress(_shuffle_key("forest"), 6)
	GameRegistry.set_shuffle(true)
	var world: Node2D = _make_world()
	assert_eq(world._current_index, 5)


func test_world_modes_shuffle_win_with_only_this_world_left_loads_next_level_in_place() -> void:
	_finish_shuffle(["sky", "market", "picnic"])
	GameRegistry.set_shuffle(true)
	var world: Node2D = _make_world()
	await _win(world)
	assert_eq(world._current_index, 1)
	assert_eq(GameRegistry.last_world_request, "")


func test_world_modes_shuffle_win_with_other_worlds_left_requests_one_of_them() -> void:
	_finish_shuffle(["market", "picnic"])
	SaveManager.set_progress(_shuffle_key("forest"), 10)
	GameRegistry.set_shuffle(true)
	var world: Node2D = _make_world()
	await _win(world)
	assert_eq(GameRegistry.last_world_request, "sky")


func test_world_modes_shuffle_all_done_shows_star_screen() -> void:
	_finish_shuffle(["sky", "market", "picnic"])
	SaveManager.set_progress(_shuffle_key("forest"), 10)
	GameRegistry.set_shuffle(true)
	var world: Node2D = _make_world()
	watch_signals(world)
	await _win(world)
	assert_signal_emitted(world, "world_complete")
	assert_true(_hud(world).is_world_complete_shown())
	assert_eq(GameRegistry.last_world_request, "")


func test_world_modes_shuffle_restart_starts_fresh_shuffle() -> void:
	_finish_shuffle(["forest", "sky", "market", "picnic"])
	GameRegistry.set_shuffle(true)
	var world: Node2D = _make_world()
	await wait_frames(2)
	GameRegistry.last_world_request = ""
	_hud(world).restart_requested.emit()
	assert_ne(GameRegistry.last_world_request, "")
	assert_eq(GameRegistry.shuffle_next_index("forest"), 0)
	assert_true(GameRegistry.is_shuffle())


func test_world_modes_picking_a_level_leaves_shuffle() -> void:
	GameRegistry.set_shuffle(true)
	var world: Node2D = _make_world()
	_hud(world).level_chosen.emit("forest", 4)
	assert_false(GameRegistry.is_shuffle())
	assert_eq(world._current_index, 4)
	assert_eq(SaveManager.load_progress("forest:easy"), 5)


func test_world_modes_shuffle_finished_world_on_open_moves_on() -> void:
	_finish_shuffle(["forest"])
	GameRegistry.set_shuffle(true)
	var world: Node2D = _make_world()
	assert_eq(world._current_index, 9)
	await wait_frames(2)
	assert_ne(GameRegistry.last_world_request, "")
	assert_ne(GameRegistry.last_world_request, "forest")


func test_world_modes_shuffle_tab_starts_shuffle() -> void:
	var world: Node2D = _make_world()
	_hud(world).shuffle_requested.emit()
	assert_true(GameRegistry.is_shuffle())
	assert_ne(GameRegistry.last_world_request, "")

extends GutTest

## Easy/hard difficulty and shuffle mode, played through the forest world.

const SCENE := preload("res://scenes/worlds/forest_bridge/forest_bridge.tscn")
const _SETTLE := 0.3

var _scene_changes: Array[String] = []
var _real_scene_changer: Callable


func before_each() -> void:
	SaveFixture.clear()
	GameRegistry.change_scenes = false
	GameRegistry.last_world_request = ""
	_scene_changes = []
	_real_scene_changer = Transition.scene_changer


func after_each() -> void:
	SaveFixture.clear()
	Transition.enabled = false
	Transition.half_duration = 0.15
	Transition.scene_changer = _real_scene_changer
	GameRegistry.change_scenes = true
	GameRegistry.last_world_request = ""
	GameRegistry.last_scene_request = ""


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


func test_world_modes_shuffle_continue_starts_shuffle() -> void:
	var world: Node2D = _make_world()
	_hud(world).shuffle_requested.emit(false)
	assert_true(GameRegistry.is_shuffle())
	assert_ne(GameRegistry.last_world_request, "")


func test_world_modes_shuffle_continue_while_shuffling_stays_put() -> void:
	SaveManager.set_progress(_shuffle_key("forest"), 4)
	GameRegistry.set_shuffle(true)
	var world: Node2D = _make_world()
	_hud(world).shuffle_requested.emit(false)
	assert_eq(GameRegistry.last_world_request, "")
	assert_eq(world._current_index, 3)
	assert_eq(SaveManager.load_progress(_shuffle_key("forest")), 4)


func test_world_modes_shuffle_start_over_clears_shuffle_progress() -> void:
	SaveManager.set_progress(_shuffle_key("forest"), 6)
	SaveManager.set_progress(_shuffle_key("sky"), 3)
	SaveManager.set_progress("forest:easy", 5)
	GameRegistry.set_shuffle(true)
	var world: Node2D = _make_world()
	_hud(world).shuffle_requested.emit(true)
	assert_true(GameRegistry.is_shuffle())
	assert_ne(GameRegistry.last_world_request, "")
	assert_eq(GameRegistry.shuffle_position().x, 1)
	assert_eq(SaveManager.load_progress("forest:easy"), 5, "normal progress is untouched")


func test_world_modes_shuffle_start_over_from_worlds_mode_turns_shuffle_on() -> void:
	SaveManager.set_progress(_shuffle_key("market"), 7)
	var world: Node2D = _make_world()
	_hud(world).shuffle_requested.emit(true)
	assert_true(GameRegistry.is_shuffle())
	assert_eq(GameRegistry.shuffle_next_index("market"), 0)


func _badge_text(world: Node2D) -> String:
	var row: Node = _hud(world).get_node("Root/LevelBadge/Row")
	return row.get_node("LevelLabel").text + row.get_node("CountLabel").text


func test_world_modes_easy_badge_counts_to_10() -> void:
	var world: Node2D = _make_world()
	assert_eq(_badge_text(world), "1/10")
	await _win(world)
	assert_eq(_badge_text(world), "2/10")


func test_world_modes_hard_badge_counts_11_to_20() -> void:
	GameRegistry.set_difficulty("hard")
	var world: Node2D = _make_world()
	assert_eq(_badge_text(world), "11/20")


func test_world_modes_shuffle_badge_counts_through_every_world() -> void:
	_finish_shuffle(["sky", "market", "picnic"])
	GameRegistry.set_shuffle(true)
	var world: Node2D = _make_world()
	var total: int = 10 * GameRegistry.get_worlds().size()
	assert_eq(_badge_text(world), "31/%d" % total)
	await _win(world)
	assert_eq(_badge_text(world), "32/%d" % total)


func test_world_modes_home_requested_goes_to_menu_and_keeps_mode() -> void:
	GameRegistry.set_difficulty("hard")
	var world: Node2D = _make_world()
	_hud(world).home_requested.emit()
	assert_eq(GameRegistry.last_scene_request, GameRegistry.MENU_SCENE)
	assert_eq(GameRegistry.get_difficulty(), "hard")
	assert_false(GameRegistry.is_shuffle())


func test_world_modes_level_change_with_transition_loads_after_cover() -> void:
	var world: Node2D = _make_world()
	Transition.half_duration = 0.05
	Transition.enabled = true
	_hud(world).level_chosen.emit("forest", 4)
	assert_eq(world._current_index, 0, "the old level stays until the screen is covered")
	await wait_for_signal(Transition.finished, 2.0)
	assert_eq(world._current_index, 4)


func test_world_modes_first_level_loads_without_transition() -> void:
	SaveManager.set_progress(SaveManager.progress_key("forest", "easy"), 3)
	Transition.enabled = true
	var world: Node2D = _make_world()
	assert_eq(world._current_index, 2)
	assert_false(Transition.is_busy())


# The player taps while the fade from an earlier tap is still running, and the celebration's timer
# runs out under it: _advance() must not undo what the player asked for.
func test_choosing_a_level_as_a_win_finishes_keeps_the_chosen_level() -> void:
	var world: Node2D = _make_world()
	Transition.half_duration = 0.01
	Transition.enabled = true
	_hud(world).level_chosen.emit("forest", 5)
	world._advance()
	await wait_for_signal(Transition.finished, 2.0)
	assert_eq(world._current_index, 5)
	assert_eq(SaveManager.load_progress("forest:easy"), 6)


func test_going_home_as_a_shuffle_win_finishes_stays_on_the_menu() -> void:
	GameRegistry.set_shuffle(true)
	SaveManager.set_progress("shuffle:forest:easy", 10)
	var world: Node2D = _make_world()
	GameRegistry.change_scenes = true
	Transition.scene_changer = func(path: String) -> void: _scene_changes.append(path)
	Transition.half_duration = 0.01
	Transition.enabled = true
	_hud(world).home_requested.emit()
	world._advance()
	await wait_for_signal(Transition.finished, 2.0)
	assert_eq(_scene_changes, [GameRegistry.MENU_SCENE] as Array[String])
	assert_eq(SaveManager.load_progress("shuffle:forest:easy"), 10, "the win wasn't counted")

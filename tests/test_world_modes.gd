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


func test_world_modes_starting_hard_level_on_easy_switches_difficulty() -> void:
	GameRegistry.request_level("forest", 13)
	var world: Node2D = _make_world()
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


func test_world_modes_shuffle_win_adds_one_to_round() -> void:
	GameRegistry.set_shuffle(true)
	var world: Node2D = _make_world()
	await _win(world)
	assert_eq(SaveManager.load_shuffle_round_played(), 1)


func test_world_modes_shuffle_tenth_win_shows_complete_screen() -> void:
	SaveManager.save_shuffle_round_played(GameRegistry.SHUFFLE_ROUND_LENGTH - 1)
	GameRegistry.set_shuffle(true)
	var world: Node2D = _make_world()
	watch_signals(world)
	await _win(world)
	assert_signal_emitted(world, "world_complete")
	assert_true(_hud(world).is_world_complete_shown())
	assert_eq(GameRegistry.last_world_request, "")


func test_world_modes_shuffle_win_before_tenth_goes_to_another_world() -> void:
	SaveManager.save_shuffle_round_played(GameRegistry.SHUFFLE_ROUND_LENGTH - 2)
	GameRegistry.set_shuffle(true)
	var world: Node2D = _make_world()
	await _win(world)
	assert_false(_hud(world).is_world_complete_shown())
	assert_false(GameRegistry.get_world(GameRegistry.last_world_request).is_empty())


func test_world_modes_shuffle_win_never_loads_same_world_next() -> void:
	GameRegistry.set_shuffle(true)
	for run in 5:
		SaveManager.save_shuffle_round_played(0)
		GameRegistry.last_world_request = ""
		var world: Node2D = _make_world()
		await _win(world)
		assert_ne(GameRegistry.last_world_request, "")
		assert_ne(GameRegistry.last_world_request, "forest")
		world.queue_free()


func test_world_modes_shuffle_restart_starts_new_round_keeping_places() -> void:
	SaveManager.save_shuffle_round_played(GameRegistry.SHUFFLE_ROUND_LENGTH)
	SaveManager.set_progress(_shuffle_key("sky"), 5)
	GameRegistry.set_shuffle(true)
	var world: Node2D = _make_world()
	_hud(world).restart_requested.emit()
	assert_eq(SaveManager.load_shuffle_round_played(), 0)
	assert_eq(GameRegistry.shuffle_next_index("sky"), 4)
	assert_true(GameRegistry.is_shuffle())
	assert_ne(GameRegistry.last_world_request, "")


func test_world_modes_shuffle_world_past_last_level_resumes_at_first() -> void:
	SaveManager.set_progress(_shuffle_key("forest"), 11)
	GameRegistry.set_shuffle(true)
	var world: Node2D = _make_world()
	assert_eq(world._current_index, 0)
	await wait_process_frames(2)
	assert_eq(GameRegistry.last_world_request, "", "it plays here instead of moving on")


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


func test_world_modes_shuffle_badge_counts_to_10_with_six_worlds() -> void:
	SaveManager.save_shuffle_round_played(2)
	GameRegistry.set_shuffle(true)
	var world: Node2D = _make_world()
	assert_eq(_badge_text(world), "3/10")


func test_world_modes_home_requested_goes_to_menu_and_keeps_mode() -> void:
	GameRegistry.set_difficulty("hard")
	var world: Node2D = _make_world()
	_hud(world).home_requested.emit()
	assert_eq(GameRegistry.last_scene_request, GameRegistry.MENU_SCENE)
	assert_eq(GameRegistry.get_difficulty(), "hard")
	assert_false(GameRegistry.is_shuffle())


func test_world_modes_level_change_with_transition_loads_after_cover() -> void:
	SaveFixture.start_at("forest", 4)
	var world: Node2D = _make_world()
	Transition.half_duration = 0.05
	Transition.enabled = true
	_hud(world).restart_requested.emit()
	assert_eq(world._current_index, 4, "the old level stays until the screen is covered")
	await wait_for_signal(Transition.finished, 2.0)
	assert_eq(world._current_index, 0)


func test_world_modes_first_level_loads_without_transition() -> void:
	SaveManager.set_progress(SaveManager.progress_key("forest", "easy"), 3)
	Transition.enabled = true
	var world: Node2D = _make_world()
	assert_eq(world._current_index, 2)
	assert_false(Transition.is_busy())


# The player taps replay, and the celebration's timer runs out under the fade: _advance() must not
# undo what the player asked for.
func test_replaying_as_a_win_finishes_keeps_the_replayed_level() -> void:
	SaveFixture.start_at("forest", 5)
	var world: Node2D = _make_world()
	Transition.half_duration = 0.01
	Transition.enabled = true
	_hud(world).replay_requested.emit()
	world._advance()
	await wait_for_signal(Transition.finished, 2.0)
	assert_eq(world._current_index, 5)
	assert_eq(SaveManager.load_progress("forest:easy"), 6)


func test_world_modes_replay_reloads_same_level() -> void:
	SaveFixture.start_at("forest", 4)
	var world: Node2D = _make_world()
	var load_count: int = world._load_count
	_hud(world).replay_requested.emit()
	assert_eq(world._current_index, 4)
	assert_eq(world._load_count, load_count + 1)
	assert_eq(SaveManager.load_progress("forest:easy"), 5)


func test_world_modes_replay_during_win_cancels_advance() -> void:
	SaveFixture.start_at("forest", 2)
	var world: Node2D = _make_world()
	_mechanic(world).correct.emit()
	_hud(world).replay_requested.emit()
	await wait_seconds(_SETTLE)
	assert_eq(world._current_index, 2)
	assert_eq(SaveManager.load_progress("forest:easy"), 3)


func test_world_modes_next_difficulty_switches_to_hard_and_loads_level_11() -> void:
	SaveManager.set_progress("forest:easy", 10)
	var world: Node2D = _make_world()
	await _win(world)
	assert_true(_hud(world).is_world_complete_shown())
	_hud(world).next_difficulty_requested.emit()
	assert_eq(GameRegistry.get_difficulty(), "hard")
	assert_eq(world._current_index, 10)
	assert_false(_hud(world).is_world_complete_shown())


func test_world_modes_next_difficulty_saves_hard_progress_at_level_11() -> void:
	SaveManager.set_progress("forest:hard", 17)
	SaveManager.set_progress("forest:easy", 10)
	var world: Node2D = _make_world()
	await _win(world)
	_hud(world).next_difficulty_requested.emit()
	assert_eq(SaveManager.load_progress("forest:hard"), 11)
	assert_eq(SaveManager.load_progress("forest:easy"), 1, "easy restarts next time")


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

extends GutTest

const SCENE := preload("res://scenes/worlds/forest_bridge/forest_bridge.tscn")
const _SAVE_PATH := "user://save.cfg"
const _LEVEL_COUNTS := [1, 2, 2, 3, 3, 3, 4, 4, 5, 5]
# AnimationPlayer speed-up so walk_across (2 s) and bridge_collapse (1 s) finish quickly.
const _ANIM_SPEED := 20.0
const _SETTLE := 0.3

var _world: Node2D
var _mechanic: Node2D
var _retry: BaseButton


func before_each() -> void:
	_clear_save()
	_world = _make_world()
	add_child(_world)
	_mechanic = _world.get_node("BridgeLayer/PlacementMechanic")
	_retry = _world.get_node("RetryPrompt/RetryIcon")


func after_each() -> void:
	_world.queue_free()
	_clear_save()


func _clear_save() -> void:
	if FileAccess.file_exists(_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))


func _make_world() -> Node2D:
	var world: Node2D = SCENE.instantiate()
	world.celebrate_duration = 0.01
	world.get_node("AnimationPlayer").speed_scale = _ANIM_SPEED
	return world


func _fill_and_confirm(mechanic: Node2D) -> void:
	for i in mechanic.target_count:
		mechanic.place()
	mechanic.confirm()


func test_forest_bridge_ready_sets_first_level_target_count() -> void:
	assert_eq(_mechanic.target_count, 1)


func test_forest_bridge_ready_resets_mechanic_count() -> void:
	assert_eq(_mechanic.get_placed_count(), 0)


func test_forest_bridge_retry_prompt_hidden_on_start() -> void:
	assert_false(_retry.visible)


func test_forest_bridge_correct_advances_level() -> void:
	_fill_and_confirm(_mechanic)
	await wait_seconds(_SETTLE)
	assert_eq(_mechanic.target_count, 2)


func test_forest_bridge_correct_resets_placed_count() -> void:
	_fill_and_confirm(_mechanic)
	await wait_seconds(_SETTLE)
	assert_eq(_mechanic.get_placed_count(), 0)


func test_forest_bridge_level_does_not_advance_until_walk_animation_finishes() -> void:
	_fill_and_confirm(_mechanic)
	assert_eq(_mechanic.target_count, 1)
	assert_eq(_world.get_node("AnimationPlayer").current_animation, "walk_across")
	await wait_seconds(_SETTLE)
	assert_eq(_mechanic.target_count, 2)


func test_forest_bridge_mechanic_not_interactive_during_walk() -> void:
	_fill_and_confirm(_mechanic)
	assert_true(_mechanic.get_node("GoButton").disabled)
	await wait_seconds(_SETTLE)
	assert_false(_mechanic.get_node("GoButton").disabled)


func test_forest_bridge_incorrect_does_not_advance_level() -> void:
	_mechanic.confirm()
	await wait_seconds(_SETTLE)
	assert_eq(_mechanic.target_count, 1)


func test_forest_bridge_retry_prompt_visible_after_incorrect() -> void:
	_mechanic.confirm()
	assert_false(_retry.visible)
	await wait_seconds(_SETTLE)
	assert_true(_retry.visible)


func test_forest_bridge_retry_prompt_hidden_and_mechanic_reset_on_retry_pressed() -> void:
	_mechanic.target_count = 2
	_mechanic.reset()
	_mechanic.place()
	_mechanic.confirm()
	await wait_seconds(_SETTLE)
	_retry.pressed.emit()
	assert_false(_retry.visible)
	assert_eq(_mechanic.get_placed_count(), 0)
	assert_eq(_mechanic.modulate.a, 1.0)
	assert_false(_mechanic.get_node("GoButton").disabled)


func test_forest_bridge_world_complete_emitted_after_last_level_animation() -> void:
	SaveManager.save_progress("forest", 10)
	var world: Node2D = add_child_autofree(_make_world())
	var mechanic: Node2D = world.get_node("BridgeLayer/PlacementMechanic")
	watch_signals(world)
	_fill_and_confirm(mechanic)
	assert_signal_not_emitted(world, "world_complete")
	await wait_seconds(_SETTLE)
	assert_signal_emitted(world, "world_complete")


func test_forest_bridge_world_complete_emits_after_all_levels() -> void:
	watch_signals(_world)
	for count in _LEVEL_COUNTS:
		assert_eq(_mechanic.target_count, count)
		_fill_and_confirm(_mechanic)
		await wait_seconds(_SETTLE)
	assert_signal_emitted(_world, "world_complete")


func test_forest_bridge_resumes_from_saved_level() -> void:
	SaveManager.save_progress("forest", 3)
	var world: Node2D = add_child_autofree(_make_world())
	var mechanic: Node2D = world.get_node("BridgeLayer/PlacementMechanic")
	assert_eq(mechanic.target_count, 2)


func test_forest_bridge_correct_saves_next_level() -> void:
	_fill_and_confirm(_mechanic)
	await wait_seconds(_SETTLE)
	assert_eq(SaveManager.load_progress("forest"), 2)


func test_forest_bridge_last_level_correct_resets_progress() -> void:
	SaveManager.save_progress("forest", 10)
	var world: Node2D = add_child_autofree(_make_world())
	_fill_and_confirm(world.get_node("BridgeLayer/PlacementMechanic"))
	await wait_seconds(_SETTLE)
	assert_eq(SaveManager.load_progress("forest"), 1)

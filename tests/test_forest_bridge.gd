extends GutTest

const SCENE := preload("res://scenes/worlds/forest_bridge/forest_bridge.tscn")
const _SAVE_PATH := "user://save.cfg"
const _SEED := 1234
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
	world.puzzle_seed = _SEED
	world.walk_speed = 50000.0
	world.get_node("AnimationPlayer").speed_scale = _ANIM_SPEED
	return world


## Drops a set of planks that adds up to the bridge length, found by brute force.
func _fill_and_confirm(mechanic: Node2D) -> void:
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


func _drop_one_short_and_confirm(mechanic: Node2D) -> void:
	var smallest: PlankDrag = null
	for plank: PlankDrag in mechanic.get_planks():
		if smallest == null or plank.length < smallest.length:
			smallest = plank
	smallest.dropped.emit(mechanic.to_global(Vector2.ZERO))
	mechanic.confirm()


func _bridge_length_in_range(level_index: int, length: int) -> bool:
	var level: Dictionary = LevelLoader.get_levels_for_world("forest")[level_index]
	return length >= level["bridge_length"]["min"] and length <= level["bridge_length"]["max"]


func _pile_lengths(mechanic: Node2D) -> Array[int]:
	var lengths: Array[int] = []
	for plank: PlankDrag in mechanic.get_planks():
		lengths.append(plank.length)
	return lengths


func _level_index(world: Node2D) -> int:
	return world._current_index


func test_forest_bridge_ready_loads_first_level() -> void:
	assert_eq(_level_index(_world), 0)


func test_forest_bridge_load_level_sets_bridge_length_within_level_range() -> void:
	assert_true(_bridge_length_in_range(0, _mechanic.get_target_length()))


func test_forest_bridge_ready_starts_with_empty_bridge() -> void:
	assert_eq(_mechanic.get_placed_total(), 0)


func test_forest_bridge_retry_prompt_hidden_on_start() -> void:
	assert_false(_retry.visible)


func test_forest_bridge_same_seed_generates_same_first_puzzle() -> void:
	var other: Node2D = add_child_autofree(_make_world())
	var other_mechanic: Node2D = other.get_node("BridgeLayer/PlacementMechanic")
	assert_eq(other_mechanic.get_target_length(), _mechanic.get_target_length())
	assert_eq(_pile_lengths(other_mechanic), _pile_lengths(_mechanic))


func test_forest_bridge_correct_advances_level() -> void:
	_fill_and_confirm(_mechanic)
	await wait_seconds(_SETTLE)
	assert_eq(_level_index(_world), 1)
	assert_true(_bridge_length_in_range(1, _mechanic.get_target_length()))


func test_forest_bridge_correct_resets_placed_total() -> void:
	_fill_and_confirm(_mechanic)
	await wait_seconds(_SETTLE)
	assert_eq(_mechanic.get_placed_total(), 0)


func test_forest_bridge_next_level_generates_new_puzzle() -> void:
	SaveManager.save_progress("forest", 9)
	var world: Node2D = add_child_autofree(_make_world())
	var mechanic: Node2D = world.get_node("BridgeLayer/PlacementMechanic")
	var before := [mechanic.get_target_length(), _pile_lengths(mechanic)]
	_fill_and_confirm(mechanic)
	await wait_seconds(_SETTLE)
	assert_eq(_level_index(world), 9)
	assert_ne([mechanic.get_target_length(), _pile_lengths(mechanic)], before)


func test_forest_bridge_level_does_not_advance_until_walk_animation_finishes() -> void:
	_fill_and_confirm(_mechanic)
	assert_eq(_level_index(_world), 0)
	assert_eq(_world.get_node("AnimationPlayer").current_animation, "walk_across")
	await wait_seconds(_SETTLE)
	assert_eq(_level_index(_world), 1)


func test_forest_bridge_mechanic_not_interactive_during_walk() -> void:
	_fill_and_confirm(_mechanic)
	assert_true(_mechanic.get_node("GoButton").disabled)
	await wait_seconds(_SETTLE)
	assert_false(_mechanic.get_node("GoButton").disabled)


func test_forest_bridge_incorrect_does_not_advance_level() -> void:
	_drop_one_short_and_confirm(_mechanic)
	await wait_seconds(_SETTLE)
	assert_eq(_level_index(_world), 0)


func test_forest_bridge_retry_prompt_visible_after_incorrect() -> void:
	_drop_one_short_and_confirm(_mechanic)
	assert_false(_retry.visible)
	await wait_seconds(_SETTLE)
	assert_true(_retry.visible)


func test_forest_bridge_retry_prompt_hidden_and_mechanic_reset_on_retry_pressed() -> void:
	_drop_one_short_and_confirm(_mechanic)
	await wait_seconds(_SETTLE)
	_retry.pressed.emit()
	assert_false(_retry.visible)
	assert_eq(_mechanic.get_placed_total(), 0)
	assert_eq(_mechanic.modulate.a, 1.0)
	assert_false(_mechanic.get_node("GoButton").disabled)


func test_forest_bridge_retry_keeps_same_puzzle() -> void:
	var target: int = _mechanic.get_target_length()
	var lengths := _pile_lengths(_mechanic)
	_drop_one_short_and_confirm(_mechanic)
	await wait_seconds(_SETTLE)
	_retry.pressed.emit()
	assert_eq(_mechanic.get_target_length(), target)
	assert_eq(_pile_lengths(_mechanic), lengths)


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
	for i in 10:
		assert_true(_bridge_length_in_range(i, _mechanic.get_target_length()), "level %d" % i)
		_fill_and_confirm(_mechanic)
		await wait_seconds(_SETTLE)
	assert_signal_emitted(_world, "world_complete")


func test_forest_bridge_resumes_from_saved_level() -> void:
	SaveManager.save_progress("forest", 3)
	var world: Node2D = add_child_autofree(_make_world())
	assert_eq(_level_index(world), 2)


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


func test_forest_bridge_incorrect_fox_falls_where_planks_end() -> void:
	var character: Node2D = _world.get_node("Character")
	_drop_one_short_and_confirm(_mechanic)
	var end_x: float = _world.to_local(_mechanic.get_bridge_end_position()).x
	await wait_seconds(_SETTLE)
	assert_almost_eq(character.position.x, end_x + 12.0, 0.5)
	assert_gt(character.position.y, 700.0)


func test_forest_bridge_incorrect_on_empty_bridge_falls_at_bank_edge() -> void:
	var character: Node2D = _world.get_node("Character")
	var bank_edge_x: float = _world.to_local(_mechanic.to_global(Vector2(-300, 0))).x
	_mechanic.confirm()
	await wait_seconds(_SETTLE)
	assert_almost_eq(character.position.x, bank_edge_x + 12.0, 0.5)


func test_forest_bridge_fox_does_not_fall_before_reaching_plank_end() -> void:
	var world: Node2D = _make_world()
	world.walk_speed = 500.0
	add_child_autofree(world)
	var mechanic: Node2D = world.get_node("BridgeLayer/PlacementMechanic")
	var character: Node2D = world.get_node("Character")
	_drop_one_short_and_confirm(mechanic)
	await wait_seconds(0.1)
	assert_eq(character.position.y, 340.0)
	assert_ne(world.get_node("AnimationPlayer").current_animation, "bridge_collapse")

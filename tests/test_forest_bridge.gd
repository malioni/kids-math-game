extends GutTest

const SCENE := preload("res://scenes/worlds/forest_bridge/forest_bridge.tscn")

var _world: Node2D
var _mechanic: Node2D


func before_each() -> void:
	_world = SCENE.instantiate()
	add_child(_world)
	_mechanic = _world.get_node("PlacementMechanic")


func after_each() -> void:
	_world.queue_free()


func test_forest_bridge_ready_sets_first_level_target_count() -> void:
	assert_eq(_mechanic.target_count, 1)


func test_forest_bridge_ready_resets_mechanic_count() -> void:
	assert_eq(_mechanic.get_placed_count(), 0)


func test_forest_bridge_correct_advances_level() -> void:
	_mechanic.place()
	assert_eq(_mechanic.target_count, 2)


func test_forest_bridge_correct_resets_placed_count() -> void:
	_mechanic.place()
	assert_eq(_mechanic.get_placed_count(), 0)


func test_forest_bridge_incorrect_does_not_advance_level() -> void:
	_mechanic.confirm()
	assert_eq(_mechanic.target_count, 1)


func test_forest_bridge_incorrect_resets_placed_count() -> void:
	_mechanic.confirm()
	assert_eq(_mechanic.get_placed_count(), 0)


func test_forest_bridge_world_complete_emits_after_all_levels() -> void:
	watch_signals(_world)
	var counts := [1, 2, 2, 3, 3, 3, 4, 4, 5, 5]
	for count in counts:
		for i in count:
			_mechanic.place()
	assert_signal_emitted(_world, "world_complete")

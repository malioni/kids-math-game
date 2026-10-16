extends GutTest

const SCENE := preload("res://scenes/worlds/market/market.tscn")
const _SAVE_PATH := "user://save.cfg"
const _SEED := 1234
const _SETTLE := 0.3
# The throw animation is 3 frames at 6 fps, then the tomato flies and the splat shows.
const _THROW_SETTLE := 0.9

var _world: Node2D
var _mechanic: MarketMechanic
var _retry: BaseButton
var _hud: LevelHud


func before_each() -> void:
	_clear_save()
	_world = _make_world()
	add_child(_world)
	_mechanic = _world.get_node("MarketMechanic")
	_retry = _world.get_node("RetryPrompt/RetryIcon")
	_hud = _world.get_node("LevelHud")


func after_each() -> void:
	_world.queue_free()
	_clear_save()


func _clear_save() -> void:
	if FileAccess.file_exists(_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))


func _make_world() -> Node2D:
	var world: Node2D = SCENE.instantiate()
	world.celebrate_duration = 0.01
	world.throw_duration = 0.05
	world.splat_duration = 0.05
	world.puzzle_seed = _SEED
	return world


func _place(mechanic: MarketMechanic, item: String, times: int) -> void:
	for i in times:
		mechanic.get_ready_bag(item).dropped.emit(mechanic.global_position)


## Places exactly the right number of bags for every order and presses Go.
func _solve(mechanic: MarketMechanic) -> void:
	for order in mechanic.get_orders():
		_place(mechanic, order["item"], order["bag_count"])
	mechanic.confirm()


func test_market_world_id_is_market() -> void:
	assert_eq(_world._world_id(), "market")
	assert_eq(SaveManager.load_last_world(), "market")


func test_market_loads_level_1_with_one_tomato_order() -> void:
	assert_eq(_world._current_index, 0)
	var orders: Array[Dictionary] = _mechanic.get_orders()
	assert_eq(orders.size(), 1)
	assert_eq(orders[0]["item"], "tomato")
	assert_eq(_hud.get_node("Root/LevelBadge/Row/LevelLabel").text, "1")


func test_market_correct_advances_to_next_level() -> void:
	_solve(_mechanic)
	await wait_seconds(_SETTLE)
	assert_eq(_world._current_index, 1)
	assert_eq(SaveManager.load_progress("market"), 2)


func test_market_correct_fox_celebrates() -> void:
	_solve(_mechanic)
	assert_eq(_world.get_node("Character").animation, &"celebrate")


func test_market_incorrect_fox_throws() -> void:
	_mechanic.confirm()
	assert_eq(_world.get_node("Character").animation, &"throw")


func test_market_incorrect_shows_retry_after_throw() -> void:
	_mechanic.confirm()
	assert_false(_retry.visible)
	assert_true(_mechanic.get_node("GoButton").disabled)
	await wait_seconds(_THROW_SETTLE)
	assert_true(_retry.visible)
	assert_true(_world.get_node("Splat").visible)
	assert_false(_world.get_node("FlyingTomato").visible)
	assert_eq(_world._current_index, 0)


func test_market_retry_keeps_same_orders_and_clears_table() -> void:
	var orders: Array[Dictionary] = _mechanic.get_orders().duplicate(true)
	_place(_mechanic, "tomato", 1)
	_mechanic.confirm()
	await wait_seconds(_THROW_SETTLE)
	_retry.pressed.emit()
	assert_false(_retry.visible)
	assert_false(_world.get_node("Splat").visible)
	assert_eq(_mechanic.get_orders(), orders)
	assert_eq(_mechanic.get_placed_count("tomato"), 0)
	assert_false(_mechanic.get_node("GoButton").disabled)


func test_market_level_change_during_throw_does_not_show_retry() -> void:
	_mechanic.confirm()
	_hud.level_chosen.emit("market", 7)
	await wait_seconds(_THROW_SETTLE)
	assert_false(_retry.visible)
	assert_false(_world.get_node("Splat").visible)
	assert_eq(_world._current_index, 7)
	assert_eq(_mechanic.get_orders().size(), 2)


func test_market_every_level_solvable_in_order() -> void:
	for i in LevelLoader.get_levels_for_world("market").size():
		assert_eq(_world._current_index, i)
		_solve(_mechanic)
		await wait_seconds(_SETTLE)
	assert_true(_hud.is_world_complete_shown())

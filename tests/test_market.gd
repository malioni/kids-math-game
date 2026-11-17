extends GutTest

const SCENE := preload("res://scenes/worlds/market/market.tscn")
const _SEED := 1234
const _SETTLE := 0.3
# The paw lets go on frame 3 of the throw at 10 fps (0.3 s), then the tomato flies and the splat
# shows.
const _THROW_SETTLE := 0.9

var _world: Node2D
var _mechanic: MarketMechanic
var _retry: BaseButton
var _hud: LevelHud


func before_each() -> void:
	SaveFixture.clear()
	_world = _make_world()
	add_child(_world)
	_mechanic = _world.get_node("MarketMechanic")
	_retry = _world.get_node("RetryPrompt/RetryIcon")
	_hud = _world.get_node("LevelHud")


func after_each() -> void:
	_world.queue_free()
	SaveFixture.clear()


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
	assert_eq(SaveManager.load_progress("market:easy"), 2)


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


func test_market_throw_animation_uses_its_own_sheet() -> void:
	var frames: SpriteFrames = _world.get_node("Character").sprite_frames
	assert_eq(frames.get_frame_count("throw"), 6)
	assert_false(frames.get_animation_loop("throw"))
	var first: AtlasTexture = frames.get_frame_texture("throw", 0)
	assert_eq(first.atlas.resource_path, "res://assets/sprites/fox/character_throw.svg")


func test_market_tomato_leaves_the_paw_on_the_release_frame() -> void:
	var fox: AnimatedSprite2D = _world.get_node("Character")
	var tomato: Sprite2D = _world.get_node("FlyingTomato")
	# Long enough that a slow frame can't land the tomato before the last check.
	_world.throw_duration = 1.0
	_mechanic.confirm()
	for i in 120:
		if fox.frame >= 3:
			break
		assert_false(
			tomato.visible, "tomato flying on frame %d, before the paw lets go" % fox.frame
		)
		await wait_process_frames(1)
	assert_true(tomato.visible, "the tomato leaves the paw on frame 3")


func test_market_tomato_still_flies_if_the_release_frame_is_skipped() -> void:
	var fox: AnimatedSprite2D = _world.get_node("Character")
	_world.throw_duration = 1.0
	_mechanic.confirm()
	fox.frame = 5
	assert_true(_world.get_node("FlyingTomato").visible)


func test_market_tomato_flies_in_an_arc() -> void:
	var tomato: Sprite2D = _world.get_node("FlyingTomato")
	var splat: Sprite2D = _world.get_node("Splat")
	# Long enough that the check below lands mid-flight even after a slow frame.
	_world.throw_duration = 1.0
	_mechanic.confirm()
	await wait_until(func() -> bool: return tomato.visible, 2.0)
	var from: Vector2 = tomato.position
	await wait_seconds(0.5)
	assert_true(tomato.visible, "still in the air")
	var along: float = inverse_lerp(from.x, splat.position.x, tomato.position.x)
	var straight_y: float = lerpf(from.y, splat.position.y, along)
	assert_lt(tomato.position.y, straight_y - 50.0, "the tomato rises above the straight line")


func test_market_fox_goes_back_to_idle_after_the_throw() -> void:
	var fox: AnimatedSprite2D = _world.get_node("Character")
	_mechanic.confirm()
	await wait_until(func() -> bool: return fox.animation == &"idle", 2.0)
	assert_eq(fox.animation, &"idle")


func test_market_incorrect_chimes_then_splats_when_tomato_lands() -> void:
	watch_signals(AudioManager)
	_mechanic.confirm()
	assert_signal_emitted_with_parameters(AudioManager, "sfx_played", ["lose"])
	assert_false(_sfx_played().has("market/splat"), "no splat before the tomato lands")
	await wait_seconds(_THROW_SETTLE)
	assert_has(_sfx_played(), "market/splat")


func _sfx_played() -> Array:
	var sounds: Array = []
	for i in get_signal_emit_count(AudioManager, "sfx_played"):
		sounds.append(get_signal_parameters(AudioManager, "sfx_played", i)[0])
	return sounds


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
	assert_false(_world.get_node("FlyingTomato").visible)
	assert_eq(_world._current_index, 7)
	assert_eq(_mechanic.get_orders().size(), 2)


func test_market_level_change_during_flight_leaves_nothing_behind() -> void:
	var tomato: Sprite2D = _world.get_node("FlyingTomato")
	_world.throw_duration = 1.0
	_mechanic.confirm()
	await wait_until(func() -> bool: return tomato.visible, 2.0)
	_hud.level_chosen.emit("market", 7)
	assert_false(tomato.visible)
	await wait_seconds(1.0 + _SETTLE)
	assert_false(tomato.visible)
	assert_false(_world.get_node("Splat").visible)
	assert_false(_retry.visible)
	assert_eq(_world.get_node("Character").animation, &"idle")


func test_market_level_change_during_splat_leaves_nothing_behind() -> void:
	var splat: Sprite2D = _world.get_node("Splat")
	_world.splat_duration = 1.0
	_mechanic.confirm()
	await wait_until(func() -> bool: return splat.visible, 2.0)
	_hud.level_chosen.emit("market", 7)
	assert_false(splat.visible)
	await wait_seconds(1.0 + _SETTLE)
	assert_false(splat.visible)
	assert_false(_world.get_node("FlyingTomato").visible)
	assert_false(_retry.visible)
	assert_eq(_world.get_node("Character").animation, &"idle")


func test_market_wrong_again_after_retry_throws_again() -> void:
	_mechanic.confirm()
	await wait_seconds(_THROW_SETTLE)
	_retry.pressed.emit()
	_mechanic.confirm()
	assert_eq(_world.get_node("Character").animation, &"throw")
	assert_eq(_world.get_node("Character").frame, 0)
	assert_false(_world.get_node("FlyingTomato").visible)
	await wait_seconds(_THROW_SETTLE)
	assert_true(_world.get_node("Splat").visible)
	assert_true(_retry.visible)


func test_market_every_level_solvable_in_order() -> void:
	for difficulty in LevelLoader.DIFFICULTIES:
		_hud.difficulty_chosen.emit(difficulty)
		var level_range: Vector2i = LevelLoader.get_difficulty_range(difficulty)
		for i in range(level_range.x, level_range.y + 1):
			assert_eq(_world._current_index, i, difficulty)
			_solve(_mechanic)
			await wait_seconds(_SETTLE)
		assert_true(_hud.is_world_complete_shown(), difficulty)

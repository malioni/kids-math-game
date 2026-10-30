extends GutTest

const SCENE := preload("res://scenes/worlds/picnic/picnic.tscn")
const _SAVE_PATH := "user://save.cfg"
const _SEED := 1234
const _DEAL_STEP := 0.01
# Long enough for a deal to 4 friends plus the world's reaction.
const _SETTLE := 0.4

var _world: Node2D
var _mechanic: SharingMechanic
var _retry: BaseButton
var _hud: LevelHud


func before_each() -> void:
	_clear_save()
	_world = _make_world()
	add_child(_world)
	_mechanic = _world.get_node("SharingMechanic")
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
	world.sad_duration = 0.05
	world.puzzle_seed = _SEED
	world.get_node("SharingMechanic").deal_step = _DEAL_STEP
	return world


func _place(item: String, times: int) -> void:
	for i in times:
		_mechanic.get_ready_piece(item).tapped.emit()


## Puts the fair share of every fruit on the fox's plate and presses Go.
func _solve() -> void:
	for order in _mechanic.get_orders():
		_place(order["item"], order["total"] / _mechanic.get_plate_count())
	_mechanic.confirm()


func test_picnic_world_id_is_picnic() -> void:
	assert_eq(_world._world_id(), "picnic")
	assert_eq(SaveManager.load_last_world(), "picnic")


func test_picnic_loads_level_1_with_one_strawberry_order() -> void:
	assert_eq(_world._current_index, 0)
	var orders: Array[Dictionary] = _mechanic.get_orders()
	assert_eq(orders.size(), 1)
	assert_eq(orders[0]["item"], "strawberry")
	assert_eq(_hud.get_node("Root/LevelBadge/Row/LevelLabel").text, "1")


func test_picnic_correct_advances_to_next_level() -> void:
	_solve()
	await wait_seconds(_SETTLE)
	assert_eq(_world._current_index, 1)
	assert_eq(SaveManager.load_progress("picnic"), 2)


func test_picnic_correct_fox_celebrates() -> void:
	_solve()
	await wait_for_signal(_mechanic.correct, 1.0)
	assert_eq(_world.get_node("Character").animation, &"celebrate")


func test_picnic_incorrect_fox_sad_and_retry_shown() -> void:
	_mechanic.confirm()
	await wait_for_signal(_mechanic.incorrect, 1.0)
	assert_eq(_world.get_node("Character").animation, &"sad")
	assert_false(_retry.visible)
	await wait_seconds(_SETTLE)
	assert_true(_retry.visible)
	assert_eq(_world._current_index, 0)


func test_picnic_sad_animation_uses_sad_sheet_and_loops() -> void:
	var frames: SpriteFrames = _world.get_node("Character").sprite_frames
	assert_eq(frames.get_frame_count("sad"), 4)
	assert_true(frames.get_animation_loop("sad"))
	var first: AtlasTexture = frames.get_frame_texture("sad", 0)
	assert_eq(first.atlas.resource_path, "res://assets/sprites/forest_bridge/character_sad.png")
	assert_eq(_mechanic.guest_frames, frames, "friends share the fox's frames, so they cry too")


func test_picnic_retry_keeps_same_orders_and_clears_plate() -> void:
	var orders: Array[Dictionary] = _mechanic.get_orders().duplicate(true)
	_place("strawberry", 1)
	_mechanic.confirm()
	await wait_seconds(_SETTLE)
	_retry.pressed.emit()
	assert_false(_retry.visible)
	assert_eq(_mechanic.get_orders(), orders)
	assert_eq(_mechanic.get_placed_count("strawberry"), 0)
	assert_false(_mechanic.get_node("GoButton").disabled)
	assert_eq(_world.get_node("Character").animation, &"idle")


func test_picnic_level_change_during_deal_does_not_show_retry() -> void:
	_mechanic.confirm()
	_hud.level_chosen.emit("picnic", 7)
	await wait_seconds(_SETTLE)
	assert_false(_retry.visible)
	assert_eq(_world._current_index, 7)
	assert_eq(_mechanic.get_orders().size(), 2)
	assert_false(_mechanic.get_node("GoButton").disabled)


func test_picnic_every_level_solvable_in_order() -> void:
	for i in LevelLoader.get_levels_for_world("picnic").size():
		assert_eq(_world._current_index, i)
		_solve()
		await wait_seconds(_SETTLE)
	assert_true(_hud.is_world_complete_shown())

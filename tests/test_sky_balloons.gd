extends GutTest

const SCENE := preload("res://scenes/worlds/sky_balloons/sky_balloons.tscn")
const _SAVE_PATH := "user://save.cfg"
const _SEED := 1234
const _SETTLE := 0.3

var _world: Node2D
var _mechanic: BalloonPopMechanic
var _retry: BaseButton
var _hud: LevelHud


func before_each() -> void:
	_clear_save()
	_world = _make_world()
	add_child(_world)
	_mechanic = _world.get_node("Rig/BalloonPopMechanic")
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
	world.fall_duration = 0.05
	world.puzzle_seed = _SEED
	return world


## Pops a set of balloons that adds up to the extra lift, found by brute force.
func _solve(mechanic: BalloonPopMechanic) -> void:
	var balloons: Array[Node] = mechanic.get_unpopped_balloons()
	var extra: int = mechanic.get_balance()
	for mask in range(1, 1 << balloons.size()):
		var total: int = 0
		for i in balloons.size():
			if mask & (1 << i):
				total += balloons[i].value
		if total == extra:
			for i in balloons.size():
				if mask & (1 << i):
					mechanic.pop(balloons[i])
			return


## Pops balloons from the biggest down until the lift drops below the weight.
func _pop_too_many(mechanic: BalloonPopMechanic) -> void:
	var balloons: Array[Node] = mechanic.get_unpopped_balloons()
	balloons.sort_custom(func(a: Balloon, b: Balloon) -> bool: return a.value > b.value)
	for balloon: Balloon in balloons:
		if mechanic.get_balance() < 0:
			return
		mechanic.pop(balloon)


func _level_values(world: Node2D) -> Array[int]:
	var values: Array[int] = []
	for balloon: Balloon in world.get_node("Rig/BalloonPopMechanic").get_balloons():
		values.append(balloon.value)
	return values


func _target_in_level_range(level_index: int) -> bool:
	var level: Dictionary = LevelLoader.get_levels_for_world("sky")[level_index]
	return _mechanic.get_lift_total() <= int(level["total_max"])


func test_sky_balloons_ready_loads_first_level_rising() -> void:
	assert_eq(_world._current_index, 0)
	assert_true(_world.is_rising())
	assert_gt(_mechanic.get_balance(), 0)
	assert_true(_target_in_level_range(0))


func test_sky_balloons_hud_shows_level() -> void:
	assert_eq(_hud.get_node("Root/LevelBadge/Row/LevelLabel").text, "1")


func test_sky_balloons_same_seed_generates_same_first_puzzle() -> void:
	var other: Node2D = add_child_autofree(_make_world())
	assert_eq(_level_values(other), _level_values(_world))


func test_sky_balloons_correct_levels_out_then_advances() -> void:
	_solve(_mechanic)
	assert_true(_world.is_level())
	await wait_seconds(_SETTLE)
	assert_eq(_world._current_index, 1)
	assert_true(_world.is_rising())
	assert_eq(SaveManager.load_progress("sky:easy"), 2)


func test_sky_balloons_too_many_pops_falls_and_shows_retry() -> void:
	_pop_too_many(_mechanic)
	assert_true(_world.is_falling())
	assert_false(_retry.visible)
	await wait_seconds(_SETTLE)
	assert_true(_retry.visible)
	assert_gt(_world.get_node("Rig").position.y, 1000.0)
	assert_eq(_world._current_index, 0)


func test_sky_balloons_retry_restores_same_puzzle() -> void:
	var values := _level_values(_world)
	var target: int = _mechanic.get_target()
	_pop_too_many(_mechanic)
	await wait_seconds(_SETTLE)
	_retry.pressed.emit()
	assert_false(_retry.visible)
	assert_true(_world.is_rising())
	assert_eq(_level_values(_world), values)
	assert_eq(_mechanic.get_target(), target)
	assert_eq(_mechanic.get_unpopped_balloons().size(), values.size())
	assert_lt(_world.get_node("Rig").position.y, 600.0)


func test_sky_balloons_picking_a_level_loads_it_and_saves() -> void:
	_hud.level_chosen.emit("sky", 6)
	assert_eq(_world._current_index, 6)
	assert_eq(SaveManager.load_progress("sky:easy"), 7)
	assert_eq(_hud.get_node("Root/LevelBadge/Row/LevelLabel").text, "7")


func test_sky_balloons_picking_a_level_mid_fall_cancels_the_fall() -> void:
	_pop_too_many(_mechanic)
	_hud.level_chosen.emit("sky", 2)
	await wait_seconds(_SETTLE)
	assert_false(_retry.visible)
	assert_true(_world.is_rising())
	assert_lt(_world.get_node("Rig").position.y, 600.0)


func test_sky_balloons_last_level_shows_world_complete_and_restart_goes_to_level_1() -> void:
	SaveManager.save_progress("sky:easy", 10)
	var world: Node2D = add_child_autofree(_make_world())
	var hud: LevelHud = world.get_node("LevelHud")
	watch_signals(world)
	_solve(world.get_node("Rig/BalloonPopMechanic"))
	await wait_seconds(_SETTLE)
	assert_signal_emitted(world, "world_complete")
	assert_true(hud.is_world_complete_shown())
	assert_eq(SaveManager.load_progress("sky:easy"), 1)
	hud.get_node("Root/Complete/Choices/RestartButton").pressed.emit()
	assert_eq(world._current_index, 0)
	assert_false(hud.is_world_complete_shown())


func test_sky_balloons_requested_level_overrides_save() -> void:
	SaveManager.save_progress("sky:easy", 10)
	GameRegistry.request_level("sky", 3)
	var world: Node2D = add_child_autofree(_make_world())
	assert_eq(world._current_index, 3)


func test_sky_balloons_remembers_it_was_played_last() -> void:
	assert_eq(SaveManager.load_last_world(), "sky")


func test_sky_balloons_every_level_solvable_in_order() -> void:
	for difficulty in LevelLoader.DIFFICULTIES:
		_hud.difficulty_chosen.emit(difficulty)
		var level_range: Vector2i = LevelLoader.get_difficulty_range(difficulty)
		for i in range(level_range.x, level_range.y + 1):
			assert_eq(_world._current_index, i, difficulty)
			_solve(_mechanic)
			await wait_seconds(_SETTLE)
		assert_true(_hud.is_world_complete_shown(), difficulty)

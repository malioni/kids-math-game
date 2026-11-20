extends GutTest

const SCENE := preload("res://scenes/worlds/drive/drive.tscn")
const _SEED := 1234
const _FAST := 0.01

var _world: Node2D
var _mechanic: DriveMechanic
var _retry: BaseButton
var _hud: LevelHud


func before_each() -> void:
	SaveFixture.clear()
	_world = _make_world()
	add_child(_world)
	_mechanic = _world.get_node("DriveMechanic")
	_retry = _world.get_node("RetryPrompt/RetryIcon")
	_hud = _world.get_node("LevelHud")


func after_each() -> void:
	_world.queue_free()
	SaveFixture.clear()


func _make_world() -> Node2D:
	var world: Node2D = SCENE.instantiate()
	world.celebrate_duration = 0.01
	world.honk_duration = _FAST
	world.lose_duration = _FAST
	world.puzzle_seed = _SEED
	var mechanic: DriveMechanic = world.get_node("DriveMechanic")
	mechanic.step_duration = _FAST
	mechanic.turn_duration = _FAST
	return world


## Enters the shortest program for the current field.
func _enter_solution() -> void:
	var best := DrivePuzzleGenerator.fewest_tiles(_mechanic.get_field(), _mechanic.get_mode())
	for tile: Dictionary in best["program"]:
		for step in int(tile["count"]):
			_mechanic.press_command(tile["command"])


## Enters a program that stops short without bumping: the shortest program's first step only.
## Every field needs at least three squares, so one step never reaches the garage.
func _enter_short() -> void:
	var best := DrivePuzzleGenerator.fewest_tiles(_mechanic.get_field(), _mechanic.get_mode())
	_mechanic.press_command(best["program"][0]["command"])


func _sfx_played() -> Array:
	var sounds: Array = []
	for i in get_signal_emit_count(AudioManager, "sfx_played"):
		sounds.append(get_signal_parameters(AudioManager, "sfx_played", i)[0])
	return sounds


func test_drive_world_id_is_drive() -> void:
	assert_eq(_world._world_id(), "drive")
	assert_eq(SaveManager.load_last_world(), "drive")


func test_drive_character_is_the_car() -> void:
	assert_eq(_world._character, _mechanic.get_car())
	assert_eq(
		_world._character.sprite_frames.resource_path, "res://assets/sprites/drive/car_frames.tres"
	)


func test_drive_level_1_is_a_global_4_by_3_field() -> void:
	assert_eq(_mechanic.get_mode(), "global")
	assert_eq(_mechanic.get_field()["cols"], 4)
	assert_eq(_mechanic.get_command_buttons().size(), 4)


func test_drive_reaching_the_garage_honks_and_advances() -> void:
	watch_signals(AudioManager)
	_enter_solution()
	var garage_position: Vector2 = _mechanic.to_global(
		_mechanic.cell_position(_mechanic.get_field()["garage"])
	)
	_mechanic.go()
	await wait_for_signal(_mechanic.correct, 3.0)
	await wait_seconds(0.3)
	assert_eq(_world._current_index, 1)
	assert_eq(
		_world.get_node("CelebrationParticles").global_position,
		garage_position,
		"the confetti bursts over the garage"
	)
	assert_has(_sfx_played(), "drive/honk")
	assert_has(_sfx_played(), "drive/step")
	assert_true(_mechanic.get_program().is_empty(), "a new level starts with an empty program")


func test_drive_stopping_short_shows_retry_and_sad_car() -> void:
	_world.lose_duration = 0.5
	_enter_short()
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	await wait_process_frames(2)
	assert_eq(_mechanic.get_car().animation, &"sad")
	await wait_seconds(0.7)
	assert_true(_retry.visible)


func test_drive_bump_plays_bump_sound_and_animation() -> void:
	watch_signals(AudioManager)
	_world.lose_duration = 0.5
	# Driving up from the start runs off the top edge on any field within rows moves.
	for i in int(_mechanic.get_field()["rows"]):
		_mechanic.press_command("up")
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	await wait_process_frames(2)
	assert_eq(_mechanic.get_car().animation, &"bump")
	assert_has(_sfx_played(), "drive/bump")
	await wait_seconds(0.7)
	assert_true(_retry.visible)


func test_drive_retry_keeps_program_and_returns_car() -> void:
	_enter_short()
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	await wait_seconds(0.2)
	_retry.pressed.emit()
	assert_false(_retry.visible)
	assert_eq(_mechanic.get_program().get_tiles().size(), 1)
	assert_eq(_mechanic.get_marked_tile(), 0)
	assert_eq(_mechanic.get_car().position, _mechanic.cell_position(_mechanic.get_field()["start"]))
	_mechanic.press_command("up")
	assert_eq(_mechanic.get_program().get_tiles().size(), 2, "editing works after retry")


func test_drive_level_change_mid_drive_leaves_nothing_behind() -> void:
	_mechanic.step_duration = 0.2
	watch_signals(_mechanic)
	_enter_solution()
	_mechanic.go()
	await wait_seconds(0.1)
	_hud.level_chosen.emit("drive", 7)
	await wait_seconds(1.5)
	assert_eq(_world._current_index, 7)
	assert_signal_not_emitted(_mechanic, "correct")
	assert_false(_retry.visible)
	assert_true(_mechanic.get_program().is_empty())
	assert_eq(_mechanic.get_car().position, _mechanic.cell_position(_mechanic.get_field()["start"]))


func test_drive_level_change_mid_bump_leaves_nothing_behind() -> void:
	_world.lose_duration = 1.0
	_enter_short()
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	_hud.level_chosen.emit("drive", 3)
	await wait_seconds(1.3)
	assert_false(_retry.visible)
	assert_eq(_mechanic.get_car().animation, &"idle")


func test_drive_through_the_garage_and_on_is_not_a_win() -> void:
	watch_signals(_mechanic)
	_enter_solution()
	var last: String = _mechanic.get_program().get_tiles()[-1]["command"]
	# One more step the same way drives off the garage (it's in the last column) or onward.
	_mechanic.press_command(last if last != "turn_left" and last != "turn_right" else "forward")
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 3.0)
	assert_signal_not_emitted(_mechanic, "correct")


func test_drive_sounds_exist() -> void:
	for sound: String in ["ambience", "place", "remove", "step", "bump", "honk"]:
		assert_true(
			ResourceLoader.exists("res://assets/audio/drive/%s.wav" % sound), "drive/%s" % sound
		)


func test_drive_every_level_solvable_in_order() -> void:
	watch_signals(_mechanic)
	for difficulty in LevelLoader.DIFFICULTIES:
		_hud.difficulty_chosen.emit(difficulty)
		var level_range: Vector2i = LevelLoader.get_difficulty_range(difficulty)
		for index in range(level_range.x, level_range.y + 1):
			_hud.level_chosen.emit("drive", index)
			await wait_process_frames(1)
			assert_eq(_world._current_index, index)
			_enter_solution()
			_mechanic.go()
			await wait_for_signal(_mechanic.correct, 5.0)
			assert_signal_emitted(_mechanic, "correct", "level %d" % (index + 1))

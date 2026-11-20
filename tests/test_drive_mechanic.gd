extends GutTest

const SCENE := preload("res://scenes/mechanics/drive_mechanic.tscn")
const CAR_FRAMES := preload("res://assets/sprites/drive/car_frames.tres")
const _FAST := 0.01

# 4×3, start (0, 1), garage (3, 1), a tree at (2, 1).
var _field := {
	"cols": 4,
	"rows": 3,
	"start": Vector2i(0, 1),
	"garage": Vector2i(3, 1),
	"obstacles": [{"cell": Vector2i(2, 1), "kind": "tree"}],
	"fallback": false,
}
var _mechanic: DriveMechanic


func before_each() -> void:
	_mechanic = SCENE.instantiate()
	_mechanic.car_frames = CAR_FRAMES
	_mechanic.step_duration = _FAST
	_mechanic.turn_duration = _FAST
	add_child_autofree(_mechanic)
	_mechanic.setup(_field, "global")


func _press(commands: Array) -> void:
	for command: String in commands:
		_mechanic.press_command(command)


func _win_route() -> Array:
	return ["down", "right", "right", "right", "up"]


func test_drive_mechanic_buttons_match_the_mode() -> void:
	assert_eq(_mechanic.get_command_buttons().keys(), ["up", "down", "left", "right"])
	_mechanic.setup(_field, "relative")
	assert_eq(_mechanic.get_command_buttons().keys(), ["forward", "turn_left", "turn_right"])


func test_drive_mechanic_pressing_builds_merged_tiles() -> void:
	watch_signals(_mechanic)
	_press(["right", "right", "down"])
	assert_eq(_mechanic.get_tiles().size(), 2)
	assert_eq(_mechanic.get_program().get_tiles()[0]["count"], 2)
	assert_signal_emit_count(_mechanic, "piece_placed", 3)


func test_drive_mechanic_command_buttons_press_commands() -> void:
	_mechanic.get_command_buttons()["down"].pressed.emit()
	assert_eq(_mechanic.get_program().get_tiles(), [{"command": "down", "count": 1}])


func test_drive_mechanic_tapping_a_tile_takes_a_step_off() -> void:
	watch_signals(_mechanic)
	_press(["right", "right", "down"])
	_mechanic.tap_tile(0)
	_mechanic.tap_tile(1)
	assert_eq(_mechanic.get_program().get_tiles(), [{"command": "right", "count": 1}])
	assert_signal_emit_count(_mechanic, "piece_removed", 2)


func test_drive_mechanic_full_strip_dims_other_buttons() -> void:
	for i in DriveProgram.MAX_TILES:
		_mechanic.press_command("up" if i % 2 == 0 else "down")
	var buttons: Dictionary = _mechanic.get_command_buttons()
	assert_false(buttons["down"].disabled, "the last tile is down")
	assert_true(buttons["up"].disabled)
	assert_true(buttons["left"].disabled)
	_mechanic.press_command("left")
	assert_eq(_mechanic.get_tiles().size(), DriveProgram.MAX_TILES)


func test_drive_mechanic_go_with_empty_program_does_nothing() -> void:
	watch_signals(_mechanic)
	_mechanic.go()
	assert_false(_mechanic.is_driving())
	await wait_seconds(0.1)
	assert_signal_not_emitted(_mechanic, "incorrect")


func test_drive_mechanic_win_route_emits_correct_once() -> void:
	watch_signals(_mechanic)
	_press(_win_route())
	_mechanic.go()
	assert_true(_mechanic.is_driving())
	await wait_for_signal(_mechanic.correct, 2.0)
	await wait_seconds(0.1)
	assert_signal_emit_count(_mechanic, "correct", 1)
	assert_signal_not_emitted(_mechanic, "incorrect")
	assert_signal_emit_count(_mechanic, "stepped", 5)
	assert_eq(_mechanic.get_car().position, _mechanic.cell_position(Vector2i(3, 1)))
	assert_false(_mechanic.is_driving())


func test_drive_mechanic_tiles_light_in_order() -> void:
	_mechanic.step_duration = 0.4
	_press(["down", "right"])
	_mechanic.go()
	await wait_seconds(0.2)
	assert_eq(_mechanic.get_lit_tile(), 0)
	await wait_seconds(0.4)
	assert_eq(_mechanic.get_lit_tile(), 1)
	await wait_for_signal(_mechanic.incorrect, 2.0)
	assert_eq(_mechanic.get_lit_tile(), -1)


func test_drive_mechanic_bump_reports_kind_then_incorrect_and_marks_tile() -> void:
	watch_signals(_mechanic)
	_press(["right", "right"])
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	assert_signal_emitted_with_parameters(_mechanic, "bumped", ["tree"])
	assert_signal_not_emitted(_mechanic, "stopped_short")
	assert_eq(_mechanic.get_marked_tile(), 0)
	assert_true(_mechanic.get_tiles()[0].is_marked())


func test_drive_mechanic_short_stop_reports_and_marks_last_tile() -> void:
	watch_signals(_mechanic)
	_press(["down", "right"])
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	assert_signal_emitted(_mechanic, "stopped_short")
	assert_signal_not_emitted(_mechanic, "bumped")
	assert_eq(_mechanic.get_marked_tile(), 1)


func test_drive_mechanic_through_the_garage_and_on_is_incorrect() -> void:
	watch_signals(_mechanic)
	_press(_win_route() + ["up"])
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	assert_signal_not_emitted(_mechanic, "correct")


func test_drive_mechanic_input_ignored_while_driving() -> void:
	_mechanic.step_duration = 0.2
	watch_signals(_mechanic)
	_press(["down", "right"])
	_mechanic.go()
	_mechanic.press_command("up")
	_mechanic.tap_tile(0)
	_mechanic.go()
	assert_eq(_mechanic.get_program().get_tiles().size(), 2)
	assert_true(_mechanic.get_command_buttons()["up"].disabled)
	await wait_for_signal(_mechanic.incorrect, 2.0)
	await wait_seconds(0.3)
	assert_signal_emit_count(_mechanic, "incorrect", 1)


func test_drive_mechanic_not_interactive_ignores_input() -> void:
	_mechanic.set_interactive(false)
	_mechanic.press_command("up")
	assert_true(_mechanic.get_program().is_empty())
	assert_true(_mechanic.get_command_buttons()["up"].disabled)


func test_drive_mechanic_reset_keeps_program_and_mark_and_returns_car() -> void:
	_press(["right", "right"])
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	_mechanic.reset()
	assert_eq(_mechanic.get_program().get_tiles(), [{"command": "right", "count": 2}])
	assert_eq(_mechanic.get_marked_tile(), 0)
	assert_eq(_mechanic.get_car().position, _mechanic.cell_position(Vector2i(0, 1)))
	assert_eq(_mechanic.get_car().rotation, 0.0)


func test_drive_mechanic_editing_clears_the_mark() -> void:
	_press(["right", "right"])
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	_mechanic.reset()
	_mechanic.press_command("up")
	assert_eq(_mechanic.get_marked_tile(), -1)


func test_drive_mechanic_go_clears_the_mark() -> void:
	_mechanic.step_duration = 0.2
	_press(["right", "right"])
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	_mechanic.reset()
	_mechanic.go()
	assert_eq(_mechanic.get_marked_tile(), -1)


func test_drive_mechanic_setup_clears_program_and_mark() -> void:
	_press(["right", "right"])
	_mechanic.go()
	await wait_for_signal(_mechanic.incorrect, 2.0)
	_mechanic.setup(_field, "global")
	assert_true(_mechanic.get_program().is_empty())
	assert_eq(_mechanic.get_marked_tile(), -1)


func test_drive_mechanic_setup_mid_drive_stops_the_old_drive() -> void:
	_mechanic.step_duration = 0.1
	watch_signals(_mechanic)
	_press(_win_route())
	_mechanic.go()
	await wait_seconds(0.15)
	_mechanic.setup(_field, "global")
	await wait_seconds(1.0)
	assert_signal_not_emitted(_mechanic, "correct")
	assert_signal_not_emitted(_mechanic, "incorrect")
	assert_false(_mechanic.is_driving())
	assert_eq(_mechanic.get_car().position, _mechanic.cell_position(Vector2i(0, 1)))


func test_drive_mechanic_relative_route_wins() -> void:
	_mechanic.setup(_field, "relative")
	watch_signals(_mechanic)
	_press(["turn_right", "forward", "turn_left", "forward", "forward", "forward"])
	_press(["turn_left", "forward"])
	_mechanic.go()
	await wait_for_signal(_mechanic.correct, 2.0)
	assert_signal_emitted(_mechanic, "correct")


func test_drive_mechanic_draws_field() -> void:
	assert_eq(_mechanic.get_node("Field/Grass").get_child_count(), 12)
	assert_eq(_mechanic.get_node("Field/Obstacles").get_child_count(), 1)
	assert_eq(_mechanic.get_node("Field/Garage").position, _mechanic.cell_position(Vector2i(3, 1)))

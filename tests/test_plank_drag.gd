extends GutTest

const SCENE := preload("res://scenes/mechanics/plank_drag.tscn")
const HOME := Vector2(200, 200)

var _plank: PlankDrag


func before_each() -> void:
	_plank = SCENE.instantiate()
	_plank.configure(3, 50.0)
	_plank.position = HOME
	add_child(_plank)


func after_each() -> void:
	_plank.queue_free()


func _press(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	_plank._unhandled_input(event)


func _move(to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	_plank._unhandled_input(event)


func _drag(from: Vector2, to: Vector2) -> void:
	_press(from, true)
	_move(to)
	_press(to, false)


func test_plank_drag_configure_sets_width_from_length_and_unit_px() -> void:
	assert_eq(_plank.get_width(), 150.0)
	assert_eq(_plank.length, 3)


func test_plank_drag_configure_sets_label_text() -> void:
	assert_eq(_plank.get_node("Body/LengthLabel").text, "3")


func test_plank_drag_follows_pointer_while_dragged() -> void:
	_press(HOME, true)
	_move(Vector2(260, 150))
	assert_eq(_plank.global_position, Vector2(260, 150))


func test_plank_drag_shows_shadow_only_while_dragged() -> void:
	_press(HOME, true)
	assert_true(_plank.get_node("Shadow").visible)
	_press(HOME, false)
	assert_false(_plank.get_node("Shadow").visible)


func test_plank_drag_ignores_press_outside_body() -> void:
	_press(Vector2(290, 200), true)
	assert_false(_plank.is_dragging())


func test_plank_drag_press_near_end_of_long_plank_starts_drag() -> void:
	_press(Vector2(270, 200), true)
	assert_true(_plank.is_dragging())


func test_plank_drag_dropped_signal_emitted_with_correct_position() -> void:
	watch_signals(_plank)
	_drag(Vector2(210, 205), Vector2(310, 105))
	assert_signal_emitted_with_parameters(_plank, "dropped", [Vector2(300, 100)])


func test_plank_drag_short_press_release_emits_tapped_not_dropped() -> void:
	watch_signals(_plank)
	_drag(HOME, HOME + Vector2(5, 0))
	assert_signal_emitted(_plank, "tapped")
	assert_signal_not_emitted(_plank, "dropped")
	assert_eq(_plank.position, HOME)


func test_plank_drag_placed_plank_does_not_drag() -> void:
	_plank.is_placed = true
	_press(HOME, true)
	_move(Vector2(400, 50))
	assert_false(_plank.is_dragging())
	assert_eq(_plank.position, HOME)


func test_plank_drag_placed_plank_emits_tapped() -> void:
	_plank.is_placed = true
	watch_signals(_plank)
	_drag(HOME, HOME)
	assert_signal_emitted(_plank, "tapped")


func test_plank_drag_bounce_back_returns_to_home() -> void:
	_drag(HOME, Vector2(500, 50))
	_plank.bounce_back()
	await wait_seconds(0.4)
	assert_almost_eq(_plank.position, HOME, Vector2(0.5, 0.5))


func test_plank_drag_move_to_tweens_to_target() -> void:
	_plank.move_to(Vector2(50, 60))
	await wait_seconds(0.3)
	assert_almost_eq(_plank.position, Vector2(50, 60), Vector2(0.5, 0.5))


func test_plank_drag_ignores_input_when_not_interactive() -> void:
	_plank.interactive = false
	_press(HOME, true)
	assert_false(_plank.is_dragging())


func test_plank_drag_set_not_interactive_mid_drag_cancels_drag() -> void:
	watch_signals(_plank)
	_press(HOME, true)
	_move(Vector2(300, 100))
	_plank.interactive = false
	assert_false(_plank.is_dragging())
	assert_false(_plank.get_node("Shadow").visible)
	assert_signal_not_emitted(_plank, "dropped")
	await wait_seconds(0.4)
	assert_almost_eq(_plank.position, HOME, Vector2(0.5, 0.5))

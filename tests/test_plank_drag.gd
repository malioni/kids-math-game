extends GutTest

const SCENE := preload("res://scenes/mechanics/plank_drag.tscn")

var _plank: Node2D


func before_each() -> void:
	_plank = SCENE.instantiate()
	_plank.position = Vector2(200, 200)
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


func test_plank_drag_follows_pointer_while_dragged() -> void:
	_press(Vector2(200, 200), true)
	_move(Vector2(260, 150))
	assert_eq(_plank.global_position, Vector2(260, 150))


func test_plank_drag_shows_shadow_only_while_dragged() -> void:
	_press(Vector2(200, 200), true)
	assert_true(_plank.get_node("Shadow").visible)
	_press(Vector2(200, 200), false)
	assert_false(_plank.get_node("Shadow").visible)


func test_plank_drag_ignores_press_outside_sprite() -> void:
	_press(Vector2(400, 400), true)
	assert_false(_plank.is_dragging())


func test_plank_drag_dropped_signal_emitted_with_correct_position() -> void:
	watch_signals(_plank)
	_press(Vector2(210, 205), true)
	_move(Vector2(310, 105))
	_press(Vector2(310, 105), false)
	assert_signal_emitted_with_parameters(_plank, "dropped", [Vector2(300, 100)])


func test_plank_drag_bounce_back_when_dropped_with_no_snap_target() -> void:
	_press(Vector2(200, 200), true)
	_move(Vector2(500, 50))
	_press(Vector2(500, 50), false)
	_plank.bounce_back()
	await wait_seconds(0.4)
	assert_almost_eq(_plank.position, Vector2(200, 200), Vector2(0.5, 0.5))


func test_plank_drag_ignores_input_when_not_interactive() -> void:
	_plank.interactive = false
	_press(Vector2(200, 200), true)
	assert_false(_plank.is_dragging())


func test_plank_drag_ignores_input_when_locked() -> void:
	_plank.lock()
	_press(Vector2(200, 200), true)
	assert_false(_plank.is_dragging())

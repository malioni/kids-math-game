extends GutTest

const SCENE := preload("res://scenes/mechanics/fruit_drag.tscn")
const ICON := preload("res://assets/sprites/picnic/icon_strawberry.png")
const HOME := Vector2(200, 200)

var _fruit: FruitDrag


func before_each() -> void:
	_fruit = SCENE.instantiate()
	_fruit.position = HOME
	add_child(_fruit)
	_fruit.configure("strawberry", ICON)


func after_each() -> void:
	_fruit.queue_free()


func _press(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	_fruit._unhandled_input(event)


func _move(to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	_fruit._unhandled_input(event)


func test_fruit_drag_configure_sets_item_and_icon() -> void:
	assert_eq(_fruit.item, "strawberry")
	assert_eq(_fruit.get_node("Body").texture, ICON)
	assert_eq(_fruit.get_node("Shadow").texture, ICON)


func test_fruit_drag_get_width_matches_body() -> void:
	assert_eq(_fruit.get_width(), 64.0)


func test_fruit_drag_press_inside_touch_padding_starts_drag() -> void:
	# Body is 64 wide, so its edge is 32 from the centre; the padding adds 8 more.
	_press(HOME + Vector2(38, 0), true)
	assert_true(_fruit.is_dragging())


func test_fruit_drag_press_outside_touch_padding_ignored() -> void:
	_press(HOME + Vector2(44, 0), true)
	assert_false(_fruit.is_dragging())


func test_fruit_drag_tap_emits_tapped() -> void:
	watch_signals(_fruit)
	_press(HOME, true)
	_press(HOME + Vector2(3, 0), false)
	assert_signal_emitted(_fruit, "tapped")
	assert_signal_not_emitted(_fruit, "dropped")


func test_fruit_drag_drag_and_release_emits_dropped() -> void:
	watch_signals(_fruit)
	_press(HOME, true)
	_move(Vector2(400, 100))
	_press(Vector2(400, 100), false)
	assert_signal_emitted_with_parameters(_fruit, "dropped", [Vector2(400, 100)])

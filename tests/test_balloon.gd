extends GutTest

const SCENE := preload("res://scenes/mechanics/balloon.tscn")

var balloon: Balloon


func before_each() -> void:
	balloon = SCENE.instantiate()
	add_child(balloon)
	balloon.position = Vector2(300, 300)
	balloon.configure(7, 50.0, Color.RED, Vector2(0, 200))


func after_each() -> void:
	balloon.queue_free()


func _press_at(global_point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = global_point
	balloon._unhandled_input(event)


func test_balloon_configure_sets_value_label_and_scale() -> void:
	assert_eq(balloon.value, 7)
	assert_eq(balloon.get_node("Body/ValueLabel").text, "7")
	assert_almost_eq(balloon.get_node("Body").scale.x, 50.0 / Balloon.TEXTURE_RADIUS, 0.001)


func test_balloon_press_inside_emits_tapped() -> void:
	watch_signals(balloon)
	_press_at(Vector2(310, 290))
	assert_signal_emitted(balloon, "tapped")


func test_balloon_press_outside_does_not_emit_tapped() -> void:
	watch_signals(balloon)
	_press_at(Vector2(400, 300))
	assert_signal_not_emitted(balloon, "tapped")


func test_balloon_touch_padding_counts_as_inside() -> void:
	assert_true(balloon.contains_global_point(Vector2(300 + 50 + Balloon.TOUCH_PADDING - 1, 300)))


func test_balloon_ignores_press_when_not_interactive() -> void:
	balloon.interactive = false
	watch_signals(balloon)
	_press_at(Vector2(300, 300))
	assert_signal_not_emitted(balloon, "tapped")


func test_balloon_pop_marks_popped_and_hides() -> void:
	balloon.pop()
	assert_true(balloon.is_popped)
	await wait_seconds(Balloon.POP_DURATION + 0.1)
	assert_false(balloon.visible)


func test_balloon_popped_ignores_press() -> void:
	balloon.pop()
	watch_signals(balloon)
	_press_at(Vector2(300, 300))
	assert_signal_not_emitted(balloon, "tapped")

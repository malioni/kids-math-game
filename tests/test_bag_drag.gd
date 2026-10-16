extends GutTest

const SCENE := preload("res://scenes/mechanics/bag_drag.tscn")
const ICON := preload("res://assets/sprites/market/icon_tomato.png")
const HOME := Vector2(200, 200)

var _bag: BagDrag


func before_each() -> void:
	_bag = SCENE.instantiate()
	_bag.position = HOME
	add_child(_bag)
	_bag.configure("tomato", 4, ICON)


func after_each() -> void:
	_bag.queue_free()


func _press(piece: DragPiece, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	piece._unhandled_input(event)


func _move(piece: DragPiece, to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	piece._unhandled_input(event)


func test_bag_drag_is_a_drag_piece() -> void:
	assert_true(_bag is DragPiece)


func test_bag_drag_configure_sets_item_and_size() -> void:
	assert_eq(_bag.item, "tomato")
	assert_eq(_bag.bag_size, 4)


func test_bag_drag_configure_sets_label_text() -> void:
	assert_eq(_bag.get_node("Body/SizeLabel").text, "4")


func test_bag_drag_configure_sets_icon_texture() -> void:
	assert_eq(_bag.get_node("Body/Icon").texture, ICON)


func test_bag_drag_get_width_returns_body_width() -> void:
	assert_eq(_bag.get_width(), 96.0)


func test_bag_drag_follows_pointer_while_dragged() -> void:
	_press(_bag, HOME, true)
	_move(_bag, Vector2(300, 120))
	assert_eq(_bag.global_position, Vector2(300, 120))


func test_bag_drag_drag_and_release_emits_dropped_with_position() -> void:
	watch_signals(_bag)
	_press(_bag, HOME + Vector2(10, 5), true)
	_move(_bag, Vector2(410, 105))
	_press(_bag, Vector2(410, 105), false)
	assert_signal_emitted_with_parameters(_bag, "dropped", [Vector2(400, 100)])


func test_bag_drag_short_press_emits_tapped_not_dropped() -> void:
	watch_signals(_bag)
	_press(_bag, HOME, true)
	_press(_bag, HOME + Vector2(4, 0), false)
	assert_signal_emitted(_bag, "tapped")
	assert_signal_not_emitted(_bag, "dropped")


func test_bag_drag_placed_bag_does_not_drag() -> void:
	_bag.is_placed = true
	_press(_bag, HOME, true)
	_move(_bag, Vector2(400, 50))
	assert_false(_bag.is_dragging())
	assert_eq(_bag.position, HOME)


func test_bag_drag_press_within_touch_padding_starts_drag() -> void:
	# Body spans x 152..248; the padding extends the grab area 6 px past each side.
	_press(_bag, Vector2(252, 200), true)
	assert_true(_bag.is_dragging())


func test_drag_piece_default_touch_padding_is_zero() -> void:
	var piece := DragPiece.new()
	var body := Control.new()
	body.name = "Body"
	body.position = Vector2(-20, -20)
	body.size = Vector2(40, 40)
	var shadow := Node2D.new()
	shadow.name = "Shadow"
	piece.add_child(body)
	piece.add_child(shadow)
	piece.position = HOME
	add_child_autofree(piece)
	_press(piece, HOME + Vector2(22, 0), true)
	assert_false(piece.is_dragging())
	_press(piece, HOME + Vector2(18, 0), true)
	assert_true(piece.is_dragging())

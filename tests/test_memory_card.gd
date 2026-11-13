extends GutTest

const SCENE := preload("res://scenes/mechanics/memory_card.tscn")
const FOX := preload("res://assets/sprites/memory/animal_fox.png")

var card: MemoryCard


func before_each() -> void:
	card = SCENE.instantiate()
	add_child(card)
	card.position = Vector2(300, 300)
	card.setup("fox", FOX, 120.0)


func after_each() -> void:
	card.queue_free()


func _press_at(global_point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = global_point
	card._unhandled_input(event)


func test_memory_card_setup_starts_face_down() -> void:
	assert_eq(card.get_animal(), "fox")
	assert_false(card.is_face_up())
	assert_true(card.get_node("Body/Back").visible)
	assert_false(card.get_node("Body/Front").visible)
	assert_eq(card.get_node("Body/Front/Face").texture, FOX)


func test_memory_card_show_face_makes_face_up() -> void:
	card.show_face()
	assert_true(card.is_face_up())
	await wait_seconds(MemoryCard.TURN_DURATION + 0.1)
	assert_true(card.get_node("Body/Front").visible)
	assert_false(card.get_node("Body/Back").visible)
	assert_almost_eq(card.get_node("Body").scale.x, 120.0 / MemoryCard.TEXTURE_SIZE, 0.001)


func test_memory_card_show_back_makes_face_down() -> void:
	card.show_face(false)
	card.show_back()
	assert_false(card.is_face_up())
	await wait_seconds(MemoryCard.TURN_DURATION + 0.1)
	assert_true(card.get_node("Body/Back").visible)
	assert_false(card.get_node("Body/Front").visible)


func test_memory_card_tap_emits_tapped() -> void:
	watch_signals(card)
	_press_at(Vector2(350, 350))
	assert_signal_emitted(card, "tapped")


func test_memory_card_press_outside_does_not_emit_tapped() -> void:
	watch_signals(card)
	_press_at(Vector2(370, 300))
	assert_signal_not_emitted(card, "tapped")


func test_memory_card_not_tappable_ignores_tap() -> void:
	card.interactive = false
	watch_signals(card)
	_press_at(Vector2(300, 300))
	assert_signal_not_emitted(card, "tapped")


func test_memory_card_mark_matched_ignores_taps() -> void:
	card.mark_matched()
	assert_true(card.is_matched())
	watch_signals(card)
	_press_at(Vector2(300, 300))
	assert_signal_not_emitted(card, "tapped")
	await wait_seconds(MemoryCard.MATCH_DURATION + 0.1)
	assert_false(card.visible)

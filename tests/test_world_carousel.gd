extends GutTest

const SCENE := preload("res://scenes/ui/world_carousel.tscn")
const _ICON := preload("res://assets/sprites/ui/icon_world_forest.png")
const _SNAP := 0.3

var carousel: WorldCarousel


func before_each() -> void:
	carousel = SCENE.instantiate()
	add_child_autofree(carousel)
	carousel.size = Vector2(1000, 320)
	carousel.set_items(_items(["a", "b", "c", "d"]))


func _items(ids: Array) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for id: String in ids:
		items.append({"id": id, "icon": _ICON})
	return items


func _ids() -> Array:
	return carousel.get_cards().map(func(c: Panel) -> String: return c.name.trim_prefix("Card_"))


# Where a card's centre is drawn, in the carousel's own coordinates.
func _card_centre(id: String) -> Vector2:
	var card: Panel = carousel.get_card(id)
	return card.get_parent().position + card.position + card.pivot_offset


func _button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	carousel._gui_input(event)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	carousel._gui_input(event)


func _tap(at: Vector2) -> void:
	_button(at, true)
	_button(at, false)


func _swipe(from: Vector2, by: float) -> void:
	_button(from, true)
	_move(from + Vector2(by / 2.0, 0))
	_move(from + Vector2(by, 0))
	_button(from + Vector2(by, 0), false)


func test_world_carousel_set_items_creates_a_card_per_item_in_order() -> void:
	assert_eq(_ids(), ["a", "b", "c", "d"])
	carousel.set_items(_items(["x", "y"]))
	await wait_process_frames(1)
	assert_eq(_ids(), ["x", "y"])


func test_world_carousel_starts_centred_on_first_item() -> void:
	assert_eq(carousel.get_centred_id(), "a")
	assert_almost_eq(_card_centre("a").x, carousel.size.x / 2.0, 0.5)


func test_world_carousel_scroll_to_centres_item_and_emits_centred_changed() -> void:
	watch_signals(carousel)
	carousel.scroll_to("c")
	assert_eq(carousel.get_centred_id(), "c")
	assert_signal_emitted_with_parameters(carousel, "centred_changed", ["c"])
	await wait_seconds(_SNAP)
	assert_almost_eq(_card_centre("c").x, carousel.size.x / 2.0, 0.5)


func test_world_carousel_scroll_to_unknown_id_does_nothing() -> void:
	watch_signals(carousel)
	carousel.scroll_to("nope")
	assert_eq(carousel.get_centred_id(), "a")
	assert_signal_not_emitted(carousel, "centred_changed")


func test_world_carousel_scroll_to_without_animation_centres_immediately() -> void:
	carousel.scroll_to("d", false)
	assert_almost_eq(_card_centre("d").x, carousel.size.x / 2.0, 0.5)


func test_world_carousel_get_card_unknown_id_returns_null() -> void:
	assert_null(carousel.get_card("nope"))
	assert_eq(carousel.get_card("b").name, "Card_b")


func test_world_carousel_next_and_previous_move_one_card() -> void:
	carousel.next()
	assert_eq(carousel.get_centred_id(), "b")
	carousel.next()
	assert_eq(carousel.get_centred_id(), "c")
	carousel.previous()
	assert_eq(carousel.get_centred_id(), "b")


func test_world_carousel_next_at_last_card_stays_on_last() -> void:
	carousel.scroll_to("d", false)
	watch_signals(carousel)
	carousel.next()
	assert_eq(carousel.get_centred_id(), "d")
	assert_signal_not_emitted(carousel, "centred_changed")


func test_world_carousel_arrows_hidden_at_ends() -> void:
	var prev: TextureButton = carousel.get_node("PrevButton")
	var next: TextureButton = carousel.get_node("NextButton")
	assert_false(prev.visible)
	assert_true(next.visible)
	carousel.scroll_to("b", false)
	assert_true(prev.visible)
	assert_true(next.visible)
	carousel.scroll_to("d", false)
	assert_true(prev.visible)
	assert_false(next.visible)


func test_world_carousel_arrows_hidden_when_all_cards_fit() -> void:
	carousel.set_items(_items(["x", "y"]))
	assert_false(carousel.get_node("PrevButton").visible)
	assert_false(carousel.get_node("NextButton").visible)


func test_world_carousel_swipe_past_half_pitch_centres_next_card() -> void:
	_swipe(Vector2(900, 160), -carousel.pitch * 0.6)
	assert_eq(carousel.get_centred_id(), "b")


func test_world_carousel_short_swipe_snaps_back_to_same_card() -> void:
	watch_signals(carousel)
	_swipe(Vector2(900, 160), -carousel.pitch * 0.3)
	assert_eq(carousel.get_centred_id(), "a")
	assert_signal_not_emitted(carousel, "centred_changed")
	await wait_seconds(_SNAP)
	assert_almost_eq(_card_centre("a").x, carousel.size.x / 2.0, 0.5)


func test_world_carousel_long_swipe_moves_several_cards_clamped_to_ends() -> void:
	_swipe(Vector2(900, 160), -carousel.pitch * 2.0)
	assert_eq(carousel.get_centred_id(), "c")
	_swipe(Vector2(100, 160), carousel.pitch * 9.0)
	assert_eq(carousel.get_centred_id(), "a")


func test_world_carousel_swipe_starting_on_a_card_moves_the_track() -> void:
	var start: Vector2 = _card_centre("a")
	_button(start, true)
	_move(start + Vector2(-100, 0))
	assert_almost_eq(_card_centre("a").x, start.x - 100.0, 0.5)
	_button(start + Vector2(-100, 0), false)


func test_world_carousel_tap_on_centred_card_emits_was_centred_true() -> void:
	watch_signals(carousel)
	_tap(_card_centre("a"))
	assert_signal_emitted_with_parameters(carousel, "card_pressed", ["a", true])


func test_world_carousel_tap_on_neighbour_emits_was_centred_false_and_centres_it() -> void:
	watch_signals(carousel)
	_tap(_card_centre("b"))
	assert_signal_emitted_with_parameters(carousel, "card_pressed", ["b", false])
	assert_eq(carousel.get_centred_id(), "b")


func test_world_carousel_swipe_does_not_emit_card_pressed() -> void:
	watch_signals(carousel)
	_swipe(_card_centre("a"), -carousel.pitch * 0.6)
	assert_signal_not_emitted(carousel, "card_pressed")


func test_world_carousel_card_position_spaces_cards_by_pitch() -> void:
	assert_eq(carousel._card_position(0), Vector2.ZERO)
	assert_eq(carousel._card_position(3), Vector2(3 * carousel.pitch, 0))
	var gap: float = carousel.get_card("b").position.x - carousel.get_card("a").position.x
	assert_almost_eq(gap, carousel.pitch, 0.5)


func test_world_carousel_highlighted_card_uses_current_colour() -> void:
	carousel.set_highlighted("c")
	var current: StyleBoxTexture = carousel.get_card("c").get_theme_stylebox("panel")
	var plain: StyleBoxTexture = carousel.get_card("a").get_theme_stylebox("panel")
	assert_eq(current.modulate_color, Color(1.0, 0.72, 0.3))
	assert_ne(plain.modulate_color, current.modulate_color)


func test_world_carousel_cards_and_arrows_meet_minimum_tap_size() -> void:
	for card: Panel in carousel.get_cards():
		assert_true(card.size.x >= 100 and card.size.y >= 100, "%s is too small" % card.name)
	for arrow_name in ["PrevButton", "NextButton"]:
		var arrow: Control = carousel.get_node(arrow_name)
		assert_true(arrow.size.x >= 100 and arrow.size.y >= 100, "%s is too small" % arrow_name)


func test_world_carousel_with_twelve_items_reaches_every_card() -> void:
	var ids: Array = range(12).map(func(i: int) -> String: return "w%d" % i)
	carousel.set_items(_items(ids))
	for i in range(1, 12):
		carousel.next()
		assert_eq(carousel.get_centred_id(), ids[i])
	carousel.scroll_to("w11", false)
	assert_almost_eq(_card_centre("w11").x, carousel.size.x / 2.0, 0.5)

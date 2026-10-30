extends GutTest

const SCENE := preload("res://scenes/mechanics/sharing_mechanic.tscn")
const ICONS := {
	"strawberry": preload("res://assets/sprites/picnic/icon_strawberry.png"),
	"apple": preload("res://assets/sprites/picnic/icon_apple.png"),
	"banana": preload("res://assets/sprites/picnic/icon_banana.png"),
}
const ORIGIN := Vector2(640, 360)
# A point over the fox's plate, in global space.
const ON_PLATE := ORIGIN + Vector2(-70, 100)
const DEAL_STEP := 0.01
const SETTLE := 0.3

var _mechanic: SharingMechanic


func before_each() -> void:
	_mechanic = SCENE.instantiate()
	_mechanic.item_icons = ICONS
	_mechanic.guest_frames = _frames()
	_mechanic.deal_step = DEAL_STEP
	_mechanic.position = ORIGIN
	add_child(_mechanic)


func after_each() -> void:
	_mechanic.queue_free()


func _frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	for animation in ["idle", "celebrate", "sad"]:
		frames.add_animation(animation)
		# play() ignores an animation with no frames.
		frames.add_frame(animation, ICONS["strawberry"])
	return frames


func _orders(spec: Array) -> Array[Dictionary]:
	var orders: Array[Dictionary] = []
	for entry: Array in spec:
		orders.append({"item": entry[0], "total": entry[1]})
	return orders


## 3 plates, 12 strawberries: the fair share is 4.
func _one_fruit() -> void:
	_mechanic.setup(3, _orders([["strawberry", 12]]))


## 2 plates: fair shares are 3 strawberries, 5 apples, 8 bananas.
func _three_fruits() -> void:
	_mechanic.setup(2, _orders([["strawberry", 6], ["apple", 10], ["banana", 16]]))


func _place(item: String, times: int = 1) -> void:
	for i in times:
		_mechanic.get_ready_piece(item).dropped.emit(ON_PLATE)


func _deal() -> void:
	_mechanic.confirm()
	await wait_seconds(SETTLE)


func _label_texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for child in node.get_children():
		if child is Label:
			texts.append(child.text)
		texts.append_array(_label_texts(child))
	return texts


func test_sharing_mechanic_setup_spawns_basket_and_ready_piece_per_order() -> void:
	_three_fruits()
	for item in ["strawberry", "apple", "banana"]:
		var piece: FruitDrag = _mechanic.get_ready_piece(item)
		assert_not_null(piece, item)
		assert_eq(piece.item, item)
	var baskets: Array = _mechanic.get_node("Baskets").get_children().filter(
		func(n: Node) -> bool: return n is Sprite2D
	)
	assert_eq(baskets.size(), 3)


func test_sharing_mechanic_setup_spawns_one_guest_per_extra_plate() -> void:
	_mechanic.setup(4, _orders([["strawberry", 8]]))
	assert_eq(_mechanic.get_node("Guests").get_child_count(), 3)
	assert_eq(_mechanic.get_guest(2).animation, &"idle")


func test_sharing_mechanic_basket_labels_show_totals() -> void:
	_three_fruits()
	assert_eq(_label_texts(_mechanic.get_node("Baskets")), ["6", "10", "16"])
	assert_eq(_mechanic.get_basket_count("apple"), 10)


func test_sharing_mechanic_get_orders_and_plate_count_return_setup_values() -> void:
	var orders: Array[Dictionary] = _orders([["strawberry", 12]])
	_mechanic.setup(3, orders)
	assert_eq(_mechanic.get_orders(), orders)
	assert_eq(_mechanic.get_plate_count(), 3)


func test_sharing_mechanic_drop_on_plate_places_piece_in_its_row() -> void:
	_three_fruits()
	_place("apple")
	await wait_seconds(SETTLE)
	var pieces: Array[FruitDrag] = _mechanic.get_placed_pieces("apple")
	assert_eq(pieces.size(), 1)
	assert_true(pieces[0].is_placed)
	assert_almost_eq(pieces[0].position.y, _mechanic.row_y[1], 0.5)


func test_sharing_mechanic_drop_on_plate_spawns_new_ready_piece() -> void:
	_one_fruit()
	var first: FruitDrag = _mechanic.get_ready_piece("strawberry")
	_place("strawberry")
	var next: FruitDrag = _mechanic.get_ready_piece("strawberry")
	assert_not_null(next)
	assert_ne(next, first)
	assert_false(next.is_placed)


func test_sharing_mechanic_drop_off_plate_bounces_back_and_places_nothing() -> void:
	_one_fruit()
	var piece: FruitDrag = _mechanic.get_ready_piece("strawberry")
	piece.dropped.emit(ORIGIN + Vector2(0, -300))
	assert_eq(_mechanic.get_placed_count("strawberry"), 0)
	assert_eq(_mechanic.get_ready_piece("strawberry"), piece)


func test_sharing_mechanic_tap_ready_piece_places_it() -> void:
	_one_fruit()
	var piece: FruitDrag = _mechanic.get_ready_piece("strawberry")
	piece.tapped.emit()
	assert_eq(_mechanic.get_placed_pieces("strawberry"), [piece])
	assert_ne(_mechanic.get_ready_piece("strawberry"), piece)


func test_sharing_mechanic_tap_placed_piece_removes_it() -> void:
	_one_fruit()
	_place("strawberry", 2)
	_mechanic.get_placed_pieces("strawberry")[0].tapped.emit()
	assert_eq(_mechanic.get_placed_count("strawberry"), 1)
	await wait_seconds(SETTLE)
	assert_eq(_mechanic.get_node("Leaving").get_child_count(), 0)


func test_sharing_mechanic_row_never_takes_more_than_basket_total() -> void:
	_mechanic.setup(2, _orders([["strawberry", 4]]))
	_place("strawberry", 6)
	assert_eq(_mechanic.get_placed_count("strawberry"), 4)


func test_sharing_mechanic_row_full_bounces_extra_piece() -> void:
	_mechanic.setup(2, _orders([["strawberry", 40]]))
	_place("strawberry", _mechanic.max_pieces_per_row + 1)
	assert_eq(_mechanic.get_placed_count("strawberry"), _mechanic.max_pieces_per_row)


func test_sharing_mechanic_crowded_row_stays_within_row_bounds() -> void:
	_mechanic.setup(2, _orders([["strawberry", 40]]))
	_place("strawberry", _mechanic.max_pieces_per_row)
	await wait_seconds(SETTLE)
	for piece in _mechanic.get_placed_pieces("strawberry"):
		var half: float = piece.get_width() / 2.0
		assert_gte(piece.position.x - half, _mechanic.row_left - 0.5)
		assert_lte(piece.position.x + half, _mechanic.row_right + 0.5)


func test_sharing_mechanic_placing_does_not_change_basket_label() -> void:
	_one_fruit()
	_place("strawberry", 3)
	assert_eq(_mechanic.get_basket_count("strawberry"), 12)
	assert_eq(_label_texts(_mechanic.get_node("Baskets")), ["12"])


func test_sharing_mechanic_confirm_exact_share_deals_everyone_and_emits_correct() -> void:
	_one_fruit()
	_place("strawberry", 4)
	watch_signals(_mechanic)
	await _deal()
	assert_signal_emitted(_mechanic, "correct")
	assert_signal_not_emitted(_mechanic, "incorrect")
	assert_eq(_mechanic.get_dealt_count(0, "strawberry"), 4)
	assert_eq(_mechanic.get_dealt_count(1, "strawberry"), 4)
	assert_eq(_mechanic.get_basket_count("strawberry"), 0)
	assert_eq(_mechanic.get_guest(0).get_node("../Fruit").get_child_count(), 4)


func test_sharing_mechanic_confirm_exact_share_guests_celebrate() -> void:
	_one_fruit()
	_place("strawberry", 4)
	await _deal()
	for g in 2:
		assert_eq(_mechanic.get_guest(g).animation, &"celebrate")


func test_sharing_mechanic_confirm_too_many_last_guest_short_and_sad_emits_incorrect() -> void:
	_one_fruit()
	_place("strawberry", 5)
	watch_signals(_mechanic)
	await _deal()
	assert_signal_emitted(_mechanic, "incorrect")
	assert_eq(_mechanic.get_dealt_count(0, "strawberry"), 5)
	assert_eq(_mechanic.get_dealt_count(1, "strawberry"), 2)
	assert_eq(_mechanic.get_basket_count("strawberry"), 0)
	assert_eq(_mechanic.get_guest(0).animation, &"idle")
	assert_eq(_mechanic.get_guest(1).animation, &"sad")


func test_sharing_mechanic_confirm_too_few_leaves_fruit_in_basket_emits_incorrect() -> void:
	_one_fruit()
	_place("strawberry", 3)
	watch_signals(_mechanic)
	await _deal()
	assert_signal_emitted(_mechanic, "incorrect")
	assert_eq(_mechanic.get_basket_count("strawberry"), 3)
	assert_eq(_label_texts(_mechanic.get_node("Baskets")), ["3"])
	assert_eq(_mechanic.get_guest(1).animation, &"idle")


func test_sharing_mechanic_confirm_one_fruit_wrong_of_three_emits_incorrect() -> void:
	_three_fruits()
	_place("strawberry", 3)
	_place("apple", 4)
	_place("banana", 8)
	watch_signals(_mechanic)
	await _deal()
	assert_signal_emitted(_mechanic, "incorrect")
	assert_signal_not_emitted(_mechanic, "correct")


func test_sharing_mechanic_confirm_all_fruits_exact_emits_correct() -> void:
	_three_fruits()
	_place("strawberry", 3)
	_place("apple", 5)
	_place("banana", 8)
	watch_signals(_mechanic)
	await _deal()
	assert_signal_emitted(_mechanic, "correct")


func test_sharing_mechanic_confirm_empty_plate_emits_incorrect() -> void:
	_one_fruit()
	watch_signals(_mechanic)
	await _deal()
	assert_signal_emitted(_mechanic, "incorrect")
	assert_eq(_mechanic.get_basket_count("strawberry"), 12)


func test_sharing_mechanic_confirm_disables_input_while_dealing() -> void:
	_one_fruit()
	_place("strawberry", 4)
	_mechanic.confirm()
	assert_true(_mechanic.is_dealing())
	assert_true(_mechanic.get_node("GoButton").disabled)
	assert_false(_mechanic.get_ready_piece("strawberry").interactive)
	await wait_seconds(SETTLE)
	assert_false(_mechanic.is_dealing())


func test_sharing_mechanic_confirm_twice_during_deal_emits_once() -> void:
	_one_fruit()
	_place("strawberry", 4)
	watch_signals(_mechanic)
	_mechanic.confirm()
	_mechanic.confirm()
	await wait_seconds(SETTLE)
	assert_signal_emit_count(_mechanic, "correct", 1)


func test_sharing_mechanic_reset_during_deal_emits_nothing() -> void:
	_one_fruit()
	_place("strawberry", 4)
	watch_signals(_mechanic)
	_mechanic.confirm()
	_mechanic.reset()
	await wait_seconds(SETTLE)
	assert_signal_not_emitted(_mechanic, "correct")
	assert_signal_not_emitted(_mechanic, "incorrect")
	assert_false(_mechanic.is_dealing())
	assert_eq(_mechanic.get_basket_count("strawberry"), 12)


func test_sharing_mechanic_reset_clears_plates_restores_totals_keeps_orders() -> void:
	_three_fruits()
	_place("strawberry", 2)
	_place("banana", 1)
	await _deal()
	var orders: Array[Dictionary] = _mechanic.get_orders().duplicate(true)
	_mechanic.reset()
	assert_eq(_mechanic.get_placed_count("strawberry"), 0)
	assert_eq(_mechanic.get_placed_count("banana"), 0)
	assert_eq(_mechanic.get_orders(), orders)
	assert_eq(_mechanic.get_basket_count("strawberry"), 6)
	assert_eq(_mechanic.get_dealt_count(0, "strawberry"), 0)
	assert_eq(_mechanic.get_guest(0).animation, &"idle")
	assert_not_null(_mechanic.get_ready_piece("banana"))


func test_sharing_mechanic_set_interactive_false_disables_go_and_pieces() -> void:
	_one_fruit()
	_place("strawberry")
	_mechanic.set_interactive(false)
	assert_true(_mechanic.get_node("GoButton").disabled)
	assert_false(_mechanic.get_ready_piece("strawberry").interactive)
	assert_false(_mechanic.get_placed_pieces("strawberry")[0].interactive)
	_mechanic.set_interactive(true)
	assert_false(_mechanic.get_node("GoButton").disabled)
	assert_true(_mechanic.get_ready_piece("strawberry").interactive)


func test_sharing_mechanic_has_no_running_total_label() -> void:
	_one_fruit()
	_place("strawberry", 5)
	await wait_seconds(SETTLE)
	assert_false(_label_texts(_mechanic).has("5"), "the fox's 5 must not be shown")


func test_sharing_mechanic_go_button_confirms() -> void:
	_one_fruit()
	_place("strawberry", 4)
	watch_signals(_mechanic)
	_mechanic.get_node("GoButton").pressed.emit()
	await wait_seconds(SETTLE)
	assert_signal_emitted(_mechanic, "correct")

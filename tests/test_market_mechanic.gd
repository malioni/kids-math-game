extends GutTest

const SCENE := preload("res://scenes/mechanics/market_mechanic.tscn")
const ICONS := {
	"tomato": preload("res://assets/sprites/market/icon_tomato.png"),
	"potato": preload("res://assets/sprites/market/icon_potato.png"),
	"carrot": preload("res://assets/sprites/market/icon_carrot.png"),
}
const ORIGIN := Vector2(640, 400)
const SETTLE := 0.3

var _mechanic: MarketMechanic


func before_each() -> void:
	_mechanic = SCENE.instantiate()
	_mechanic.item_icons = ICONS
	_mechanic.position = ORIGIN
	add_child(_mechanic)


func after_each() -> void:
	_mechanic.queue_free()


func _orders(spec: Array) -> Array[Dictionary]:
	var orders: Array[Dictionary] = []
	for entry: Array in spec:
		orders.append({"item": entry[0], "bag_size": entry[1], "quantity": entry[2]})
	return orders


func _one_tomato_order() -> void:
	_mechanic.setup(_orders([["tomato", 4, 12]]))


func _three_item_order() -> void:
	_mechanic.setup(_orders([["tomato", 2, 6], ["potato", 5, 10], ["carrot", 8, 32]]))


func _place(item: String, times: int = 1) -> void:
	for i in times:
		_mechanic.get_ready_bag(item).dropped.emit(ORIGIN)


func _label_texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for child in node.get_children():
		if child is Label:
			texts.append(child.text)
		texts.append_array(_label_texts(child))
	return texts


func test_market_mechanic_setup_spawns_one_crate_and_ready_bag_per_order() -> void:
	_three_item_order()
	assert_eq(_mechanic.get_node("Crates").get_child_count(), 3)
	for item in ["tomato", "potato", "carrot"]:
		var bag: BagDrag = _mechanic.get_ready_bag(item)
		assert_not_null(bag, item)
		assert_eq(bag.item, item)
	assert_eq(_mechanic.get_ready_bag("potato").bag_size, 5)


func test_market_mechanic_order_slip_shows_quantities_not_totals() -> void:
	_three_item_order()
	assert_eq(_label_texts(_mechanic.get_node("OrderSlip/Lines")), ["6", "10", "32"])


func test_market_mechanic_get_orders_returns_setup_orders() -> void:
	var orders: Array[Dictionary] = _orders([["tomato", 4, 12]])
	_mechanic.setup(orders)
	assert_eq(_mechanic.get_orders(), orders)


func test_market_mechanic_drop_on_table_places_bag_in_its_row() -> void:
	_three_item_order()
	_place("potato")
	await wait_seconds(SETTLE)
	var bags: Array[BagDrag] = _mechanic.get_placed_bags("potato")
	assert_eq(bags.size(), 1)
	assert_true(bags[0].is_placed)
	assert_almost_eq(bags[0].position.y, _mechanic.row_y[1], 0.5)


func test_market_mechanic_drop_on_table_spawns_new_ready_bag() -> void:
	_one_tomato_order()
	var first: BagDrag = _mechanic.get_ready_bag("tomato")
	_place("tomato")
	var next: BagDrag = _mechanic.get_ready_bag("tomato")
	assert_not_null(next)
	assert_ne(next, first)
	assert_false(next.is_placed)


func test_market_mechanic_drop_off_table_bounces_back_and_places_nothing() -> void:
	_one_tomato_order()
	var bag: BagDrag = _mechanic.get_ready_bag("tomato")
	bag.dropped.emit(ORIGIN + Vector2(0, -300))
	assert_eq(_mechanic.get_placed_count("tomato"), 0)
	assert_eq(_mechanic.get_ready_bag("tomato"), bag)


func test_market_mechanic_drop_emits_bags_changed_with_count() -> void:
	_one_tomato_order()
	watch_signals(_mechanic)
	_place("tomato", 2)
	assert_signal_emitted_with_parameters(_mechanic, "bags_changed", ["tomato", 2])


func test_market_mechanic_tap_placed_bag_removes_it() -> void:
	_one_tomato_order()
	_place("tomato", 2)
	watch_signals(_mechanic)
	_mechanic.get_placed_bags("tomato")[0].tapped.emit()
	assert_eq(_mechanic.get_placed_count("tomato"), 1)
	assert_signal_emitted_with_parameters(_mechanic, "bags_changed", ["tomato", 1])
	await wait_seconds(SETTLE)
	assert_eq(_mechanic.get_node("Leaving").get_child_count(), 0)


func test_market_mechanic_tap_ready_bag_does_nothing() -> void:
	_one_tomato_order()
	var bag: BagDrag = _mechanic.get_ready_bag("tomato")
	bag.tapped.emit()
	assert_eq(_mechanic.get_ready_bag("tomato"), bag)
	assert_eq(_mechanic.get_placed_count("tomato"), 0)


func test_market_mechanic_row_full_bounces_extra_bag() -> void:
	_one_tomato_order()
	_place("tomato", _mechanic.max_bags_per_row + 1)
	assert_eq(_mechanic.get_placed_count("tomato"), _mechanic.max_bags_per_row)


func test_market_mechanic_crowded_row_stays_within_row_bounds() -> void:
	_one_tomato_order()
	_place("tomato", _mechanic.max_bags_per_row)
	await wait_seconds(SETTLE)
	for bag in _mechanic.get_placed_bags("tomato"):
		var half: float = bag.get_width() / 2.0
		assert_gte(bag.position.x - half, _mechanic.row_left - 0.5)
		assert_lte(bag.position.x + half, _mechanic.row_right + 0.5)


func test_market_mechanic_get_placed_total_is_count_times_bag_size() -> void:
	_one_tomato_order()
	_place("tomato", 3)
	assert_eq(_mechanic.get_placed_total("tomato"), 12)


func test_market_mechanic_confirm_exact_single_item_emits_correct() -> void:
	_one_tomato_order()
	_place("tomato", 3)
	watch_signals(_mechanic)
	_mechanic.confirm()
	assert_signal_emitted(_mechanic, "correct")
	assert_signal_not_emitted(_mechanic, "incorrect")


func test_market_mechanic_confirm_too_few_emits_incorrect() -> void:
	_one_tomato_order()
	_place("tomato", 2)
	watch_signals(_mechanic)
	_mechanic.confirm()
	assert_signal_emitted(_mechanic, "incorrect")
	assert_signal_not_emitted(_mechanic, "correct")


func test_market_mechanic_confirm_too_many_emits_incorrect() -> void:
	_one_tomato_order()
	_place("tomato", 4)
	watch_signals(_mechanic)
	_mechanic.confirm()
	assert_signal_emitted(_mechanic, "incorrect")


func test_market_mechanic_confirm_one_item_wrong_of_three_emits_incorrect() -> void:
	_three_item_order()
	_place("tomato", 3)
	_place("potato", 2)
	_place("carrot", 3)
	watch_signals(_mechanic)
	_mechanic.confirm()
	assert_signal_emitted(_mechanic, "incorrect")


func test_market_mechanic_confirm_all_items_exact_emits_correct() -> void:
	_three_item_order()
	_place("tomato", 3)
	_place("potato", 2)
	_place("carrot", 4)
	watch_signals(_mechanic)
	_mechanic.confirm()
	assert_signal_emitted(_mechanic, "correct")


func test_market_mechanic_confirm_empty_table_emits_incorrect() -> void:
	_one_tomato_order()
	watch_signals(_mechanic)
	_mechanic.confirm()
	assert_signal_emitted(_mechanic, "incorrect")


func test_market_mechanic_go_button_confirms() -> void:
	_one_tomato_order()
	_place("tomato", 3)
	watch_signals(_mechanic)
	_mechanic.get_node("GoButton").pressed.emit()
	assert_signal_emitted(_mechanic, "correct")


func test_market_mechanic_reset_clears_table_keeps_orders() -> void:
	_three_item_order()
	_place("tomato", 2)
	_place("carrot", 1)
	var orders: Array[Dictionary] = _mechanic.get_orders().duplicate(true)
	watch_signals(_mechanic)
	_mechanic.reset()
	assert_eq(_mechanic.get_placed_count("tomato"), 0)
	assert_eq(_mechanic.get_placed_count("carrot"), 0)
	assert_eq(_mechanic.get_orders(), orders)
	assert_not_null(_mechanic.get_ready_bag("carrot"))
	assert_signal_emitted_with_parameters(_mechanic, "bags_changed", ["carrot", 0])


func test_market_mechanic_set_interactive_false_disables_go_and_bags() -> void:
	_one_tomato_order()
	_place("tomato")
	_mechanic.set_interactive(false)
	assert_true(_mechanic.get_node("GoButton").disabled)
	assert_false(_mechanic.get_ready_bag("tomato").interactive)
	assert_false(_mechanic.get_placed_bags("tomato")[0].interactive)
	_mechanic.set_interactive(true)
	assert_false(_mechanic.get_node("GoButton").disabled)
	assert_true(_mechanic.get_ready_bag("tomato").interactive)


func test_market_mechanic_has_no_running_total_label() -> void:
	_mechanic.setup(_orders([["tomato", 3, 21]]))
	_place("tomato", 5)
	await wait_seconds(SETTLE)
	assert_false(_label_texts(_mechanic).has("15"), "placed total 15 must not be shown")

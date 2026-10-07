extends GutTest

var mechanic: Node2D


func before_each() -> void:
	mechanic = preload("res://scenes/mechanics/placement_mechanic.tscn").instantiate()
	mechanic.target_count = 3
	add_child(mechanic)


func after_each() -> void:
	mechanic.queue_free()


func test_place_increments_placed_count() -> void:
	mechanic.place()
	assert_eq(mechanic.get_placed_count(), 1)


func test_place_multiple_accumulates_count() -> void:
	mechanic.place()
	mechanic.place()
	assert_eq(mechanic.get_placed_count(), 2)


func test_remove_decrements_placed_count() -> void:
	mechanic.place()
	mechanic.remove()
	assert_eq(mechanic.get_placed_count(), 0)


func test_remove_at_zero_does_not_go_negative() -> void:
	mechanic.remove()
	assert_eq(mechanic.get_placed_count(), 0)


func test_place_emits_count_changed() -> void:
	watch_signals(mechanic)
	mechanic.place()
	assert_signal_emitted_with_parameters(mechanic, "count_changed", [1])


func test_remove_emits_count_changed() -> void:
	mechanic.place()
	watch_signals(mechanic)
	mechanic.remove()
	assert_signal_emitted_with_parameters(mechanic, "count_changed", [0])


func test_place_exact_target_does_not_emit_correct_before_confirm() -> void:
	watch_signals(mechanic)
	mechanic.place()
	mechanic.place()
	mechanic.place()
	assert_signal_not_emitted(mechanic, "correct")


func test_confirm_exact_target_emits_correct() -> void:
	mechanic.place()
	mechanic.place()
	mechanic.place()
	watch_signals(mechanic)
	mechanic.confirm()
	assert_signal_emitted(mechanic, "correct")


func test_confirm_under_target_emits_incorrect() -> void:
	mechanic.place()
	watch_signals(mechanic)
	mechanic.confirm()
	assert_signal_emitted(mechanic, "incorrect")


func test_confirm_over_target_emits_incorrect() -> void:
	mechanic.place()
	mechanic.place()
	mechanic.place()
	mechanic.place()
	watch_signals(mechanic)
	mechanic.confirm()
	assert_signal_emitted(mechanic, "incorrect")


func test_confirm_exact_target_does_not_emit_incorrect() -> void:
	mechanic.place()
	mechanic.place()
	mechanic.place()
	watch_signals(mechanic)
	mechanic.confirm()
	assert_signal_not_emitted(mechanic, "incorrect")


func test_reset_sets_count_to_zero() -> void:
	mechanic.place()
	mechanic.place()
	mechanic.reset()
	assert_eq(mechanic.get_placed_count(), 0)


func test_reset_emits_count_changed_with_zero() -> void:
	mechanic.place()
	watch_signals(mechanic)
	mechanic.reset()
	assert_signal_emitted_with_parameters(mechanic, "count_changed", [0])


func test_confirm_under_target_does_not_emit_correct() -> void:
	mechanic.place()
	watch_signals(mechanic)
	mechanic.confirm()
	assert_signal_not_emitted(mechanic, "correct")


func test_go_button_press_calls_confirm() -> void:
	watch_signals(mechanic)
	mechanic.get_node("GoButton").pressed.emit()
	assert_signal_emitted(mechanic, "incorrect")


func test_set_interactive_false_disables_go_button_and_planks() -> void:
	mechanic.reset()
	mechanic.set_interactive(false)
	assert_true(mechanic.get_node("GoButton").disabled)
	for plank in mechanic.get_planks():
		assert_false(plank.interactive)


func test_placement_mechanic_snap_calls_place_when_plank_dropped_on_empty_slot() -> void:
	mechanic.reset()
	var slot: Node2D = mechanic.get_gap_slots()[0]
	var plank: Node2D = mechanic.get_planks()[0]
	plank.global_position = slot.global_position + Vector2(10, 10)
	plank.dropped.emit(plank.global_position)
	assert_eq(mechanic.get_placed_count(), 1)
	assert_true(slot.is_occupied)
	assert_eq(plank.global_position, slot.global_position)


func test_placement_mechanic_snap_does_not_call_place_when_slot_already_occupied() -> void:
	mechanic.target_count = 1
	mechanic.reset()
	var slot: Node2D = mechanic.get_gap_slots()[0]
	var planks: Array[Node] = mechanic.get_planks()
	planks[0].dropped.emit(slot.global_position)
	planks[1].dropped.emit(slot.global_position)
	assert_eq(mechanic.get_placed_count(), 1)


func test_placement_mechanic_plank_bounces_back_when_no_slot_within_snap_radius() -> void:
	mechanic.reset()
	var plank: Node2D = mechanic.get_planks()[0]
	var origin: Vector2 = plank.position
	plank.position = Vector2(0, -300)
	plank.dropped.emit(plank.global_position)
	await wait_seconds(0.4)
	assert_eq(mechanic.get_placed_count(), 0)
	assert_almost_eq(plank.position, origin, Vector2(0.5, 0.5))


func test_placement_mechanic_correct_emitted_after_all_slots_filled() -> void:
	mechanic.reset()
	watch_signals(mechanic)
	var planks: Array[Node] = mechanic.get_planks()
	var slots: Array[Node] = mechanic.get_gap_slots()
	for i in slots.size():
		planks[i].dropped.emit(slots[i].global_position)
		mechanic.confirm()
		if i < slots.size() - 1:
			assert_signal_not_emitted(mechanic, "correct")
	assert_signal_emitted(mechanic, "correct")


func test_placement_mechanic_reset_clears_slots_and_respawns_planks() -> void:
	mechanic.reset()
	var old_plank: Node = mechanic.get_planks()[0]
	var slot: Node2D = mechanic.get_gap_slots()[0]
	old_plank.dropped.emit(slot.global_position)
	mechanic.reset()
	assert_eq(mechanic.get_placed_count(), 0)
	assert_false(mechanic.get_planks().has(old_plank))
	for gap in mechanic.get_gap_slots():
		assert_false(gap.is_occupied)


func test_placement_mechanic_gap_layout_creates_n_slots_for_target_count_1() -> void:
	mechanic.target_count = 1
	mechanic.reset()
	var slots: Array[Node] = mechanic.get_gap_slots()
	assert_eq(slots.size(), 1)
	assert_eq(slots[0].position, Vector2.ZERO)


func test_placement_mechanic_gap_layout_creates_n_slots_for_target_count_5() -> void:
	mechanic.target_count = 5
	mechanic.reset()
	var slots: Array[Node] = mechanic.get_gap_slots()
	assert_eq(slots.size(), 5)
	assert_eq(slots[0].position.x, -240.0)
	assert_eq(slots[2].position.x, 0.0)
	assert_eq(slots[4].position.x, 240.0)


func test_placement_mechanic_spawns_n_plus_1_planks_in_source() -> void:
	mechanic.target_count = 4
	mechanic.reset()
	assert_eq(mechanic.get_planks().size(), 5)

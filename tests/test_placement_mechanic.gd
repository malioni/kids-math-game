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


func test_place_exact_target_emits_correct() -> void:
	watch_signals(mechanic)
	mechanic.place()
	mechanic.place()
	mechanic.place()
	assert_signal_emitted(mechanic, "correct")


func test_place_exact_target_does_not_emit_incorrect() -> void:
	watch_signals(mechanic)
	mechanic.place()
	mechanic.place()
	mechanic.place()
	assert_signal_not_emitted(mechanic, "incorrect")


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

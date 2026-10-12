extends GutTest

const SCENE := preload("res://scenes/mechanics/balloon_pop_mechanic.tscn")
# Lift 3+5+4+2 = 14 against weight 9: pop 5, or 3+2.
const TARGET := 9
const VALUES: Array[int] = [3, 5, 4, 2]

var mechanic: BalloonPopMechanic


func before_each() -> void:
	mechanic = SCENE.instantiate()
	add_child(mechanic)
	mechanic.setup(TARGET, VALUES)


func after_each() -> void:
	mechanic.queue_free()


func _balloon(value: int) -> Balloon:
	for balloon: Balloon in mechanic.get_unpopped_balloons():
		if balloon.value == value:
			return balloon
	return null


func _values() -> Array[int]:
	var values: Array[int] = []
	for balloon: Balloon in mechanic.get_balloons():
		values.append(balloon.value)
	values.sort()
	return values


func test_balloon_pop_mechanic_setup_spawns_one_balloon_per_value() -> void:
	assert_eq(_values(), [2, 3, 4, 5])


func test_balloon_pop_mechanic_shows_lift_and_weight() -> void:
	assert_eq(mechanic.get_node("LiftBadge/LiftLabel").text, "14")
	assert_eq(mechanic.get_node("WeightSign/WeightLabel").text, "9")


func test_balloon_pop_mechanic_starts_rising() -> void:
	assert_eq(mechanic.get_lift_total(), 14)
	assert_eq(mechanic.get_balance(), 5)


func test_balloon_pop_mechanic_bigger_number_bigger_balloon() -> void:
	assert_gt(_balloon(5).radius, _balloon(2).radius)


func test_balloon_pop_mechanic_tap_pops_and_updates_lift() -> void:
	watch_signals(mechanic)
	_balloon(3).tapped.emit()
	assert_eq(mechanic.get_lift_total(), 11)
	assert_eq(mechanic.get_node("LiftBadge/LiftLabel").text, "11")
	assert_signal_emitted_with_parameters(mechanic, "total_changed", [11])
	assert_signal_not_emitted(mechanic, "correct")
	assert_signal_not_emitted(mechanic, "incorrect")


func test_balloon_pop_mechanic_reaching_weight_emits_correct() -> void:
	watch_signals(mechanic)
	mechanic.pop(_balloon(5))
	assert_signal_emitted(mechanic, "correct")
	assert_eq(mechanic.get_balance(), 0)


func test_balloon_pop_mechanic_two_pops_reaching_weight_emits_correct() -> void:
	watch_signals(mechanic)
	mechanic.pop(_balloon(3))
	mechanic.pop(_balloon(2))
	assert_signal_emit_count(mechanic, "correct", 1)


func test_balloon_pop_mechanic_dropping_below_weight_emits_incorrect() -> void:
	watch_signals(mechanic)
	mechanic.pop(_balloon(4))
	mechanic.pop(_balloon(3))
	assert_signal_emitted(mechanic, "incorrect")
	assert_signal_not_emitted(mechanic, "correct")


func test_balloon_pop_mechanic_popping_same_balloon_twice_counts_once() -> void:
	var balloon := _balloon(2)
	mechanic.pop(balloon)
	mechanic.pop(balloon)
	assert_eq(mechanic.get_lift_total(), 12)


func test_balloon_pop_mechanic_not_interactive_ignores_pops() -> void:
	mechanic.set_interactive(false)
	mechanic.pop(_balloon(5))
	assert_eq(mechanic.get_lift_total(), 14)
	for balloon: Balloon in mechanic.get_balloons():
		assert_false(balloon.interactive)


func test_balloon_pop_mechanic_reset_brings_back_all_balloons() -> void:
	mechanic.pop(_balloon(4))
	watch_signals(mechanic)
	mechanic.reset()
	await wait_frames(1)
	assert_eq(mechanic.get_unpopped_balloons().size(), 4)
	assert_eq(_values(), [2, 3, 4, 5])
	assert_eq(mechanic.get_lift_total(), 14)
	assert_signal_emitted_with_parameters(mechanic, "total_changed", [14])


func test_balloon_pop_mechanic_balloons_do_not_overlap_with_8_balloons() -> void:
	var values: Array[int] = [15, 15, 15, 15, 15, 15, 15, 15]
	mechanic.setup(30, values)
	var balloons := mechanic.get_balloons()
	for i in balloons.size():
		for j in range(i + 1, balloons.size()):
			var a: Balloon = balloons[i]
			var b: Balloon = balloons[j]
			assert_gt(a.position.distance_to(b.position), a.radius + b.radius, "%d-%d" % [i, j])


func test_balloon_pop_mechanic_8_balloons_fit_on_screen() -> void:
	var values: Array[int] = [15, 15, 15, 15, 15, 15, 15, 15]
	mechanic.setup(30, values)
	for balloon: Balloon in mechanic.get_balloons():
		assert_lt(absf(balloon.position.x) + balloon.radius, 600.0)

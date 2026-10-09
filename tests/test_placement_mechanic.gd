extends GutTest

const SCENE := preload("res://scenes/mechanics/placement_mechanic.tscn")
# Bridge 10 wide over 600 px -> 60 px per unit. Solutions: 3+7 and 4+6.
const TARGET := 10
const LENGTHS: Array[int] = [3, 7, 4, 6, 9]

var mechanic: Node2D


func before_each() -> void:
	mechanic = SCENE.instantiate()
	add_child(mechanic)
	mechanic.setup(TARGET, LENGTHS)


func after_each() -> void:
	mechanic.queue_free()


func _plank(length: int) -> PlankDrag:
	for plank: PlankDrag in mechanic.get_planks():
		if plank.length == length and not plank.is_placed:
			return plank
	return null


func _drop_on_gap(plank: PlankDrag) -> void:
	plank.dropped.emit(mechanic.to_global(Vector2(0, 10)))


func _settle() -> void:
	await wait_seconds(0.3)


func test_placement_mechanic_setup_spawns_one_plank_per_length() -> void:
	var lengths: Array[int] = []
	for plank: PlankDrag in mechanic.get_planks():
		lengths.append(plank.length)
	lengths.sort()
	assert_eq(lengths, [3, 4, 6, 7, 9])


func test_placement_mechanic_setup_sets_target_sign_text() -> void:
	assert_eq(mechanic.get_node("TargetSign/TargetLabel").text, "10")


func test_placement_mechanic_plank_widths_proportional_to_length() -> void:
	for plank: PlankDrag in mechanic.get_planks():
		assert_eq(plank.get_width(), plank.length * 60.0)


func test_placement_mechanic_drop_on_gap_places_plank_and_updates_total() -> void:
	_drop_on_gap(_plank(3))
	assert_eq(mechanic.get_placed_total(), 3)
	assert_eq(mechanic.get_placed_planks().size(), 1)


func test_placement_mechanic_drop_on_gap_emits_total_changed() -> void:
	watch_signals(mechanic)
	_drop_on_gap(_plank(4))
	assert_signal_emitted_with_parameters(mechanic, "total_changed", [4])


func test_placement_mechanic_placed_planks_laid_end_to_end_from_left() -> void:
	var first := _plank(3)
	var second := _plank(7)
	_drop_on_gap(first)
	_drop_on_gap(second)
	await _settle()
	assert_almost_eq(first.position.x, -300.0 + 90.0, 0.5)
	assert_almost_eq(second.position.x, -300.0 + 180.0 + 210.0, 0.5)
	assert_almost_eq(first.position.y, 0.0, 0.5)


func test_placement_mechanic_drop_longer_than_remaining_bounces_back() -> void:
	_drop_on_gap(_plank(7))
	var nine := _plank(9)
	var home := nine.home
	nine.position = Vector2(0, 0)
	_drop_on_gap(nine)
	await _settle()
	assert_eq(mechanic.get_placed_total(), 7)
	assert_false(nine.is_placed)
	assert_almost_eq(nine.position, home, Vector2(0.5, 0.5))


func test_placement_mechanic_drop_exactly_remaining_is_accepted() -> void:
	_drop_on_gap(_plank(4))
	_drop_on_gap(_plank(6))
	assert_eq(mechanic.get_placed_total(), 10)
	assert_eq(mechanic.get_remaining_length(), 0)


func test_placement_mechanic_drop_outside_gap_bounces_back() -> void:
	var plank := _plank(3)
	plank.dropped.emit(mechanic.to_global(Vector2(0, -200)))
	assert_eq(mechanic.get_placed_total(), 0)
	assert_false(plank.is_placed)


func test_placement_mechanic_tap_placed_plank_returns_it_and_closes_gap() -> void:
	var three := _plank(3)
	var seven := _plank(7)
	_drop_on_gap(three)
	_drop_on_gap(seven)
	three.tapped.emit()
	await _settle()
	assert_eq(mechanic.get_placed_total(), 7)
	assert_false(three.is_placed)
	assert_almost_eq(three.position, three.home, Vector2(0.5, 0.5))
	assert_almost_eq(seven.position.x, -300.0 + 210.0, 0.5)


func test_placement_mechanic_tap_pile_plank_does_nothing() -> void:
	watch_signals(mechanic)
	_plank(3).tapped.emit()
	assert_signal_not_emitted(mechanic, "total_changed")


func test_placement_mechanic_confirm_exact_total_emits_correct() -> void:
	_drop_on_gap(_plank(3))
	_drop_on_gap(_plank(7))
	watch_signals(mechanic)
	mechanic.confirm()
	assert_signal_emitted(mechanic, "correct")
	assert_signal_not_emitted(mechanic, "incorrect")


func test_placement_mechanic_confirm_short_total_emits_incorrect() -> void:
	_drop_on_gap(_plank(6))
	watch_signals(mechanic)
	mechanic.confirm()
	assert_signal_emitted(mechanic, "incorrect")
	assert_signal_not_emitted(mechanic, "correct")


func test_placement_mechanic_confirm_empty_bridge_emits_incorrect() -> void:
	watch_signals(mechanic)
	mechanic.confirm()
	assert_signal_emitted(mechanic, "incorrect")


func test_placement_mechanic_reset_returns_all_planks_to_pile_with_same_lengths() -> void:
	_drop_on_gap(_plank(3))
	mechanic.reset()
	assert_eq(mechanic.get_placed_planks().size(), 0)
	assert_eq(mechanic.get_planks().size(), LENGTHS.size())
	assert_eq(mechanic.get_placed_total(), 0)


func test_placement_mechanic_reset_emits_total_changed_zero() -> void:
	_drop_on_gap(_plank(3))
	watch_signals(mechanic)
	mechanic.reset()
	assert_signal_emitted_with_parameters(mechanic, "total_changed", [0])


func test_placement_mechanic_pile_fits_within_three_rows_for_level_10() -> void:
	var level: Dictionary = LevelLoader.get_levels_for_world("forest")[9]
	var rng := RandomNumberGenerator.new()
	var max_y: float = mechanic.pile_row_y[-1]
	for s in 50:
		rng.seed = s
		var puzzle := PlankPuzzleGenerator.generate(level, rng)
		mechanic.setup(puzzle["bridge_length"], puzzle["plank_lengths"])
		var used_rows := {}
		for plank: PlankDrag in mechanic.get_planks():
			var right: float = plank.position.x + plank.get_width() / 2.0
			assert_lte(right, mechanic.pile_right + 0.5, "seed %d overflows right edge" % s)
			used_rows[plank.position.y] = true
		assert_lte(used_rows.size(), 3, "seed %d needs more than 3 rows" % s)
		for y in used_rows:
			assert_lte(y, max_y)


func test_placement_mechanic_get_remaining_length_is_target_minus_total() -> void:
	assert_eq(mechanic.get_target_length(), TARGET)
	_drop_on_gap(_plank(4))
	assert_eq(mechanic.get_remaining_length(), 6)


func test_placement_mechanic_set_interactive_false_disables_go_and_planks() -> void:
	mechanic.set_interactive(false)
	assert_true(mechanic.get_node("GoButton").disabled)
	for plank: PlankDrag in mechanic.get_planks():
		assert_false(plank.interactive)


func test_set_interactive_false_mid_drag_cancels_drag() -> void:
	var plank := _plank(3)
	plank._begin_press(plank.global_position)
	mechanic.set_interactive(false)
	assert_false(plank.is_dragging())
	assert_eq(mechanic.get_placed_total(), 0)


func test_go_button_press_calls_confirm() -> void:
	watch_signals(mechanic)
	mechanic.get_node("GoButton").pressed.emit()
	assert_signal_emitted(mechanic, "incorrect")


func test_go_texture_applied_to_go_button() -> void:
	var m: Node2D = SCENE.instantiate()
	var tex := PlaceholderTexture2D.new()
	m.go_texture = tex
	add_child_autofree(m)
	assert_eq(m.get_node("GoButton").texture_normal, tex)

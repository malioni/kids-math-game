extends GutTest

const SCENE := preload("res://scenes/mechanics/memory_mechanic.tscn")
const TEXTURES := {
	"fox": preload("res://assets/sprites/memory/animal_fox.png"),
	"owl": preload("res://assets/sprites/memory/animal_owl.png"),
	"frog": preload("res://assets/sprites/memory/animal_frog.png"),
}
const ORIGIN := Vector2(640, 360)
const DELAY := 0.02
const SETTLE := 0.1

var _mechanic: MemoryMechanic


func before_each() -> void:
	_mechanic = SCENE.instantiate()
	_mechanic.card_textures = TEXTURES
	_mechanic.match_delay = DELAY
	_mechanic.mismatch_delay = DELAY
	_mechanic.position = ORIGIN
	add_child(_mechanic)


func after_each() -> void:
	_mechanic.queue_free()


## Fox pair at 0 and 2, owl pair at 1 and 3.
func _two_pairs(preview_seconds: float = 0.0) -> void:
	_mechanic.setup(_deck(["fox", "owl", "fox", "owl"]), preview_seconds)


func _deck(animals: Array) -> Array[String]:
	var deck: Array[String] = []
	deck.assign(animals)
	return deck


func _deck_of(card_count: int) -> Array[String]:
	var deck: Array[String] = []
	for i in card_count:
		deck.append(["fox", "owl", "frog"][(i / 2) % 3])
	return deck


func _card(index: int) -> MemoryCard:
	return _mechanic.get_cards()[index]


func test_memory_mechanic_setup_creates_one_card_per_deck_entry() -> void:
	_two_pairs()
	assert_eq(_mechanic.get_cards().size(), 4)
	for i in 4:
		assert_eq(_card(i).get_animal(), _mechanic.get_deck()[i])


func test_memory_mechanic_setup_all_cards_face_down_without_preview() -> void:
	_two_pairs()
	for card in _mechanic.get_cards():
		assert_false(card.is_face_up())
	assert_false(_mechanic.is_previewing())


func test_memory_mechanic_grid_for_matches_table_for_every_even_count_4_to_20() -> void:
	for count in range(4, 21, 2):
		var grid: Vector2i = MemoryMechanic.grid_for(count)
		assert_eq(grid.x * grid.y, count, str(count))
	assert_eq(MemoryMechanic.grid_for(4), Vector2i(4, 1))
	assert_eq(MemoryMechanic.grid_for(20), Vector2i(5, 4))


func test_memory_mechanic_cards_fit_inside_board_rect() -> void:
	for count in range(4, 21, 2):
		_mechanic.setup(_deck_of(count), 0.0)
		for card in _mechanic.get_cards():
			var half := Vector2.ONE * card.get_size() / 2.0
			var rect := Rect2(card.position - half, half * 2.0)
			assert_true(_mechanic.board_rect.encloses(rect), "%d cards: %s" % [count, rect])


func test_memory_mechanic_cards_meet_minimum_tap_size_at_20_cards() -> void:
	_mechanic.setup(_deck_of(20), 0.0)
	assert_gte(_card(0).get_size(), 100.0)


func test_memory_mechanic_preview_shows_faces_then_hides_them() -> void:
	_two_pairs(0.1)
	assert_true(_mechanic.is_previewing())
	for card in _mechanic.get_cards():
		assert_true(card.is_face_up())
	await wait_seconds(0.1 + SETTLE)
	assert_false(_mechanic.is_previewing())
	for card in _mechanic.get_cards():
		assert_false(card.is_face_up())


func test_memory_mechanic_taps_ignored_during_preview() -> void:
	_two_pairs(0.5)
	watch_signals(_mechanic)
	_card(0).tapped.emit()
	assert_signal_not_emitted(_mechanic, "piece_placed")


func test_memory_mechanic_turning_a_card_emits_piece_placed() -> void:
	_two_pairs()
	watch_signals(_mechanic)
	_card(0).tapped.emit()
	assert_true(_card(0).is_face_up())
	assert_signal_emit_count(_mechanic, "piece_placed", 1)


func test_memory_mechanic_matching_pair_emits_pair_matched_and_marks_matched() -> void:
	_two_pairs()
	watch_signals(_mechanic)
	_mechanic.tap_card(0)
	_mechanic.tap_card(2)
	await wait_seconds(DELAY + SETTLE)
	assert_signal_emitted_with_parameters(_mechanic, "pair_matched", ["fox"])
	assert_true(_card(0).is_matched())
	assert_true(_card(2).is_matched())
	assert_eq(_mechanic.get_matched_count(), 1)
	assert_signal_not_emitted(_mechanic, "correct")


func test_memory_mechanic_mismatch_turns_both_back_and_emits_piece_removed() -> void:
	_two_pairs()
	watch_signals(_mechanic)
	_mechanic.tap_card(0)
	_mechanic.tap_card(1)
	await wait_seconds(DELAY + SETTLE)
	assert_false(_card(0).is_face_up())
	assert_false(_card(1).is_face_up())
	assert_signal_emit_count(_mechanic, "piece_removed", 1)
	assert_signal_not_emitted(_mechanic, "pair_matched")


func test_memory_mechanic_mismatch_does_not_emit_incorrect() -> void:
	_two_pairs()
	watch_signals(_mechanic)
	_mechanic.tap_card(0)
	_mechanic.tap_card(1)
	await wait_seconds(DELAY + SETTLE)
	assert_signal_not_emitted(_mechanic, "incorrect")


func test_memory_mechanic_third_tap_ignored_while_two_cards_up() -> void:
	_two_pairs()
	_mechanic.tap_card(0)
	_mechanic.tap_card(1)
	watch_signals(_mechanic)
	_mechanic.tap_card(2)
	assert_false(_card(2).is_face_up())
	assert_signal_not_emitted(_mechanic, "piece_placed")


func test_memory_mechanic_tapping_face_up_card_does_nothing() -> void:
	_two_pairs()
	_mechanic.tap_card(0)
	watch_signals(_mechanic)
	_mechanic.tap_card(0)
	assert_signal_not_emitted(_mechanic, "piece_placed")
	await wait_seconds(DELAY + SETTLE)
	assert_true(_card(0).is_face_up(), "one card up waits for a second")


func test_memory_mechanic_last_pair_emits_correct_once() -> void:
	_two_pairs()
	watch_signals(_mechanic)
	_mechanic.tap_card(0)
	_mechanic.tap_card(2)
	await wait_seconds(DELAY + SETTLE)
	_mechanic.tap_card(1)
	_mechanic.tap_card(3)
	await wait_seconds(DELAY + SETTLE)
	assert_signal_emit_count(_mechanic, "correct", 1)
	assert_true(_mechanic.is_solved())


func test_memory_mechanic_set_interactive_false_ignores_taps() -> void:
	_two_pairs()
	_mechanic.set_interactive(false)
	watch_signals(_mechanic)
	_mechanic.tap_card(0)
	assert_false(_card(0).is_face_up())
	assert_signal_not_emitted(_mechanic, "piece_placed")


func test_memory_mechanic_reset_turns_all_down_with_same_deck() -> void:
	_two_pairs()
	var deck: Array[String] = _mechanic.get_deck().duplicate()
	_mechanic.tap_card(0)
	_mechanic.tap_card(2)
	await wait_seconds(DELAY + SETTLE)
	_mechanic.reset()
	assert_eq(_mechanic.get_deck(), deck)
	assert_eq(_mechanic.get_matched_count(), 0)
	for card in _mechanic.get_cards():
		assert_false(card.is_face_up())
		assert_false(card.is_matched())


func test_memory_mechanic_reset_during_mismatch_delay_cancels_pending_turn_back() -> void:
	_mechanic.mismatch_delay = 0.1
	_two_pairs()
	_mechanic.tap_card(0)
	_mechanic.tap_card(1)
	_mechanic.reset()
	watch_signals(_mechanic)
	_mechanic.tap_card(0)
	await wait_seconds(0.1 + SETTLE)
	assert_signal_not_emitted(_mechanic, "piece_removed")
	assert_true(_card(0).is_face_up())


func test_memory_mechanic_setup_does_not_emit_piece_signals() -> void:
	watch_signals(_mechanic)
	_two_pairs(0.05)
	await wait_seconds(0.05 + SETTLE)
	_mechanic.reset()
	assert_signal_not_emitted(_mechanic, "piece_placed")
	assert_signal_not_emitted(_mechanic, "piece_removed")

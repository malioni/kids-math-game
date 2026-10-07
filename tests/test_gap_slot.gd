extends GutTest

const SCENE := preload("res://scenes/mechanics/gap_slot.tscn")

var _slot: Area2D


func before_each() -> void:
	_slot = add_child_autofree(SCENE.instantiate())


func test_gap_slot_starts_empty() -> void:
	assert_false(_slot.is_occupied)
	assert_eq(_slot.get_node("Sprite2D").texture, _slot.empty_texture)


func test_gap_slot_occupy_marks_occupied_and_swaps_texture() -> void:
	_slot.occupy()
	assert_true(_slot.is_occupied)
	assert_eq(_slot.get_node("Sprite2D").texture, _slot.filled_texture)


func test_gap_slot_vacate_restores_empty_state() -> void:
	_slot.occupy()
	_slot.vacate()
	assert_false(_slot.is_occupied)
	assert_eq(_slot.get_node("Sprite2D").texture, _slot.empty_texture)

extends GutTest

var _program: DriveProgram


func before_each() -> void:
	_program = DriveProgram.new()


func _tile_summary() -> Array:
	return _program.get_tiles().map(
		func(tile: Dictionary) -> String: return "%s%d" % [tile["command"], tile["count"]]
	)


func test_drive_program_starts_empty() -> void:
	assert_true(_program.is_empty())
	assert_eq(_program.get_tiles(), [])


func test_drive_program_same_command_merges_into_one_tile() -> void:
	_program.add("right")
	_program.add("right")
	_program.add("down")
	assert_eq(_tile_summary(), ["right2", "down1"])


func test_drive_program_turns_merge_too() -> void:
	_program.add("turn_left")
	_program.add("turn_left")
	assert_eq(_tile_summary(), ["turn_left2"])


func test_drive_program_take_step_lowers_count() -> void:
	_program.add("right")
	_program.add("right")
	_program.take_step(0)
	assert_eq(_tile_summary(), ["right1"])


func test_drive_program_take_step_at_one_removes_tile() -> void:
	_program.add("right")
	_program.add("down")
	_program.add("right")
	_program.take_step(1)
	# The two "right" tiles are now neighbours but stay separate.
	assert_eq(_tile_summary(), ["right1", "right1"])


func test_drive_program_add_after_removal_merges_with_new_last_tile() -> void:
	_program.add("right")
	_program.add("down")
	_program.take_step(1)
	_program.add("right")
	assert_eq(_tile_summary(), ["right2"])


func test_drive_program_take_step_out_of_range_does_nothing() -> void:
	_program.add("up")
	_program.take_step(5)
	_program.take_step(-1)
	assert_eq(_tile_summary(), ["up1"])


func test_drive_program_holds_at_most_12_tiles() -> void:
	for i in DriveProgram.MAX_TILES:
		assert_true(_program.add("up" if i % 2 == 0 else "down"))
	assert_true(_program.is_full())
	assert_false(_program.add("left"), "a 13th tile is refused")
	assert_eq(_program.get_tiles().size(), 12)


func test_drive_program_full_strip_still_raises_last_tile() -> void:
	for i in DriveProgram.MAX_TILES:
		_program.add("up" if i % 2 == 0 else "down")
	assert_true(_program.can_add("down"), "the last tile is down")
	assert_false(_program.can_add("up"))
	assert_true(_program.add("down"))
	assert_eq(_program.get_tiles()[-1]["count"], 2)


func test_drive_program_expand_unrolls_with_tile_index() -> void:
	_program.add("forward")
	_program.add("forward")
	_program.add("turn_right")
	_program.add("forward")
	assert_eq(
		_program.expand(),
		[
			{"command": "forward", "tile": 0},
			{"command": "forward", "tile": 0},
			{"command": "turn_right", "tile": 1},
			{"command": "forward", "tile": 2},
		]
	)


func test_drive_program_get_tiles_is_a_copy() -> void:
	_program.add("up")
	_program.get_tiles()[0]["count"] = 9
	assert_eq(_tile_summary(), ["up1"])


func test_drive_program_clear_empties() -> void:
	_program.add("up")
	_program.clear()
	assert_true(_program.is_empty())

extends GutTest

const SCENE := preload("res://scenes/worlds/memory/memory.tscn")
const _SEED := 1234
const _DELAY := 0.01
# Long enough for a pair to resolve plus the world's reaction.
const _SETTLE := 0.15

var _world: Node2D
var _mechanic: MemoryMechanic
var _retry: BaseButton
var _hud: LevelHud


func before_each() -> void:
	SaveFixture.clear()
	_world = _make_world()
	add_child(_world)
	_mechanic = _world.get_node("MemoryMechanic")
	_retry = _world.get_node("RetryPrompt/RetryIcon")
	_hud = _world.get_node("LevelHud")


func after_each() -> void:
	_world.queue_free()
	SaveFixture.clear()


func _make_world() -> Node2D:
	var world: Node2D = SCENE.instantiate()
	world.celebrate_duration = 0.01
	world.hop_duration = 0.01
	world.puzzle_seed = _SEED
	var mechanic: MemoryMechanic = world.get_node("MemoryMechanic")
	mechanic.match_delay = _DELAY
	mechanic.mismatch_delay = _DELAY
	return world


## Ends the level's peek, if it has one. reset() keeps the deck and turns every card down.
func _skip_preview() -> void:
	if _mechanic.is_previewing():
		_mechanic.reset()
	await wait_process_frames(1)


## Returns the deck index of each card's partner.
func _pairs() -> Array[Vector2i]:
	var first_seen := {}
	var pairs: Array[Vector2i] = []
	var deck: Array[String] = _mechanic.get_deck()
	for i in deck.size():
		if first_seen.has(deck[i]):
			pairs.append(Vector2i(first_seen[deck[i]], i))
		else:
			first_seen[deck[i]] = i
	return pairs


## Turns over every pair in turn, waiting for each to leave the board.
func _solve() -> void:
	await _skip_preview()
	for pair in _pairs():
		_mechanic.tap_card(pair.x)
		_mechanic.tap_card(pair.y)
		await wait_for_signal(_mechanic.pair_matched, 1.0)


## Returns the deck indices of two cards that don't match.
func _mismatch() -> Vector2i:
	var deck: Array[String] = _mechanic.get_deck()
	for i in range(1, deck.size()):
		if deck[i] != deck[0]:
			return Vector2i(0, i)
	return Vector2i(-1, -1)


func _sfx_played() -> Array:
	var sounds: Array = []
	for i in get_signal_emit_count(AudioManager, "sfx_played"):
		sounds.append(get_signal_parameters(AudioManager, "sfx_played", i)[0])
	return sounds


func test_memory_world_id_is_memory() -> void:
	assert_eq(_world._world_id(), "memory")
	assert_eq(SaveManager.load_last_world(), "memory")


func test_memory_loads_level_1_with_two_pairs_including_fox() -> void:
	assert_eq(_world._current_index, 0)
	assert_eq(_mechanic.get_deck().size(), 4)
	assert_eq(_mechanic.get_deck().count("fox"), 2)


func test_memory_level_badge_shows_level_1() -> void:
	assert_eq(_hud.get_node("Root/LevelBadge/Row/LevelLabel").text, "1")


func test_memory_level_1_starts_with_a_peek() -> void:
	assert_true(_mechanic.is_previewing())


func test_memory_clearing_board_advances_to_level_2() -> void:
	await _solve()
	await wait_seconds(_SETTLE)
	assert_eq(_world._current_index, 1)
	assert_eq(_mechanic.get_deck().size(), 4)


func test_memory_clearing_board_saves_progress() -> void:
	await _solve()
	await wait_seconds(_SETTLE)
	assert_eq(SaveManager.load_progress("memory:easy"), 2)


func test_memory_clearing_board_fox_celebrates() -> void:
	# Long enough that a slow frame can't move on to the next level before the check below.
	_world.celebrate_duration = 0.5
	await _solve()
	assert_eq(_world.get_node("Character").animation, &"celebrate")


func test_memory_last_easy_level_shows_world_complete() -> void:
	_hud.level_chosen.emit("memory", 9)
	await _solve()
	await wait_seconds(_SETTLE)
	assert_true(_hud.is_world_complete_shown())


func test_memory_pair_matched_plays_match_sound_and_fox_hops() -> void:
	await _skip_preview()
	watch_signals(AudioManager)
	var pair: Vector2i = _pairs()[0]
	_mechanic.tap_card(pair.x)
	_mechanic.tap_card(pair.y)
	await wait_for_signal(_mechanic.pair_matched, 1.0)
	assert_has(_sfx_played(), "memory/match")
	assert_eq(_world.get_node("Character").animation, &"celebrate")
	await wait_seconds(_SETTLE)
	assert_eq(_world.get_node("Character").animation, &"idle")


func test_memory_mismatch_never_shows_retry_prompt() -> void:
	await _skip_preview()
	watch_signals(AudioManager)
	var pair: Vector2i = _mismatch()
	_mechanic.tap_card(pair.x)
	_mechanic.tap_card(pair.y)
	await wait_seconds(_SETTLE)
	assert_false(_retry.visible)
	assert_does_not_have(_sfx_played(), "lose")
	assert_has(_sfx_played(), "memory/remove")
	assert_eq(_world._current_index, 0)


func test_memory_registered_in_game_registry() -> void:
	var world: Dictionary = GameRegistry.get_world("memory")
	assert_eq(world["scene"], "res://scenes/worlds/memory/memory.tscn")
	assert_true(ResourceLoader.exists(world["icon"]))


func test_memory_every_level_solvable_in_order() -> void:
	for difficulty in LevelLoader.DIFFICULTIES:
		_hud.difficulty_chosen.emit(difficulty)
		var level_range: Vector2i = LevelLoader.get_difficulty_range(difficulty)
		for i in range(level_range.x, level_range.y + 1):
			assert_eq(_world._current_index, i, difficulty)
			assert_eq(_mechanic.get_deck().size(), 2 * int(_world._levels[i]["pairs"]))
			await _solve()
			await wait_seconds(_SETTLE)
		assert_true(_hud.is_world_complete_shown(), difficulty)

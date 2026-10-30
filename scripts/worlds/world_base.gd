class_name WorldBase
extends Node2D

## Level flow shared by every world: loads the world's levels, resumes from the save, keeps the
## level HUD up to date, advances after a win, and offers a restart after the last level.
##
## Only the current difficulty's levels are played (easy 1–10, hard 11–20; see GameRegistry). In
## shuffle mode a win moves on to a random world's next shuffle level instead of this world's
## next level; shuffle keeps its own place in each world.
##
## A world extends this, overrides _world_id() and _setup_level(), connects its own mechanic in
## _ready() before calling super(), and calls _advance() once its win animation has played.

## Emitted when the player completes the last level of the difficulty in this world, or the last
## level of a whole shuffle.
signal world_complete

## Seconds the celebration plays before the next level loads.
@export var celebrate_duration: float = 1.5
## Seed for puzzle generation. 0 picks a random seed, so every run gets different puzzles.
@export var puzzle_seed: int = 0

var _levels: Array[Dictionary] = []
var _current_index: int = 0
var _rng := RandomNumberGenerator.new()
# Bumped on every level load. An animation that awaits checks it afterwards, so a win or fall
# from a level the player has since left (e.g. by picking another level) doesn't carry on.
var _load_count: int = 0

@onready var _hud: LevelHud = $LevelHud


func _ready() -> void:
	_levels = LevelLoader.get_levels_for_world(_world_id())
	if puzzle_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = puzzle_seed
	_hud.level_chosen.connect(_on_level_chosen)
	_hud.restart_requested.connect(_on_restart_requested)
	_hud.difficulty_chosen.connect(_on_difficulty_chosen)
	_hud.shuffle_requested.connect(GameRegistry.start_shuffle)
	SaveManager.save_last_world(_world_id())
	var start_index: int = GameRegistry.take_requested_level(_world_id())
	if start_index >= 0:
		_choose_level(start_index)
	else:
		_resume()


## Returns the world's id as registered in GameRegistry. Subclasses must override.
func _world_id() -> String:
	push_error("WorldBase: _world_id() not overridden")
	return ""


## Resets the stage and sets up a fresh puzzle for the given level. Subclasses must override.
func _setup_level(_level: Dictionary) -> void:
	push_error("WorldBase: _setup_level() not overridden")


func _load_level(index: int) -> void:
	_current_index = index
	_load_count += 1
	_hud.show_level(_world_id(), index, _levels.size())
	_setup_level(_levels[index])


## Moves on after a win: in shuffle, to the next shuffle pick; otherwise to the next level, or after
## the difficulty's last level resets its save and shows the world-complete screen.
func _advance() -> void:
	if GameRegistry.is_shuffle():
		_advance_shuffle()
		return
	var level_range: Vector2i = _level_range()
	if _current_index >= level_range.y:
		SaveManager.set_progress(_progress_key(), level_range.x + 1)
		world_complete.emit()
		_hud.show_world_complete()
	else:
		SaveManager.save_progress(_progress_key(), _current_index + 2)
		_load_level(_current_index + 1)


func _advance_shuffle() -> void:
	SaveManager.set_progress(_progress_key(), _current_index + 2)
	var next_world: String = GameRegistry.next_shuffle_world()
	if next_world == "":
		world_complete.emit()
		_hud.show_world_complete()
	elif next_world == _world_id():
		_load_level(_current_index + 1)
	else:
		GameRegistry.go_to_world(next_world)


# Loads where the current mode and difficulty left off. A world whose shuffle levels are all
# played shows its last level while shuffle moves on to another world.
func _resume() -> void:
	var level_range: Vector2i = _level_range()
	var index: int = SaveManager.load_progress(_progress_key()) - 1
	if GameRegistry.is_shuffle() and index > level_range.y:
		_load_level(level_range.y)
		GameRegistry.start_shuffle.call_deferred()
		return
	_load_level(clampi(index, level_range.x, level_range.y))


# Plays the chosen level outside shuffle, switching difficulty if the level belongs to another.
func _choose_level(index: int) -> void:
	index = clampi(index, 0, _levels.size() - 1)
	if not GameRegistry.is_shuffle():
		var level_range: Vector2i = _level_range()
		if index < level_range.x or index > level_range.y:
			for difficulty in LevelLoader.DIFFICULTIES:
				var other: Vector2i = LevelLoader.get_difficulty_range(difficulty)
				if index >= other.x and index <= other.y:
					GameRegistry.set_difficulty(difficulty)
		SaveManager.set_progress(_progress_key(), index + 1)
	_load_level(index)


func _level_range() -> Vector2i:
	var level_range: Vector2i = GameRegistry.get_level_range()
	return Vector2i(level_range.x, mini(level_range.y, _levels.size() - 1))


func _progress_key() -> String:
	return SaveManager.progress_key(
		_world_id(), GameRegistry.get_difficulty(), GameRegistry.is_shuffle()
	)


func _on_level_chosen(world_id: String, index: int) -> void:
	GameRegistry.set_shuffle(false)
	if world_id != _world_id():
		GameRegistry.go_to_world(world_id, index)
	elif index < 0:
		_resume()
	else:
		_choose_level(index)


func _on_restart_requested() -> void:
	if GameRegistry.is_shuffle():
		GameRegistry.start_shuffle()
		return
	var first: int = _level_range().x
	SaveManager.set_progress(_progress_key(), first + 1)
	_load_level(first)


func _on_difficulty_chosen(difficulty: String) -> void:
	GameRegistry.set_difficulty(difficulty)
	_resume()

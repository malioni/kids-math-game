class_name WorldBase
extends Node2D

## Level flow shared by every world: loads the world's levels, resumes from the save, keeps the
## level HUD up to date, advances after a win, and offers a restart after the last level.
##
## A world extends this, overrides _world_id() and _setup_level(), connects its own mechanic in
## _ready() before calling super(), and calls _advance() once its win animation has played.

## Emitted when the player completes all levels in this world.
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
	SaveManager.save_last_world(_world_id())
	var start_index: int = GameRegistry.take_requested_level(_world_id())
	if start_index < 0:
		start_index = SaveManager.load_progress(_world_id()) - 1
	else:
		SaveManager.set_progress(_world_id(), start_index + 1)
	_load_level(clampi(start_index, 0, _levels.size() - 1))


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


## Moves on after a win: loads the next level, or after the last one resets the save and shows the
## world-complete screen.
func _advance() -> void:
	if _current_index >= _levels.size() - 1:
		SaveManager.reset_progress(_world_id())
		world_complete.emit()
		_hud.show_world_complete()
	else:
		SaveManager.save_progress(_world_id(), _current_index + 2)
		_load_level(_current_index + 1)


func _on_level_chosen(world_id: String, index: int) -> void:
	if world_id != _world_id():
		GameRegistry.go_to_world(world_id, index)
		return
	SaveManager.set_progress(world_id, index + 1)
	_load_level(index)


func _on_restart_requested() -> void:
	SaveManager.set_progress(_world_id(), 1)
	_load_level(0)

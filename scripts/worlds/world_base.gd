class_name WorldBase
extends Node2D

## Level flow shared by every world: loads the world's levels, resumes from the save, keeps the
## level HUD up to date, plays the win and lose flow, advances after a win, and offers a restart
## after the last level.
##
## Only the current difficulty's levels are played (easy 1–10, hard 11–20; see GameRegistry). In
## shuffle mode a win moves on to a random world's next shuffle level instead of this world's
## next level; shuffle keeps its own place in each world.
##
## Level changes inside the world fade through Transition (the first level is covered by the
## scene's own fade instead). Home in the HUD goes back to the main menu.
##
## Sounds play through AudioManager: the world's ambience on load, its place and remove sounds
## when the mechanic reports a piece, win and lose on an answer, and complete with the star screen.
##
## A world extends this and overrides _world_id(), _get_mechanic() and _setup_level(), then adds its
## own animations with _play_win(), _play_lose() and _restore_stage(). Its scene needs a Character
## (or an override of _get_character()), CelebrationParticles, RetryPrompt/RetryIcon and a LevelHud.

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
# Bumped on every level load. The win and lose flows check it after each wait, so a win or fall
# from a level the player has since left (e.g. by picking another level) doesn't carry on.
var _load_count: int = 0

@onready var _hud: LevelHud = $LevelHud
@onready var _character: AnimatedSprite2D = _get_character()
@onready var _particles: GPUParticles2D = $CelebrationParticles
@onready var _retry_prompt: BaseButton = $RetryPrompt/RetryIcon


func _ready() -> void:
	_levels = LevelLoader.get_levels_for_world(_world_id())
	if puzzle_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = puzzle_seed
	_get_mechanic().correct.connect(_on_correct)
	_get_mechanic().incorrect.connect(_on_incorrect)
	_get_mechanic().piece_placed.connect(_play_world_sound.bind("place"))
	_get_mechanic().piece_removed.connect(_play_world_sound.bind("remove"))
	_retry_prompt.pressed.connect(_on_retry_pressed)
	_retry_prompt.visible = false
	_hud.level_chosen.connect(_on_level_chosen)
	_hud.restart_requested.connect(_on_restart_requested)
	_hud.difficulty_chosen.connect(_on_difficulty_chosen)
	_hud.shuffle_requested.connect(_on_shuffle_requested)
	_hud.home_requested.connect(GameRegistry.go_to_menu)
	SaveManager.save_last_world(_world_id())
	AudioManager.play_music("%s/ambience" % _world_id())
	var start_index: int = GameRegistry.take_requested_level(_world_id())
	if start_index >= 0:
		_choose_level(start_index, false)
	else:
		_resume(false)


## Returns the world's id as registered in GameRegistry. Subclasses must override.
func _world_id() -> String:
	push_error("WorldBase: _world_id() not overridden")
	return ""


## Returns the world's mechanic. Subclasses must override.
func _get_mechanic() -> Mechanic:
	push_error("WorldBase: _get_mechanic() not overridden")
	return null


## Sets up the mechanic with a fresh puzzle for the given level. Subclasses must override.
func _setup_level(_level: Dictionary) -> void:
	push_error("WorldBase: _setup_level() not overridden")


## Returns the fox. Override if it isn't the scene's Character child.
func _get_character() -> AnimatedSprite2D:
	return $Character


## Puts the stage back for a new try, stopping any tween or animation _play_win() or _play_lose() is
## waiting on. Subclasses that override must call super().
func _restore_stage() -> void:
	_character.play("idle")


## Plays what happens between a right answer and the fox's celebration. Nothing by default.
func _play_win() -> void:
	pass


## Plays what happens between a wrong answer and the retry prompt. Nothing by default.
func _play_lose() -> void:
	pass


func _go_to_level(index: int) -> void:
	Transition.run(_load_level.bind(index))


func _load_level(index: int) -> void:
	_current_index = index
	_load_count += 1
	_hud.show_level(_world_id(), index)
	_retry_prompt.visible = false
	_restore_stage()
	_setup_level(_levels[index])
	_get_mechanic().set_interactive(true)


func _on_correct() -> void:
	var load_count: int = _load_count
	AudioManager.play_sfx("win")
	_get_mechanic().set_interactive(false)
	await _play_win()
	if load_count != _load_count:
		return
	_character.play("celebrate")
	_particles.restart()
	await get_tree().create_timer(celebrate_duration).timeout
	if load_count != _load_count:
		return
	_advance()


func _on_incorrect() -> void:
	var load_count: int = _load_count
	AudioManager.play_sfx("lose")
	_get_mechanic().set_interactive(false)
	await _play_lose()
	if load_count != _load_count:
		return
	_retry_prompt.visible = true


func _on_retry_pressed() -> void:
	_retry_prompt.visible = false
	_restore_stage()
	_get_mechanic().reset()
	_get_mechanic().set_interactive(true)


## Moves on after a win: in shuffle, to the next shuffle pick; otherwise to the next level, or after
## the difficulty's last level resets its save and shows the world-complete screen.
func _advance() -> void:
	# A fade this late means the player has already picked a level or gone home.
	if Transition.is_busy():
		return
	if GameRegistry.is_shuffle():
		_advance_shuffle()
		return
	var level_range: Vector2i = GameRegistry.get_level_range()
	if _current_index >= level_range.y:
		SaveManager.set_progress(_progress_key(), level_range.x + 1)
		_show_world_complete()
	else:
		SaveManager.save_progress(_progress_key(), _current_index + 2)
		_go_to_level(_current_index + 1)


func _advance_shuffle() -> void:
	SaveManager.set_progress(_progress_key(), _current_index + 2)
	var next_world: String = GameRegistry.next_shuffle_world()
	if next_world == "":
		_show_world_complete()
	elif next_world == _world_id():
		_go_to_level(_current_index + 1)
	else:
		GameRegistry.go_to_world(next_world)


func _show_world_complete() -> void:
	world_complete.emit()
	_hud.show_world_complete()
	AudioManager.play_sfx("complete")


func _play_world_sound(sound: String) -> void:
	AudioManager.play_sfx("%s/%s" % [_world_id(), sound])


# Loads where the current mode and difficulty left off, fading unless fade is false. A world whose
# shuffle levels are all played shows its last level while shuffle moves on to another world.
func _resume(fade: bool = true) -> void:
	var level_range: Vector2i = GameRegistry.get_level_range()
	var index: int = SaveManager.load_progress(_progress_key()) - 1
	if GameRegistry.is_shuffle() and index > level_range.y:
		_show_level(level_range.y, fade)
		GameRegistry.start_shuffle.call_deferred()
		return
	_show_level(clampi(index, level_range.x, level_range.y), fade)


# Plays the chosen level outside shuffle, switching difficulty if the level belongs to another.
func _choose_level(index: int, fade: bool = true) -> void:
	index = clampi(index, 0, _levels.size() - 1)
	if not GameRegistry.is_shuffle():
		var level_range: Vector2i = GameRegistry.get_level_range()
		if index < level_range.x or index > level_range.y:
			for difficulty in LevelLoader.DIFFICULTIES:
				var other: Vector2i = LevelLoader.get_difficulty_range(difficulty)
				if index >= other.x and index <= other.y:
					GameRegistry.set_difficulty(difficulty)
		SaveManager.set_progress(_progress_key(), index + 1)
	_show_level(index, fade)


func _show_level(index: int, fade: bool) -> void:
	if fade:
		_go_to_level(index)
	else:
		_load_level(index)


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
	var first: int = GameRegistry.get_level_range().x
	SaveManager.set_progress(_progress_key(), first + 1)
	_go_to_level(first)


func _on_difficulty_chosen(difficulty: String) -> void:
	GameRegistry.set_difficulty(difficulty)
	_resume()


func _on_shuffle_requested(from_start: bool) -> void:
	if from_start:
		GameRegistry.set_shuffle(true)
		GameRegistry.reset_shuffle()
		GameRegistry.start_shuffle()
	elif not GameRegistry.is_shuffle():
		GameRegistry.start_shuffle()

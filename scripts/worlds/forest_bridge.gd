extends Node2D

## Emitted when the player completes all levels in this world.
signal world_complete

# How far past the last plank the fox steps before falling, so it visibly walks off the end.
const _STEP_OFF_PX := 12.0

## Seconds the celebration plays at home before the next level loads.
@export var celebrate_duration: float = 1.5
## Fox walking speed, in px/s, onto a too-short bridge before it falls.
## Matches walk_across, which covers 1000 px in 2 s.
@export var walk_speed: float = 500.0
## Seed for puzzle generation. 0 picks a random seed, so every run gets different puzzles.
@export var puzzle_seed: int = 0

var _levels: Array[Dictionary] = []
var _current_index: int = 0
var _rng := RandomNumberGenerator.new()

@onready var _mechanic: Node2D = $BridgeLayer/PlacementMechanic
@onready var _character: AnimatedSprite2D = $Character
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _particles: GPUParticles2D = $CelebrationParticles
@onready var _retry_prompt: BaseButton = $RetryPrompt/RetryIcon


func _ready() -> void:
	_levels = LevelLoader.get_levels_for_world("forest")
	if puzzle_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = puzzle_seed
	_mechanic.correct.connect(_on_correct)
	_mechanic.incorrect.connect(_on_incorrect)
	_retry_prompt.pressed.connect(_on_retry_pressed)
	_retry_prompt.visible = false
	var start_index: int = clampi(SaveManager.load_progress("forest") - 1, 0, _levels.size() - 1)
	_load_level(start_index)


func _load_level(index: int) -> void:
	_current_index = index
	_restore_stage()
	var puzzle: Dictionary = PlankPuzzleGenerator.generate(_levels[index], _rng)
	_mechanic.setup(puzzle["bridge_length"], puzzle["plank_lengths"])
	_mechanic.set_interactive(true)


func _restore_stage() -> void:
	_anim.play("RESET")
	_anim.advance(0.0)
	_character.play("idle")


func _on_correct() -> void:
	_mechanic.set_interactive(false)
	_anim.play("walk_across")
	await _anim.animation_finished
	_character.play("celebrate")
	_particles.restart()
	await get_tree().create_timer(celebrate_duration).timeout
	if _current_index >= _levels.size() - 1:
		SaveManager.reset_progress("forest")
		world_complete.emit()
	else:
		SaveManager.save_progress("forest", _current_index + 2)
		_load_level(_current_index + 1)


func _on_incorrect() -> void:
	_mechanic.set_interactive(false)
	await _walk_to_bridge_end()
	_anim.play("bridge_collapse")
	await _anim.animation_finished
	_retry_prompt.visible = true


func _walk_to_bridge_end() -> void:
	var end_x: float = to_local(_mechanic.get_bridge_end_position()).x + _STEP_OFF_PX
	var distance: float = end_x - _character.position.x
	if distance <= 0.0:
		return
	_character.play("walk")
	var tween := create_tween()
	tween.tween_property(_character, "position:x", end_x, distance / walk_speed)
	await tween.finished


func _on_retry_pressed() -> void:
	_retry_prompt.visible = false
	_restore_stage()
	_mechanic.reset()
	_mechanic.set_interactive(true)

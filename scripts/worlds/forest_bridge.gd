extends WorldBase

## World 1: the fox builds a bridge from numbered planks that add up to the gap's length.

# How far past the last plank the fox steps before falling, so it visibly walks off the end.
const _STEP_OFF_PX := 12.0

## Fox walking speed, in px/s, onto a too-short bridge before it falls.
## Matches walk_across, which covers 1000 px in 2 s.
@export var walk_speed: float = 500.0

var _walk_tween: Tween

@onready var _mechanic: Node2D = $BridgeLayer/PlacementMechanic
@onready var _character: AnimatedSprite2D = $Character
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _particles: GPUParticles2D = $CelebrationParticles
@onready var _retry_prompt: BaseButton = $RetryPrompt/RetryIcon


func _ready() -> void:
	_mechanic.correct.connect(_on_correct)
	_mechanic.incorrect.connect(_on_incorrect)
	_retry_prompt.pressed.connect(_on_retry_pressed)
	_retry_prompt.visible = false
	super()


func _world_id() -> String:
	return "forest"


func _setup_level(level: Dictionary) -> void:
	_retry_prompt.visible = false
	_restore_stage()
	var puzzle: Dictionary = PlankPuzzleGenerator.generate(level, _rng)
	_mechanic.setup(puzzle["bridge_length"], puzzle["plank_lengths"])
	_mechanic.set_interactive(true)


func _restore_stage() -> void:
	if _walk_tween != null:
		_walk_tween.kill()
	_anim.play("RESET")
	_anim.advance(0.0)
	_character.play("idle")


func _on_correct() -> void:
	var load_count: int = _load_count
	_mechanic.set_interactive(false)
	_anim.play("walk_across")
	await _anim.animation_finished
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
	_mechanic.set_interactive(false)
	await _walk_to_bridge_end()
	if load_count != _load_count:
		return
	_anim.play("bridge_collapse")
	await _anim.animation_finished
	if load_count != _load_count:
		return
	_retry_prompt.visible = true


func _walk_to_bridge_end() -> void:
	var end_x: float = to_local(_mechanic.get_bridge_end_position()).x + _STEP_OFF_PX
	var distance: float = end_x - _character.position.x
	if distance <= 0.0:
		return
	_character.play("walk")
	_walk_tween = create_tween()
	_walk_tween.tween_property(_character, "position:x", end_x, distance / walk_speed)
	await _walk_tween.finished


func _on_retry_pressed() -> void:
	_retry_prompt.visible = false
	_restore_stage()
	_mechanic.reset()
	_mechanic.set_interactive(true)

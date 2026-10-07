extends Node2D

## Emitted when the player completes all levels in this world.
signal world_complete

## Seconds the celebration plays at home before the next level loads.
@export var celebrate_duration: float = 1.5

var _levels: Array[Dictionary] = []
var _current_index: int = 0

@onready var _mechanic: Node2D = $BridgeLayer/PlacementMechanic
@onready var _character: AnimatedSprite2D = $Character
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _particles: GPUParticles2D = $CelebrationParticles
@onready var _retry_prompt: BaseButton = $RetryPrompt/RetryIcon


func _ready() -> void:
	_levels = LevelLoader.get_levels_for_world("forest")
	_mechanic.correct.connect(_on_correct)
	_mechanic.incorrect.connect(_on_incorrect)
	_retry_prompt.pressed.connect(_on_retry_pressed)
	_retry_prompt.visible = false
	var start_index: int = clampi(SaveManager.load_progress("forest") - 1, 0, _levels.size() - 1)
	_load_level(start_index)


func _load_level(index: int) -> void:
	_current_index = index
	_restore_stage()
	_mechanic.target_count = _levels[index]["target_count"]
	_mechanic.reset()
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
	_anim.play("bridge_collapse")
	await _anim.animation_finished
	_retry_prompt.visible = true


func _on_retry_pressed() -> void:
	_retry_prompt.visible = false
	_restore_stage()
	_mechanic.reset()
	_mechanic.set_interactive(true)

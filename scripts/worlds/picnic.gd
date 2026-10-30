extends WorldBase

## World 4: the fox and its friends share a picnic. The child fills the fox's plate and the
## baskets deal the same to every friend. A fair share makes everyone cheer; an unfair one makes
## the fox sad, and the child tries again.

## Seconds the sad fox shows before the retry prompt appears.
@export var sad_duration: float = 0.8

@onready var _mechanic: SharingMechanic = $SharingMechanic
@onready var _character: AnimatedSprite2D = $Character
@onready var _particles: GPUParticles2D = $CelebrationParticles
@onready var _retry_prompt: BaseButton = $RetryPrompt/RetryIcon


func _ready() -> void:
	_mechanic.correct.connect(_on_correct)
	_mechanic.incorrect.connect(_on_incorrect)
	_retry_prompt.pressed.connect(_on_retry_pressed)
	_retry_prompt.visible = false
	super()


func _world_id() -> String:
	return "picnic"


func _setup_level(level: Dictionary) -> void:
	_restore_stage()
	var puzzle: Dictionary = SharingPuzzleGenerator.generate(level, _rng)
	_mechanic.setup(puzzle["plates"], puzzle["orders"])
	_mechanic.set_interactive(true)


func _restore_stage() -> void:
	_retry_prompt.visible = false
	_character.play("idle")


func _on_correct() -> void:
	var load_count: int = _load_count
	_character.play("celebrate")
	_particles.restart()
	await get_tree().create_timer(celebrate_duration).timeout
	if load_count != _load_count:
		return
	_advance()


func _on_incorrect() -> void:
	var load_count: int = _load_count
	_character.play("sad")
	await get_tree().create_timer(sad_duration).timeout
	if load_count != _load_count:
		return
	_retry_prompt.visible = true


func _on_retry_pressed() -> void:
	_restore_stage()
	_mechanic.reset()
	_mechanic.set_interactive(true)

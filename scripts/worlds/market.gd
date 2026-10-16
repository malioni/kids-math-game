extends WorldBase

## World 3: a customer orders an amount of produce, and the child fills it with equal-sized bags.
## A right order makes the customer cheer; a wrong one gets a tomato thrown at the table.

# Where the tomato leaves the customer's hand, relative to the customer.
const _HAND_OFFSET := Vector2(70, -90)

## Seconds the thrown tomato takes to reach the table.
@export var throw_duration: float = 0.5
## Seconds the splat stays before the retry prompt appears.
@export var splat_duration: float = 0.6

var _throw_tween: Tween

@onready var _mechanic: MarketMechanic = $MarketMechanic
@onready var _customer: AnimatedSprite2D = $Customer
@onready var _flying_tomato: Sprite2D = $FlyingTomato
@onready var _splat: Sprite2D = $Splat
@onready var _particles: GPUParticles2D = $CelebrationParticles
@onready var _retry_prompt: BaseButton = $RetryPrompt/RetryIcon


func _ready() -> void:
	_mechanic.correct.connect(_on_correct)
	_mechanic.incorrect.connect(_on_incorrect)
	_retry_prompt.pressed.connect(_on_retry_pressed)
	_retry_prompt.visible = false
	super()


func _world_id() -> String:
	return "market"


func _setup_level(level: Dictionary) -> void:
	_restore_stage()
	_mechanic.setup(MarketPuzzleGenerator.generate(level, _rng))
	_mechanic.set_interactive(true)


func _restore_stage() -> void:
	if _throw_tween != null:
		_throw_tween.kill()
	_retry_prompt.visible = false
	_flying_tomato.visible = false
	_splat.visible = false
	_customer.play("idle")


func _on_correct() -> void:
	var load_count: int = _load_count
	_mechanic.set_interactive(false)
	_customer.play("celebrate")
	_particles.restart()
	await get_tree().create_timer(celebrate_duration).timeout
	if load_count != _load_count:
		return
	_advance()


func _on_incorrect() -> void:
	var load_count: int = _load_count
	_mechanic.set_interactive(false)
	_customer.play("throw")
	await _customer.animation_finished
	if load_count != _load_count:
		return
	_flying_tomato.position = _customer.position + _HAND_OFFSET
	_flying_tomato.scale = Vector2(0.6, 0.6)
	_flying_tomato.rotation = 0.0
	_flying_tomato.visible = true
	_throw_tween = create_tween().set_parallel()
	_throw_tween.tween_property(_flying_tomato, "position", _splat.position, throw_duration)
	_throw_tween.tween_property(_flying_tomato, "scale", Vector2(1.6, 1.6), throw_duration)
	_throw_tween.tween_property(_flying_tomato, "rotation", TAU, throw_duration)
	await _throw_tween.finished
	if load_count != _load_count:
		return
	_flying_tomato.visible = false
	_splat.visible = true
	_customer.play("idle")
	await get_tree().create_timer(splat_duration).timeout
	if load_count != _load_count:
		return
	_retry_prompt.visible = true


func _on_retry_pressed() -> void:
	_restore_stage()
	_mechanic.reset()
	_mechanic.set_interactive(true)

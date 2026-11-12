extends WorldBase

## World 3: the fox orders an amount of produce, and the child fills the order with equal-sized
## bags. A right order makes the fox cheer; a wrong one gets a tomato thrown at the table.

# Where the tomato leaves the fox's paw, relative to the fox.
const _HAND_OFFSET := Vector2(50, -20)

## Seconds the thrown tomato takes to reach the table.
@export var throw_duration: float = 0.5
## Seconds the splat stays before the retry prompt appears.
@export var splat_duration: float = 0.6

var _throw_tween: Tween

@onready var _mechanic: MarketMechanic = $MarketMechanic
@onready var _flying_tomato: Sprite2D = $FlyingTomato
@onready var _splat: Sprite2D = $Splat


func _world_id() -> String:
	return "market"


func _get_mechanic() -> Mechanic:
	return _mechanic


func _setup_level(level: Dictionary) -> void:
	_mechanic.setup(MarketPuzzleGenerator.generate(level, _rng))


func _restore_stage() -> void:
	if _throw_tween != null:
		_throw_tween.kill()
	_flying_tomato.visible = false
	_splat.visible = false
	super()


func _play_lose() -> void:
	_character.play("throw")
	await _character.animation_finished
	_flying_tomato.position = _character.position + _HAND_OFFSET
	_flying_tomato.scale = Vector2(0.6, 0.6)
	_flying_tomato.rotation = 0.0
	_flying_tomato.visible = true
	_throw_tween = create_tween().set_parallel()
	_throw_tween.tween_property(_flying_tomato, "position", _splat.position, throw_duration)
	_throw_tween.tween_property(_flying_tomato, "scale", Vector2(1.6, 1.6), throw_duration)
	_throw_tween.tween_property(_flying_tomato, "rotation", TAU, throw_duration)
	await _throw_tween.finished
	_flying_tomato.visible = false
	_splat.visible = true
	AudioManager.play_sfx("market/splat")
	_character.play("idle")
	await get_tree().create_timer(splat_duration).timeout

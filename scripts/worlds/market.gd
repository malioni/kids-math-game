extends WorldBase

## World 3: the fox orders an amount of produce, and the child fills the order with equal-sized
## bags. A right order makes the fox cheer; a wrong one gets a tomato lobbed at the table.

# Where the tomato leaves the fox's paw, relative to the fox. tools/make_fox_sheets.gd prints it.
const _HAND_OFFSET := Vector2(56, 34)
# The throw animation's frame on which the paw lets go.
const _RELEASE_FRAME := 3
# How far above the straight line from paw to table the tomato peaks, in px.
const _ARC_HEIGHT := 120.0
# Seconds the splat takes to pop to full size.
const _SPLAT_POP := 0.15

## Seconds the thrown tomato takes to reach the table.
@export var throw_duration: float = 0.5
## Seconds the splat stays before the retry prompt appears.
@export var splat_duration: float = 0.6

var _throw_tween: Tween
var _splat_tween: Tween
var _throw_from: Vector2

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
	if _splat_tween != null:
		_splat_tween.kill()
	_flying_tomato.visible = false
	_splat.visible = false
	super()


func _play_lose() -> void:
	# A level change mid-throw leaves this waiting; the check stops it from joining the next throw.
	var load_count: int = _load_count
	_character.play("throw")
	# A slow frame can skip past the release frame, so wait for it or any later one. A level change
	# or a retry plays idle, which ends the wait.
	while _character.animation == &"throw" and _character.frame < _RELEASE_FRAME:
		await _character.frame_changed
	if _character.animation != &"throw" or load_count != _load_count:
		return
	_throw_from = _character.position + _HAND_OFFSET
	_set_flight(0.0)
	_flying_tomato.visible = true
	_throw_tween = create_tween()
	_throw_tween.tween_method(_set_flight, 0.0, 1.0, throw_duration)
	await _throw_tween.finished
	if load_count != _load_count:
		return
	_flying_tomato.visible = false
	_splat.scale = Vector2(0.6, 0.6)
	_splat.visible = true
	_splat_tween = create_tween()
	_splat_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_splat_tween.tween_property(_splat, "scale", Vector2.ONE, _SPLAT_POP)
	AudioManager.play_sfx("market/splat")
	await get_tree().create_timer(splat_duration).timeout


# Puts the thrown tomato at `progress` along its arc: 0 at the paw, 1 at the table.
func _set_flight(progress: float) -> void:
	var hump: float = _ARC_HEIGHT * 4.0 * progress * (1.0 - progress)
	_flying_tomato.position = _throw_from.lerp(_splat.position, progress) + Vector2.UP * hump
	_flying_tomato.scale = Vector2.ONE * lerpf(0.6, 1.6, progress)
	_flying_tomato.rotation = TAU * progress


func _on_character_animation_finished() -> void:
	if _character.animation == &"throw":
		_character.play("idle")

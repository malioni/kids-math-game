extends WorldBase

## World 2: the fox floats in a basket under numbered balloons that lift more than the basket
## weighs, so it keeps rising. Popping balloons that add up to the extra lift levels it out;
## popping too many makes it fall.

enum State { RISING, LEVEL, FALLING }

## Cloud scroll speed, in px/s, per unit of extra lift, so the child sees the basket slow down
## as they pop.
@export var rise_speed_per_unit: float = 30.0
## Fastest the clouds scroll, in px/s.
@export var max_cloud_speed: float = 360.0
## How quickly the cloud speed changes, in px/s².
@export var cloud_acceleration: float = 600.0
## Seconds the basket takes to fall off the bottom of the screen.
@export var fall_duration: float = 0.9
## How far, in px, the basket falls.
@export var fall_distance: float = 750.0
## Height, in px, of the basket's gentle bob.
@export var bob_height: float = 8.0

var _state: State = State.RISING
var _time: float = 0.0
var _cloud_speed: float = 0.0
var _rig_home: Vector2 = Vector2.ZERO
var _rig_tween: Tween

@onready var _rig: Node2D = $Rig
@onready var _mechanic: BalloonPopMechanic = $Rig/BalloonPopMechanic
@onready var _character: AnimatedSprite2D = $Rig/Character
@onready var _clouds: Node2D = $Clouds
@onready var _particles: GPUParticles2D = $CelebrationParticles
@onready var _retry_prompt: BaseButton = $RetryPrompt/RetryIcon


func _ready() -> void:
	_rig_home = _rig.position
	_mechanic.correct.connect(_on_correct)
	_mechanic.incorrect.connect(_on_incorrect)
	_retry_prompt.pressed.connect(_on_retry_pressed)
	_retry_prompt.visible = false
	super()


func _process(delta: float) -> void:
	_time += delta
	var target_speed: float = 0.0
	if _state == State.RISING:
		target_speed = clampf(_mechanic.get_balance() * rise_speed_per_unit, 0.0, max_cloud_speed)
	elif _state == State.FALLING:
		target_speed = -max_cloud_speed
	_cloud_speed = move_toward(_cloud_speed, target_speed, cloud_acceleration * delta)
	_scroll_clouds(delta)
	if _state != State.FALLING:
		_rig.position.y = _rig_home.y + sin(_time * 2.0) * bob_height


## Returns true while the basket is rising (more lift than weight, nothing decided yet).
func is_rising() -> bool:
	return _state == State.RISING


## Returns true once the basket has levelled out.
func is_level() -> bool:
	return _state == State.LEVEL


## Returns true while the basket is falling or has fallen.
func is_falling() -> bool:
	return _state == State.FALLING


func _world_id() -> String:
	return "sky"


func _setup_level(level: Dictionary) -> void:
	_retry_prompt.visible = false
	_restore_stage()
	var puzzle: Dictionary = BalloonPuzzleGenerator.generate(level, _rng)
	_mechanic.setup(puzzle["target"], puzzle["balloon_values"])
	_mechanic.set_interactive(true)


func _restore_stage() -> void:
	if _rig_tween != null:
		_rig_tween.kill()
	_rig.position = _rig_home
	_state = State.RISING
	_character.play("idle")


func _on_correct() -> void:
	var load_count: int = _load_count
	_state = State.LEVEL
	_mechanic.set_interactive(false)
	_character.play("celebrate")
	_particles.restart()
	await get_tree().create_timer(celebrate_duration).timeout
	if load_count != _load_count:
		return
	_advance()


func _on_incorrect() -> void:
	var load_count: int = _load_count
	_state = State.FALLING
	_mechanic.set_interactive(false)
	_character.play("fall")
	_rig_tween = create_tween()
	_rig_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_rig_tween.tween_property(_rig, "position:y", _rig.position.y + fall_distance, fall_duration)
	await _rig_tween.finished
	if load_count != _load_count:
		return
	_retry_prompt.visible = true


func _on_retry_pressed() -> void:
	_retry_prompt.visible = false
	_restore_stage()
	_mechanic.reset()
	_mechanic.set_interactive(true)


# Clouds further back (smaller) move slower, for a little depth. They wrap top to bottom.
func _scroll_clouds(delta: float) -> void:
	for cloud: Node2D in _clouds.get_children():
		cloud.position.y += _cloud_speed * delta * cloud.scale.x
		if cloud.position.y > 960.0:
			cloud.position.y -= 1200.0
		elif cloud.position.y < -240.0:
			cloud.position.y += 1200.0

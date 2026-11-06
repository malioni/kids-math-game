extends WorldBase

## World 1: the fox builds a bridge from numbered planks that add up to the gap's length.

# How far past the last plank the fox steps before falling, so it visibly walks off the end.
const _STEP_OFF_PX := 12.0

## Fox walking speed, in px/s, onto a too-short bridge before it falls.
## Matches walk_across, which covers 1000 px in 2 s.
@export var walk_speed: float = 500.0

var _walk_tween: Tween

@onready var _mechanic: PlacementMechanic = $BridgeLayer/PlacementMechanic
@onready var _anim: AnimationPlayer = $AnimationPlayer


func _world_id() -> String:
	return "forest"


func _get_mechanic() -> Mechanic:
	return _mechanic


func _setup_level(level: Dictionary) -> void:
	var puzzle: Dictionary = PlankPuzzleGenerator.generate(level, _rng)
	_mechanic.setup(puzzle["bridge_length"], puzzle["plank_lengths"])


func _restore_stage() -> void:
	if _walk_tween != null:
		_walk_tween.kill()
	_anim.play("RESET")
	_anim.advance(0.0)
	super()


func _play_win() -> void:
	_anim.play("walk_across")
	await _anim.animation_finished


func _play_lose() -> void:
	await _walk_to_bridge_end()
	_anim.play("bridge_collapse")
	await _anim.animation_finished


func _walk_to_bridge_end() -> void:
	var end_x: float = to_local(_mechanic.get_bridge_end_position()).x + _STEP_OFF_PX
	var distance: float = end_x - _character.position.x
	if distance <= 0.0:
		return
	_character.play("walk")
	_walk_tween = create_tween()
	_walk_tween.tween_property(_character, "position:x", end_x, distance / walk_speed)
	await _walk_tween.finished

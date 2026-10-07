class_name PlankDrag
extends Node2D

## A plank the player can drag with a finger or mouse.

## Emitted when the player releases a drag, with the plank's global position.
signal dropped(release_position: Vector2)

const BOUNCE_DURATION := 0.25
const DRAG_Z_INDEX := 10

## When false, the plank ignores pointer input.
var interactive: bool = true

var _origin: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _grab_offset: Vector2 = Vector2.ZERO
var _locked: bool = false
var _base_z_index: int = 0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shadow: Sprite2D = $Shadow


func _ready() -> void:
	_origin = position


func _unhandled_input(event: InputEvent) -> void:
	if not interactive or _locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pointer: Vector2 = _pointer_global(event)
		if event.pressed and not _dragging and _contains_global_point(pointer):
			_begin_drag(pointer)
			get_viewport().set_input_as_handled()
		elif not event.pressed and _dragging:
			_end_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		global_position = _pointer_global(event) + _grab_offset
		get_viewport().set_input_as_handled()


## Tweens the plank back to where it was before the current drag began.
func bounce_back() -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position", _origin, BOUNCE_DURATION)


## Fixes the plank in place so it can no longer be dragged.
func lock() -> void:
	_locked = true


## Returns true while the player is holding the plank.
func is_dragging() -> bool:
	return _dragging


func _begin_drag(pointer: Vector2) -> void:
	_dragging = true
	_origin = position
	_grab_offset = global_position - pointer
	_base_z_index = z_index
	z_index = DRAG_Z_INDEX
	_shadow.visible = true


func _end_drag() -> void:
	_dragging = false
	z_index = _base_z_index
	_shadow.visible = false
	dropped.emit(global_position)


func _contains_global_point(point: Vector2) -> bool:
	return _sprite.get_rect().has_point(_sprite.to_local(point))


func _pointer_global(event: InputEvent) -> Vector2:
	return get_canvas_transform().affine_inverse() * event.position

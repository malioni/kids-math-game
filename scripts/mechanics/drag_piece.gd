class_name DragPiece
extends Node2D

## A piece the player can drag with a finger or mouse, or tap. Subclass scenes must have a
## [code]Body[/code] Control (the grab area) and a [code]Shadow[/code] CanvasItem shown only while
## the piece is dragged.

## Emitted when the player releases a drag, with the piece's global position.
signal dropped(release_position: Vector2)
## Emitted when the player presses and releases without moving more than TAP_THRESHOLD.
signal tapped

## Seconds the piece takes to tween back home.
const BOUNCE_DURATION := 0.25
## Seconds move_to() takes.
const MOVE_DURATION := 0.2
## z_index applied to the piece while it is being dragged.
const DRAG_Z_INDEX := 10
## Pointer travel, in pixels, below which a press and release counts as a tap.
const TAP_THRESHOLD := 12.0

## When false, the piece ignores pointer input. Setting it false mid-drag cancels the drag.
var interactive: bool = true:
	set(value):
		interactive = value
		if not interactive:
			_pressing = false
			if _dragging:
				cancel_drag()

## True while the piece is placed. Placed pieces can be tapped but not dragged.
var is_placed: bool = false
## Position in the parent's space that bounce_back() returns to.
var home: Vector2 = Vector2.ZERO

var _dragging: bool = false
var _pressing: bool = false
var _press_point: Vector2 = Vector2.ZERO
var _grab_offset: Vector2 = Vector2.ZERO
var _base_z_index: int = 0
var _tween: Tween

@onready var _body: Control = $Body
@onready var _shadow: CanvasItem = $Shadow


func _ready() -> void:
	home = position


func _unhandled_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pointer: Vector2 = _pointer_global(event)
		if event.pressed and not _pressing and _contains_global_point(pointer):
			_begin_press(pointer)
			get_viewport().set_input_as_handled()
		elif not event.pressed and _pressing:
			_end_press(pointer)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		global_position = _pointer_global(event) + _grab_offset
		get_viewport().set_input_as_handled()


## Tweens the piece back to home.
func bounce_back() -> void:
	_tween_to(home, BOUNCE_DURATION, Tween.TRANS_BACK)


## Tweens the piece to target (in the parent's space).
func move_to(target: Vector2) -> void:
	_tween_to(target, MOVE_DURATION, Tween.TRANS_QUAD)


## Aborts the current drag without emitting dropped and bounces the piece back.
func cancel_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	_pressing = false
	z_index = _base_z_index
	_shadow.visible = false
	bounce_back()


## Returns true while the player is holding the piece.
func is_dragging() -> bool:
	return _dragging


## Extra grab area around Body on each side. Subclasses override to enlarge small pieces.
func _touch_padding() -> Vector2:
	return Vector2.ZERO


func _begin_press(pointer: Vector2) -> void:
	_pressing = true
	_press_point = pointer
	if is_placed:
		return
	if _tween != null:
		_tween.kill()
	_dragging = true
	_grab_offset = global_position - pointer
	_base_z_index = z_index
	z_index = DRAG_Z_INDEX
	_shadow.visible = true


func _end_press(pointer: Vector2) -> void:
	_pressing = false
	var was_dragging := _dragging
	if _dragging:
		_dragging = false
		z_index = _base_z_index
		_shadow.visible = false
	if pointer.distance_to(_press_point) < TAP_THRESHOLD:
		if was_dragging:
			position = home
		tapped.emit()
	elif was_dragging:
		dropped.emit(global_position)


func _tween_to(target: Vector2, duration: float, trans: Tween.TransitionType) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(trans)
	_tween.tween_property(self, "position", target, duration)


func _contains_global_point(point: Vector2) -> bool:
	var padding: Vector2 = _touch_padding()
	var area := _body.get_rect().grow_individual(padding.x, padding.y, padding.x, padding.y)
	return area.has_point(to_local(point))


func _pointer_global(event: InputEvent) -> Vector2:
	return get_canvas_transform().affine_inverse() * event.position

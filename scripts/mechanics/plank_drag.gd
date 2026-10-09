class_name PlankDrag
extends Node2D

## A numbered plank the player can drag with a finger or mouse. Its drawn width is
## proportional to its length.

## Emitted when the player releases a drag, with the plank's global position.
signal dropped(release_position: Vector2)
## Emitted when the player presses and releases without moving more than TAP_THRESHOLD.
signal tapped

## Seconds the plank takes to tween back home.
const BOUNCE_DURATION := 0.25
## Seconds move_to() takes.
const MOVE_DURATION := 0.2
## z_index applied to the plank while it is being dragged.
const DRAG_Z_INDEX := 10
## Pointer travel, in pixels, below which a press and release counts as a tap.
const TAP_THRESHOLD := 12.0
## Drawn height of the plank in pixels. 64 keeps it near Apple's 44 pt minimum on a phone.
const PLANK_HEIGHT := 64.0
## Extra touch area around the drawn plank, so small fingers and narrow planks are easy to grab.
## Horizontal padding is half the pile spacing, so neighbouring planks' areas don't overlap.
const TOUCH_PADDING := Vector2(8, 6)

## When false, the plank ignores pointer input. Setting it false mid-drag cancels the drag.
var interactive: bool = true:
	set(value):
		interactive = value
		if not interactive:
			_pressing = false
			if _dragging:
				cancel_drag()

## The plank's length in puzzle units.
var length: int = 0
## True while the plank sits on the bridge. Placed planks can be tapped but not dragged.
var is_placed: bool = false
## Position in the parent's space that bounce_back() returns to.
var home: Vector2 = Vector2.ZERO

var _dragging: bool = false
var _pressing: bool = false
var _press_point: Vector2 = Vector2.ZERO
var _grab_offset: Vector2 = Vector2.ZERO
var _base_z_index: int = 0
var _tween: Tween

@onready var _body: NinePatchRect = $Body
@onready var _shadow: NinePatchRect = $Shadow
@onready var _label: Label = $Body/LengthLabel


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


## Sets the plank's length and sizes it to length_units * unit_px pixels wide.
func configure(length_units: int, unit_px: float) -> void:
	length = length_units
	var size := Vector2(length_units * unit_px, PLANK_HEIGHT)
	for rect: NinePatchRect in [$Body, $Shadow]:
		rect.size = size
		rect.position = -size / 2.0
	$Shadow.position += Vector2(4, 8)
	$Body/LengthLabel.text = str(length_units)


## Returns the plank's drawn width in pixels.
func get_width() -> float:
	return $Body.size.x


## Tweens the plank back to home.
func bounce_back() -> void:
	_tween_to(home, BOUNCE_DURATION, Tween.TRANS_BACK)


## Tweens the plank to target (in the parent's space).
func move_to(target: Vector2) -> void:
	_tween_to(target, MOVE_DURATION, Tween.TRANS_QUAD)


## Aborts the current drag without emitting dropped and bounces the plank back.
func cancel_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	_pressing = false
	z_index = _base_z_index
	_shadow.visible = false
	bounce_back()


## Returns true while the player is holding the plank.
func is_dragging() -> bool:
	return _dragging


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
	var area := _body.get_rect().grow_individual(
		TOUCH_PADDING.x, TOUCH_PADDING.y, TOUCH_PADDING.x, TOUCH_PADDING.y
	)
	return area.has_point(to_local(point))


func _pointer_global(event: InputEvent) -> Vector2:
	return get_canvas_transform().affine_inverse() * event.position

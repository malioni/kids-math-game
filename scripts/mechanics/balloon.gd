class_name Balloon
extends Node2D

## A numbered balloon on a string. Bigger numbers are drawn bigger. Pressing it emits tapped;
## the owner decides whether to pop() it.

## Emitted when the player presses the balloon.
signal tapped

## Radius, in pixels, of the balloon texture's round body at scale 1.
const TEXTURE_RADIUS := 60.0
## Seconds the pop animation takes.
const POP_DURATION := 0.15
## Extra touch radius around the drawn balloon, so small fingers hit small balloons.
const TOUCH_PADDING := 8.0
## Colour of the string.
const STRING_COLOR := Color(0.35, 0.35, 0.35)

## When false, the balloon ignores pointer input.
var interactive: bool = true
## The balloon's number.
var value: int = 0
## Drawn radius of the balloon body, in pixels.
var radius: float = TEXTURE_RADIUS
## True once the balloon has popped.
var is_popped: bool = false

var _string_end: Vector2 = Vector2.ZERO

@onready var _body: Sprite2D = $Body
@onready var _label: Label = $Body/ValueLabel


func _unhandled_input(event: InputEvent) -> void:
	if not interactive or is_popped:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pointer: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if contains_global_point(pointer):
			get_viewport().set_input_as_handled()
			tapped.emit()


## Sets the number, drawn radius and colour. string_end is where the string is tied, in this
## balloon's local space.
func configure(
	balloon_value: int, balloon_radius: float, color: Color, string_end: Vector2
) -> void:
	value = balloon_value
	radius = balloon_radius
	_string_end = string_end
	$Body.scale = Vector2.ONE * (balloon_radius / TEXTURE_RADIUS)
	$Body.self_modulate = color
	$Body/ValueLabel.text = str(balloon_value)
	queue_redraw()


## Pops the balloon: it bursts, disappears and stops taking input.
func pop() -> void:
	if is_popped:
		return
	is_popped = true
	var tween := create_tween().set_parallel()
	tween.tween_property(_body, "scale", _body.scale * 1.35, POP_DURATION)
	tween.tween_property(self, "modulate:a", 0.0, POP_DURATION)
	tween.chain().tween_callback(hide)


## Returns true if global_point is on the balloon (including its touch padding).
func contains_global_point(global_point: Vector2) -> bool:
	return to_local(global_point).length() <= radius + TOUCH_PADDING


func _draw() -> void:
	draw_line(Vector2(0, radius + radius * 0.2), _string_end, STRING_COLOR, 2.0, true)

class_name MemoryCard
extends Node2D

## One memory card: a leaf back and an animal face. Pressing it emits tapped; the owner decides
## whether to turn it over.

## Emitted when the player presses the card.
signal tapped

## Width and height, in pixels, of the card textures at scale 1.
const TEXTURE_SIZE := 160.0
## Seconds a full turn takes, half to squash the card flat and half to open it on the other side.
const TURN_DURATION := 0.16
## Seconds the matched pop and fade takes.
const MATCH_DURATION := 0.25

## When false, the card ignores pointer input.
var interactive: bool = true

var _animal: String = ""
var _size: float = TEXTURE_SIZE
var _face_up: bool = false
var _matched: bool = false
var _turn_tween: Tween

@onready var _body: Node2D = $Body
@onready var _back: Sprite2D = $Body/Back
@onready var _front: Sprite2D = $Body/Front
@onready var _face: Sprite2D = $Body/Front/Face


func _unhandled_input(event: InputEvent) -> void:
	if not interactive or _matched:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var pointer: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if contains_global_point(pointer):
			get_viewport().set_input_as_handled()
			tapped.emit()


## Sets the card's animal, the face texture drawn on its front and its width and height in pixels.
## The card starts face down.
func setup(animal: String, face_texture: Texture2D, card_size: float) -> void:
	_animal = animal
	_size = card_size
	_face.texture = face_texture
	_body.scale = Vector2.ONE * _body_scale()
	show_back(false)


## Returns the card's animal.
func get_animal() -> String:
	return _animal


## Returns the card's width and height in pixels.
func get_size() -> float:
	return _size


## Returns true while the animal is showing.
func is_face_up() -> bool:
	return _face_up


## Returns true once the card has been matched.
func is_matched() -> bool:
	return _matched


## Turns the card face up, with a turning animation unless animated is false.
func show_face(animated: bool = true) -> void:
	_turn(true, animated)


## Turns the card face down, with a turning animation unless animated is false.
func show_back(animated: bool = true) -> void:
	_turn(false, animated)


## Marks the card matched: it pops, fades out and stops taking input.
func mark_matched() -> void:
	_matched = true
	if _turn_tween != null:
		_turn_tween.kill()
	var tween := create_tween().set_parallel()
	tween.tween_property(_body, "scale", Vector2.ONE * _body_scale() * 1.2, MATCH_DURATION)
	tween.tween_property(self, "modulate:a", 0.0, MATCH_DURATION)
	tween.chain().tween_callback(hide)


## Returns true if global_point is on the card.
func contains_global_point(global_point: Vector2) -> bool:
	return Rect2(-_size / 2.0, -_size / 2.0, _size, _size).has_point(to_local(global_point))


func _turn(face_up: bool, animated: bool) -> void:
	_face_up = face_up
	if _turn_tween != null:
		_turn_tween.kill()
	if not animated:
		_show_side()
		_body.scale.x = _body_scale()
		return
	_turn_tween = create_tween()
	_turn_tween.tween_property(_body, "scale:x", 0.0, TURN_DURATION / 2.0)
	_turn_tween.tween_callback(_show_side)
	_turn_tween.tween_property(_body, "scale:x", _body_scale(), TURN_DURATION / 2.0)


func _show_side() -> void:
	_back.visible = not _face_up
	_front.visible = _face_up


func _body_scale() -> float:
	return _size / TEXTURE_SIZE

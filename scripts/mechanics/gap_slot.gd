class_name GapSlot
extends Area2D

## A single gap that accepts exactly one plank.

## Texture shown while the slot is empty.
@export var empty_texture: Texture2D
## Texture shown once a plank is locked in.
@export var filled_texture: Texture2D
## True once a plank has been snapped into this slot.
@export var is_occupied: bool = false

@onready var _sprite: Sprite2D = $Sprite2D


## Marks the slot as holding a plank and shows the filled texture.
func occupy() -> void:
	is_occupied = true
	_sprite.texture = filled_texture


## Clears the slot and restores the empty texture.
func vacate() -> void:
	is_occupied = false
	_sprite.texture = empty_texture

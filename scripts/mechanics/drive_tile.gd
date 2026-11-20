class_name DriveTile
extends TextureButton

## One tile in the drive program strip: a command icon and, above 1, how many times it runs. Lit
## while the car runs it; marked where the last run went wrong.

## Tint of the frame while the car runs this tile.
const LIT_TINT := Color(1.0, 0.86, 0.45)
## Tint of the frame where the last run went wrong.
const MARKED_TINT := Color(1.0, 0.6, 0.55)

var _lit: bool = false
var _marked: bool = false

@onready var _icon: TextureRect = $Icon
@onready var _count: Label = $Count


## Shows icon, and count when it is above 1.
func setup(icon: Texture2D, count: int) -> void:
	_icon.texture = icon
	_count.text = str(count)
	_count.visible = count > 1


## Lights the tile, or turns the light off.
func set_lit(lit: bool) -> void:
	_lit = lit
	_tint()


## Marks the tile as where the last run went wrong, or clears the mark.
func set_marked(marked: bool) -> void:
	_marked = marked
	_tint()


## Returns true while the tile is lit.
func is_lit() -> bool:
	return _lit


## Returns true while the tile is marked.
func is_marked() -> bool:
	return _marked


func _tint() -> void:
	if _lit:
		self_modulate = LIT_TINT
	elif _marked:
		self_modulate = MARKED_TINT
	else:
		self_modulate = Color.WHITE

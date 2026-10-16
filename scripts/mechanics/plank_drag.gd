class_name PlankDrag
extends DragPiece

## A numbered plank the player can drag with a finger or mouse. Its drawn width is
## proportional to its length.

## Drawn height of the plank in pixels. 64 keeps it near Apple's 44 pt minimum on a phone.
const PLANK_HEIGHT := 64.0
## Extra touch area around the drawn plank, so small fingers and narrow planks are easy to grab.
## Horizontal padding is half the pile spacing, so neighbouring planks' areas don't overlap.
const TOUCH_PADDING := Vector2(8, 6)

## The plank's length in puzzle units.
var length: int = 0


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


func _touch_padding() -> Vector2:
	return TOUCH_PADDING

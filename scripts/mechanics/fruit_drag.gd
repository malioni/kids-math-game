class_name FruitDrag
extends DragPiece

## One piece of fruit the player can drag with a finger or mouse, or tap.

## Extra touch area around the drawn fruit.
const TOUCH_PADDING := Vector2(8, 8)

## Id of the fruit (e.g. "strawberry").
var item: String = ""


## Sets the fruit's id and shows its icon.
func configure(item_id: String, icon: Texture2D) -> void:
	item = item_id
	$Body.texture = icon
	$Shadow.texture = icon


## Returns the fruit's drawn width in pixels.
func get_width() -> float:
	return $Body.size.x


func _touch_padding() -> Vector2:
	return TOUCH_PADDING

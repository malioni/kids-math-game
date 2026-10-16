class_name BagDrag
extends DragPiece

## A bag of one kind of item the player can drag with a finger or mouse. It shows how many items
## it holds and an icon of the item.

## Extra touch area around the drawn bag.
const TOUCH_PADDING := Vector2(6, 6)

## Id of the item the bag holds (e.g. "tomato").
var item: String = ""
## How many items the bag holds.
var bag_size: int = 0


## Sets the bag's item and size, and shows the size and the item's icon.
func configure(item_id: String, size: int, icon: Texture2D) -> void:
	item = item_id
	bag_size = size
	$Body/SizeLabel.text = str(size)
	$Body/Icon.texture = icon


## Returns the bag's drawn width in pixels.
func get_width() -> float:
	return $Body.size.x


func _touch_padding() -> Vector2:
	return TOUCH_PADDING

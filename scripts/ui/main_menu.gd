class_name MainMenu
extends Control

## Start screen: Play continues where the child left off (the last world, in the saved mode, so a
## shuffle carries on), Shuffle starts or continues a shuffle, and the carousel has a card per
## registered world. Tapping the centred card opens that world at its saved level and leaves
## shuffle; tapping a card beside it only slides it to the centre. No text anywhere.

@onready var _carousel: WorldCarousel = $PlayArea/WorldCarousel
@onready var _play_button: TextureButton = $PlayArea/PlayButton
@onready var _shuffle_button: TextureButton = $PlayArea/ShuffleButton


func _ready() -> void:
	var items: Array[Dictionary] = []
	for world in GameRegistry.get_worlds():
		items.append({"id": world["id"], "icon": load(world["icon"])})
	_carousel.set_items(items)
	_carousel.scroll_to(SaveManager.load_last_world(), false)
	_carousel.card_pressed.connect(_on_card_pressed)
	_play_button.pressed.connect(GameRegistry.start_last_world)
	_shuffle_button.pressed.connect(GameRegistry.start_shuffle)
	$PlayArea/Fox.play("idle")


## Returns the world carousel.
func get_carousel() -> WorldCarousel:
	return _carousel


## Returns the Play (continue) button.
func get_play_button() -> TextureButton:
	return _play_button


## Returns the Shuffle button.
func get_shuffle_button() -> TextureButton:
	return _shuffle_button


func _on_card_pressed(world_id: String, was_centred: bool) -> void:
	if not was_centred:
		return
	GameRegistry.set_shuffle(false)
	GameRegistry.go_to_world(world_id)

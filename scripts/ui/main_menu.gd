class_name MainMenu
extends Control

## Start screen: a carousel with a card per registered world, a Play button and a Shuffle button.
## The carousel opens on the last world played. Play, or tapping the centred card, opens the centred
## world at its saved level and leaves shuffle; tapping a card beside it only slides it to the
## centre. Shuffle starts or continues a shuffle. No text anywhere.
## Its background loop and button taps play through AudioManager.

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
	_play_button.pressed.connect(_open_centred_world)
	_shuffle_button.pressed.connect(GameRegistry.start_shuffle)
	$PlayArea/Fox.play("idle")
	AudioManager.play_music(AudioManager.MENU_MUSIC)
	_play_button.pressed.connect(_play_tap)
	_shuffle_button.pressed.connect(_play_tap)
	_carousel.card_pressed.connect(_play_tap.unbind(2))


## Returns the world carousel.
func get_carousel() -> WorldCarousel:
	return _carousel


## Returns the Play button, which opens the centred world.
func get_play_button() -> TextureButton:
	return _play_button


## Returns the Shuffle button.
func get_shuffle_button() -> TextureButton:
	return _shuffle_button


func _on_card_pressed(_world_id: String, was_centred: bool) -> void:
	if was_centred:
		_open_centred_world()


func _open_centred_world() -> void:
	GameRegistry.set_shuffle(false)
	GameRegistry.go_to_world(_carousel.get_centred_id())


func _play_tap() -> void:
	AudioManager.play_sfx("tap")

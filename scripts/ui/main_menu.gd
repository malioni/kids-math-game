class_name MainMenu
extends Control

## Start screen and the only place to choose what to play: a carousel with a card per registered
## world and a Shuffle card last, a level wheel under it, a Play button, Easy/Hard buttons in the
## top-left corner and background sound and effects toggles in the top-right. No text apart from the
## level numbers.
##
## The carousel opens on the Shuffle card while shuffling, otherwise on the last world played. With
## a world centred, the level wheel shows the current difficulty's levels and opens on that world's
## saved level; Play, or tapping the centred world or level card, opens the world at the centred
## level and leaves shuffle. With the Shuffle card centred, the wheel gives way to the shuffle setup
## and Play starts or continues a shuffle. Tapping a side card only slides it to the centre.
## Its background loop and taps play through AudioManager.

const SHUFFLE_ID := "shuffle"
const _SHUFFLE_ICON := preload("res://assets/sprites/ui/icon_shuffle.svg")
const _MUSIC_ON := preload("res://assets/sprites/ui/icon_music_on.svg")
const _MUSIC_OFF := preload("res://assets/sprites/ui/icon_music_off.svg")
const _EFFECTS_ON := preload("res://assets/sprites/ui/icon_effects_on.svg")
const _EFFECTS_OFF := preload("res://assets/sprites/ui/icon_effects_off.svg")
const _CREAM := Color(1.0, 0.96, 0.86)
const _CURRENT := Color(1.0, 0.72, 0.3)
const _BORDER := Color(0.45, 0.3, 0.18)

@onready var _carousel: WorldCarousel = $PlayArea/WorldCarousel
@onready var _level_wheel: WorldCarousel = $PlayArea/LevelWheel
@onready var _shuffle_setup: Control = $PlayArea/ShuffleSetup
@onready var _play_button: TextureButton = $PlayArea/PlayButton
@onready var _easy_button: Button = $PlayArea/DifficultyRow/EasyButton
@onready var _hard_button: Button = $PlayArea/DifficultyRow/HardButton
@onready var _music_button: Button = $PlayArea/SoundRow/MusicButton
@onready var _effects_button: Button = $PlayArea/SoundRow/EffectsButton


func _ready() -> void:
	var items: Array[Dictionary] = []
	for world in GameRegistry.get_worlds():
		items.append({"id": world["id"], "icon": load(world["icon"])})
	items.append({"id": SHUFFLE_ID, "icon": _SHUFFLE_ICON})
	_carousel.set_items(items)
	var start_id: String = (
		SHUFFLE_ID if GameRegistry.is_shuffle() else SaveManager.load_last_world()
	)
	_carousel.scroll_to(start_id, false)
	_carousel.card_pressed.connect(_on_card_pressed)
	_carousel.centred_changed.connect(_show_centred.unbind(1))
	_level_wheel.card_pressed.connect(_on_level_card_pressed)
	_play_button.pressed.connect(_play)
	_easy_button.pressed.connect(_on_difficulty_pressed.bind("easy"))
	_hard_button.pressed.connect(_on_difficulty_pressed.bind("hard"))
	_music_button.pressed.connect(_on_music_pressed)
	_effects_button.pressed.connect(_on_effects_pressed)
	$PlayArea/Fox.play("idle")
	AudioManager.play_music(AudioManager.MENU_MUSIC)
	for button: BaseButton in [
		_play_button, _easy_button, _hard_button, _music_button, _effects_button
	]:
		button.pressed.connect(_play_tap)
	for carousel in [_carousel, _level_wheel]:
		carousel.card_pressed.connect(_play_tap.unbind(2))
		for arrow in carousel.get_arrow_buttons():
			arrow.pressed.connect(_play_tap)
	_update_difficulty_buttons()
	_update_sound_buttons()
	_show_centred()


## Returns the world carousel (the Shuffle card is its last card).
func get_carousel() -> WorldCarousel:
	return _carousel


## Returns the level wheel, whose card ids are the 1-based level numbers.
func get_level_wheel() -> WorldCarousel:
	return _level_wheel


## Returns the shuffle setup, shown in place of the level wheel while the Shuffle card is centred.
func get_shuffle_setup() -> Control:
	return _shuffle_setup


## Returns the Play button, which opens the centred world at the centred level, or starts shuffle.
func get_play_button() -> TextureButton:
	return _play_button


## Returns the difficulty buttons: easy, then hard.
func get_difficulty_buttons() -> Array[Button]:
	return [_easy_button, _hard_button]


## Returns the sound toggles: background sound, then effects.
func get_sound_buttons() -> Array[Button]:
	return [_music_button, _effects_button]


func _on_card_pressed(_id: String, was_centred: bool) -> void:
	if was_centred:
		_play()


func _on_level_card_pressed(_id: String, was_centred: bool) -> void:
	if was_centred:
		_play()


func _play() -> void:
	var id: String = _carousel.get_centred_id()
	if id == SHUFFLE_ID:
		GameRegistry.start_shuffle()
		return
	GameRegistry.set_shuffle(false)
	GameRegistry.go_to_world(id, int(_level_wheel.get_centred_id()) - 1)


func _show_centred() -> void:
	var id: String = _carousel.get_centred_id()
	var on_shuffle: bool = id == SHUFFLE_ID
	_level_wheel.visible = not on_shuffle
	_shuffle_setup.visible = on_shuffle
	if on_shuffle:
		return
	var level_range: Vector2i = GameRegistry.get_level_range()
	var items: Array[Dictionary] = []
	for i in range(level_range.x, level_range.y + 1):
		items.append({"id": str(i + 1), "text": str(i + 1)})
	_level_wheel.set_items(items)
	var key: String = SaveManager.progress_key(id, GameRegistry.get_difficulty())
	var saved: int = clampi(SaveManager.load_progress(key) - 1, level_range.x, level_range.y)
	_level_wheel.scroll_to(str(saved + 1), false)
	_level_wheel.set_highlighted(str(saved + 1))


func _on_difficulty_pressed(difficulty: String) -> void:
	GameRegistry.set_difficulty(difficulty)
	_update_difficulty_buttons()
	_show_centred()


func _update_difficulty_buttons() -> void:
	var difficulty: String = GameRegistry.get_difficulty()
	_style_button(_easy_button, _CURRENT if difficulty == "easy" else _CREAM)
	_style_button(_hard_button, _CURRENT if difficulty == "hard" else _CREAM)


func _on_music_pressed() -> void:
	AudioManager.set_music_enabled(not AudioManager.is_music_enabled())
	_update_sound_buttons()


func _on_effects_pressed() -> void:
	AudioManager.set_effects_enabled(not AudioManager.is_effects_enabled())
	_update_sound_buttons()


func _update_sound_buttons() -> void:
	var music_on: bool = AudioManager.is_music_enabled()
	var effects_on: bool = AudioManager.is_effects_enabled()
	_music_button.icon = _MUSIC_ON if music_on else _MUSIC_OFF
	_effects_button.icon = _EFFECTS_ON if effects_on else _EFFECTS_OFF
	_style_button(_music_button, _CURRENT if music_on else _CREAM)
	_style_button(_effects_button, _CURRENT if effects_on else _CREAM)


func _style_button(button: Button, fill: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = fill.darkened(0.08) if state == "pressed" else fill
		box.border_color = _BORDER
		box.set_border_width_all(4)
		box.set_corner_radius_all(16)
		box.content_margin_left = 8
		box.content_margin_right = 8
		button.add_theme_stylebox_override(state, box)


func _play_tap() -> void:
	AudioManager.play_sfx("tap")

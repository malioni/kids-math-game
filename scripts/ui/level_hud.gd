class_name LevelHud
extends CanvasLayer

## Level badge, level picker and world-complete screen shared by every world.
##
## The badge in the top-left shows the world and the current level number (with a shuffle icon in
## shuffle mode); tapping it opens a picker with a strip of world cards plus a shuffle card
## (continue the shuffle, or start it over), a button per level of the current difficulty,
## Easy/Hard buttons and a home button.
## The picker also has background sound and effects toggles, which talk to AudioManager directly
## since they don't affect the world; every tap in the HUD plays AudioManager's tap sound.
## After the last level, show_world_complete() offers a restart, home, and a strip of the other
## worlds' cards. The HUD only emits signals; the world decides what loading a level means.

## Emitted when the player picks a level. index is 0-based, or -1 to resume a world from its save.
signal level_chosen(world_id: String, index: int)
## Emitted when the player taps restart on the world-complete screen.
signal restart_requested
## Emitted when the player picks a difficulty in the picker: "easy" or "hard".
signal difficulty_chosen(difficulty: String)
## Emitted when the player taps continue (from_start false) or start over (from_start true) on the
## picker's shuffle page.
signal shuffle_requested(from_start: bool)
## Emitted when the player taps home in the picker or on the world-complete screen.
signal home_requested

# The picker page id of the shuffle card.
const _SHUFFLE_PAGE := "shuffle"
const _SHUFFLE_ICON := preload("res://assets/sprites/ui/icon_shuffle.png")
const _MUSIC_ON := preload("res://assets/sprites/ui/icon_music_on.png")
const _MUSIC_OFF := preload("res://assets/sprites/ui/icon_music_off.png")
const _EFFECTS_ON := preload("res://assets/sprites/ui/icon_effects_on.png")
const _EFFECTS_OFF := preload("res://assets/sprites/ui/icon_effects_off.png")

const _CREAM := Color(1.0, 0.96, 0.86)
const _CURRENT := Color(1.0, 0.72, 0.3)
const _BORDER := Color(0.45, 0.3, 0.18)
const _TEXT := Color(0.3, 0.2, 0.12)

var _world_id: String = ""
var _level_index: int = 0
var _picker_world_id: String = ""

@onready var _badge: Button = $Root/LevelBadge
@onready var _badge_icon: TextureRect = $Root/LevelBadge/Row/WorldIcon
@onready var _badge_level: Label = $Root/LevelBadge/Row/LevelLabel
@onready var _badge_count: Label = $Root/LevelBadge/Row/CountLabel
@onready var _picker: Control = $Root/Picker
@onready var _world_carousel: WorldCarousel = $Root/Picker/Panel/Margin/VBox/TopRow/WorldCarousel
@onready var _picker_home: BaseButton = $Root/Picker/Panel/Margin/VBox/TopRow/HomeButton
@onready var _grid: GridContainer = $Root/Picker/Panel/Margin/VBox/Grid
@onready var _complete: Control = $Root/Complete
@onready var _choice_carousel: WorldCarousel = $Root/Complete/ChoiceCarousel
@onready var _complete_home: BaseButton = $Root/Complete/Choices/HomeButton
@onready var _shuffle_icon: TextureRect = $Root/LevelBadge/ShuffleIcon
@onready var _easy_button: Button = $Root/Picker/Panel/Margin/VBox/ModeRow/EasyButton
@onready var _hard_button: Button = $Root/Picker/Panel/Margin/VBox/ModeRow/HardButton
@onready var _music_button: Button = $Root/Picker/Panel/Margin/VBox/ModeRow/MusicButton
@onready var _effects_button: Button = $Root/Picker/Panel/Margin/VBox/ModeRow/EffectsButton
@onready var _restart_label: Label = $Root/Complete/Choices/RestartButton/OneLabel
@onready var _shuffle_page: Control = $Root/Picker/Panel/Margin/VBox/ShufflePage
@onready var _shuffle_continue: BaseButton = _shuffle_page.get_node("ContinueButton")
@onready var _shuffle_restart: BaseButton = _shuffle_page.get_node("RestartButton")


func _ready() -> void:
	_badge.pressed.connect(open_picker)
	$Root/Picker/Panel/Margin/VBox/TopRow/CloseButton.pressed.connect(close_picker)
	$Root/Picker/Backdrop.gui_input.connect(_on_backdrop_input)
	$Root/Complete/Choices/RestartButton.pressed.connect(_on_restart_pressed)
	_easy_button.pressed.connect(_on_difficulty_pressed.bind("easy"))
	_hard_button.pressed.connect(_on_difficulty_pressed.bind("hard"))
	_shuffle_continue.pressed.connect(_on_shuffle_pressed.bind(false))
	_shuffle_restart.pressed.connect(_on_shuffle_pressed.bind(true))
	_picker_home.pressed.connect(_on_home_pressed)
	_complete_home.pressed.connect(_on_home_pressed)
	_world_carousel.card_pressed.connect(_on_picker_card_pressed)
	_choice_carousel.card_pressed.connect(_on_choice_card_pressed)
	_music_button.pressed.connect(_on_music_pressed)
	_effects_button.pressed.connect(_on_effects_pressed)
	var buttons: Array[BaseButton] = [
		_badge,
		$Root/Picker/Panel/Margin/VBox/TopRow/CloseButton,
		$Root/Complete/Choices/RestartButton,
		_easy_button,
		_hard_button,
		_music_button,
		_effects_button,
		_shuffle_continue,
		_shuffle_restart,
		_picker_home,
		_complete_home,
	]
	for button in buttons:
		button.pressed.connect(_play_tap)
	_world_carousel.card_pressed.connect(_play_tap.unbind(2))
	_choice_carousel.card_pressed.connect(_play_tap.unbind(2))
	var items: Array[Dictionary] = _world_items()
	items.append({"id": _SHUFFLE_PAGE, "icon": _SHUFFLE_ICON})
	_world_carousel.set_items(items)
	_picker.visible = false
	_complete.visible = false


## Shows the given level (0-based) of the world on the badge and closes any open overlay. The badge
## counts to the end of the difficulty (e.g. 4/10 on easy, 14/20 on hard), or in shuffle mode shows
## the place in the whole shuffle (e.g. 7/40).
func show_level(world_id: String, index: int) -> void:
	_world_id = world_id
	_level_index = index
	_update_badge_numbers()
	_badge_icon.texture = _world_icon(world_id)
	_shuffle_icon.visible = GameRegistry.is_shuffle()
	_picker.visible = false
	_complete.visible = false


## Opens the level picker on the current world's levels, or on the shuffle page while shuffling.
func open_picker() -> void:
	_complete.visible = false
	_show_picker_world(_SHUFFLE_PAGE if GameRegistry.is_shuffle() else _world_id)
	var difficulty: String = GameRegistry.get_difficulty()
	_style_button(_easy_button, _CURRENT if difficulty == "easy" else _CREAM, 4)
	_style_button(_hard_button, _CURRENT if difficulty == "hard" else _CREAM, 4)
	_update_sound_buttons()
	_picker.visible = true


## Closes the level picker without choosing a level.
func close_picker() -> void:
	_picker.visible = false


## Returns true while the level picker is open.
func is_picker_open() -> bool:
	return _picker.visible


## Shows the world-complete screen: restart (from the difficulty's first level, or a fresh shuffle
## in shuffle mode), home, or go to another world (any world in shuffle mode).
func show_world_complete() -> void:
	var shuffle: bool = GameRegistry.is_shuffle()
	_restart_label.text = str(GameRegistry.get_level_range().x + 1)
	_restart_label.visible = not shuffle
	_picker.visible = false
	_choice_carousel.set_items(_world_items("" if shuffle else _world_id))
	_complete.visible = true


## Returns true while the world-complete screen is showing.
func is_world_complete_shown() -> bool:
	return _complete.visible


## Returns the difficulty buttons in the picker: easy, then hard.
func get_difficulty_buttons() -> Array[Button]:
	return [_easy_button, _hard_button]


## Returns the level buttons currently in the picker, in level order.
func get_level_buttons() -> Array[Node]:
	return _grid.get_children()


## Returns the world cards in the picker's strip, in GameRegistry order (the shuffle card left
## out).
func get_world_tabs() -> Array[Panel]:
	var cards: Array[Panel] = []
	for card in _world_carousel.get_cards():
		if card != get_shuffle_tab():
			cards.append(card)
	return cards


## Returns the shuffle card in the picker's strip.
func get_shuffle_tab() -> Panel:
	return _world_carousel.get_card(_SHUFFLE_PAGE)


## Returns the home buttons: the picker's, then the world-complete screen's.
func get_home_buttons() -> Array[BaseButton]:
	return [_picker_home, _complete_home]


## Returns the strip of world cards on the world-complete screen.
func get_choice_carousel() -> WorldCarousel:
	return _choice_carousel


## Returns true while the picker shows the shuffle page instead of a world's levels.
func is_shuffle_page_shown() -> bool:
	return _shuffle_page.visible


## Returns the shuffle page's buttons: continue, then start over.
func get_shuffle_buttons() -> Array[BaseButton]:
	return [_shuffle_continue, _shuffle_restart]


## Returns the sound toggles in the picker: background sound, then effects.
func get_sound_buttons() -> Array[Button]:
	return [_music_button, _effects_button]


func _show_picker_world(world_id: String) -> void:
	_picker_world_id = world_id
	_world_carousel.scroll_to(world_id, false)
	_world_carousel.set_highlighted(world_id)
	var on_shuffle: bool = world_id == _SHUFFLE_PAGE

	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_shuffle_page.visible = on_shuffle
	_grid.visible = not on_shuffle
	if on_shuffle:
		return
	var level_range: Vector2i = GameRegistry.get_level_range()
	for i in range(level_range.x, level_range.y + 1):
		var button := Button.new()
		button.name = "Level_%d" % (i + 1)
		button.text = str(i + 1)
		button.custom_minimum_size = Vector2(150, 100)
		button.add_theme_font_size_override("font_size", 40)
		var current: bool = world_id == _world_id and i == _level_index
		_style_button(button, _CURRENT if current else _CREAM, 4 if current else 2)
		button.pressed.connect(_on_level_pressed.bind(i))
		button.pressed.connect(_play_tap)
		_grid.add_child(button)


func _on_level_pressed(index: int) -> void:
	_picker.visible = false
	level_chosen.emit(_picker_world_id, index)


func _on_difficulty_pressed(difficulty: String) -> void:
	_picker.visible = false
	difficulty_chosen.emit(difficulty)


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
	_style_button(_music_button, _CURRENT if music_on else _CREAM, 4)
	_style_button(_effects_button, _CURRENT if effects_on else _CREAM, 4)


func _play_tap() -> void:
	AudioManager.play_sfx("tap")


func _on_shuffle_pressed(from_start: bool) -> void:
	_picker.visible = false
	shuffle_requested.emit(from_start)


func _on_picker_card_pressed(id: String, _was_centred: bool) -> void:
	_show_picker_world(id)


func _on_home_pressed() -> void:
	_picker.visible = false
	_complete.visible = false
	home_requested.emit()


func _on_restart_pressed() -> void:
	_complete.visible = false
	restart_requested.emit()


func _on_choice_card_pressed(world_id: String, _was_centred: bool) -> void:
	_complete.visible = false
	level_chosen.emit(world_id, -1)


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_picker()


# Carousel items for every registered world except skip_id.
func _world_items(skip_id: String = "") -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for world in GameRegistry.get_worlds():
		if world["id"] == skip_id:
			continue
		items.append({"id": world["id"], "icon": load(world["icon"])})
	return items


func _world_icon(world_id: String) -> Texture2D:
	var world: Dictionary = GameRegistry.get_world(world_id)
	return load(world["icon"]) if not world.is_empty() else null


func _style_button(button: Button, fill: Color, border_width: int) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = fill.darkened(0.08) if state == "pressed" else fill
		box.border_color = _BORDER
		box.set_border_width_all(border_width)
		box.set_corner_radius_all(16)
		box.content_margin_left = 8
		box.content_margin_right = 8
		button.add_theme_stylebox_override(state, box)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, _TEXT)


func _update_badge_numbers() -> void:
	if GameRegistry.is_shuffle():
		var position: Vector2i = GameRegistry.shuffle_position()
		_badge_level.text = str(position.x)
		_badge_count.text = "/%d" % position.y
		return
	_badge_level.text = str(_level_index + 1)
	_badge_count.text = "/%d" % (GameRegistry.get_level_range().y + 1)

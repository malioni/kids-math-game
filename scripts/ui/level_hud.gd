class_name LevelHud
extends CanvasLayer

## Level badge, level picker and world-complete screen shared by every world.
##
## The badge in the top-left shows the world and the current level number (with a shuffle icon in
## shuffle mode); tapping it opens a picker with a tab per world, a shuffle tab, a button per level
## of the current difficulty, and Easy/Hard buttons. After the last level, show_world_complete()
## offers a restart and a button for each other world. The HUD only emits signals; the world
## decides what loading a level means.

## Emitted when the player picks a level. index is 0-based, or -1 to resume a world from its save.
signal level_chosen(world_id: String, index: int)
## Emitted when the player taps restart on the world-complete screen.
signal restart_requested
## Emitted when the player picks a difficulty in the picker: "easy" or "hard".
signal difficulty_chosen(difficulty: String)
## Emitted when the player taps the shuffle tab in the picker.
signal shuffle_requested

const _CREAM := Color(1.0, 0.96, 0.86)
const _CURRENT := Color(1.0, 0.72, 0.3)
const _BORDER := Color(0.45, 0.3, 0.18)
const _TEXT := Color(0.3, 0.2, 0.12)

var _world_id: String = ""
var _level_index: int = 0
var _level_count: int = 0
var _picker_world_id: String = ""

@onready var _badge: Button = $Root/LevelBadge
@onready var _badge_icon: TextureRect = $Root/LevelBadge/Row/WorldIcon
@onready var _badge_level: Label = $Root/LevelBadge/Row/LevelLabel
@onready var _badge_count: Label = $Root/LevelBadge/Row/CountLabel
@onready var _picker: Control = $Root/Picker
@onready var _world_tabs: HBoxContainer = $Root/Picker/Panel/Margin/VBox/TopRow/WorldTabs
@onready var _grid: GridContainer = $Root/Picker/Panel/Margin/VBox/Grid
@onready var _complete: Control = $Root/Complete
@onready var _choices: HBoxContainer = $Root/Complete/Choices
@onready var _shuffle_icon: TextureRect = $Root/LevelBadge/ShuffleIcon
@onready var _easy_button: Button = $Root/Picker/Panel/Margin/VBox/ModeRow/EasyButton
@onready var _hard_button: Button = $Root/Picker/Panel/Margin/VBox/ModeRow/HardButton
@onready var _restart_label: Label = $Root/Complete/Choices/RestartButton/OneLabel


func _ready() -> void:
	_badge.pressed.connect(open_picker)
	$Root/Picker/Panel/Margin/VBox/TopRow/CloseButton.pressed.connect(close_picker)
	$Root/Picker/Backdrop.gui_input.connect(_on_backdrop_input)
	$Root/Complete/Choices/RestartButton.pressed.connect(_on_restart_pressed)
	_easy_button.pressed.connect(_on_difficulty_pressed.bind("easy"))
	_hard_button.pressed.connect(_on_difficulty_pressed.bind("hard"))
	_picker.visible = false
	_complete.visible = false


## Shows the given level (0-based) of the world's count levels on the badge and closes any open
## overlay. The badge counts to the end of the difficulty (e.g. 4/10 on easy, 14/20 on hard), or in
## shuffle mode shows the place in the whole shuffle (e.g. 7/40).
func show_level(world_id: String, index: int, count: int) -> void:
	_world_id = world_id
	_level_index = index
	_level_count = count
	_update_badge_numbers()
	_badge_icon.texture = _world_icon(world_id)
	_shuffle_icon.visible = GameRegistry.is_shuffle()
	_picker.visible = false
	_complete.visible = false


## Opens the level picker on the current world's tab.
func open_picker() -> void:
	_complete.visible = false
	_show_picker_world(_world_id)
	var difficulty: String = GameRegistry.get_difficulty()
	_style_button(_easy_button, _CURRENT if difficulty == "easy" else _CREAM, 4)
	_style_button(_hard_button, _CURRENT if difficulty == "hard" else _CREAM, 4)
	_picker.visible = true


## Closes the level picker without choosing a level.
func close_picker() -> void:
	_picker.visible = false


## Returns true while the level picker is open.
func is_picker_open() -> bool:
	return _picker.visible


## Shows the world-complete screen: restart (from the difficulty's first level, or a fresh shuffle
## in shuffle mode), or go to another world (any world in shuffle mode).
func show_world_complete() -> void:
	var shuffle: bool = GameRegistry.is_shuffle()
	_restart_label.text = str(GameRegistry.get_level_range().x + 1)
	_restart_label.visible = not shuffle
	_picker.visible = false
	for child in _choices.get_children():
		if child.name != "RestartButton":
			child.queue_free()
	for world in GameRegistry.get_worlds():
		if world["id"] == _world_id and not shuffle:
			continue
		var button := TextureButton.new()
		button.name = "World_%s" % world["id"]
		button.texture_normal = load(world["icon"])
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = Vector2(180, 180)
		button.pressed.connect(_on_choice_world_pressed.bind(world["id"]))
		_choices.add_child(button)
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


## Returns the world tab buttons in the picker, in GameRegistry order.
func get_world_tabs() -> Array[Node]:
	return _world_tabs.get_children().filter(func(tab: Node) -> bool: return tab != _shuffle_tab())


## Returns the shuffle tab in the picker (null until the picker has opened).
func get_shuffle_tab() -> Button:
	return _shuffle_tab()


func _show_picker_world(world_id: String) -> void:
	_picker_world_id = world_id
	for child in _world_tabs.get_children():
		_world_tabs.remove_child(child)
		child.queue_free()
	for world in GameRegistry.get_worlds():
		var tab := Button.new()
		tab.name = "Tab_%s" % world["id"]
		tab.icon = _world_icon(world["id"])
		tab.expand_icon = true
		tab.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab.custom_minimum_size = Vector2(110, 80)
		var selected: bool = world["id"] == world_id
		_style_button(tab, _CURRENT if selected else _CREAM, 4 if selected else 2)
		tab.pressed.connect(_show_picker_world.bind(world["id"]))
		_world_tabs.add_child(tab)
	var shuffle_tab := Button.new()
	shuffle_tab.name = "Tab_shuffle"
	shuffle_tab.icon = preload("res://assets/sprites/ui/icon_shuffle.png")
	shuffle_tab.expand_icon = true
	shuffle_tab.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shuffle_tab.custom_minimum_size = Vector2(110, 80)
	var shuffling: bool = GameRegistry.is_shuffle()
	_style_button(shuffle_tab, _CURRENT if shuffling else _CREAM, 4 if shuffling else 2)
	shuffle_tab.pressed.connect(_on_shuffle_pressed)
	_world_tabs.add_child(shuffle_tab)

	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var count: int = (
		_level_count if world_id == _world_id else GameRegistry.get_level_count(world_id)
	)
	var level_range: Vector2i = GameRegistry.get_level_range()
	for i in range(level_range.x, mini(level_range.y + 1, count)):
		var button := Button.new()
		button.name = "Level_%d" % (i + 1)
		button.text = str(i + 1)
		button.custom_minimum_size = Vector2(150, 90)
		button.add_theme_font_size_override("font_size", 40)
		var current: bool = world_id == _world_id and i == _level_index
		_style_button(button, _CURRENT if current else _CREAM, 4 if current else 2)
		button.pressed.connect(_on_level_pressed.bind(i))
		_grid.add_child(button)


func _on_level_pressed(index: int) -> void:
	_picker.visible = false
	level_chosen.emit(_picker_world_id, index)


func _on_difficulty_pressed(difficulty: String) -> void:
	_picker.visible = false
	difficulty_chosen.emit(difficulty)


func _on_shuffle_pressed() -> void:
	_picker.visible = false
	shuffle_requested.emit()


func _shuffle_tab() -> Button:
	return _world_tabs.get_node_or_null("Tab_shuffle")


func _on_restart_pressed() -> void:
	_complete.visible = false
	restart_requested.emit()


func _on_choice_world_pressed(world_id: String) -> void:
	_complete.visible = false
	level_chosen.emit(world_id, -1)


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_picker()


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
	var last: int = mini(GameRegistry.get_level_range().y + 1, _level_count)
	_badge_level.text = str(_level_index + 1)
	_badge_count.text = "/%d" % last

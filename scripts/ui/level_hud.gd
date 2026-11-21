class_name LevelHud
extends CanvasLayer

## Level badge, pause panel and world-complete screen shared by every world.
##
## The badge in the top-left shows the world and the current level number (with a shuffle icon in
## shuffle mode); tapping it opens a pause panel with home, replay this level, background sound and
## effects toggles, and close. Choosing a world, level or difficulty happens on the main menu only.
## The sound toggles talk to AudioManager directly since they don't affect the world; every tap in
## the HUD plays AudioManager's tap sound.
## After the last level, show_world_complete() offers a restart, home and, when there is a harder
## difficulty (and not in shuffle), the same world at that difficulty. The HUD only emits signals;
## the world decides what they mean.

## Emitted when the player taps replay in the pause panel.
signal replay_requested
## Emitted when the player taps restart on the world-complete screen.
signal restart_requested
## Emitted when the player taps the next-difficulty button on the world-complete screen.
signal next_difficulty_requested
## Emitted when the player taps home in the pause panel or on the world-complete screen.
signal home_requested

const _MUSIC_ON := preload("res://assets/sprites/ui/icon_music_on.svg")
const _MUSIC_OFF := preload("res://assets/sprites/ui/icon_music_off.svg")
const _EFFECTS_ON := preload("res://assets/sprites/ui/icon_effects_on.svg")
const _EFFECTS_OFF := preload("res://assets/sprites/ui/icon_effects_off.svg")

const _CREAM := Color(1.0, 0.96, 0.86)
const _CURRENT := Color(1.0, 0.72, 0.3)
const _BORDER := Color(0.45, 0.3, 0.18)

var _level_index: int = 0

@onready var _badge: Button = $Root/LevelBadge
@onready var _badge_icon: TextureRect = $Root/LevelBadge/Row/WorldIcon
@onready var _badge_level: Label = $Root/LevelBadge/Row/LevelLabel
@onready var _badge_count: Label = $Root/LevelBadge/Row/CountLabel
@onready var _shuffle_icon: TextureRect = $Root/LevelBadge/ShuffleIcon
@onready var _pause: Control = $Root/Pause
@onready var _pause_home: BaseButton = $Root/Pause/Panel/Margin/Row/HomeButton
@onready var _replay_button: BaseButton = $Root/Pause/Panel/Margin/Row/ReplayButton
@onready var _music_button: Button = $Root/Pause/Panel/Margin/Row/MusicButton
@onready var _effects_button: Button = $Root/Pause/Panel/Margin/Row/EffectsButton
@onready var _close_button: BaseButton = $Root/Pause/Panel/Margin/Row/CloseButton
@onready var _complete: Control = $Root/Complete
@onready var _restart_button: BaseButton = $Root/Complete/Choices/RestartButton
@onready var _restart_label: Label = $Root/Complete/Choices/RestartButton/OneLabel
@onready var _next_difficulty_button: TextureButton = $Root/Complete/Choices/NextDifficultyButton
@onready var _next_difficulty_label: Label = _next_difficulty_button.get_node("FirstLabel")
@onready var _complete_home: BaseButton = $Root/Complete/Choices/HomeButton


func _ready() -> void:
	_badge.pressed.connect(open_pause)
	_close_button.pressed.connect(close_pause)
	$Root/Pause/Backdrop.gui_input.connect(_on_backdrop_input)
	_replay_button.pressed.connect(_on_replay_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_next_difficulty_button.pressed.connect(_on_next_difficulty_pressed)
	_pause_home.pressed.connect(_on_home_pressed)
	_complete_home.pressed.connect(_on_home_pressed)
	_music_button.pressed.connect(_on_music_pressed)
	_effects_button.pressed.connect(_on_effects_pressed)
	var buttons: Array[BaseButton] = [
		_badge,
		_close_button,
		_replay_button,
		_restart_button,
		_next_difficulty_button,
		_music_button,
		_effects_button,
		_pause_home,
		_complete_home,
	]
	for button in buttons:
		button.pressed.connect(_play_tap)
	_pause.visible = false
	_complete.visible = false


## Shows the given level (0-based) of the world on the badge and closes any open overlay. The badge
## counts to the end of the difficulty (e.g. 4/10 on easy, 14/20 on hard), or in shuffle mode shows
## the place in the shuffle round (e.g. 7/10).
func show_level(world_id: String, index: int) -> void:
	_level_index = index
	_update_badge_numbers()
	_badge_icon.texture = _world_icon(world_id)
	_shuffle_icon.visible = GameRegistry.is_shuffle()
	_pause.visible = false
	_complete.visible = false


## Opens the pause panel.
func open_pause() -> void:
	_complete.visible = false
	_update_sound_buttons()
	_pause.visible = true


## Closes the pause panel.
func close_pause() -> void:
	_pause.visible = false


## Returns true while the pause panel is open.
func is_pause_open() -> bool:
	return _pause.visible


## Shows the world-complete screen: restart (from the difficulty's first level, or a new shuffle
## round in shuffle mode), home, and outside shuffle the next difficulty if there is one.
func show_world_complete() -> void:
	var shuffle: bool = GameRegistry.is_shuffle()
	_restart_label.text = str(GameRegistry.get_level_range().x + 1)
	_restart_label.visible = not shuffle
	var next: String = GameRegistry.next_difficulty()
	_next_difficulty_button.visible = next != "" and not shuffle
	if _next_difficulty_button.visible:
		_next_difficulty_button.texture_normal = load("res://assets/sprites/ui/icon_%s.svg" % next)
		_next_difficulty_label.text = str(LevelLoader.get_difficulty_range(next).x + 1)
	_pause.visible = false
	_complete.visible = true


## Returns true while the world-complete screen is showing.
func is_world_complete_shown() -> bool:
	return _complete.visible


## Returns the home buttons: the pause panel's, then the world-complete screen's.
func get_home_buttons() -> Array[BaseButton]:
	return [_pause_home, _complete_home]


## Returns the pause panel's replay button.
func get_replay_button() -> BaseButton:
	return _replay_button


## Returns the pause panel's close button.
func get_close_button() -> BaseButton:
	return _close_button


## Returns the world-complete screen's restart button.
func get_restart_button() -> BaseButton:
	return _restart_button


## Returns the world-complete screen's next-difficulty button.
func get_next_difficulty_button() -> TextureButton:
	return _next_difficulty_button


## Returns the sound toggles in the pause panel: background sound, then effects.
func get_sound_buttons() -> Array[Button]:
	return [_music_button, _effects_button]


func _on_replay_pressed() -> void:
	_pause.visible = false
	replay_requested.emit()


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


func _play_tap() -> void:
	AudioManager.play_sfx("tap")


func _on_home_pressed() -> void:
	_pause.visible = false
	_complete.visible = false
	home_requested.emit()


func _on_restart_pressed() -> void:
	_complete.visible = false
	restart_requested.emit()


func _on_next_difficulty_pressed() -> void:
	_complete.visible = false
	next_difficulty_requested.emit()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_pause()


func _world_icon(world_id: String) -> Texture2D:
	var world: Dictionary = GameRegistry.get_world(world_id)
	return load(world["icon"]) if not world.is_empty() else null


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


func _update_badge_numbers() -> void:
	if GameRegistry.is_shuffle():
		var position: Vector2i = GameRegistry.shuffle_position()
		_badge_level.text = str(position.x)
		_badge_count.text = "/%d" % position.y
		return
	_badge_level.text = str(_level_index + 1)
	_badge_count.text = "/%d" % (GameRegistry.get_level_range().y + 1)

class_name DriveMechanic
extends Mechanic

## A driving puzzle. The car starts on the left of a grid, its garage is on the right and obstacles
## stand between. The player builds a program from command buttons (screen arrows in "global" mode;
## forward and turns in "relative" mode), then presses Go: the car runs it square by square, the
## running tile lit. correct is emitted when the last move ends on the garage; a bump into an
## obstacle or the field's edge, or a program that ends anywhere else, emits incorrect and marks
## the tile where it went wrong.

## Emitted before incorrect when the car bumps; kind is "edge" or the obstacle's kind.
signal bumped(kind: String)
## Emitted before incorrect when the program ends without reaching the garage.
signal stopped_short
## Emitted each time the car drives one square.
signal stepped

const TILE_SCENE := preload("res://scenes/mechanics/drive_tile.tscn")
## Width and height of a car frame and of the obstacle and garage textures, in pixels.
const CAR_CELL := 160.0
const ART_SIZE := 128.0
const BUTTON_SIZE := 90.0
const BUTTON_GAP := 12.0
const TILE_SIZE := 76.0
const TILE_GAP := 6.0

## Icon of each command (String → Texture2D), used on its button and on its tiles.
@export var command_textures: Dictionary = {}
## Texture of each obstacle kind (String → Texture2D).
@export var obstacle_textures: Dictionary = {}
## The two grass shades, laid as a checkerboard.
@export var grass_textures: Array[Texture2D] = []
## The garage's texture.
@export var garage_texture: Texture2D
## The frame behind every tile; null keeps the tile scene's own.
@export var tile_texture: Texture2D
## The Go button's texture.
@export var go_texture: Texture2D
## The car's animations: idle, drive, celebrate, bump and sad.
@export var car_frames: SpriteFrames
## Area the grid is centred in, in local pixels.
@export var field_rect: Rect2 = Rect2(190, 110, 1060, 450)
## Largest a square is drawn, so small fields don't look huge.
@export var max_square_size: float = 110.0
## Top-left of the command button column.
@export var buttons_origin: Vector2 = Vector2(30, 120)
## Top-left of the program strip.
@export var strip_origin: Vector2 = Vector2(30, 592)
## Seconds the car takes to drive one square.
@export var step_duration: float = 0.35
## Seconds the car takes to turn 90°.
@export var turn_duration: float = 0.2

var _program := DriveProgram.new()
var _field: Dictionary = {}
var _mode: String = "global"
var _square: float = 0.0
var _origin: Vector2 = Vector2.ZERO
var _interactive: bool = true
var _driving: bool = false
var _lit: int = -1
var _marked: int = -1
# Bumped by setup() and reset(); a drive checks it after every wait and stops if it changed.
var _run: int = 0
var _tween: Tween
var _command_buttons: Dictionary = {}

@onready var _grass: Node2D = $Field/Grass
@onready var _obstacles: Node2D = $Field/Obstacles
@onready var _garage: Sprite2D = $Field/Garage
@onready var _car: AnimatedSprite2D = $Field/Car
@onready var _buttons: Node2D = $Buttons
@onready var _strip: Node2D = $Strip
@onready var _go_button: TextureButton = $GoButton


func _ready() -> void:
	if car_frames != null:
		_car.sprite_frames = car_frames
	if go_texture != null:
		_go_button.texture_normal = go_texture
	_go_button.pressed.connect(go)


## Lays out field (see DrivePuzzleGenerator.generate()) and the buttons for mode ("global" or
## "relative"), empties the program and puts the car on the start.
func setup(field: Dictionary, mode: String) -> void:
	_field = field
	_mode = mode
	_program.clear()
	_marked = -1
	_draw_field()
	_make_buttons()
	reset()


## Stops any drive and puts the car back on the start, facing right. The program and the mark
## stay, so the player can fix the program.
func reset() -> void:
	_run += 1
	if _tween != null:
		_tween.kill()
	_driving = false
	_lit = -1
	if not _field.is_empty():
		_car.position = cell_position(_field["start"])
	_car.rotation = 0.0
	_play_car("idle")
	_refresh()


## Enables or disables the buttons, the tiles and Go.
func set_interactive(enabled: bool) -> void:
	_interactive = enabled
	_refresh()


## Adds one step of command to the program, as if its button was pressed.
func press_command(command: String) -> void:
	if not _can_edit() or not _program.can_add(command):
		return
	_program.add(command)
	_marked = -1
	_refresh()
	piece_placed.emit()


## Takes one step off the tile at index, as if it was tapped.
func tap_tile(index: int) -> void:
	if not _can_edit() or index < 0 or index >= _program.get_tiles().size():
		return
	_program.take_step(index)
	_marked = -1
	_refresh()
	piece_removed.emit()


## Runs the program, as if Go was pressed. Does nothing while driving, when not interactive, or
## when the program is empty.
func go() -> void:
	if not _can_edit() or _program.is_empty():
		return
	_marked = -1
	_drive(_run)


## Returns the program.
func get_program() -> DriveProgram:
	return _program


## Returns the car, which is also the world's character.
func get_car() -> AnimatedSprite2D:
	return $Field/Car


## Returns the field passed to setup().
func get_field() -> Dictionary:
	return _field


## Returns the mode passed to setup().
func get_mode() -> String:
	return _mode


## Returns the strip's tiles in order.
func get_tiles() -> Array[DriveTile]:
	var tiles: Array[DriveTile] = []
	for tile: DriveTile in _strip.get_children():
		if not tile.is_queued_for_deletion():
			tiles.append(tile)
	return tiles


## Returns the command buttons for the current mode (command → TextureButton), in button order.
func get_command_buttons() -> Dictionary:
	return _command_buttons


## Returns the index of the tile the car is running, or -1.
func get_lit_tile() -> int:
	return _lit


## Returns the index of the tile where the last run went wrong, or -1.
func get_marked_tile() -> int:
	return _marked


## Returns true while the car is running the program.
func is_driving() -> bool:
	return _driving


## Returns the centre of cell in local pixels.
func cell_position(cell: Vector2i) -> Vector2:
	return _origin + (Vector2(cell) + Vector2(0.5, 0.5)) * _square


func _can_edit() -> bool:
	return _interactive and not _driving


func _drive(run_id: int) -> void:
	var moves := _program.expand()
	var result := DriveSimulator.run(_field, moves)
	var poses: Array = result["poses"]
	_driving = true
	_refresh()
	var facing := DriveSimulator.RIGHT
	for i in poses.size():
		_lit = moves[i]["tile"]
		_refresh()
		var pose: Dictionary = poses[i]
		if pose["facing"] != facing:
			facing = pose["facing"]
			await _turn_to(facing)
			if run_id != _run:
				return
		if i == result["fail_move"] and result["outcome"] == "bump":
			await _nudge(facing)
		elif pose["cell"] != _cell_of_car():
			_play_car("drive")
			stepped.emit()
			await _move_to(cell_position(pose["cell"]))
		if run_id != _run:
			return
	_driving = false
	_lit = -1
	_play_car("idle")
	if result["outcome"] == "garage":
		_refresh()
		correct.emit()
		return
	_marked = moves[result["fail_move"]]["tile"]
	_refresh()
	if result["outcome"] == "bump":
		bumped.emit(result["bump_kind"])
	else:
		stopped_short.emit()
	incorrect.emit()


func _turn_to(facing: Vector2i) -> Signal:
	var target: float = Vector2(facing).angle()
	_tween = create_tween()
	_tween.tween_method(
		func(weight: float) -> void: _car.rotation = lerp_angle(_car.rotation, target, weight),
		0.0,
		1.0,
		turn_duration
	)
	return _tween.finished


func _move_to(target: Vector2) -> Signal:
	_tween = create_tween()
	_tween.tween_property(_car, "position", target, step_duration)
	return _tween.finished


# Drives a third of a square towards whatever is in the way, and back.
func _nudge(facing: Vector2i) -> Signal:
	var home: Vector2 = _car.position
	_tween = create_tween()
	_tween.tween_property(
		_car, "position", home + Vector2(facing) * _square / 3.0, step_duration / 2.0
	)
	_tween.tween_property(_car, "position", home, step_duration / 2.0)
	return _tween.finished


func _cell_of_car() -> Vector2i:
	return Vector2i(((_car.position - _origin) / _square).floor())


func _play_car(animation: String) -> void:
	if _car.sprite_frames != null and _car.sprite_frames.has_animation(animation):
		_car.play(animation)


func _draw_field() -> void:
	var cols := int(_field["cols"])
	var rows := int(_field["rows"])
	_square = minf(max_square_size, minf(field_rect.size.x / cols, field_rect.size.y / rows))
	_origin = field_rect.get_center() - Vector2(cols, rows) * _square / 2.0
	for child in _grass.get_children() + _obstacles.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	for y in rows:
		for x in cols:
			var grass := Sprite2D.new()
			if grass_textures.size() == 2:
				grass.texture = grass_textures[(x + y) % 2]
			grass.position = cell_position(Vector2i(x, y))
			grass.scale = Vector2.ONE * _square / ART_SIZE
			_grass.add_child(grass)
	for obstacle: Dictionary in _field["obstacles"]:
		var sprite := Sprite2D.new()
		sprite.texture = obstacle_textures.get(obstacle["kind"])
		sprite.position = cell_position(obstacle["cell"])
		sprite.scale = Vector2.ONE * _square / ART_SIZE
		_obstacles.add_child(sprite)
	_garage.texture = garage_texture
	_garage.position = cell_position(_field["garage"])
	_garage.scale = Vector2.ONE * _square / ART_SIZE
	_car.scale = Vector2.ONE * _square / CAR_CELL


func _make_buttons() -> void:
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	_command_buttons.clear()
	var commands: Array = DrivePuzzleGenerator.COMMANDS[_mode]
	for i in commands.size():
		var command: String = commands[i]
		var button := TextureButton.new()
		button.texture_normal = command_textures.get(command)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.position = buttons_origin + Vector2(0, i * (BUTTON_SIZE + BUTTON_GAP))
		button.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
		button.pressed.connect(press_command.bind(command))
		_buttons.add_child(button)
		_command_buttons[command] = button


# Rebuilds the strip from the program and updates every button's state.
func _refresh() -> void:
	for child in _strip.get_children():
		_strip.remove_child(child)
		child.queue_free()
	var tiles := _program.get_tiles()
	for i in tiles.size():
		var tile: DriveTile = TILE_SCENE.instantiate()
		if tile_texture != null:
			tile.texture_normal = tile_texture
		tile.position = strip_origin + Vector2(i * (TILE_SIZE + TILE_GAP), 0)
		_strip.add_child(tile)
		tile.setup(command_textures.get(tiles[i]["command"]), int(tiles[i]["count"]))
		tile.set_lit(i == _lit)
		tile.set_marked(i == _marked)
		tile.disabled = not _can_edit()
		tile.pressed.connect(tap_tile.bind(i))
	for command: String in _command_buttons:
		var button: TextureButton = _command_buttons[command]
		button.disabled = not _can_edit() or not _program.can_add(command)
		button.modulate.a = 0.4 if button.disabled else 1.0
	_go_button.disabled = not _can_edit()

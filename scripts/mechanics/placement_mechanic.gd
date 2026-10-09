extends Node2D

## Emitted when confirm() is called and the placed planks add up to target_length exactly.
signal correct

## Emitted when confirm() is called and the placed planks fall short of target_length.
signal incorrect

## Emitted on every placement, removal, or reset with the new placed total.
signal total_changed(new_total: int)

## Scene instantiated for each draggable plank.
const PLANK_DRAG_SCENE := preload("res://scenes/mechanics/plank_drag.tscn")

## Width of the gap, in pixels. The puzzle's target length always spans this width.
@export var bridge_width: float = 600.0
## Vertical tolerance, in pixels, above and below the gap within which a drop counts.
@export var drop_margin: float = 60.0
## Left edge of the plank pile, in local pixels.
@export var pile_left: float = -460.0
## Right edge of the plank pile; planks wrap to the next row past this.
@export var pile_right: float = 340.0
## Local y of each pile row, top to bottom.
@export var pile_row_y: Array[float] = [170.0, 230.0, 290.0]
## Horizontal gap between planks in the pile.
@export var pile_spacing: float = 16.0
## Texture shown on the Go button.
@export var go_texture: Texture2D

var _target_length: int = 0
var _plank_lengths: Array[int] = []
var _unit_px: float = 0.0

@onready var _placed_planks: Node2D = $PlacedPlanks
@onready var _plank_source: Node2D = $PlankSource
@onready var _go_button: TextureButton = $GoButton
@onready var _target_label: Label = $TargetSign/TargetLabel


func _ready() -> void:
	if go_texture != null:
		_go_button.texture_normal = go_texture
	_go_button.pressed.connect(confirm)


## Stores the puzzle (bridge length and the lengths of every plank in the pile) and calls reset().
func setup(target_length: int, plank_lengths: Array[int]) -> void:
	_target_length = target_length
	_plank_lengths = plank_lengths.duplicate()
	reset()


## Returns every plank to the pile, rebuilt from the stored puzzle.
func reset() -> void:
	_clear_children(_placed_planks)
	_clear_children(_plank_source)
	_target_label.text = str(_target_length)
	_unit_px = bridge_width / _target_length if _target_length > 0 else 0.0
	_spawn_pile()
	total_changed.emit(0)


## Emits correct if the placed planks add up to the target length exactly, incorrect otherwise.
func confirm() -> void:
	if get_placed_total() == _target_length:
		correct.emit()
	else:
		incorrect.emit()


## Enables or disables dragging planks and pressing the Go button.
func set_interactive(enabled: bool) -> void:
	_go_button.disabled = not enabled
	_go_button.modulate.a = 1.0 if enabled else 0.4
	for plank: PlankDrag in get_planks():
		plank.interactive = enabled


## Returns the bridge length the placed planks must add up to.
func get_target_length() -> int:
	return _target_length


## Returns the sum of the lengths of the planks on the bridge.
func get_placed_total() -> int:
	var total: int = 0
	for plank: PlankDrag in _placed_planks.get_children():
		total += plank.length
	return total


## Returns how much of the bridge is still open.
func get_remaining_length() -> int:
	return _target_length - get_placed_total()


## Returns the global position where the placed planks end (the left bank edge if none).
## Uses the placed total rather than plank nodes, which may still be tweening into place.
func get_bridge_end_position() -> Vector2:
	return to_global(Vector2(-bridge_width / 2.0 + get_placed_total() * _unit_px, 0.0))


## Returns every plank, in the pile and on the bridge.
func get_planks() -> Array[Node]:
	return _plank_source.get_children() + _placed_planks.get_children()


## Returns the planks on the bridge, left to right.
func get_placed_planks() -> Array[Node]:
	return _placed_planks.get_children()


func _spawn_pile() -> void:
	var row: int = 0
	var cursor: float = pile_left
	for plank_length in _plank_lengths:
		var plank: PlankDrag = PLANK_DRAG_SCENE.instantiate()
		plank.configure(plank_length, _unit_px)
		var width: float = plank.get_width()
		if cursor + width > pile_right and cursor > pile_left:
			row = mini(row + 1, pile_row_y.size() - 1)
			cursor = pile_left
		plank.position = Vector2(cursor + width / 2.0, pile_row_y[row])
		cursor += width + pile_spacing
		plank.dropped.connect(_on_plank_dropped.bind(plank))
		plank.tapped.connect(_on_plank_tapped.bind(plank))
		_plank_source.add_child(plank)


func _on_plank_dropped(release_position: Vector2, plank: PlankDrag) -> void:
	if not _is_over_gap(release_position) or plank.length > get_remaining_length():
		plank.bounce_back()
		return
	plank.is_placed = true
	plank.reparent(_placed_planks)
	_relayout_placed()
	total_changed.emit(get_placed_total())


func _on_plank_tapped(plank: PlankDrag) -> void:
	if not plank.is_placed:
		return
	plank.is_placed = false
	plank.reparent(_plank_source)
	plank.move_to(plank.home)
	_relayout_placed()
	total_changed.emit(get_placed_total())


func _relayout_placed() -> void:
	var cursor: float = -bridge_width / 2.0
	for plank: PlankDrag in _placed_planks.get_children():
		var width: float = plank.get_width()
		plank.move_to(Vector2(cursor + width / 2.0, 0.0))
		cursor += width


func _is_over_gap(global_point: Vector2) -> bool:
	var local_point: Vector2 = to_local(global_point)
	var area := Rect2(
		-bridge_width / 2.0 - 40.0, -drop_margin, bridge_width + 80.0, drop_margin * 2.0
	)
	return area.has_point(local_point)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

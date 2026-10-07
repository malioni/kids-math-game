extends Node2D

## Emitted when confirm() is called and the placed count matches target_count.
signal correct

## Emitted when confirm() is called and the placed count does not match target_count.
signal incorrect

## Emitted on every placement, removal, or reset with the new count value.
signal count_changed(new_count: int)

const GAP_SLOT_SCENE := preload("res://scenes/mechanics/gap_slot.tscn")
const PLANK_DRAG_SCENE := preload("res://scenes/mechanics/plank_drag.tscn")
## Horizontal space, in pixels, the gap slots are spread across.
const BRIDGE_WIDTH := 600.0
## Vertical offset of the plank supply row below the bridge.
const PLANK_SOURCE_Y := 200.0
## Horizontal distance between planks in the supply row.
const PLANK_SPACING := 120.0
## Maximum distance from a slot centre at which a dropped plank snaps in.
const SNAP_RADIUS := 60.0

## The number of objects the player must place to satisfy this mechanic.
@export var target_count: int = 0

var _placed_count: int = 0

@onready var _gap_container: Node2D = $GapContainer
@onready var _plank_source: Node2D = $PlankSource
@onready var _go_button: BaseButton = $GoButton


func _ready() -> void:
	_go_button.pressed.connect(confirm)


## Places one object, incrementing the count.
func place() -> void:
	_placed_count += 1
	count_changed.emit(_placed_count)


## Removes one object, decrementing the count. Count cannot go below zero.
func remove() -> void:
	if _placed_count > 0:
		_placed_count -= 1
	count_changed.emit(_placed_count)


## Checks the placed count against target_count: emits correct on a match, else incorrect.
func confirm() -> void:
	if _placed_count == target_count:
		correct.emit()
	else:
		incorrect.emit()


## Resets the count to zero and rebuilds the gap slots and plank supply for target_count.
func reset() -> void:
	_placed_count = 0
	_clear_children(_gap_container)
	_clear_children(_plank_source)
	_layout_gaps()
	_spawn_planks()
	count_changed.emit(_placed_count)


## Returns the current number of placed objects.
func get_placed_count() -> int:
	return _placed_count


## Enables or disables dragging planks and pressing the go button.
func set_interactive(enabled: bool) -> void:
	_go_button.disabled = not enabled
	_go_button.modulate.a = 1.0 if enabled else 0.4
	for plank: PlankDrag in _plank_source.get_children():
		plank.interactive = enabled


## Returns the gap slot nodes currently laid out, left to right.
func get_gap_slots() -> Array[Node]:
	return _gap_container.get_children()


## Returns the plank nodes currently in play.
func get_planks() -> Array[Node]:
	return _plank_source.get_children()


func _layout_gaps() -> void:
	if target_count <= 0:
		return
	var spacing: float = BRIDGE_WIDTH / target_count
	for i in target_count:
		var slot: GapSlot = GAP_SLOT_SCENE.instantiate()
		slot.position = Vector2(-BRIDGE_WIDTH / 2.0 + spacing * (i + 0.5), 0.0)
		_gap_container.add_child(slot)


func _spawn_planks() -> void:
	var plank_count: int = target_count + 1
	var start_x: float = -PLANK_SPACING * (plank_count - 1) / 2.0
	for i in plank_count:
		var plank: PlankDrag = PLANK_DRAG_SCENE.instantiate()
		plank.position = Vector2(start_x + PLANK_SPACING * i, PLANK_SOURCE_Y)
		plank.dropped.connect(_on_plank_dropped.bind(plank))
		_plank_source.add_child(plank)


func _on_plank_dropped(release_position: Vector2, plank: PlankDrag) -> void:
	var slot: GapSlot = _find_snap_slot(release_position)
	if slot == null:
		plank.bounce_back()
		return
	plank.global_position = slot.global_position
	plank.lock()
	slot.occupy()
	place()


func _find_snap_slot(point: Vector2) -> GapSlot:
	var nearest: GapSlot = null
	var nearest_distance: float = SNAP_RADIUS
	for slot: GapSlot in _gap_container.get_children():
		if slot.is_occupied:
			continue
		var distance: float = slot.global_position.distance_to(point)
		if distance <= nearest_distance:
			nearest = slot
			nearest_distance = distance
	return nearest


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

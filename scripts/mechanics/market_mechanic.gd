class_name MarketMechanic
extends Node2D

## A market table. An order slip shows how many of each item the customer wants; each ordered item
## has a crate of equal-sized bags that never runs out. The player drags or taps bags onto the
## table (one row per item), taps a placed bag to take it off, and presses Go. The number of items
## placed is never shown, so the player has to work out bags × bag size themselves.

## Emitted when confirm() is called and every item's placed bags hold exactly the ordered quantity.
signal correct
## Emitted when confirm() is called and any item's placed bags hold too few or too many.
signal incorrect
## Emitted whenever the number of placed bags of an item changes, and for every item on reset.
signal bags_changed(item: String, count: int)

## Scene instantiated for each bag.
const BAG_SCENE := preload("res://scenes/mechanics/bag_drag.tscn")

## Icon for each item id (String → Texture2D), shown on bags and the order slip.
@export var item_icons: Dictionary = {}
## Texture shown on the Go button.
@export var go_texture: Texture2D
## Texture of the crates bags come from.
@export var crate_texture: Texture2D
## The table top in local pixels; a bag released inside it is placed.
@export var table_rect: Rect2 = Rect2(-380, -165, 760, 330)
## Local y of each item's row, top to bottom. Order i uses row i.
@export var row_y: Array[float] = [-100.0, 0.0, 100.0]
## Left edge of the bags in a row, in local pixels.
@export var row_left: float = -350.0
## Right edge of the bags in a row; crowded rows overlap to stay inside it.
@export var row_right: float = 350.0
## Local x of the crates, each in line with its row.
@export var crate_x: float = 470.0
## Horizontal gap between bags in an uncrowded row.
@export var bag_gap: float = 12.0
## Most bags a row holds; one more bounces back.
@export var max_bags_per_row: int = 12

var _orders: Array[Dictionary] = []

@onready var _crates: Node2D = $Crates
@onready var _placed_bags: Node2D = $PlacedBags
@onready var _ready_bags: Node2D = $ReadyBags
@onready var _leaving: Node2D = $Leaving
@onready var _order_lines: VBoxContainer = $OrderSlip/Lines
@onready var _go_button: TextureButton = $GoButton


func _ready() -> void:
	$Table.position = table_rect.position
	$Table.size = table_rect.size
	if go_texture != null:
		_go_button.texture_normal = go_texture
	_go_button.pressed.connect(confirm)


## Stores the orders and calls reset(). Each order needs "item", "bag_size" and "quantity".
func setup(orders: Array[Dictionary]) -> void:
	_orders = orders.duplicate(true)
	reset()


## Clears the table and rebuilds the order slip and crates from the stored orders.
func reset() -> void:
	for parent: Node in [_crates, _placed_bags, _ready_bags, _leaving, _order_lines]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	for i in _orders.size():
		var order: Dictionary = _orders[i]
		_add_order_line(order)
		var crate := Sprite2D.new()
		crate.texture = crate_texture
		crate.position = _crate_position(i)
		_crates.add_child(crate)
		_spawn_ready_bag(i)
	for order in _orders:
		bags_changed.emit(order["item"], 0)


## Emits correct if every item's placed bags hold exactly its ordered quantity, incorrect otherwise.
func confirm() -> void:
	for order in _orders:
		if get_placed_total(order["item"]) != int(order["quantity"]):
			incorrect.emit()
			return
	correct.emit()


## Enables or disables dragging and tapping bags and pressing the Go button.
func set_interactive(enabled: bool) -> void:
	_go_button.disabled = not enabled
	_go_button.modulate.a = 1.0 if enabled else 0.4
	for bag: BagDrag in _ready_bags.get_children() + _placed_bags.get_children():
		bag.interactive = enabled


## Returns the orders passed to setup().
func get_orders() -> Array[Dictionary]:
	return _orders


## Returns how many bags of the item are on the table.
func get_placed_count(item: String) -> int:
	return get_placed_bags(item).size()


## Returns how many items of the given kind the placed bags hold. Never shown to the player.
func get_placed_total(item: String) -> int:
	var total: int = 0
	for bag in get_placed_bags(item):
		total += bag.bag_size
	return total


## Returns the item's bags on the table, left to right.
func get_placed_bags(item: String) -> Array[BagDrag]:
	var bags: Array[BagDrag] = []
	for bag: BagDrag in _placed_bags.get_children():
		if bag.item == item:
			bags.append(bag)
	return bags


## Returns the bag waiting on the item's crate, or null if the item isn't ordered.
func get_ready_bag(item: String) -> BagDrag:
	for bag: BagDrag in _ready_bags.get_children():
		if bag.item == item:
			return bag
	return null


func _add_order_line(order: Dictionary) -> void:
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = str(order["quantity"])
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", Color(0.24, 0.15, 0.09))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(label)
	var icon := TextureRect.new()
	icon.texture = item_icons.get(order["item"])
	icon.custom_minimum_size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon)
	_order_lines.add_child(line)


func _spawn_ready_bag(row: int) -> void:
	var order: Dictionary = _orders[row]
	var bag: BagDrag = BAG_SCENE.instantiate()
	bag.position = _crate_position(row)
	bag.dropped.connect(_on_bag_dropped.bind(bag))
	bag.tapped.connect(_on_bag_tapped.bind(bag))
	_ready_bags.add_child(bag)
	bag.configure(order["item"], order["bag_size"], item_icons.get(order["item"]))


func _on_bag_dropped(release_position: Vector2, bag: BagDrag) -> void:
	var over_table: bool = table_rect.has_point(to_local(release_position))
	if not over_table or not _place(bag):
		bag.bounce_back()


func _on_bag_tapped(bag: BagDrag) -> void:
	if bag.is_placed:
		_remove(bag)
	else:
		_place(bag)


func _place(bag: BagDrag) -> bool:
	var row: int = _row_of(bag.item)
	if get_placed_count(bag.item) >= max_bags_per_row:
		return false
	bag.is_placed = true
	bag.reparent(_placed_bags)
	_relayout_row(row)
	_spawn_ready_bag(row)
	bags_changed.emit(bag.item, get_placed_count(bag.item))
	return true


func _remove(bag: BagDrag) -> void:
	var row: int = _row_of(bag.item)
	bag.interactive = false
	bag.reparent(_leaving)
	bag.move_to(_crate_position(row))
	get_tree().create_timer(DragPiece.MOVE_DURATION).timeout.connect(bag.queue_free)
	_relayout_row(row)
	bags_changed.emit(bag.item, get_placed_count(bag.item))


func _relayout_row(row: int) -> void:
	var bags: Array[BagDrag] = get_placed_bags(_orders[row]["item"])
	if bags.is_empty():
		return
	var bag_w: float = bags[0].get_width()
	var step: float = minf(
		bag_w + bag_gap, (row_right - row_left - bag_w) / maxi(bags.size() - 1, 1)
	)
	# Bags are children of PlacedBags in drop order, so later bags already draw on top of
	# earlier ones where a crowded row overlaps. A z_index would also lift them above a bag
	# being dragged.
	for k in bags.size():
		bags[k].move_to(Vector2(row_left + bag_w / 2.0 + k * step, row_y[row]))


func _row_of(item: String) -> int:
	for i in _orders.size():
		if _orders[i]["item"] == item:
			return i
	return -1


func _crate_position(row: int) -> Vector2:
	return Vector2(crate_x, row_y[row])

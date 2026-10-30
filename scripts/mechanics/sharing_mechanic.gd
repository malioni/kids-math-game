class_name SharingMechanic
extends Node2D

## A picnic. Each fruit has a basket showing only how many it holds; friends sit at plates along
## the top. The player drags or taps fruit from the baskets onto the fox's plate (one row per
## fruit), taps a placed fruit to put it back, and presses Go. The basket then deals the fox's
## amount to every friend in turn. Too much and the last friends come up short; too little and
## fruit is left in the basket. How much the fox took is never shown, so the player has to work
## out total ÷ plates themselves.

## Emitted after the deal when every plate got the same of every fruit and the baskets are empty.
signal correct
## Emitted after the deal when any friend came up short or any basket has fruit left.
signal incorrect

## Scene instantiated for each piece of fruit.
const FRUIT_SCENE := preload("res://scenes/mechanics/fruit_drag.tscn")
# Width of a guest plate's fruit rows, in pixels.
const _GUEST_ROW_WIDTH := 150.0
# Vertical distance between a guest plate's fruit rows.
const _GUEST_ROW_SPACING := 28.0
# Seconds a dealt fruit takes to pop in.
const _POP_DURATION := 0.15

## Icon for each fruit id (String → Texture2D), shown on fruit pieces and guest plates.
@export var item_icons: Dictionary = {}
## Texture shown on the Go button.
@export var go_texture: Texture2D
## Texture of the baskets fruit comes from.
@export var basket_texture: Texture2D
## Texture of each friend's plate.
@export var guest_plate_texture: Texture2D
## Frames for the friends. Needs "idle", "celebrate" and "sad" animations.
@export var guest_frames: SpriteFrames
## Tints given to the friends in turn, so they look different from each other.
@export var guest_tints: Array[Color] = [Color.WHITE]
## Scale of each friend's sprite.
@export var guest_scale: float = 2.0
## The fox's plate in local pixels; fruit released inside it is placed.
@export var plate_rect: Rect2 = Rect2(-390, -30, 640, 260)
## Local y of each fruit's row on the fox's plate, top to bottom. Order i uses row i.
@export var row_y: Array[float] = [20.0, 100.0, 180.0]
## Left edge of the fruit in a row, in local pixels.
@export var row_left: float = -370.0
## Right edge of the fruit in a row; crowded rows overlap to stay inside it.
@export var row_right: float = 230.0
## Local x of the baskets, each in line with its row.
@export var basket_x: float = 350.0
## Horizontal gap between fruit in an uncrowded row.
@export var piece_gap: float = 8.0
## Most fruit a row holds (never more than the basket's total); one more bounces back.
@export var max_pieces_per_row: int = 12
## Local x where the friends' row starts.
@export var guest_left: float = -300.0
## Local x where the friends' row ends; friends spread evenly between guest_left and this.
@export var guest_right: float = 540.0
## Local y of each friend's sprite.
@export var guest_y: float = -210.0
## Local y of each friend's plate.
@export var guest_plate_y: float = -100.0
## Size in pixels of the fruit icons dealt onto friends' plates.
@export var mini_icon_size: float = 28.0
## Seconds between dealing to one friend and the next.
@export var deal_step: float = 0.45

var _plates: int = 0
var _orders: Array[Dictionary] = []
var _basket_counts: Dictionary = {}
var _basket_labels: Dictionary = {}
# _dealt[guest][item] is how many of that fruit the guest was dealt.
var _dealt: Array[Dictionary] = []
var _dealing: bool = false
# Bumped on every reset. The deal checks it after each wait, so a reset stops a deal in progress.
var _round: int = 0

@onready var _baskets: Node2D = $Baskets
@onready var _guests: Node2D = $Guests
@onready var _placed_fruit: Node2D = $PlacedFruit
@onready var _ready_fruit: Node2D = $ReadyFruit
@onready var _leaving: Node2D = $Leaving
@onready var _go_button: TextureButton = $GoButton


func _ready() -> void:
	$Tray.position = plate_rect.position
	$Tray.size = plate_rect.size
	if go_texture != null:
		_go_button.texture_normal = go_texture
	_go_button.pressed.connect(confirm)


## Stores the plate count (the fox's included) and the orders, then calls reset(). Each order
## needs "item" and "total".
func setup(plates: int, orders: Array[Dictionary]) -> void:
	_plates = plates
	_orders = orders.duplicate(true)
	reset()


## Stops any deal, empties every plate, refills the baskets and seats the friends again.
func reset() -> void:
	_round += 1
	_dealing = false
	for parent: Node in [_baskets, _guests, _placed_fruit, _ready_fruit, _leaving]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	_basket_counts.clear()
	_basket_labels.clear()
	for i in _orders.size():
		_add_basket(i)
		_spawn_ready_piece(i)
	_dealt.clear()
	for g in _plates - 1:
		_add_guest(g)
		_dealt.append({})


## Starts the deal: the fox's fruit leaves the baskets, then each friend in turn is dealt the
## fox's amount of every fruit, or what's left. Emits correct or incorrect once the deal is done.
## Input stays disabled afterwards until set_interactive(true). Ignored while a deal is running.
func confirm() -> void:
	if _dealing:
		return
	_dealing = true
	set_interactive(false)
	_deal(_round)


## Enables or disables dragging and tapping fruit and pressing the Go button.
func set_interactive(enabled: bool) -> void:
	_go_button.disabled = not enabled
	_go_button.modulate.a = 1.0 if enabled else 0.4
	for piece: FruitDrag in _ready_fruit.get_children() + _placed_fruit.get_children():
		piece.interactive = enabled


## Returns true while the deal animation is running.
func is_dealing() -> bool:
	return _dealing


## Returns the orders passed to setup().
func get_orders() -> Array[Dictionary]:
	return _orders


## Returns how many plates there are, the fox's included.
func get_plate_count() -> int:
	return _plates


## Returns how many of the fruit are on the fox's plate. Never shown to the player.
func get_placed_count(item: String) -> int:
	return get_placed_pieces(item).size()


## Returns the fruit's pieces on the fox's plate, left to right.
func get_placed_pieces(item: String) -> Array[FruitDrag]:
	var pieces: Array[FruitDrag] = []
	for piece: FruitDrag in _placed_fruit.get_children():
		if piece.item == item:
			pieces.append(piece)
	return pieces


## Returns the piece waiting on the fruit's basket, or null if the fruit isn't in the puzzle.
func get_ready_piece(item: String) -> FruitDrag:
	for piece: FruitDrag in _ready_fruit.get_children():
		if piece.item == item:
			return piece
	return null


## Returns the number on the fruit's basket: its total before Go, what's left during the deal.
func get_basket_count(item: String) -> int:
	return _basket_counts.get(item, 0)


## Returns how many of the fruit the friend at index guest (0-based, left to right) was dealt.
func get_dealt_count(guest: int, item: String) -> int:
	return _dealt[guest].get(item, 0)


## Returns the sprite of the friend at index guest (0-based, left to right).
func get_guest(guest: int) -> AnimatedSprite2D:
	return _guests.get_child(guest).get_node("Animal")


func _deal(round_id: int) -> void:
	var shares := {}
	for order in _orders:
		var item: String = order["item"]
		shares[item] = get_placed_count(item)
		_set_basket_count(item, int(order["total"]) - shares[item])
	for g in _dealt.size():
		await _wait(deal_step)
		if not _is_current(round_id):
			return
		for i in _orders.size():
			var item: String = _orders[i]["item"]
			var given: int = mini(shares[item], _basket_counts[item])
			_dealt[g][item] = given
			_set_basket_count(item, _basket_counts[item] - given)
			_show_dealt(g, i, given)
	await _wait(deal_step)
	if not _is_current(round_id):
		return
	var all_equal: bool = true
	for order in _orders:
		if shares[order["item"]] * _plates != int(order["total"]):
			all_equal = false
	for g in _dealt.size():
		var short: bool = false
		for order in _orders:
			if get_dealt_count(g, order["item"]) < shares[order["item"]]:
				short = true
		if short:
			get_guest(g).play("sad")
		elif all_equal:
			get_guest(g).play("celebrate")
	_dealing = false
	if all_equal:
		correct.emit()
	else:
		incorrect.emit()


# A tween bound to this node, so a deal stops quietly if the node is freed mid-wait.
func _wait(seconds: float) -> Signal:
	return create_tween().tween_interval(seconds).finished


func _is_current(round_id: int) -> bool:
	return round_id == _round and is_inside_tree()


func _add_basket(row: int) -> void:
	var item: String = _orders[row]["item"]
	var basket := Sprite2D.new()
	basket.texture = basket_texture
	basket.position = Vector2(basket_x, row_y[row] + 10.0)
	_baskets.add_child(basket)
	var label := Label.new()
	label.position = Vector2(basket_x + 62.0, row_y[row] - 30.0)
	label.size = Vector2(90, 60)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", Color(0.24, 0.15, 0.09))
	label.add_theme_color_override("font_outline_color", Color(1.0, 0.96, 0.86))
	label.add_theme_constant_override("outline_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_baskets.add_child(label)
	_basket_labels[item] = label
	_set_basket_count(item, int(_orders[row]["total"]))


func _set_basket_count(item: String, count: int) -> void:
	_basket_counts[item] = count
	_basket_labels[item].text = str(count)


func _add_guest(guest: int) -> void:
	var seat := Node2D.new()
	var guest_count: int = _plates - 1
	seat.position.x = guest_left + (guest + 0.5) * (guest_right - guest_left) / guest_count
	var animal := AnimatedSprite2D.new()
	animal.name = "Animal"
	animal.sprite_frames = guest_frames
	animal.position.y = guest_y
	animal.scale = Vector2(guest_scale, guest_scale)
	animal.modulate = guest_tints[guest % guest_tints.size()]
	seat.add_child(animal)
	animal.play("idle")
	var plate := Sprite2D.new()
	plate.texture = guest_plate_texture
	plate.position.y = guest_plate_y
	seat.add_child(plate)
	var fruit := Node2D.new()
	fruit.name = "Fruit"
	fruit.position.y = guest_plate_y
	seat.add_child(fruit)
	_guests.add_child(seat)


func _show_dealt(guest: int, row: int, count: int) -> void:
	if count == 0:
		return
	var icon: Texture2D = item_icons.get(_orders[row]["item"])
	var fruit: Node2D = _guests.get_child(guest).get_node("Fruit")
	var y: float = (row - (_orders.size() - 1) / 2.0) * _GUEST_ROW_SPACING
	var step: float = minf(
		mini_icon_size + 2.0, (_GUEST_ROW_WIDTH - mini_icon_size) / maxi(count - 1, 1)
	)
	var x0: float = -(mini_icon_size + (count - 1) * step) / 2.0 + mini_icon_size / 2.0
	var icon_scale: float = mini_icon_size / maxf(icon.get_width(), 1.0) if icon != null else 1.0
	for k in count:
		var sprite := Sprite2D.new()
		sprite.texture = icon
		sprite.position = Vector2(x0 + k * step, y)
		sprite.scale = Vector2.ZERO
		fruit.add_child(sprite)
		var pop := create_tween()
		pop.tween_property(sprite, "scale", Vector2(icon_scale, icon_scale), _POP_DURATION)


func _spawn_ready_piece(row: int) -> void:
	var item: String = _orders[row]["item"]
	var piece: FruitDrag = FRUIT_SCENE.instantiate()
	piece.position = _basket_position(row)
	piece.dropped.connect(_on_piece_dropped.bind(piece))
	piece.tapped.connect(_on_piece_tapped.bind(piece))
	_ready_fruit.add_child(piece)
	piece.configure(item, item_icons.get(item))


func _on_piece_dropped(release_position: Vector2, piece: FruitDrag) -> void:
	var over_plate: bool = plate_rect.has_point(to_local(release_position))
	if not over_plate or not _place(piece):
		piece.bounce_back()


func _on_piece_tapped(piece: FruitDrag) -> void:
	if piece.is_placed:
		_remove(piece)
	else:
		_place(piece)


func _place(piece: FruitDrag) -> bool:
	var row: int = _row_of(piece.item)
	var cap: int = mini(max_pieces_per_row, int(_orders[row]["total"]))
	if get_placed_count(piece.item) >= cap:
		return false
	piece.is_placed = true
	piece.reparent(_placed_fruit)
	_relayout_row(row)
	_spawn_ready_piece(row)
	return true


func _remove(piece: FruitDrag) -> void:
	var row: int = _row_of(piece.item)
	piece.interactive = false
	piece.reparent(_leaving)
	piece.move_to(_basket_position(row))
	get_tree().create_timer(DragPiece.MOVE_DURATION).timeout.connect(piece.queue_free)
	_relayout_row(row)


func _relayout_row(row: int) -> void:
	var pieces: Array[FruitDrag] = get_placed_pieces(_orders[row]["item"])
	if pieces.is_empty():
		return
	var piece_w: float = pieces[0].get_width()
	var step: float = minf(
		piece_w + piece_gap, (row_right - row_left - piece_w) / maxi(pieces.size() - 1, 1)
	)
	# Pieces are children of PlacedFruit in drop order, so later ones already draw on top where a
	# crowded row overlaps. A z_index would also lift them above a piece being dragged.
	for k in pieces.size():
		pieces[k].move_to(Vector2(row_left + piece_w / 2.0 + k * step, row_y[row]))


func _row_of(item: String) -> int:
	for i in _orders.size():
		if _orders[i]["item"] == item:
			return i
	return -1


func _basket_position(row: int) -> Vector2:
	return Vector2(basket_x, row_y[row] - 6.0)

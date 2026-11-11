class_name WorldCarousel
extends Control

## A horizontal strip of picture cards, one per item, that snaps to one centred card.
##
## Swipe the strip or use the arrow buttons to move; tap a card to pick it. Cards further from the
## centre are drawn smaller and fainter. Nothing in here knows about worlds: callers pass a list of
## {"id": String, "icon": Texture2D} items (normally built from GameRegistry.WORLDS). Every card's
## place on the strip comes from _card_position(), and the cards sit on Track, which is what
## scrolls, so a painted path can replace the straight line later.

## Emitted when a card is tapped. was_centred is true if it was already the centred card; the
## tapped card is centred either way.
signal card_pressed(id: String, was_centred: bool)
## Emitted when a different card becomes the centred one.
signal centred_changed(id: String)

const _TAP_THRESHOLD := 12.0
const _SNAP_DURATION := 0.2
# How far past either end a swipe can pull the strip, in cards.
const _OVERSCROLL := 0.3
const _CREAM := Color(1.0, 0.96, 0.86)
const _CURRENT := Color(1.0, 0.72, 0.3)
const _FRAME := preload("res://assets/sprites/ui/card_frame.png")
const _FRAME_MARGIN := 24.0

## Size of the centred card.
@export var card_size: Vector2 = Vector2(360, 300)
## Distance between neighbouring cards' centres.
@export var pitch: float = 420.0
## Scale of a card one place or more away from the centre.
@export var side_scale: float = 0.75
## Opacity of a card one place or more away from the centre.
@export var side_alpha: float = 0.6
## Drawn along the strip behind the cards when set (for a future painted path).
@export var track_texture: Texture2D:
	set(value):
		track_texture = value
		queue_redraw()

var _items: Array[Dictionary] = []
var _cards: Array[Panel] = []
var _centred: int = 0
# Scroll position in cards: 0.0 has the first card centred, 1.0 the second, and so on.
var _offset: float = 0.0
var _highlighted: String = ""
var _pressing: bool = false
var _dragging: bool = false
var _press_position := Vector2.ZERO
var _press_offset: float = 0.0
var _tween: Tween

@onready var _track: Control = $Track
@onready var _prev_button: TextureButton = $PrevButton
@onready var _next_button: TextureButton = $NextButton


func _ready() -> void:
	_prev_button.pressed.connect(previous)
	_next_button.pressed.connect(next)
	resized.connect(_layout)
	_layout()


func _draw() -> void:
	if track_texture and not _cards.is_empty():
		var start: Vector2 = _track.position + _card_position(0)
		var end: Vector2 = _track.position + _card_position(_cards.size() - 1)
		var height: float = card_size.y * 0.4
		draw_texture_rect(
			track_texture, Rect2(start.x, start.y - height / 2.0, end.x - start.x, height), true
		)


## Replaces the cards with one per item, in order, and centres the first.
func set_items(items: Array[Dictionary]) -> void:
	_items = items
	for card in _cards:
		_track.remove_child(card)
		card.queue_free()
	_cards.clear()
	for item in items:
		_cards.append(_make_card(item))
	_centred = 0
	_offset = 0.0
	_apply_highlight()
	_layout()


## Centres the card with the given id, sliding to it unless animate is false. Does nothing for an
## unknown id.
func scroll_to(id: String, animate: bool = true) -> void:
	var index: int = _index_of(id)
	if index >= 0:
		_scroll_to_index(index, animate)


## Centres the next card, if there is one.
func next() -> void:
	_scroll_to_index(mini(_centred + 1, _cards.size() - 1), true)


## Centres the previous card, if there is one.
func previous() -> void:
	_scroll_to_index(maxi(_centred - 1, 0), true)


## Returns the id of the centred card, or "" when there are no cards.
func get_centred_id() -> String:
	return _items[_centred]["id"] if not _items.is_empty() else ""


## Returns the cards in item order.
func get_cards() -> Array[Panel]:
	return _cards


## Returns the previous and next arrow buttons, so a screen can react to their taps.
func get_arrow_buttons() -> Array[TextureButton]:
	return [_prev_button, _next_button]


## Returns the card for the given id, or null if there is none.
func get_card(id: String) -> Panel:
	var index: int = _index_of(id)
	return _cards[index] if index >= 0 else null


## Draws the card with the given id in the highlight colour and every other card plainly. "" (or an
## unknown id) highlights none.
func set_highlighted(id: String) -> void:
	_highlighted = id
	_apply_highlight()


## Returns where the card at index sits on the track, relative to the first card's centre.
func _card_position(index: int) -> Vector2:
	return Vector2(index * pitch, 0.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_press(event.position)
		elif _pressing:
			_on_release(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _pressing:
		_on_drag(event.position)
		accept_event()


func _on_press(at: Vector2) -> void:
	_pressing = true
	_dragging = false
	_press_position = at
	if _tween:
		_tween.kill()
	_press_offset = _offset


func _on_drag(at: Vector2) -> void:
	var drag: float = at.x - _press_position.x
	if not _dragging and absf(drag) > _TAP_THRESHOLD:
		_dragging = true
	if _dragging and not _all_fit():
		var last: float = _cards.size() - 1
		_set_offset(clampf(_press_offset - drag / pitch, -_OVERSCROLL, last + _OVERSCROLL))


func _on_release(at: Vector2) -> void:
	_pressing = false
	if _dragging or at.distance_to(_press_position) > _TAP_THRESHOLD:
		_dragging = false
		var target: float = _press_offset - (at.x - _press_position.x) / pitch
		_scroll_to_index(clampi(roundi(target), 0, _cards.size() - 1), true)
		return
	var index: int = _card_at(at)
	if index < 0:
		return
	var was_centred: bool = index == _centred
	_scroll_to_index(index, true)
	card_pressed.emit(_items[index]["id"], was_centred)


func _scroll_to_index(index: int, animate: bool) -> void:
	if _cards.is_empty():
		return
	var changed: bool = index != _centred
	_centred = index
	if _tween:
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.tween_method(_set_offset, _offset, float(index), _SNAP_DURATION)
	else:
		_set_offset(index)
	_update_arrows()
	if changed:
		centred_changed.emit(_items[index]["id"])


func _set_offset(value: float) -> void:
	_offset = value
	_layout()


func _layout() -> void:
	if not is_node_ready():
		return
	var view_offset: float = (_cards.size() - 1) / 2.0 if _all_fit() else _offset
	_track.position = size / 2.0 - Vector2(view_offset * pitch, 0.0)
	for i in _cards.size():
		var card: Panel = _cards[i]
		var away: float = clampf(absf(i - view_offset), 0.0, 1.0)
		if _all_fit():
			away = 0.0
		card.size = card_size
		card.pivot_offset = card_size / 2.0
		card.position = _card_position(i) - card_size / 2.0
		card.scale = Vector2.ONE * lerpf(1.0, side_scale, away)
		card.modulate.a = lerpf(1.0, side_alpha, away)
		card.z_index = 10 - mini(absi(i - roundi(view_offset)), 10)
	_update_arrows()
	queue_redraw()


func _update_arrows() -> void:
	if not is_node_ready():
		return
	var scrolls: bool = not _all_fit()
	_prev_button.visible = scrolls and _centred > 0
	_next_button.visible = scrolls and _centred < _cards.size() - 1


func _all_fit() -> bool:
	return (_cards.size() - 1) * pitch + card_size.x <= size.x


# Checks the cards nearest the centre first, since they are drawn on top.
func _card_at(at: Vector2) -> int:
	var order: Array = range(_cards.size())
	order.sort_custom(func(a: int, b: int) -> bool: return _cards[a].z_index > _cards[b].z_index)
	for i: int in order:
		var card: Panel = _cards[i]
		var half: Vector2 = card_size * card.scale / 2.0
		var centre: Vector2 = _track.position + _card_position(i)
		if Rect2(centre - half, half * 2.0).has_point(at):
			return i
	return -1


func _index_of(id: String) -> int:
	for i in _items.size():
		if _items[i]["id"] == id:
			return i
	return -1


func _make_card(item: Dictionary) -> Panel:
	var card := Panel.new()
	card.name = "Card_%s" % item["id"]
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxTexture.new()
	frame.texture = _FRAME
	frame.set_texture_margin_all(_FRAME_MARGIN)
	card.add_theme_stylebox_override("panel", frame)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = item["icon"]
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset: float = minf(card_size.x, card_size.y) * 0.12
	icon.offset_left = inset
	icon.offset_top = inset
	icon.offset_right = -inset
	icon.offset_bottom = -inset
	card.add_child(icon)
	_track.add_child(card)
	return card


func _apply_highlight() -> void:
	for i in _cards.size():
		var frame: StyleBoxTexture = _cards[i].get_theme_stylebox("panel")
		frame.modulate_color = _CURRENT if _items[i]["id"] == _highlighted else _CREAM

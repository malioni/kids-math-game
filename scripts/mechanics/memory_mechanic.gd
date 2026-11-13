class_name MemoryMechanic
extends Mechanic

## A memory game. Animal cards lie face down in a grid; the player turns over two at a time. A
## matching pair leaves the board; a mismatch shows both faces for a moment, then turns them back.
## correct is emitted when every pair is found. There is no limit on turns, so a mismatch is never
## a wrong answer and incorrect is never emitted.

## Emitted once for each pair the player finds, with the pair's animal.
signal pair_matched(animal: String)

## Scene instantiated for each card.
const CARD_SCENE := preload("res://scenes/mechanics/memory_card.tscn")
## Grid (columns, rows) for each deck size.
const GRIDS := {
	4: Vector2i(4, 1),
	6: Vector2i(3, 2),
	8: Vector2i(4, 2),
	10: Vector2i(5, 2),
	12: Vector2i(4, 3),
	14: Vector2i(7, 2),
	16: Vector2i(4, 4),
	18: Vector2i(6, 3),
	20: Vector2i(5, 4),
}

## Face texture for each animal (String → Texture2D).
@export var card_textures: Dictionary = {}
## Area the grid is centred in, in local pixels.
@export var board_rect: Rect2 = Rect2(-340, -330, 950, 660)
## Gap between cards, in pixels.
@export var card_gap: float = 16.0
## Largest a card is drawn, in pixels; small decks stop growing here.
@export var max_card_size: float = 200.0
## Seconds a matching pair stays face up before it leaves the board.
@export var match_delay: float = 0.4
## Seconds a mismatched pair stays face up before turning back.
@export var mismatch_delay: float = 1.0

var _deck: Array[String] = []
var _turned: Array[MemoryCard] = []
var _interactive: bool = true
var _previewing: bool = false
# Bumped on every reset. Pending waits check it, so a reset stops a preview or turn-back in
# progress.
var _round: int = 0

@onready var _cards: Node2D = $Cards


## Returns the grid (columns, rows) a deck of card_count cards is dealt into.
static func grid_for(card_count: int) -> Vector2i:
	return GRIDS[card_count]


## Deals the deck face down into the grid. With preview_seconds above 0, every card shows face up
## for that long first, and taps are ignored until the cards turn down.
func setup(deck: Array[String], preview_seconds: float) -> void:
	_deck = deck.duplicate()
	reset()
	if preview_seconds > 0.0:
		_preview(preview_seconds, _round)


## Deals the same deck again, every card face down and unmatched, with no preview.
func reset() -> void:
	_round += 1
	_previewing = false
	_turned.clear()
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	var grid: Vector2i = grid_for(_deck.size())
	var card_size: float = _card_size(grid)
	var step: float = card_size + card_gap
	var origin: Vector2 = board_rect.get_center() - Vector2(grid.x - 1, grid.y - 1) * step / 2.0
	for i in _deck.size():
		var card: MemoryCard = CARD_SCENE.instantiate()
		card.position = origin + Vector2(i % grid.x, i / grid.x) * step
		_cards.add_child(card)
		card.setup(_deck[i], card_textures.get(_deck[i]), card_size)
		card.tapped.connect(_on_card_tapped.bind(card))


## Enables or disables turning cards over.
func set_interactive(enabled: bool) -> void:
	_interactive = enabled


## Turns over the card at index (0-based, in deck order), as if the player tapped it.
func tap_card(index: int) -> void:
	_on_card_tapped(get_cards()[index])


## Returns the cards in deck order, matched ones included.
func get_cards() -> Array[MemoryCard]:
	var cards: Array[MemoryCard] = []
	for card: MemoryCard in _cards.get_children():
		cards.append(card)
	return cards


## Returns the deck passed to setup(): one animal per card, in grid order.
func get_deck() -> Array[String]:
	return _deck


## Returns how many pairs have been found.
func get_matched_count() -> int:
	return get_cards().filter(func(card: MemoryCard) -> bool: return card.is_matched()).size() / 2


## Returns true once every pair has been found.
func is_solved() -> bool:
	return get_matched_count() * 2 == _deck.size()


## Returns true while the cards are showing face up before the first turn.
func is_previewing() -> bool:
	return _previewing


func _card_size(grid: Vector2i) -> float:
	var fit_w: float = (board_rect.size.x - card_gap * (grid.x - 1)) / grid.x
	var fit_h: float = (board_rect.size.y - card_gap * (grid.y - 1)) / grid.y
	return minf(max_card_size, minf(fit_w, fit_h))


func _preview(seconds: float, round_id: int) -> void:
	_previewing = true
	for card in get_cards():
		card.show_face(false)
	await _wait(seconds)
	if not _is_current(round_id):
		return
	for card in get_cards():
		card.show_back()
	_previewing = false


func _on_card_tapped(card: MemoryCard) -> void:
	if not _interactive or _previewing or _turned.size() >= 2:
		return
	if card.is_face_up() or card.is_matched():
		return
	card.show_face()
	_turned.append(card)
	piece_placed.emit()
	if _turned.size() == 2:
		_resolve(_round)


func _resolve(round_id: int) -> void:
	var first: MemoryCard = _turned[0]
	var second: MemoryCard = _turned[1]
	var matched: bool = first.get_animal() == second.get_animal()
	await _wait(match_delay if matched else mismatch_delay)
	if not _is_current(round_id):
		return
	_turned.clear()
	if not matched:
		first.show_back()
		second.show_back()
		piece_removed.emit()
		return
	first.mark_matched()
	second.mark_matched()
	pair_matched.emit(first.get_animal())
	if is_solved():
		correct.emit()


# A tween bound to this node, so a wait stops quietly if the node is freed mid-wait.
func _wait(seconds: float) -> Signal:
	return create_tween().tween_interval(seconds).finished


func _is_current(round_id: int) -> bool:
	return round_id == _round and is_inside_tree()

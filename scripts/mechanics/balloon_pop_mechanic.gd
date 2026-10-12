class_name BalloonPopMechanic
extends Node2D

## A bunch of numbered balloons lifting a weight. The lift total (sum of unpopped balloons) and
## the weight (target) are both shown. Popping a balloon lowers the lift: landing exactly on the
## weight emits correct, going below it emits incorrect. Starts with more lift than weight, so the
## child has to take away the difference.
##
## Local origin is where the ropes meet the load (e.g. a basket's rim). Balloon strings meet at
## knot_position, where the lift total is shown.

## Emitted when popping a balloon makes the lift equal the weight.
signal correct
## Emitted when popping a balloon makes the lift less than the weight.
signal incorrect
## Emitted on every pop and on reset, with the new lift total.
signal total_changed(new_total: int)

## Scene instantiated for each balloon.
const BALLOON_SCENE := preload("res://scenes/mechanics/balloon.tscn")

## Where the balloon strings meet, and where the lift total is shown.
@export var knot_position: Vector2 = Vector2(0, -130)
## Points on the load that ropes run to from the knot.
@export var rope_ends: PackedVector2Array = PackedVector2Array([Vector2(-62, 4), Vector2(62, 4)])
## Point on the load the weight sign hangs from.
@export var weight_rope_start: Vector2 = Vector2(66, 8)
## Local y of each balloon row's centre, lowest row first.
@export var row_y: Array[float] = [-250.0, -380.0]
## Most balloons in one row; more than this splits the bunch over the rows.
@export var max_per_row: int = 4
## Horizontal gap between neighbouring balloons in a row.
@export var balloon_spacing: float = 12.0
## Radius of a balloon numbered 0; radius grows with the square root of the number.
@export var radius_base: float = 30.0
## Radius added per square root of the balloon's number.
@export var radius_per_sqrt: float = 8.0
## Balloon colours, used in turn.
@export var palette: Array[Color] = [
	Color(0.92, 0.33, 0.33),
	Color(0.98, 0.72, 0.22),
	Color(0.38, 0.72, 0.42),
	Color(0.35, 0.55, 0.9),
	Color(0.7, 0.45, 0.85),
	Color(0.95, 0.5, 0.7),
	Color(0.25, 0.7, 0.75),
	Color(0.9, 0.55, 0.25),
]
## Colour of the ropes from the knot to the load.
@export var rope_color: Color = Color(0.4, 0.3, 0.2)

var _target: int = 0
var _values: Array[int] = []
var _interactive: bool = true

@onready var _balloons: Node2D = $Balloons
@onready var _lift_badge: Node2D = $LiftBadge
@onready var _lift_label: Label = $LiftBadge/LiftLabel
@onready var _weight_sign: Node2D = $WeightSign
@onready var _weight_label: Label = $WeightSign/WeightLabel


func _ready() -> void:
	_lift_badge.position = knot_position


## Stores the puzzle (the weight and every balloon's number) and calls reset().
func setup(target: int, balloon_values: Array[int]) -> void:
	_target = target
	_values = balloon_values.duplicate()
	reset()


## Brings back every balloon, rebuilt from the stored puzzle.
func reset() -> void:
	for child in _balloons.get_children():
		_balloons.remove_child(child)
		child.queue_free()
	_spawn_balloons()
	_weight_label.text = str(_target)
	_update_lift()
	queue_redraw()


## Pops the given balloon and checks the new lift against the weight.
func pop(balloon: Balloon) -> void:
	if balloon.is_popped or not _interactive:
		return
	balloon.pop()
	_update_lift()
	var lift: int = get_lift_total()
	if lift == _target:
		correct.emit()
	elif lift < _target:
		incorrect.emit()


## Enables or disables popping balloons.
func set_interactive(enabled: bool) -> void:
	_interactive = enabled
	for balloon: Balloon in get_balloons():
		balloon.interactive = enabled


## Returns the weight the balloons must balance.
func get_target() -> int:
	return _target


## Returns the sum of the numbers on the balloons that haven't popped.
func get_lift_total() -> int:
	var total: int = 0
	for balloon: Balloon in get_balloons():
		if not balloon.is_popped:
			total += balloon.value
	return total


## Returns lift minus weight: positive while rising, 0 when level, negative when falling.
func get_balance() -> int:
	return get_lift_total() - _target


## Returns every balloon, popped or not.
func get_balloons() -> Array[Node]:
	return _balloons.get_children()


## Returns the balloons that haven't popped.
func get_unpopped_balloons() -> Array[Node]:
	return get_balloons().filter(func(b: Balloon) -> bool: return not b.is_popped)


## Returns the drawn radius for a balloon with the given number.
func radius_for(value: int) -> float:
	return radius_base + radius_per_sqrt * sqrt(float(value))


func _spawn_balloons() -> void:
	var rows: int = mini(ceili(float(_values.size()) / max_per_row), row_y.size())
	var per_row: int = ceili(float(_values.size()) / maxi(rows, 1))
	# Higher rows are added first so their strings pass behind the balloons below them.
	for row in range(rows - 1, -1, -1):
		var start: int = row * per_row
		var row_values: Array[int] = _values.slice(start, start + per_row)
		var widths: Array[float] = []
		var row_width: float = balloon_spacing * (row_values.size() - 1)
		for value in row_values:
			widths.append(radius_for(value) * 2.0)
			row_width += widths[-1]
		var cursor: float = -row_width / 2.0
		for i in row_values.size():
			var balloon: Balloon = BALLOON_SCENE.instantiate()
			balloon.position = Vector2(cursor + widths[i] / 2.0, row_y[row])
			cursor += widths[i] + balloon_spacing
			_balloons.add_child(balloon)
			var color: Color = palette[(start + i) % palette.size()]
			balloon.configure(
				row_values[i], widths[i] / 2.0, color, knot_position - balloon.position
			)
			balloon.interactive = _interactive
			balloon.tapped.connect(pop.bind(balloon))


func _update_lift() -> void:
	var lift: int = get_lift_total()
	_lift_label.text = str(lift)
	total_changed.emit(lift)


func _draw() -> void:
	for rope_end in rope_ends:
		draw_line(knot_position, rope_end, rope_color, 3.0, true)
	draw_line(weight_rope_start, _weight_sign.position + Vector2(0, -50), rope_color, 3.0, true)

extends WorldBase

## World 5: animal cards lie face down in a meadow, the fox's among them. The child turns over two
## at a time; each pair found makes the fox hop, and clearing the board wins the level. A mismatch
## just turns back, so there is no wrong answer and no retry.

## Seconds the fox hops after each pair is found.
@export var hop_duration: float = 0.4

var _hop_tween: Tween

@onready var _mechanic: MemoryMechanic = $MemoryMechanic


func _ready() -> void:
	super()
	_mechanic.pair_matched.connect(_on_pair_matched)


func _world_id() -> String:
	return "memory"


func _get_mechanic() -> Mechanic:
	return _mechanic


func _setup_level(level: Dictionary) -> void:
	var deck: Array[String] = MemoryPuzzleGenerator.generate(level, _rng)
	_mechanic.setup(deck, float(level["preview_seconds"]))


func _restore_stage() -> void:
	if _hop_tween != null:
		_hop_tween.kill()
	super()


func _on_pair_matched(_animal: String) -> void:
	# The last pair goes straight into the win flow, which has its own sound and celebration.
	if _mechanic.is_solved():
		return
	AudioManager.play_sfx("memory/match")
	_character.play("celebrate")
	if _hop_tween != null:
		_hop_tween.kill()
	_hop_tween = create_tween()
	_hop_tween.tween_interval(hop_duration)
	_hop_tween.tween_callback(_character.play.bind("idle"))

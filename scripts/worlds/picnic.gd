extends WorldBase

## World 4: the fox and its friends share a picnic. The child fills the fox's plate and the
## baskets deal the same to every friend. A fair share makes everyone cheer; an unfair one makes
## the fox sad, and the child tries again.

## Seconds the sad fox shows before the retry prompt appears.
@export var sad_duration: float = 0.8

@onready var _mechanic: SharingMechanic = $SharingMechanic


func _world_id() -> String:
	return "picnic"


func _get_mechanic() -> Mechanic:
	return _mechanic


func _setup_level(level: Dictionary) -> void:
	var puzzle: Dictionary = SharingPuzzleGenerator.generate(level, _rng)
	_mechanic.setup(puzzle["plates"], puzzle["orders"])


func _play_lose() -> void:
	_character.play("sad")
	await get_tree().create_timer(sad_duration).timeout

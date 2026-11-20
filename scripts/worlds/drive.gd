extends WorldBase

## World 6: the fox drives its car across a field to its garage, following the program the child
## builds first. A bump or a program that ends anywhere but the garage shows the retry button;
## retry keeps the program so it can be fixed.

## Seconds the horn plays before the celebration.
@export var honk_duration: float = 0.4
## Seconds the bump or sad animation plays before the retry button appears.
@export var lose_duration: float = 0.8

# "bump" or "short": how the last run went wrong, set just before the mechanic emits incorrect.
var _failure: String = ""

@onready var _mechanic: DriveMechanic = $DriveMechanic


func _ready() -> void:
	super()
	_mechanic.bumped.connect(_on_bumped)
	_mechanic.stopped_short.connect(_on_stopped_short)
	_mechanic.stepped.connect(AudioManager.play_sfx.bind("drive/step"))


func _world_id() -> String:
	return "drive"


func _get_mechanic() -> Mechanic:
	return _mechanic


# WorldBase reads this while its @onready variables are set, before this script's _mechanic is.
func _get_character() -> AnimatedSprite2D:
	return ($DriveMechanic as DriveMechanic).get_car()


func _setup_level(level: Dictionary) -> void:
	_mechanic.setup(DrivePuzzleGenerator.generate(level, _rng), str(level["mode"]))


func _restore_stage() -> void:
	_mechanic.reset()
	super()


func _play_win() -> void:
	AudioManager.play_sfx("drive/honk")
	await get_tree().create_timer(honk_duration).timeout


func _play_lose() -> void:
	if _failure == "bump":
		AudioManager.play_sfx("drive/bump")
		_character.play("bump")
	else:
		_character.play("sad")
	await get_tree().create_timer(lose_duration).timeout


func _on_bumped(_kind: String) -> void:
	_failure = "bump"


func _on_stopped_short() -> void:
	_failure = "short"

extends Node

## Global registry for worlds and mechanics available in the game.
##
## Lists every world in play order and handles moving between them. Also handles the
## application quit flow. Because [member auto_accept_quit] is disabled in project settings, the
## OS quit request is routed here via [constant NOTIFICATION_WM_CLOSE_REQUEST] so the game can
## save state before exiting.

## The main menu scene.
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
## Levels in one shuffle round, however many worlds there are.
const SHUFFLE_ROUND_LENGTH := 10

## Every world in play order. "id" matches the world's level folder (data/levels/world_<id>/)
## and its save key; "icon" is shown on the world's card in the menu and on the level badge.
## Every world needs levels for all of every difficulty's range in data/levels/difficulty.json.
const WORLDS: Array[Dictionary] = [
	{
		"id": "forest",
		"scene": "res://scenes/worlds/forest_bridge/forest_bridge.tscn",
		"icon": "res://assets/sprites/ui/icon_world_forest.svg",
	},
	{
		"id": "sky",
		"scene": "res://scenes/worlds/sky_balloons/sky_balloons.tscn",
		"icon": "res://assets/sprites/ui/icon_world_sky.svg",
	},
	{
		"id": "market",
		"scene": "res://scenes/worlds/market/market.tscn",
		"icon": "res://assets/sprites/ui/icon_world_market.svg",
	},
	{
		"id": "picnic",
		"scene": "res://scenes/worlds/picnic/picnic.tscn",
		"icon": "res://assets/sprites/ui/icon_world_picnic.svg",
	},
	{
		"id": "memory",
		"scene": "res://scenes/worlds/memory/memory.tscn",
		"icon": "res://assets/sprites/ui/icon_world_memory.svg",
	},
	{
		"id": "drive",
		"scene": "res://scenes/worlds/drive/drive.tscn",
		"icon": "res://assets/sprites/ui/icon_world_drive.svg",
	},
]

## When false, go_to_world() and go_to_menu() only record where they were going (in
## last_world_request and last_scene_request) instead of changing scene. Tests turn it off so a
## world switch doesn't replace the test runner's scene.
var change_scenes: bool = true
## The world the last go_to_world() call asked for.
var last_world_request: String = ""
## The scene path the last go_to_world() or go_to_menu() call asked for.
var last_scene_request: String = ""

var _requested_levels := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


## Returns every registered world in play order.
func get_worlds() -> Array[Dictionary]:
	return WORLDS


## Returns the registered world with the given id, or {} if there is none.
func get_world(world_id: String) -> Dictionary:
	for world in WORLDS:
		if world["id"] == world_id:
			return world
	return {}


## Fades to the given world's scene. A level_index of 0 or more starts that level (0-based); -1
## lets the world resume from its saved progress.
func go_to_world(world_id: String, level_index: int = -1) -> void:
	var world: Dictionary = get_world(world_id)
	if world.is_empty():
		push_error("GameRegistry: unknown world %s" % world_id)
		return
	if level_index >= 0:
		request_level(world_id, level_index)
	last_world_request = world_id
	_change_scene(world["scene"])


## Fades to the main menu. Mode, difficulty and progress are left as they are.
func go_to_menu() -> void:
	_change_scene(MENU_SCENE)


## Asks the given world to start at level_index (0-based) the next time it loads, instead of
## resuming from its save.
func request_level(world_id: String, level_index: int) -> void:
	_requested_levels[world_id] = level_index


## Returns and clears the level requested for the given world by go_to_world(), or -1 if none.
func take_requested_level(world_id: String) -> int:
	var index: int = _requested_levels.get(world_id, -1)
	_requested_levels.erase(world_id)
	return index


## Returns the game-wide difficulty, "easy" or "hard".
func get_difficulty() -> String:
	return SaveManager.load_difficulty()


## Sets and saves the game-wide difficulty, "easy" or "hard".
func set_difficulty(difficulty: String) -> void:
	SaveManager.save_difficulty(difficulty)


## Returns the difficulty after the current one, or "" when it is already the hardest.
func next_difficulty() -> String:
	return LevelLoader.get_next_difficulty(get_difficulty())


## Returns true while the game is in shuffle mode.
func is_shuffle() -> bool:
	return SaveManager.load_play_mode() == "shuffle"


## Turns shuffle mode on or off and saves it, so the game reopens in the same mode.
func set_shuffle(enabled: bool) -> void:
	SaveManager.save_play_mode("shuffle" if enabled else "worlds")


## Returns the 0-based first and last level index (x and y) of the current difficulty.
func get_level_range() -> Vector2i:
	return LevelLoader.get_difficulty_range(get_difficulty())


## Returns the 0-based index of the given world's next shuffle level at the current difficulty.
## Shuffle keeps each world's place between rounds; a place past the end of the difficulty's
## levels goes back to its first.
func shuffle_next_index(world_id: String) -> int:
	var level_range: Vector2i = get_level_range()
	var key: String = SaveManager.progress_key(world_id, get_difficulty(), true)
	var index: int = maxi(SaveManager.load_progress(key) - 1, level_range.x)
	return level_range.x if index > level_range.y else index


## Returns where the current shuffle round is (x, 1-based: the level being played) out of
## SHUFFLE_ROUND_LENGTH (y), e.g. (3, 10).
func shuffle_position() -> Vector2i:
	var played: int = SaveManager.load_shuffle_round_played()
	return Vector2i(mini(played + 1, SHUFFLE_ROUND_LENGTH), SHUFFLE_ROUND_LENGTH)


## Returns the worlds switched on for shuffle, in play order. If fewer than two are on (e.g. a
## save edited by hand), every world is.
func shuffle_worlds() -> Array[String]:
	var off: Array[String] = SaveManager.load_shuffle_off()
	var on: Array[String] = []
	for world in WORLDS:
		if not world["id"] in off:
			on.append(world["id"])
	if on.size() < 2:
		on.clear()
		for world in WORLDS:
			on.append(world["id"])
	return on


## Switches the given world on or off for shuffle and saves it. Returns false, changing nothing,
## when that would leave fewer than two worlds on.
func set_shuffle_world_on(world_id: String, on: bool) -> bool:
	var worlds: Array[String] = shuffle_worlds()
	if not on and world_id in worlds and worlds.size() <= 2:
		return false
	if on and not world_id in worlds:
		worlds.append(world_id)
	elif not on:
		worlds.erase(world_id)
	var off: Array[String] = []
	for world in WORLDS:
		if not world["id"] in worlds:
			off.append(world["id"])
	SaveManager.save_shuffle_off(off)
	return true


## Returns a random switched-on world other than previous, for the next shuffle level.
func next_shuffle_world(previous: String = "") -> String:
	return ShufflePicker.pick(shuffle_worlds(), previous, _rng)


## Returns true once the current shuffle round has had SHUFFLE_ROUND_LENGTH wins.
func is_shuffle_round_finished() -> bool:
	return SaveManager.load_shuffle_round_played() >= SHUFFLE_ROUND_LENGTH


## Starts a new shuffle round. Every world keeps its shuffle place.
func start_new_shuffle_round() -> void:
	SaveManager.save_shuffle_round_played(0)


## Turns shuffle on and goes to a random switched-on world, starting a new round first if the last
## one is finished. The round count is kept when the player leaves shuffle or changes difficulty,
## so an unfinished round carries on.
func start_shuffle() -> void:
	set_shuffle(true)
	if is_shuffle_round_finished():
		start_new_shuffle_round()
	go_to_world(next_shuffle_world())


func _change_scene(path: String) -> void:
	last_scene_request = path
	if change_scenes:
		Transition.change_scene(path)

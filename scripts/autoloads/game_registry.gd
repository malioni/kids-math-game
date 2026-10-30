extends Node

## Global registry for worlds and mechanics available in the game.
##
## Lists every world in play order and handles moving between them. Also handles the
## application quit flow. Because [member auto_accept_quit] is disabled in project settings, the
## OS quit request is routed here via [constant NOTIFICATION_WM_CLOSE_REQUEST] so the game can
## save state before exiting.

## Every world in play order. "id" matches the world's level folder (data/levels/world_<id>/)
## and its save key; "icon" is shown in the level picker.
const WORLDS: Array[Dictionary] = [
	{
		"id": "forest",
		"scene": "res://scenes/worlds/forest_bridge/forest_bridge.tscn",
		"icon": "res://assets/sprites/ui/icon_world_forest.png",
	},
	{
		"id": "sky",
		"scene": "res://scenes/worlds/sky_balloons/sky_balloons.tscn",
		"icon": "res://assets/sprites/ui/icon_world_sky.png",
	},
	{
		"id": "market",
		"scene": "res://scenes/worlds/market/market.tscn",
		"icon": "res://assets/sprites/ui/icon_world_market.png",
	},
	{
		"id": "picnic",
		"scene": "res://scenes/worlds/picnic/picnic.tscn",
		"icon": "res://assets/sprites/ui/icon_world_picnic.png",
	},
]

## When false, go_to_world() records the world in last_world_request instead of changing scene.
## Tests turn it off so a world switch doesn't replace the test runner's scene.
var change_scenes: bool = true
## The world the last go_to_world() call asked for.
var last_world_request: String = ""

var _requested_levels := {}
var _level_counts := {}
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


## Returns how many levels the given world has (0 for an unknown world).
func get_level_count(world_id: String) -> int:
	if not _level_counts.has(world_id):
		_level_counts[world_id] = LevelLoader.get_levels_for_world(world_id).size()
	return _level_counts[world_id]


## Switches to the given world's scene. A level_index of 0 or more starts that level (0-based);
## -1 lets the world resume from its saved progress.
func go_to_world(world_id: String, level_index: int = -1) -> void:
	var world: Dictionary = get_world(world_id)
	if world.is_empty():
		push_error("GameRegistry: unknown world %s" % world_id)
		return
	if level_index >= 0:
		request_level(world_id, level_index)
	last_world_request = world_id
	if change_scenes:
		get_tree().change_scene_to_file(world["scene"])


## Asks the given world to start at level_index (0-based) the next time it loads, instead of
## resuming from its save.
func request_level(world_id: String, level_index: int) -> void:
	_requested_levels[world_id] = level_index


## Returns and clears the level requested for the given world by go_to_world(), or -1 if none.
func take_requested_level(world_id: String) -> int:
	var index: int = _requested_levels.get(world_id, -1)
	_requested_levels.erase(world_id)
	return index


## Opens the world played last, or the first world if none is saved.
func start_last_world() -> void:
	var world_id: String = SaveManager.load_last_world()
	if get_world(world_id).is_empty():
		world_id = WORLDS[0]["id"]
	go_to_world(world_id)


## Returns the game-wide difficulty, "easy" or "hard".
func get_difficulty() -> String:
	return SaveManager.load_difficulty()


## Sets and saves the game-wide difficulty, "easy" or "hard".
func set_difficulty(difficulty: String) -> void:
	SaveManager.save_difficulty(difficulty)


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
## It is past get_level_range().y once shuffle has played all of that world's levels.
func shuffle_next_index(world_id: String) -> int:
	var key: String = SaveManager.progress_key(world_id, get_difficulty(), true)
	return maxi(SaveManager.load_progress(key) - 1, get_level_range().x)


## Returns where the current shuffle is (x, 1-based: the level being played) out of every world's
## levels at the current difficulty (y), e.g. (1, 40) at the start of a shuffle with four worlds.
func shuffle_position() -> Vector2i:
	var level_range: Vector2i = get_level_range()
	var played: int = 0
	var total: int = 0
	for world in WORLDS:
		var last: int = mini(level_range.y, get_level_count(world["id"]) - 1)
		var size: int = maxi(last - level_range.x + 1, 0)
		total += size
		played += clampi(shuffle_next_index(world["id"]) - level_range.x, 0, size)
	return Vector2i(mini(played + 1, total), total)


## Returns a random world that still has shuffle levels left at the current difficulty, or "" if
## shuffle has played every world's levels.
func next_shuffle_world() -> String:
	var next_levels := {}
	for world in WORLDS:
		next_levels[world["id"]] = shuffle_next_index(world["id"])
	return ShufflePicker.pick(next_levels, get_level_range().y, _rng)


## Clears shuffle's place in every world at the current difficulty.
func reset_shuffle() -> void:
	for world in WORLDS:
		SaveManager.reset_progress(SaveManager.progress_key(world["id"], get_difficulty(), true))


## Turns shuffle on and goes to a random world with levels left, starting a fresh shuffle first if
## every world's levels have been played.
func start_shuffle() -> void:
	set_shuffle(true)
	var world_id: String = next_shuffle_world()
	if world_id == "":
		reset_shuffle()
		world_id = next_shuffle_world()
	go_to_world(world_id)

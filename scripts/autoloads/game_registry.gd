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
]

var _requested_levels := {}
var _level_counts := {}


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

extends Node

## Handles reading and writing local save data for level progress. The save is read once at launch
## and kept in memory; every change is written to the file straight away.

const _SECTION_PROGRESS := "progress"
const _SECTION_META := "meta"
const _KEY_LAST_WORLD := "last_world"
const _KEY_DIFFICULTY := "difficulty"
const _KEY_PLAY_MODE := "play_mode"
const _KEY_MUSIC := "music_enabled"
const _KEY_EFFECTS := "effects_enabled"
const _DIFFICULTIES: Array[String] = ["easy", "hard"]
const _PLAY_MODES: Array[String] = ["worlds", "shuffle"]

## Path to the local save file. Call reload() after changing it. Tests point it at their own file.
var save_path: String = "user://save.cfg"

var _cfg := ConfigFile.new()


func _ready() -> void:
	reload()


## Returns the progress key for a world at a difficulty, e.g. "forest:easy", or with shuffle
## "shuffle:forest:easy" for shuffle mode's separate place in that world.
static func progress_key(world: String, difficulty: String, shuffle: bool = false) -> String:
	var key: String = "%s:%s" % [world, difficulty]
	return "shuffle:" + key if shuffle else key


## Reads the save from save_path. A missing or unreadable file starts an empty save.
func reload() -> void:
	_cfg = ConfigFile.new()
	if _cfg.load(save_path) != OK:
		_cfg.clear()


## Saves the 1-indexed level number to resume from for the given world.
## Only updates if the new value is higher than the stored value.
func save_progress(world: String, level: int) -> void:
	if level > load_progress(world):
		_write(_SECTION_PROGRESS, world, level)


## Returns the 1-indexed level to resume from for the given world.
## Returns 1 if none is saved or the saved value is invalid.
func load_progress(world: String) -> int:
	var value: Variant = _cfg.get_value(_SECTION_PROGRESS, world, 1)
	if not value is int or value < 1:
		return 1
	return value


## Unconditionally resets the saved progress for the given world to 1.
## Use after world completion to allow a fresh replay next session.
func reset_progress(world: String) -> void:
	_write(_SECTION_PROGRESS, world, 1)


## Unconditionally sets the 1-indexed level to resume from for the given world.
## Use when the player picks a level themselves, so the game reopens where they left off.
func set_progress(world: String, level: int) -> void:
	_write(_SECTION_PROGRESS, world, maxi(level, 1))


## Remembers which world was played last, so the game can reopen in it.
func save_last_world(world: String) -> void:
	_write(_SECTION_META, _KEY_LAST_WORLD, world)


## Returns the world played last, or "" if none is saved or the saved value is invalid.
func load_last_world() -> String:
	var value: Variant = _cfg.get_value(_SECTION_META, _KEY_LAST_WORLD, "")
	return value if value is String else ""


## Saves the game-wide difficulty ("easy" or "hard").
func save_difficulty(difficulty: String) -> void:
	_write(_SECTION_META, _KEY_DIFFICULTY, difficulty)


## Returns the game-wide difficulty: "easy" (the default) or "hard".
func load_difficulty() -> String:
	var value: Variant = _cfg.get_value(_SECTION_META, _KEY_DIFFICULTY, "easy")
	return value if value is String and value in _DIFFICULTIES else "easy"


## Saves how the game is played: "worlds" (one world at a time) or "shuffle".
func save_play_mode(mode: String) -> void:
	_write(_SECTION_META, _KEY_PLAY_MODE, mode)


## Returns how the game is played: "worlds" (the default) or "shuffle".
func load_play_mode() -> String:
	var value: Variant = _cfg.get_value(_SECTION_META, _KEY_PLAY_MODE, "worlds")
	return value if value is String and value in _PLAY_MODES else "worlds"


## Saves whether background sound is on.
func save_music_enabled(enabled: bool) -> void:
	_write(_SECTION_META, _KEY_MUSIC, enabled)


## Returns whether background sound is on: true unless it was saved off.
func load_music_enabled() -> bool:
	return _load_flag(_KEY_MUSIC)


## Saves whether sound effects are on.
func save_effects_enabled(enabled: bool) -> void:
	_write(_SECTION_META, _KEY_EFFECTS, enabled)


## Returns whether sound effects are on: true unless they were saved off.
func load_effects_enabled() -> bool:
	return _load_flag(_KEY_EFFECTS)


## Moves progress saved before difficulties existed (one level per world) to the per-difficulty
## keys: a level within the easy range becomes easy progress; a higher one becomes hard progress,
## with easy back at 1. Worlds that already have per-difficulty progress are left alone.
func migrate_progress(worlds: Array) -> void:
	var easy_last: int = LevelLoader.get_difficulty_range("easy").y + 1
	var changed: bool = false
	for world: String in worlds:
		if not _cfg.has_section_key(_SECTION_PROGRESS, world):
			continue
		var level: Variant = _cfg.get_value(_SECTION_PROGRESS, world)
		_cfg.erase_section_key(_SECTION_PROGRESS, world)
		changed = true
		var easy_key: String = progress_key(world, "easy")
		if not level is int or _cfg.has_section_key(_SECTION_PROGRESS, easy_key):
			continue
		if level <= easy_last:
			_cfg.set_value(_SECTION_PROGRESS, easy_key, maxi(level, 1))
		else:
			_cfg.set_value(_SECTION_PROGRESS, easy_key, 1)
			_cfg.set_value(_SECTION_PROGRESS, progress_key(world, "hard"), level)
	if changed:
		_cfg.save(save_path)


func _write(section: String, key: String, value: Variant) -> void:
	_cfg.set_value(section, key, value)
	_cfg.save(save_path)


func _load_flag(key: String) -> bool:
	var value: Variant = _cfg.get_value(_SECTION_META, key, true)
	return value if value is bool else true

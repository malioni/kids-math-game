extends Node

## Handles reading and writing local save data for level progress.

## Path to the local save file.
const SAVE_PATH := "user://save.cfg"

const _SECTION_PROGRESS := "progress"
const _SECTION_META := "meta"
const _KEY_SESSIONS := "sessions_played"
const _KEY_LAST_WORLD := "last_world"
const _KEY_DIFFICULTY := "difficulty"
const _KEY_PLAY_MODE := "play_mode"
const _DIFFICULTIES: Array[String] = ["easy", "hard"]
const _PLAY_MODES: Array[String] = ["worlds", "shuffle"]


## Returns the progress key for a world at a difficulty, e.g. "forest:easy", or with shuffle
## "shuffle:forest:easy" for shuffle mode's separate place in that world.
static func progress_key(world: String, difficulty: String, shuffle: bool = false) -> String:
	var key: String = "%s:%s" % [world, difficulty]
	return "shuffle:" + key if shuffle else key


## Saves the 1-indexed level number to resume from for the given world.
## Only updates if the new value is higher than the stored value.
func save_progress(world: String, level: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var current: int = cfg.get_value(_SECTION_PROGRESS, world, 1)
	if level > current:
		cfg.set_value(_SECTION_PROGRESS, world, level)
		cfg.save(SAVE_PATH)


## Returns the 1-indexed level to resume from for the given world.
## Returns 1 if no save data exists or the file is corrupt.
func load_progress(world: String) -> int:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(SAVE_PATH)
	if err != OK:
		return 1
	var value: Variant = cfg.get_value(_SECTION_PROGRESS, world, 1)
	if not value is int or value < 1:
		return 1
	return value


## Unconditionally resets the saved progress for the given world to 1.
## Use after world completion to allow a fresh replay next session.
func reset_progress(world: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value(_SECTION_PROGRESS, world, 1)
	cfg.save(SAVE_PATH)


## Unconditionally sets the 1-indexed level to resume from for the given world.
## Use when the player picks a level themselves, so the game reopens where they left off.
func set_progress(world: String, level: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value(_SECTION_PROGRESS, world, maxi(level, 1))
	cfg.save(SAVE_PATH)


## Remembers which world was played last, so the game can reopen in it.
func save_last_world(world: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value(_SECTION_META, _KEY_LAST_WORLD, world)
	cfg.save(SAVE_PATH)


## Returns the world played last, or "" if none is saved or the file is corrupt.
func load_last_world() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return ""
	var value: Variant = cfg.get_value(_SECTION_META, _KEY_LAST_WORLD, "")
	return value if value is String else ""


## Increments the total session count by one and persists it.
func increment_session_count() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var count: int = cfg.get_value(_SECTION_META, _KEY_SESSIONS, 0)
	cfg.set_value(_SECTION_META, _KEY_SESSIONS, count + 1)
	cfg.save(SAVE_PATH)


## Returns the total number of sessions played.
## Returns 0 if no save data exists or the file is corrupt.
func get_session_count() -> int:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(SAVE_PATH)
	if err != OK:
		return 0
	var value: Variant = cfg.get_value(_SECTION_META, _KEY_SESSIONS, 0)
	if not value is int or value < 0:
		return 0
	return value


## Saves the game-wide difficulty ("easy" or "hard").
func save_difficulty(difficulty: String) -> void:
	_save_meta(_KEY_DIFFICULTY, difficulty)


## Returns the game-wide difficulty: "easy" (the default) or "hard".
func load_difficulty() -> String:
	var value: Variant = _load_meta(_KEY_DIFFICULTY)
	return value if value is String and value in _DIFFICULTIES else "easy"


## Saves how the game is played: "worlds" (one world at a time) or "shuffle".
func save_play_mode(mode: String) -> void:
	_save_meta(_KEY_PLAY_MODE, mode)


## Returns how the game is played: "worlds" (the default) or "shuffle".
func load_play_mode() -> String:
	var value: Variant = _load_meta(_KEY_PLAY_MODE)
	return value if value is String and value in _PLAY_MODES else "worlds"


## Moves progress saved before difficulties existed (one level per world) to the per-difficulty
## keys: a level within the easy range becomes easy progress; a higher one becomes hard progress,
## with easy back at 1. Worlds that already have per-difficulty progress are left alone.
func migrate_progress(worlds: Array) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var easy_last: int = LevelLoader.get_difficulty_range("easy").y + 1
	var changed: bool = false
	for world: String in worlds:
		if not cfg.has_section_key(_SECTION_PROGRESS, world):
			continue
		var level: Variant = cfg.get_value(_SECTION_PROGRESS, world)
		cfg.erase_section_key(_SECTION_PROGRESS, world)
		changed = true
		var easy_key: String = progress_key(world, "easy")
		if not level is int or cfg.has_section_key(_SECTION_PROGRESS, easy_key):
			continue
		if level <= easy_last:
			cfg.set_value(_SECTION_PROGRESS, easy_key, maxi(level, 1))
		else:
			cfg.set_value(_SECTION_PROGRESS, easy_key, 1)
			cfg.set_value(_SECTION_PROGRESS, progress_key(world, "hard"), level)
	if changed:
		cfg.save(SAVE_PATH)


func _save_meta(key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value(_SECTION_META, key, value)
	cfg.save(SAVE_PATH)


func _load_meta(key: String) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK or not cfg.has_section_key(_SECTION_META, key):
		return null
	return cfg.get_value(_SECTION_META, key)

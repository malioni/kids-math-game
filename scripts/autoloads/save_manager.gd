extends Node

## Handles reading and writing local save data for level progress.

const SAVE_PATH := "user://save.cfg"

const _SECTION_PROGRESS := "progress"
const _SECTION_META := "meta"
const _KEY_SESSIONS := "sessions_played"


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

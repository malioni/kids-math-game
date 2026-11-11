extends GutTest

## Sounds WorldBase plays, checked through AudioManager's signals.

const FOREST := preload("res://scenes/worlds/forest_bridge/forest_bridge.tscn")
const SKY := preload("res://scenes/worlds/sky_balloons/sky_balloons.tscn")


func before_each() -> void:
	SaveFixture.clear()
	GameRegistry.change_scenes = false


func after_each() -> void:
	SaveFixture.clear()
	GameRegistry.change_scenes = true
	GameRegistry.last_world_request = ""
	GameRegistry.last_scene_request = ""


func _make_world(scene: PackedScene) -> WorldBase:
	var world: WorldBase = scene.instantiate()
	world.celebrate_duration = 0.01
	world.puzzle_seed = 99
	return add_child_autofree(world)


func _sfx_played() -> Array:
	var sounds: Array = []
	for i in get_signal_emit_count(AudioManager, "sfx_played"):
		sounds.append(get_signal_parameters(AudioManager, "sfx_played", i)[0])
	return sounds


func test_world_audio_world_plays_its_ambience() -> void:
	AudioManager.play_music(AudioManager.MENU_MUSIC)
	_make_world(FOREST)
	assert_eq(AudioManager.current_music(), "forest/ambience")


func test_world_audio_changing_level_keeps_the_music() -> void:
	var world: WorldBase = _make_world(FOREST)
	watch_signals(AudioManager)
	world.get_node("LevelHud").level_chosen.emit("forest", 3)
	assert_signal_not_emitted(AudioManager, "music_changed")


func test_world_audio_right_and_wrong_answers() -> void:
	var world: WorldBase = _make_world(FOREST)
	watch_signals(AudioManager)
	world._get_mechanic().correct.emit()
	assert_has(_sfx_played(), "win")
	world._get_mechanic().incorrect.emit()
	assert_has(_sfx_played(), "lose")


func test_world_audio_pieces_play_the_world_sounds() -> void:
	var world: WorldBase = _make_world(FOREST)
	watch_signals(AudioManager)
	world._get_mechanic().piece_placed.emit()
	world._get_mechanic().piece_removed.emit()
	assert_eq(_sfx_played(), ["forest/place", "forest/remove"])


func test_world_audio_balloon_pop_plays_the_sky_pop() -> void:
	var world: WorldBase = _make_world(SKY)
	watch_signals(AudioManager)
	var mechanic: BalloonPopMechanic = world.get_node("Rig/BalloonPopMechanic")
	mechanic.pop(mechanic.get_unpopped_balloons()[0])
	assert_has(_sfx_played(), "sky/remove")


func test_world_audio_star_screen_plays_complete() -> void:
	var world: WorldBase = _make_world(FOREST)
	world.get_node("LevelHud").level_chosen.emit("forest", 9)
	watch_signals(AudioManager)
	world._advance()
	assert_has(_sfx_played(), "complete")

extends GutTest

const SCENE := preload("res://scenes/ui/level_hud.tscn")

var hud: LevelHud


func before_each() -> void:
	hud = SCENE.instantiate()
	add_child(hud)
	hud.show_level("forest", 4, 20)


func after_each() -> void:
	hud.queue_free()


func test_level_hud_badge_shows_level_number_and_count() -> void:
	assert_eq(hud.get_node("Root/LevelBadge/Row/LevelLabel").text, "5")
	assert_eq(hud.get_node("Root/LevelBadge/Row/CountLabel").text, "/20")


func test_level_hud_badge_shows_world_icon() -> void:
	var icon: Texture2D = hud.get_node("Root/LevelBadge/Row/WorldIcon").texture
	assert_eq(icon.resource_path, GameRegistry.get_world("forest")["icon"])


func test_level_hud_picker_hidden_on_start() -> void:
	assert_false(hud.is_picker_open())
	assert_false(hud.is_world_complete_shown())


func test_level_hud_badge_press_opens_picker_with_a_button_per_level() -> void:
	hud.get_node("Root/LevelBadge").pressed.emit()
	assert_true(hud.is_picker_open())
	assert_eq(hud.get_level_buttons().size(), 20)
	assert_eq(hud.get_level_buttons()[0].text, "1")


func test_level_hud_picker_has_a_tab_per_world() -> void:
	hud.open_picker()
	assert_eq(hud.get_world_tabs().size(), GameRegistry.get_worlds().size())


func test_level_hud_level_button_emits_level_chosen_and_closes() -> void:
	hud.open_picker()
	watch_signals(hud)
	hud.get_level_buttons()[11].pressed.emit()
	assert_signal_emitted_with_parameters(hud, "level_chosen", ["forest", 11])
	assert_false(hud.is_picker_open())


func test_level_hud_other_world_tab_lists_its_levels_and_emits_its_id() -> void:
	hud.open_picker()
	hud.get_node("Root/Picker/Panel/Margin/VBox/TopRow/WorldTabs/Tab_sky").pressed.emit()
	await wait_frames(1)
	assert_eq(hud.get_level_buttons().size(), GameRegistry.get_level_count("sky"))
	watch_signals(hud)
	hud.get_level_buttons()[2].pressed.emit()
	assert_signal_emitted_with_parameters(hud, "level_chosen", ["sky", 2])


func test_level_hud_close_button_closes_picker_without_choosing() -> void:
	hud.open_picker()
	watch_signals(hud)
	hud.get_node("Root/Picker/Panel/Margin/VBox/TopRow/CloseButton").pressed.emit()
	assert_false(hud.is_picker_open())
	assert_signal_not_emitted(hud, "level_chosen")


func test_level_hud_world_complete_shows_restart() -> void:
	hud.show_world_complete()
	assert_true(hud.is_world_complete_shown())
	watch_signals(hud)
	hud.get_node("Root/Complete/Choices/RestartButton").pressed.emit()
	assert_signal_emitted(hud, "restart_requested")
	assert_false(hud.is_world_complete_shown())


func test_level_hud_world_complete_offers_other_worlds() -> void:
	hud.show_world_complete()
	watch_signals(hud)
	hud.get_node("Root/Complete/Choices/World_sky").pressed.emit()
	assert_signal_emitted_with_parameters(hud, "level_chosen", ["sky", -1])
	assert_null(hud.get_node_or_null("Root/Complete/Choices/World_forest"))


func test_level_hud_show_level_closes_overlays() -> void:
	hud.show_world_complete()
	hud.show_level("forest", 0, 20)
	assert_false(hud.is_world_complete_shown())
	assert_eq(hud.get_node("Root/LevelBadge/Row/LevelLabel").text, "1")

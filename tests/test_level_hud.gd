extends GutTest

const SCENE := preload("res://scenes/ui/level_hud.tscn")
const _SAVE_PATH := "user://save.cfg"

var hud: LevelHud


func before_each() -> void:
	_clear_save()
	hud = SCENE.instantiate()
	add_child(hud)
	hud.show_level("forest", 4, 20)


func after_each() -> void:
	hud.queue_free()
	_clear_save()


func _clear_save() -> void:
	if FileAccess.file_exists(_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))


func _level_texts() -> Array:
	return hud.get_level_buttons().map(func(b: Button) -> String: return b.text)


func _badge_text() -> String:
	return (
		hud.get_node("Root/LevelBadge/Row/LevelLabel").text
		+ hud.get_node("Root/LevelBadge/Row/CountLabel").text
	)


func test_level_hud_badge_on_easy_counts_to_10() -> void:
	assert_eq(_badge_text(), "5/10")


func test_level_hud_badge_on_hard_shows_real_number_out_of_20() -> void:
	GameRegistry.set_difficulty("hard")
	hud.show_level("forest", 13, 20)
	assert_eq(_badge_text(), "14/20")


func test_level_hud_badge_in_shuffle_shows_place_in_whole_shuffle() -> void:
	GameRegistry.set_shuffle(true)
	SaveManager.set_progress(SaveManager.progress_key("sky", "easy", true), 4)
	SaveManager.set_progress(SaveManager.progress_key("market", "easy", true), 3)
	hud.show_level("sky", 3, 20)
	assert_eq(_badge_text(), "6/%d" % (10 * GameRegistry.get_worlds().size()))


func test_level_hud_badge_shows_world_icon() -> void:
	var icon: Texture2D = hud.get_node("Root/LevelBadge/Row/WorldIcon").texture
	assert_eq(icon.resource_path, GameRegistry.get_world("forest")["icon"])


func test_level_hud_picker_hidden_on_start() -> void:
	assert_false(hud.is_picker_open())
	assert_false(hud.is_world_complete_shown())


func test_level_hud_badge_press_opens_picker() -> void:
	hud.get_node("Root/LevelBadge").pressed.emit()
	assert_true(hud.is_picker_open())


func test_level_hud_picker_lists_only_easy_levels() -> void:
	hud.open_picker()
	assert_eq(_level_texts(), ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"])


func test_level_hud_picker_on_hard_lists_levels_11_to_20() -> void:
	GameRegistry.set_difficulty("hard")
	hud.open_picker()
	assert_eq(_level_texts(), ["11", "12", "13", "14", "15", "16", "17", "18", "19", "20"])
	watch_signals(hud)
	hud.get_level_buttons()[3].pressed.emit()
	assert_signal_emitted_with_parameters(hud, "level_chosen", ["forest", 13])


func test_level_hud_picker_has_a_tab_per_world() -> void:
	hud.open_picker()
	assert_eq(hud.get_world_tabs().size(), GameRegistry.get_worlds().size())


func test_level_hud_level_button_emits_level_chosen_and_closes() -> void:
	hud.open_picker()
	watch_signals(hud)
	hud.get_level_buttons()[6].pressed.emit()
	assert_signal_emitted_with_parameters(hud, "level_chosen", ["forest", 6])
	assert_false(hud.is_picker_open())


func test_level_hud_other_world_tab_lists_its_levels_and_emits_its_id() -> void:
	hud.open_picker()
	hud.get_node("Root/Picker/Panel/Margin/VBox/TopRow/WorldTabs/Tab_sky").pressed.emit()
	await wait_frames(1)
	assert_eq(hud.get_level_buttons().size(), 10)
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


func test_level_hud_difficulty_button_emits_difficulty_chosen_and_closes() -> void:
	hud.open_picker()
	watch_signals(hud)
	hud.get_difficulty_buttons()[1].pressed.emit()
	assert_signal_emitted_with_parameters(hud, "difficulty_chosen", ["hard"])
	assert_false(hud.is_picker_open())


func test_level_hud_current_difficulty_button_is_highlighted() -> void:
	GameRegistry.set_difficulty("hard")
	hud.open_picker()
	var easy: StyleBoxFlat = hud.get_difficulty_buttons()[0].get_theme_stylebox("normal")
	var hard: StyleBoxFlat = hud.get_difficulty_buttons()[1].get_theme_stylebox("normal")
	assert_ne(easy.bg_color, hard.bg_color)
	assert_eq(hard.bg_color, Color(1.0, 0.72, 0.3))


func test_level_hud_shuffle_tab_shows_shuffle_page_instead_of_levels() -> void:
	hud.open_picker()
	assert_false(hud.is_shuffle_page_shown())
	watch_signals(hud)
	hud.get_shuffle_tab().pressed.emit()
	await wait_frames(1)
	assert_true(hud.is_shuffle_page_shown())
	assert_true(hud.is_picker_open())
	assert_eq(hud.get_level_buttons().size(), 0)
	assert_signal_not_emitted(hud, "shuffle_requested")


func test_level_hud_shuffle_continue_emits_not_from_start_and_closes() -> void:
	hud.open_picker()
	hud.get_shuffle_tab().pressed.emit()
	watch_signals(hud)
	hud.get_shuffle_buttons()[0].pressed.emit()
	assert_signal_emitted_with_parameters(hud, "shuffle_requested", [false])
	assert_false(hud.is_picker_open())


func test_level_hud_shuffle_start_over_emits_from_start_and_closes() -> void:
	hud.open_picker()
	hud.get_shuffle_tab().pressed.emit()
	watch_signals(hud)
	hud.get_shuffle_buttons()[1].pressed.emit()
	assert_signal_emitted_with_parameters(hud, "shuffle_requested", [true])
	assert_false(hud.is_picker_open())


func test_level_hud_picker_opens_on_shuffle_page_while_shuffling() -> void:
	GameRegistry.set_shuffle(true)
	hud.open_picker()
	assert_true(hud.is_shuffle_page_shown())
	var style: StyleBoxFlat = hud.get_shuffle_tab().get_theme_stylebox("normal")
	assert_eq(style.bg_color, Color(1.0, 0.72, 0.3))


func test_level_hud_world_tab_from_shuffle_page_shows_its_levels() -> void:
	GameRegistry.set_shuffle(true)
	hud.open_picker()
	hud.get_node("Root/Picker/Panel/Margin/VBox/TopRow/WorldTabs/Tab_sky").pressed.emit()
	await wait_frames(1)
	assert_false(hud.is_shuffle_page_shown())
	assert_eq(hud.get_level_buttons().size(), 10)


func test_level_hud_badge_shows_shuffle_icon_only_while_shuffling() -> void:
	var icon: TextureRect = hud.get_node("Root/LevelBadge/ShuffleIcon")
	assert_false(icon.visible)
	GameRegistry.set_shuffle(true)
	hud.show_level("sky", 2, 20)
	assert_true(icon.visible)
	GameRegistry.set_shuffle(false)
	hud.show_level("sky", 2, 20)
	assert_false(icon.visible)


func test_level_hud_world_complete_restart_label_shows_first_level_of_difficulty() -> void:
	var label: Label = hud.get_node("Root/Complete/Choices/RestartButton/OneLabel")
	hud.show_world_complete()
	assert_eq(label.text, "1")
	GameRegistry.set_difficulty("hard")
	hud.show_world_complete()
	assert_eq(label.text, "11")
	assert_true(label.visible)


func test_level_hud_world_complete_in_shuffle_hides_label_and_lists_every_world() -> void:
	GameRegistry.set_shuffle(true)
	hud.show_world_complete()
	assert_false(hud.get_node("Root/Complete/Choices/RestartButton/OneLabel").visible)
	assert_not_null(hud.get_node_or_null("Root/Complete/Choices/World_forest"))

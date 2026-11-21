extends GutTest

const SCENE := preload("res://scenes/ui/main_menu.tscn")


func before_each() -> void:
	SaveFixture.clear()
	GameRegistry.change_scenes = false
	GameRegistry.last_world_request = ""
	GameRegistry.last_scene_request = ""


func after_each() -> void:
	for world in GameRegistry.get_worlds():
		GameRegistry.take_requested_level(world["id"])
	AudioManager.set_music_enabled(true)
	AudioManager.set_effects_enabled(true)
	SaveFixture.clear()
	GameRegistry.change_scenes = true
	GameRegistry.last_world_request = ""
	GameRegistry.last_scene_request = ""


func _make_menu() -> MainMenu:
	var menu: MainMenu = SCENE.instantiate()
	add_child_autofree(menu)
	return menu


# Taps the card with the given id in the carousel, as a finger would, once the menu has laid out.
func _tap_card(carousel: WorldCarousel, id: String) -> void:
	await wait_process_frames(1)
	var card: Panel = carousel.get_card(id)
	var at: Vector2 = card.get_parent().position + card.position + card.pivot_offset
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		carousel._gui_input(event)


func _assert_tap_size(control: Control) -> void:
	var drawn: Vector2 = control.size * control.scale
	assert_true(drawn.x >= 100 and drawn.y >= 100, "%s is %s" % [control.name, drawn])


func _wheel_texts(menu: MainMenu) -> Array:
	return menu.get_level_wheel().get_cards().map(
		func(c: Panel) -> String: return c.get_node("Text").text
	)


func _world_ids() -> Array:
	return GameRegistry.get_worlds().map(func(w: Dictionary) -> String: return w["id"])


func test_main_menu_has_a_card_per_registered_world() -> void:
	var menu: MainMenu = _make_menu()
	for id in _world_ids():
		assert_not_null(menu.get_carousel().get_card(id), id)


func test_main_menu_carousel_has_every_world_then_shuffle_card_last() -> void:
	var menu: MainMenu = _make_menu()
	var names: Array = menu.get_carousel().get_cards().map(func(c: Panel) -> String: return c.name)
	var expected: Array = _world_ids().map(func(id: String) -> String: return "Card_%s" % id)
	expected.append("Card_%s" % MainMenu.SHUFFLE_ID)
	assert_eq(names, expected)


func test_main_menu_has_no_separate_shuffle_button() -> void:
	var menu: MainMenu = _make_menu()
	assert_null(menu.get_node_or_null("PlayArea/ShuffleButton"))


func test_main_menu_carousel_starts_on_last_world_played() -> void:
	SaveManager.save_last_world("market")
	var menu: MainMenu = _make_menu()
	assert_eq(menu.get_carousel().get_centred_id(), "market")


func test_main_menu_carousel_starts_on_first_world_without_save() -> void:
	var menu: MainMenu = _make_menu()
	assert_eq(menu.get_carousel().get_centred_id(), _world_ids()[0])


func test_main_menu_opens_on_shuffle_card_while_shuffling() -> void:
	SaveManager.save_last_world("market")
	GameRegistry.set_shuffle(true)
	var menu: MainMenu = _make_menu()
	assert_eq(menu.get_carousel().get_centred_id(), MainMenu.SHUFFLE_ID)


func test_main_menu_level_wheel_lists_current_difficultys_levels() -> void:
	var menu: MainMenu = _make_menu()
	assert_eq(_wheel_texts(menu), ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"])


func test_main_menu_level_wheel_on_hard_lists_levels_11_to_20() -> void:
	GameRegistry.set_difficulty("hard")
	var menu: MainMenu = _make_menu()
	assert_eq(_wheel_texts(menu), ["11", "12", "13", "14", "15", "16", "17", "18", "19", "20"])


func test_main_menu_level_wheel_opens_on_centred_worlds_saved_level() -> void:
	SaveManager.save_last_world("sky")
	SaveManager.set_progress(SaveManager.progress_key("sky", "easy"), 6)
	var menu: MainMenu = _make_menu()
	assert_eq(menu.get_level_wheel().get_centred_id(), "6")


func test_main_menu_centring_another_world_rebuilds_wheel_at_its_saved_level() -> void:
	SaveManager.save_last_world("forest")
	SaveManager.set_progress(SaveManager.progress_key("forest", "easy"), 3)
	SaveManager.set_progress(SaveManager.progress_key("sky", "easy"), 8)
	var menu: MainMenu = _make_menu()
	assert_eq(menu.get_level_wheel().get_centred_id(), "3")
	menu.get_carousel().scroll_to("sky", false)
	assert_eq(menu.get_level_wheel().get_centred_id(), "8")


func test_main_menu_play_without_swiping_opens_last_world() -> void:
	SaveManager.save_last_world("picnic")
	var menu: MainMenu = _make_menu()
	menu.get_play_button().pressed.emit()
	assert_eq(GameRegistry.last_world_request, "picnic")
	assert_false(GameRegistry.is_shuffle())


func test_main_menu_play_opens_centred_world_at_centred_level() -> void:
	SaveManager.save_last_world("forest")
	var menu: MainMenu = _make_menu()
	menu.get_carousel().scroll_to("market", false)
	menu.get_level_wheel().scroll_to("4", false)
	menu.get_play_button().pressed.emit()
	assert_eq(GameRegistry.last_world_request, "market")
	assert_eq(GameRegistry.take_requested_level("market"), 3)


func test_main_menu_tapping_centred_level_card_opens_that_level() -> void:
	SaveManager.save_last_world("sky")
	var menu: MainMenu = _make_menu()
	menu.get_level_wheel().scroll_to("5", false)
	await _tap_card(menu.get_level_wheel(), "5")
	assert_eq(GameRegistry.last_world_request, "sky")
	assert_eq(GameRegistry.take_requested_level("sky"), 4)


func test_main_menu_tapping_side_level_card_only_centres_it() -> void:
	SaveManager.save_last_world("sky")
	var menu: MainMenu = _make_menu()
	await _tap_card(menu.get_level_wheel(), "2")
	assert_eq(GameRegistry.last_world_request, "")
	assert_eq(menu.get_level_wheel().get_centred_id(), "2")


func test_main_menu_play_on_world_leaves_shuffle() -> void:
	SaveManager.save_last_world("sky")
	GameRegistry.set_shuffle(true)
	var menu: MainMenu = _make_menu()
	menu.get_carousel().scroll_to("sky", false)
	menu.get_play_button().pressed.emit()
	assert_eq(GameRegistry.last_world_request, "sky")
	assert_false(GameRegistry.is_shuffle())


func test_main_menu_tapping_centred_card_opens_world_and_leaves_shuffle() -> void:
	SaveManager.save_last_world("sky")
	GameRegistry.set_shuffle(true)
	var menu: MainMenu = _make_menu()
	menu.get_carousel().scroll_to("sky", false)
	await _tap_card(menu.get_carousel(), "sky")
	assert_eq(GameRegistry.last_world_request, "sky")
	assert_false(GameRegistry.is_shuffle())


func test_main_menu_tapping_neighbour_card_only_centres_it() -> void:
	SaveManager.save_last_world("sky")
	var menu: MainMenu = _make_menu()
	await _tap_card(menu.get_carousel(), "market")
	assert_eq(GameRegistry.last_world_request, "")
	assert_eq(menu.get_carousel().get_centred_id(), "market")


func test_main_menu_shuffle_card_hides_wheel_and_shows_shuffle_setup() -> void:
	var menu: MainMenu = _make_menu()
	menu.get_carousel().scroll_to(MainMenu.SHUFFLE_ID, false)
	assert_false(menu.get_level_wheel().visible)
	assert_true(menu.get_shuffle_setup().visible)


func test_main_menu_shuffle_setup_hidden_on_world_card() -> void:
	var menu: MainMenu = _make_menu()
	assert_true(menu.get_level_wheel().visible)
	assert_false(menu.get_shuffle_setup().visible)
	menu.get_carousel().scroll_to(MainMenu.SHUFFLE_ID, false)
	menu.get_carousel().scroll_to("forest", false)
	assert_true(menu.get_level_wheel().visible)
	assert_false(menu.get_shuffle_setup().visible)


func test_main_menu_play_on_shuffle_card_starts_shuffle() -> void:
	var menu: MainMenu = _make_menu()
	menu.get_carousel().scroll_to(MainMenu.SHUFFLE_ID, false)
	menu.get_play_button().pressed.emit()
	assert_true(GameRegistry.is_shuffle())
	assert_false(GameRegistry.get_world(GameRegistry.last_world_request).is_empty())


func test_main_menu_play_on_shuffle_card_continues_shuffle_place() -> void:
	GameRegistry.set_shuffle(true)
	for world in GameRegistry.get_worlds():
		if world["id"] != "market":
			var key: String = SaveManager.progress_key(world["id"], "easy", true)
			SaveManager.set_progress(key, 12)
	SaveManager.set_progress(SaveManager.progress_key("market", "easy", true), 5)
	var menu: MainMenu = _make_menu()
	menu.get_play_button().pressed.emit()
	assert_eq(GameRegistry.last_world_request, "market")
	assert_eq(GameRegistry.shuffle_next_index("market"), 4)


func test_main_menu_difficulty_button_sets_difficulty_and_rebuilds_wheel() -> void:
	SaveManager.set_progress(SaveManager.progress_key("forest", "hard"), 15)
	var menu: MainMenu = _make_menu()
	menu.get_difficulty_buttons()[1].pressed.emit()
	assert_eq(GameRegistry.get_difficulty(), "hard")
	assert_eq(_wheel_texts(menu)[0], "11")
	assert_eq(menu.get_level_wheel().get_centred_id(), "15")
	menu.get_difficulty_buttons()[0].pressed.emit()
	assert_eq(GameRegistry.get_difficulty(), "easy")
	assert_eq(_wheel_texts(menu)[0], "1")


func test_main_menu_current_difficulty_button_is_highlighted() -> void:
	var menu: MainMenu = _make_menu()
	var buttons: Array[Button] = menu.get_difficulty_buttons()
	var easy_fill: Color = buttons[0].get_theme_stylebox("normal").bg_color
	var hard_fill: Color = buttons[1].get_theme_stylebox("normal").bg_color
	assert_ne(easy_fill, hard_fill)
	buttons[1].pressed.emit()
	assert_eq(buttons[1].get_theme_stylebox("normal").bg_color, easy_fill)
	assert_eq(buttons[0].get_theme_stylebox("normal").bg_color, hard_fill)


func test_main_menu_music_button_toggles_and_shows_it() -> void:
	var menu: MainMenu = _make_menu()
	var music: Button = menu.get_sound_buttons()[0]
	assert_eq(music.icon.resource_path, "res://assets/sprites/ui/icon_music_on.svg")
	music.pressed.emit()
	assert_false(AudioManager.is_music_enabled())
	assert_true(AudioManager.is_effects_enabled())
	assert_eq(music.icon.resource_path, "res://assets/sprites/ui/icon_music_off.svg")


func test_main_menu_effects_button_toggles_and_shows_it() -> void:
	var menu: MainMenu = _make_menu()
	var effects: Button = menu.get_sound_buttons()[1]
	effects.pressed.emit()
	assert_false(AudioManager.is_effects_enabled())
	assert_true(AudioManager.is_music_enabled())
	assert_eq(effects.icon.resource_path, "res://assets/sprites/ui/icon_effects_off.svg")


func test_main_menu_sound_buttons_show_saved_settings() -> void:
	AudioManager.set_effects_enabled(false)
	var menu: MainMenu = _make_menu()
	assert_eq(
		menu.get_sound_buttons()[1].icon.resource_path,
		"res://assets/sprites/ui/icon_effects_off.svg"
	)


func test_main_menu_buttons_meet_minimum_tap_size() -> void:
	var menu: MainMenu = _make_menu()
	await wait_process_frames(2)
	_assert_tap_size(menu.get_play_button())
	for button in menu.get_difficulty_buttons() + menu.get_sound_buttons():
		_assert_tap_size(button)
	for carousel in [menu.get_carousel(), menu.get_level_wheel()]:
		for card in carousel.get_cards():
			_assert_tap_size(card)
		_assert_tap_size(carousel.get_node("NextButton"))


func test_main_menu_corner_buttons_do_not_overlap_carousel_or_play() -> void:
	var menu: MainMenu = _make_menu()
	await wait_process_frames(2)
	var corners: Array[Control] = []
	corners.append_array(menu.get_difficulty_buttons())
	corners.append_array(menu.get_sound_buttons())
	var others: Array[Control] = [menu.get_play_button(), menu.get_level_wheel()]
	for carousel in [menu.get_carousel(), menu.get_level_wheel()]:
		for card in carousel.get_cards():
			others.append(card)
		others.append_array(carousel.get_arrow_buttons())
	for corner in corners:
		for other in others:
			if other.is_visible_in_tree():
				assert_false(
					corner.get_global_rect().intersects(other.get_global_rect()),
					"%s overlaps %s" % [corner.name, other.name]
				)


func test_main_menu_plays_the_menu_loop() -> void:
	AudioManager.play_music("forest/ambience")
	_make_menu()
	assert_eq(AudioManager.current_music(), AudioManager.MENU_MUSIC)


func test_main_menu_buttons_play_tap() -> void:
	var menu: MainMenu = _make_menu()
	var buttons: Array[BaseButton] = [menu.get_play_button()]
	buttons.append_array(menu.get_difficulty_buttons())
	buttons.append_array(menu.get_sound_buttons())
	for button in buttons:
		watch_signals(AudioManager)
		button.pressed.emit()
		assert_signal_emitted_with_parameters(AudioManager, "sfx_played", ["tap"])


func test_main_menu_card_tap_plays_tap() -> void:
	var menu: MainMenu = _make_menu()
	for carousel in [menu.get_carousel(), menu.get_level_wheel()]:
		watch_signals(AudioManager)
		carousel.card_pressed.emit("x", false)
		assert_signal_emitted_with_parameters(AudioManager, "sfx_played", ["tap"])


func test_main_menu_carousel_arrows_play_tap() -> void:
	var menu: MainMenu = _make_menu()
	watch_signals(AudioManager)
	for carousel in [menu.get_carousel(), menu.get_level_wheel()]:
		carousel.get_node("PrevButton").pressed.emit()
		carousel.get_node("NextButton").pressed.emit()
	assert_signal_emit_count(AudioManager, "sfx_played", 4)
	assert_signal_emitted_with_parameters(AudioManager, "sfx_played", ["tap"])

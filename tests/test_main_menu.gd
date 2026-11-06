extends GutTest

const SCENE := preload("res://scenes/ui/main_menu.tscn")
const _SAVE_PATH := "user://save.cfg"


func before_each() -> void:
	_clear_save()
	GameRegistry.change_scenes = false
	GameRegistry.last_world_request = ""
	GameRegistry.last_scene_request = ""


func after_each() -> void:
	_clear_save()
	GameRegistry.change_scenes = true
	GameRegistry.last_world_request = ""
	GameRegistry.last_scene_request = ""


func _clear_save() -> void:
	if FileAccess.file_exists(_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_SAVE_PATH))


func _make_menu() -> MainMenu:
	var menu: MainMenu = SCENE.instantiate()
	add_child_autofree(menu)
	return menu


func _tap_card(menu: MainMenu, id: String) -> void:
	await wait_process_frames(1)
	var carousel: WorldCarousel = menu.get_carousel()
	var card: Panel = carousel.get_card(id)
	var at: Vector2 = card.get_parent().position + card.position + card.pivot_offset
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		carousel._gui_input(event)


func _assert_tap_size(control: Control) -> void:
	assert_true(
		control.size.x >= 100 and control.size.y >= 100, "%s is %s" % [control.name, control.size]
	)


func test_main_menu_has_a_card_per_registered_world() -> void:
	var menu: MainMenu = _make_menu()
	var names: Array = menu.get_carousel().get_cards().map(func(c: Panel) -> String: return c.name)
	var ids: Array = GameRegistry.get_worlds().map(func(w: Dictionary) -> String: return w["id"])
	assert_eq(names, ids.map(func(id: String) -> String: return "Card_%s" % id))


func test_main_menu_carousel_starts_on_last_world_played() -> void:
	SaveManager.save_last_world("market")
	var menu: MainMenu = _make_menu()
	assert_eq(menu.get_carousel().get_centred_id(), "market")


func test_main_menu_carousel_starts_on_first_world_without_save() -> void:
	var menu: MainMenu = _make_menu()
	assert_eq(menu.get_carousel().get_centred_id(), GameRegistry.get_worlds()[0]["id"])


func test_main_menu_play_without_swiping_opens_last_world() -> void:
	SaveManager.save_last_world("picnic")
	var menu: MainMenu = _make_menu()
	menu.get_play_button().pressed.emit()
	assert_eq(GameRegistry.last_world_request, "picnic")
	assert_false(GameRegistry.is_shuffle())


func test_main_menu_play_opens_the_centred_world() -> void:
	SaveManager.save_last_world("forest")
	var menu: MainMenu = _make_menu()
	menu.get_carousel().next()
	menu.get_carousel().next()
	menu.get_play_button().pressed.emit()
	assert_eq(GameRegistry.last_world_request, "market")


func test_main_menu_play_leaves_shuffle() -> void:
	SaveManager.save_last_world("sky")
	GameRegistry.set_shuffle(true)
	var menu: MainMenu = _make_menu()
	menu.get_play_button().pressed.emit()
	assert_eq(GameRegistry.last_world_request, "sky")
	assert_false(GameRegistry.is_shuffle())


func test_main_menu_shuffle_button_continues_shuffle_place() -> void:
	GameRegistry.set_shuffle(true)
	for world in GameRegistry.get_worlds():
		if world["id"] != "market":
			var key: String = SaveManager.progress_key(world["id"], "easy", true)
			SaveManager.set_progress(key, 12)
	SaveManager.set_progress(SaveManager.progress_key("market", "easy", true), 5)
	var menu: MainMenu = _make_menu()
	menu.get_shuffle_button().pressed.emit()
	assert_eq(GameRegistry.last_world_request, "market")
	assert_eq(GameRegistry.shuffle_next_index("market"), 4)


func test_main_menu_shuffle_button_starts_shuffle() -> void:
	var menu: MainMenu = _make_menu()
	menu.get_shuffle_button().pressed.emit()
	assert_true(GameRegistry.is_shuffle())
	assert_false(GameRegistry.get_world(GameRegistry.last_world_request).is_empty())


func test_main_menu_tapping_centred_card_opens_world_and_leaves_shuffle() -> void:
	SaveManager.save_last_world("sky")
	GameRegistry.set_shuffle(true)
	var menu: MainMenu = _make_menu()
	await _tap_card(menu, "sky")
	assert_eq(GameRegistry.last_world_request, "sky")
	assert_false(GameRegistry.is_shuffle())


func test_main_menu_tapping_neighbour_card_only_centres_it() -> void:
	SaveManager.save_last_world("sky")
	var menu: MainMenu = _make_menu()
	await _tap_card(menu, "market")
	assert_eq(GameRegistry.last_world_request, "")
	assert_eq(menu.get_carousel().get_centred_id(), "market")


func test_main_menu_buttons_meet_minimum_tap_size() -> void:
	var menu: MainMenu = _make_menu()
	await wait_process_frames(1)
	_assert_tap_size(menu.get_play_button())
	_assert_tap_size(menu.get_shuffle_button())
	for card in menu.get_carousel().get_cards():
		_assert_tap_size(card)
	_assert_tap_size(menu.get_carousel().get_node("NextButton"))

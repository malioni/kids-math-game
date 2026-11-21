extends GutTest

## Checks on the sprite files themselves. Every sprite is an SVG imported as a scalable texture, or
## it turns soft when the window is stretched (tools/import_svgs.sh sets that up for a new file),
## and each keeps the size its scene was laid out around.

const SPRITES := "res://assets/sprites/"

# Every redrawn sprite and the size its scene was laid out around.
const SIZES := {
	"market/bg_market.svg": Vector2(1800, 1000),
	"market/table.svg": Vector2(760, 330),
	"market/crate.svg": Vector2(150, 110),
	"market/bag.svg": Vector2(96, 96),
	"market/bag_shadow.svg": Vector2(96, 96),
	"market/order_slip.svg": Vector2(200, 230),
	"market/icon_tomato.svg": Vector2(64, 64),
	"market/icon_potato.svg": Vector2(64, 64),
	"market/icon_carrot.svg": Vector2(64, 64),
	"market/splat.svg": Vector2(200, 200),
	"ui/icon_world_market.svg": Vector2(128, 128),
	"forest_bridge/bg_river.svg": Vector2(1800, 1000),
	"forest_bridge/bridge_platform.svg": Vector2(400, 80),
	"forest_bridge/plank.svg": Vector2(100, 40),
	"forest_bridge/plank_shadow.svg": Vector2(100, 20),
	"forest_bridge/gap_slot_empty.svg": Vector2(80, 80),
	"forest_bridge/target_sign.svg": Vector2(120, 100),
	"forest_bridge/home.svg": Vector2(120, 120),
	"forest_bridge/go_icon.svg": Vector2(80, 80),
	"forest_bridge/retry_icon.svg": Vector2(80, 80),
	"ui/icon_world_forest.svg": Vector2(128, 128),
	"sky_balloons/bg_sky.svg": Vector2(1800, 1000),
	"sky_balloons/cloud.svg": Vector2(300, 140),
	"sky_balloons/balloon.svg": Vector2(128, 150),
	"sky_balloons/basket.svg": Vector2(150, 90),
	"sky_balloons/sandbag.svg": Vector2(120, 120),
	"sky_balloons/lift_badge.svg": Vector2(120, 120),
	"ui/icon_world_sky.svg": Vector2(128, 128),
	"picnic/bg_picnic.svg": Vector2(1800, 1000),
	"picnic/tray.svg": Vector2(640, 260),
	"picnic/guest_plate.svg": Vector2(170, 100),
	"picnic/basket.svg": Vector2(120, 80),
	"picnic/icon_strawberry.svg": Vector2(64, 64),
	"picnic/icon_apple.svg": Vector2(64, 64),
	"picnic/icon_banana.svg": Vector2(64, 64),
	"ui/icon_world_picnic.svg": Vector2(128, 128),
	"memory/bg_memory.svg": Vector2(1800, 1000),
	"memory/card_back.svg": Vector2(160, 160),
	"memory/card_front.svg": Vector2(160, 160),
	"memory/animal_fox.svg": Vector2(128, 128),
	"memory/animal_rabbit.svg": Vector2(128, 128),
	"memory/animal_bear.svg": Vector2(128, 128),
	"memory/animal_owl.svg": Vector2(128, 128),
	"memory/animal_frog.svg": Vector2(128, 128),
	"memory/animal_hedgehog.svg": Vector2(128, 128),
	"memory/animal_mouse.svg": Vector2(128, 128),
	"memory/animal_duck.svg": Vector2(128, 128),
	"memory/animal_pig.svg": Vector2(128, 128),
	"memory/animal_cat.svg": Vector2(128, 128),
	"memory/animal_deer.svg": Vector2(128, 128),
	"memory/animal_squirrel.svg": Vector2(128, 128),
	"ui/icon_world_memory.svg": Vector2(128, 128),
	"drive/bg_drive.svg": Vector2(1800, 1000),
	"drive/grass_light.svg": Vector2(128, 128),
	"drive/grass_dark.svg": Vector2(128, 128),
	"drive/tree.svg": Vector2(128, 128),
	"drive/rock.svg": Vector2(128, 128),
	"drive/bush.svg": Vector2(128, 128),
	"drive/pond.svg": Vector2(128, 128),
	"drive/garage.svg": Vector2(128, 128),
	"drive/cmd_up.svg": Vector2(96, 96),
	"drive/cmd_down.svg": Vector2(96, 96),
	"drive/cmd_left.svg": Vector2(96, 96),
	"drive/cmd_right.svg": Vector2(96, 96),
	"drive/cmd_forward.svg": Vector2(96, 96),
	"drive/cmd_turn_left.svg": Vector2(96, 96),
	"drive/cmd_turn_right.svg": Vector2(96, 96),
	"drive/tile_frame.svg": Vector2(96, 96),
	"ui/icon_world_drive.svg": Vector2(128, 128),
	"ui/bg_menu.svg": Vector2(1800, 1000),
	"ui/card_frame.svg": Vector2(96, 96),
	"ui/icon_arrow.svg": Vector2(128, 128),
	"ui/icon_close.svg": Vector2(128, 128),
	"ui/icon_easy.svg": Vector2(128, 128),
	"ui/icon_hard.svg": Vector2(128, 128),
	"ui/icon_home.svg": Vector2(128, 128),
	"ui/icon_play.svg": Vector2(200, 200),
	"ui/icon_shuffle.svg": Vector2(128, 128),
	"ui/icon_star.svg": Vector2(200, 200),
	"ui/icon_music_on.svg": Vector2(128, 128),
	"ui/icon_music_off.svg": Vector2(128, 128),
	"ui/icon_effects_on.svg": Vector2(128, 128),
	"ui/icon_effects_off.svg": Vector2(128, 128),
	"ui/icon_replay.svg": Vector2(128, 128),
	"ui/icon_new_round.svg": Vector2(128, 128),
}


func _paths(dir_path: String, extension: String) -> Array[String]:
	var paths: Array[String] = []
	for dir_name: String in DirAccess.get_directories_at(dir_path):
		paths.append_array(_paths(dir_path + dir_name + "/", extension))
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(extension):
			paths.append(dir_path + file_name)
	return paths


func test_sprites_every_svg_is_scalable() -> void:
	var paths: Array[String] = _paths(SPRITES, ".svg")
	assert_gt(paths.size(), 0, "no SVG sprites found")
	for path: String in paths:
		assert_true(load(path) is DPITexture, "%s: run tools/import_svgs.sh" % path)


func test_sprites_redrawn_sprites_keep_their_sizes() -> void:
	for file: String in SIZES:
		assert_true(ResourceLoader.exists(SPRITES + file), "%s is missing" % file)
		if ResourceLoader.exists(SPRITES + file):
			var texture: Texture2D = load(SPRITES + file)
			assert_eq(texture.get_size(), SIZES[file], file)


func test_sprites_no_png_is_left() -> void:
	var left: Array[String] = _paths(SPRITES, ".png")
	assert_eq(left.size(), 0, "sprites are SVGs (see the READMEs), but found %s" % [left])


func test_sprites_every_svg_has_a_recorded_size() -> void:
	for path: String in _paths(SPRITES, ".svg"):
		var file: String = path.trim_prefix(SPRITES)
		# The fox's and the car's sheets are checked frame by frame in test_fox_frames.gd and
		# test_car_frames.gd.
		if not file.begins_with("fox/") and not file.begins_with("drive/car_"):
			assert_true(SIZES.has(file), "%s: add its size to SIZES" % file)

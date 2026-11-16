extends GutTest

## Checks on the sprite files themselves. Every SVG must be imported as a scalable texture, or it
## turns soft when the window is stretched; tools/import_svgs.sh sets that up for a new file.

const SPRITES := "res://assets/sprites/"

# The market's sprites and the sizes its layout was built around.
const MARKET_SIZES := {
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
}


func _svg_paths(dir_path: String) -> Array[String]:
	var paths: Array[String] = []
	for dir_name: String in DirAccess.get_directories_at(dir_path):
		paths.append_array(_svg_paths(dir_path + dir_name + "/"))
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".svg"):
			paths.append(dir_path + file_name)
	return paths


func test_sprites_every_svg_is_scalable() -> void:
	var paths: Array[String] = _svg_paths(SPRITES)
	assert_gt(paths.size(), 0, "no SVG sprites found")
	for path: String in paths:
		assert_true(load(path) is DPITexture, "%s: run tools/import_svgs.sh" % path)


func test_sprites_market_sprites_keep_their_sizes() -> void:
	for file: String in MARKET_SIZES:
		assert_true(ResourceLoader.exists(SPRITES + file), "%s is missing" % file)
		if ResourceLoader.exists(SPRITES + file):
			var texture: Texture2D = load(SPRITES + file)
			assert_eq(texture.get_size(), MARKET_SIZES[file], file)

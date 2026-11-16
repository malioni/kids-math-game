extends GutTest

## Checks on the sprite files themselves. Every SVG must be imported as a scalable texture, or it
## turns soft when the window is stretched; tools/import_svgs.sh sets that up for a new file.

const SPRITES := "res://assets/sprites/"


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

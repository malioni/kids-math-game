extends GutTest

## The fox's car in Country Drive (assets/sprites/drive/car_frames.tres), built by
## tools/make_car_sheets.gd.

const FRAMES_PATH := "res://assets/sprites/drive/car_frames.tres"
const SHEET_PATH := "res://assets/sprites/drive/car_%s.svg"
const CELL := 160
# animation -> [frame count, frames per second, loops]
const EXPECTED := {
	"idle": [4, 6.0, true],
	"drive": [4, 10.0, true],
	"celebrate": [4, 8.0, true],
	"bump": [4, 10.0, false],
	"sad": [4, 4.0, true],
}

var _frames: SpriteFrames


func before_each() -> void:
	_frames = load(FRAMES_PATH)


func test_car_frames_has_every_animation() -> void:
	for animation: String in EXPECTED:
		assert_true(_frames.has_animation(animation), "missing %s" % animation)
		assert_eq(_frames.get_frame_count(animation), EXPECTED[animation][0], animation)
		assert_eq(_frames.get_animation_speed(animation), EXPECTED[animation][1], animation)
		assert_eq(_frames.get_animation_loop(animation), EXPECTED[animation][2], animation)


func test_car_frames_each_frame_is_one_cell_of_its_sheet() -> void:
	for animation: String in EXPECTED:
		var count: int = EXPECTED[animation][0]
		for i in count:
			var frame: AtlasTexture = _frames.get_frame_texture(animation, i)
			assert_eq(frame.atlas.resource_path, SHEET_PATH % animation)
			assert_eq(frame.region, Rect2(i * CELL, 0, CELL, CELL))
		var sheet: Texture2D = load(SHEET_PATH % animation)
		assert_true(sheet is DPITexture, "%s: run tools/import_svgs.sh" % animation)
		assert_eq(sheet.get_size(), Vector2(count * CELL, CELL), animation)


func test_car_frames_every_pose_stays_inside_its_cell() -> void:
	# The car is rotated in all four directions, so it must also stay clear of the top and bottom.
	for animation: String in EXPECTED:
		var image := Image.new()
		var svg: String = FileAccess.get_file_as_string(SHEET_PATH % animation)
		assert_eq(image.load_svg_from_string(svg, 1.0), OK, animation)
		for i: int in EXPECTED[animation][0]:
			for x: int in [i * CELL, i * CELL + 1, (i + 1) * CELL - 2, (i + 1) * CELL - 1]:
				assert_false(_column_has_paint(image, x), "%s frame %d col %d" % [animation, i, x])
		for y: int in [0, 1, CELL - 2, CELL - 1]:
			assert_false(_row_has_paint(image, y), "%s row %d" % [animation, y])


func _column_has_paint(image: Image, x: int) -> bool:
	for y in image.get_height():
		if image.get_pixel(x, y).a > 0.0:
			return true
	return false


func _row_has_paint(image: Image, y: int) -> bool:
	for x in image.get_width():
		if image.get_pixel(x, y).a > 0.0:
			return true
	return false

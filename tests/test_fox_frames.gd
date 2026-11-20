extends GutTest

## The fox's animations, shared by every world (assets/sprites/fox/fox_frames.tres) and built by
## tools/make_fox_sheets.gd.

const FRAMES_PATH := "res://assets/sprites/fox/fox_frames.tres"
const SHEET_PATH := "res://assets/sprites/fox/character_%s.svg"
const CELL := 160
# Worlds whose character isn't the fox's own sprite (the drive's character is its car).
const OWN_CHARACTER := ["drive"]
# animation -> [frame count, frames per second, loops]
const EXPECTED := {
	"idle": [4, 6.0, true],
	"walk": [6, 10.0, true],
	"celebrate": [4, 8.0, true],
	"fall": [3, 8.0, false],
	"sad": [4, 4.0, true],
	"throw": [6, 10.0, false],
}
# World id -> the fox's height on screen in px, which the redraw must not change.
const FOX_SIZE := {
	"forest": 64.0,
	"sky": 83.2,
	"market": 160.0,
	"picnic": 160.0,
	"memory": 160.0,
}

var _frames: SpriteFrames


func before_each() -> void:
	_frames = load(FRAMES_PATH)


func test_fox_frames_has_every_animation() -> void:
	for animation: String in EXPECTED:
		assert_true(_frames.has_animation(animation), "missing %s" % animation)
		assert_eq(_frames.get_frame_count(animation), EXPECTED[animation][0], animation)
		assert_eq(_frames.get_animation_speed(animation), EXPECTED[animation][1], animation)
		assert_eq(_frames.get_animation_loop(animation), EXPECTED[animation][2], animation)


func test_fox_frames_each_frame_is_one_cell_of_its_sheet() -> void:
	for animation: String in EXPECTED:
		var count: int = EXPECTED[animation][0]
		for i in count:
			var frame: AtlasTexture = _frames.get_frame_texture(animation, i)
			assert_eq(frame.atlas.resource_path, SHEET_PATH % animation)
			assert_eq(frame.region, Rect2(i * CELL, 0, CELL, CELL))
		var sheet: Texture2D = load(SHEET_PATH % animation)
		assert_eq(sheet.get_size(), Vector2(count * CELL, CELL), animation)


func test_fox_frames_every_pose_stays_inside_its_cell() -> void:
	# A pose that reaches its cell's edge shows up at the edge of the neighbouring frame (the stray
	# tail tip fixed in #24), so the two outermost columns of every cell must be empty.
	for animation: String in EXPECTED:
		var image := Image.new()
		var svg: String = FileAccess.get_file_as_string(SHEET_PATH % animation)
		assert_eq(image.load_svg_from_string(svg, 1.0), OK, animation)
		for i: int in EXPECTED[animation][0]:
			for x: int in [i * CELL, i * CELL + 1, (i + 1) * CELL - 2, (i + 1) * CELL - 1]:
				assert_false(
					_column_has_paint(image, x), "%s frame %d reaches column %d" % [animation, i, x]
				)


func _column_has_paint(image: Image, x: int) -> bool:
	for y in image.get_height():
		if image.get_pixel(x, y).a > 0.0:
			return true
	return false


func test_fox_frames_every_world_uses_the_shared_frames_at_its_old_size() -> void:
	for world: Dictionary in GameRegistry.get_worlds():
		var id: String = world["id"]
		if id in OWN_CHARACTER:
			continue
		var root: Node = load(world["scene"]).instantiate()
		var fox: AnimatedSprite2D = root.find_child("Character", true, false)
		assert_eq(fox.sprite_frames, _frames, "%s has its own copy of the fox's frames" % id)
		assert_true(FOX_SIZE.has(id), "add %s to FOX_SIZE" % id)
		assert_almost_eq(fox.scale.y * CELL, float(FOX_SIZE.get(id, 0.0)), 0.01, id)
		root.free()


func test_fox_frames_main_menu_uses_the_shared_frames_at_scale_one() -> void:
	var root: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	var fox: AnimatedSprite2D = root.get_node("PlayArea/Fox")
	assert_eq(fox.sprite_frames.resource_path, FRAMES_PATH)
	assert_eq(fox.scale, Vector2.ONE)
	root.free()

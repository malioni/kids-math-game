extends SceneTree

## Draws assets/sprites/forest_bridge/character_sad.png, a 4-frame placeholder sad fox, from the
## first idle frame: the head droops and bobs as if sobbing, the brows tilt up in the middle, the
## eyes half close and a tear runs down under each eye. Run from the project root:
##   Godot --path . --headless -s tools/make_fox_sad_placeholder.gd
## then `Godot --path . --headless --import` to create the .import file.

const IDLE := "res://assets/sprites/forest_bridge/character_idle.png"
const OUT := "res://assets/sprites/forest_bridge/character_sad.png"
const FRAME := 64
const FRAMES := 4
# Rows 0 to HEAD_BOTTOM are the head; they're moved down to droop it.
const HEAD_BOTTOM := 36
# How far the head droops in each frame.
const DROOP: Array[int] = [3, 4, 3, 4]
# Top-left of each 5×5 eye in the idle frame.
const EYES: Array[Vector2i] = [Vector2i(30, 18), Vector2i(44, 18)]
const DARK := Color("3c281e")
const TEAR := Color("6ec3f5")
const TEAR_LIGHT := Color("d8f1ff")


func _init() -> void:
	var idle := Image.load_from_file(IDLE)
	var fur: Color = idle.get_pixel(EYES[0].x - 2, EYES[0].y + 2)
	var sheet := Image.create(FRAME * FRAMES, FRAME, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for f in FRAMES:
		_draw_frame(idle, sheet, f, fur)
	var err: Error = sheet.save_png(ProjectSettings.globalize_path(OUT))
	if err != OK:
		push_error("Could not save %s" % OUT)
	quit()


func _draw_frame(idle: Image, sheet: Image, f: int, fur: Color) -> void:
	var x0: int = f * FRAME
	var d: int = DROOP[f]
	for y in range(HEAD_BOTTOM + 1, FRAME):
		for x in FRAME:
			sheet.set_pixel(x0 + x, y, idle.get_pixel(x, y))
	# The head drawn lower, over the top of the body.
	for y in HEAD_BOTTOM + 1:
		if y + d >= FRAME:
			continue
		for x in FRAME:
			var c: Color = idle.get_pixel(x, y)
			if c.a > 0.1:
				sheet.set_pixel(x0 + x, y + d, c)
	for eye in EYES:
		var e := Vector2i(x0 + eye.x, eye.y + d)
		# Half-closed: fur over the top of the eye, dark only along the bottom.
		sheet.fill_rect(Rect2i(e, Vector2i(5, 5)), fur)
		sheet.fill_rect(Rect2i(e + Vector2i(0, 3), Vector2i(5, 2)), DARK)
	# Brows raised at the inner ends (towards the middle of the face).
	_brow(sheet, Vector2i(x0 + EYES[0].x - 1, EYES[0].y + d - 2), 1)
	_brow(sheet, Vector2i(x0 + EYES[1].x + 5, EYES[1].y + d - 2), -1)
	# A tear under the outer corner of each eye, a little lower every frame.
	var fall: int = 2 + f * 3
	_tear(sheet, Vector2i(x0 + EYES[0].x, EYES[0].y + d + 5 + fall))
	_tear(sheet, Vector2i(x0 + EYES[1].x + 4, EYES[1].y + d + 5 + fall))


# A 6 px brow, 2 px thick, climbing 2 px toward the inner end. dir is +1 when the inner end is to
# the right of start, -1 when it's to the left.
func _brow(sheet: Image, start: Vector2i, dir: int) -> void:
	for k in 6:
		var p := Vector2i(start.x + k * dir, start.y - k / 2)
		sheet.fill_rect(Rect2i(p, Vector2i(1, 2)), DARK)


func _tear(sheet: Image, top: Vector2i) -> void:
	sheet.fill_rect(Rect2i(top, Vector2i(2, 4)), TEAR)
	sheet.set_pixel(top.x - 1, top.y + 2, TEAR)
	sheet.set_pixel(top.x + 2, top.y + 2, TEAR)
	sheet.set_pixel(top.x, top.y + 1, TEAR_LIGHT)

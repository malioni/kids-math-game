extends SceneTree

## Draws placeholder icons for the level picker's mode buttons into assets/sprites/ui/: shuffle
## (two crossing arrows), easy (a small hill) and hard (a tall snowy mountain). Run from the
## project root:
##   Godot --path . --headless -s tools/make_mode_icons.gd
## then `Godot --path . --headless --import` to create the .import files.

const UI_OUT := "res://assets/sprites/ui/"
const SIZE := 128

const OUTLINE := Color(0.3, 0.2, 0.12)
const ARROW_A := Color(0.95, 0.55, 0.2)
const ARROW_B := Color(0.35, 0.6, 0.85)
const HILL := Color(0.5, 0.75, 0.35)
const ROCK := Color(0.55, 0.52, 0.5)
const SNOW := Color(0.98, 0.98, 1.0)
const SKY := Color(0.8, 0.92, 0.98)


func _init() -> void:
	_save(_shuffle(), UI_OUT + "icon_shuffle.png")
	_save(_easy(), UI_OUT + "icon_easy.png")
	_save(_hard(), UI_OUT + "icon_hard.png")
	quit()


func _save(image: Image, path: String) -> void:
	var err: Error = image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Could not save %s" % path)


func _blank() -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return image


func _ellipse(image: Image, center: Vector2, radii: Vector2, color: Color) -> void:
	for y in SIZE:
		for x in SIZE:
			var d := Vector2((x + 0.5 - center.x) / radii.x, (y + 0.5 - center.y) / radii.y)
			if d.length_squared() <= 1.0:
				image.set_pixel(x, y, color)


func _triangle(image: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	for y in SIZE:
		for x in SIZE:
			if Geometry2D.point_is_inside_triangle(Vector2(x + 0.5, y + 0.5), a, b, c):
				image.set_pixel(x, y, color)


# A thick line from a to b with an arrowhead at b.
func _arrow(image: Image, a: Vector2, b: Vector2, color: Color) -> void:
	var dir: Vector2 = (b - a).normalized()
	var side := Vector2(-dir.y, dir.x)
	var shaft_end: Vector2 = b - dir * 26.0
	for width_color: Array in [[13.0, OUTLINE], [8.0, color]]:
		var w: float = width_color[0]
		var c: Color = width_color[1]
		_triangle(image, a + side * w, a - side * w, shaft_end + side * w, c)
		_triangle(image, a - side * w, shaft_end - side * w, shaft_end + side * w, c)
	_triangle(image, b + dir * 4.0, shaft_end + side * 26.0, shaft_end - side * 26.0, OUTLINE)
	_triangle(
		image, b, shaft_end + side * 20.0 + dir * 2.0, shaft_end - side * 20.0 + dir * 2.0, color
	)


func _shuffle() -> Image:
	var image := _blank()
	_arrow(image, Vector2(14, 100), Vector2(112, 26), ARROW_A)
	_arrow(image, Vector2(14, 28), Vector2(112, 102), ARROW_B)
	return image


func _easy() -> Image:
	var image := _blank()
	_ellipse(image, Vector2(64, 64), Vector2(60, 60), SKY)
	_ellipse(image, Vector2(64, 112), Vector2(58, 40), OUTLINE)
	_ellipse(image, Vector2(64, 112), Vector2(54, 36), HILL)
	_image_clear_below(image, 116)
	return image


func _hard() -> Image:
	var image := _blank()
	_ellipse(image, Vector2(64, 64), Vector2(60, 60), SKY)
	_triangle(image, Vector2(64, 8), Vector2(2, 118), Vector2(126, 118), OUTLINE)
	_triangle(image, Vector2(64, 16), Vector2(10, 114), Vector2(118, 114), ROCK)
	_triangle(image, Vector2(64, 16), Vector2(44, 52), Vector2(84, 52), SNOW)
	_image_clear_below(image, 118)
	return image


# Cuts the icon off flat at row y, like the ground line.
func _image_clear_below(image: Image, y: int) -> void:
	image.fill_rect(Rect2i(0, y, SIZE, SIZE - y), Color(0, 0, 0, 0))
	image.fill_rect(Rect2i(4, y - 4, SIZE - 8, 4), OUTLINE)

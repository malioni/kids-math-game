extends SceneTree

## Draws placeholder art for the main menu and the world carousel into assets/sprites/ui/: home
## (a little house), arrow (pointing right; the left arrow is flipped), play (a green circle with a
## white triangle), the card frame (white so it can be tinted, used as a 9-patch) and the menu
## background (sky over a meadow). Run from the project root:
##   Godot --path . --headless -s tools/make_menu_placeholders.gd
## then `Godot --path . --headless --import` to create the .import files.

const UI_OUT := "res://assets/sprites/ui/"

const OUTLINE := Color(0.3, 0.2, 0.12)
const ROOF := Color(0.8, 0.32, 0.2)
const WALL := Color(1.0, 0.94, 0.8)
const DOOR := Color(0.55, 0.35, 0.2)
const CREAM := Color(1.0, 0.96, 0.86)
const ARROW := Color(0.95, 0.55, 0.2)
const PLAY := Color(0.36, 0.72, 0.32)
const SKY_TOP := Color(0.62, 0.84, 0.97)
const SKY_LOW := Color(0.9, 0.96, 0.98)
const MEADOW := Color(0.52, 0.76, 0.38)
const MEADOW_FAR := Color(0.64, 0.82, 0.46)


func _init() -> void:
	_save(_home(), "icon_home.png")
	_save(_arrow(), "icon_arrow.png")
	_save(_play(), "icon_play.png")
	_save(_card_frame(), "card_frame.png")
	_save(_background(), "bg_menu.png")
	quit()


func _save(image: Image, file_name: String) -> void:
	var err: Error = image.save_png(ProjectSettings.globalize_path(UI_OUT + file_name))
	if err != OK:
		push_error("Could not save %s" % file_name)


func _blank(size: Vector2i) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return image


func _ellipse(image: Image, center: Vector2, radii: Vector2, color: Color) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var d := Vector2((x + 0.5 - center.x) / radii.x, (y + 0.5 - center.y) / radii.y)
			if d.length_squared() <= 1.0:
				image.set_pixel(x, y, color)


func _triangle(image: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	for y in image.get_height():
		for x in image.get_width():
			if Geometry2D.point_is_inside_triangle(Vector2(x + 0.5, y + 0.5), a, b, c):
				image.set_pixel(x, y, color)


func _rounded_rect(image: Image, rect: Rect2, radius: float, color: Color) -> void:
	var inner: Rect2 = rect.grow(-radius)
	for y in range(int(rect.position.y), int(rect.end.y)):
		for x in range(int(rect.position.x), int(rect.end.x)):
			var p := Vector2(x + 0.5, y + 0.5)
			var nearest := Vector2(
				clampf(p.x, inner.position.x, inner.end.x), clampf(p.y, inner.position.y, inner.end.y)
			)
			if p.distance_to(nearest) <= radius:
				image.set_pixel(x, y, color)


func _home() -> Image:
	var image := _blank(Vector2i(128, 128))
	_triangle(image, Vector2(64, 6), Vector2(2, 62), Vector2(126, 62), OUTLINE)
	_triangle(image, Vector2(64, 16), Vector2(14, 58), Vector2(114, 58), ROOF)
	image.fill_rect(Rect2i(20, 56, 88, 66), OUTLINE)
	image.fill_rect(Rect2i(26, 60, 76, 56), WALL)
	image.fill_rect(Rect2i(52, 78, 26, 44), OUTLINE)
	image.fill_rect(Rect2i(56, 82, 18, 36), DOOR)
	return image


func _arrow() -> Image:
	var image := _blank(Vector2i(128, 128))
	_ellipse(image, Vector2(64, 64), Vector2(60, 60), OUTLINE)
	_ellipse(image, Vector2(64, 64), Vector2(54, 54), CREAM)
	_triangle(image, Vector2(98, 64), Vector2(44, 26), Vector2(44, 102), OUTLINE)
	_triangle(image, Vector2(90, 64), Vector2(50, 36), Vector2(50, 92), ARROW)
	return image


func _play() -> Image:
	var image := _blank(Vector2i(200, 200))
	_ellipse(image, Vector2(100, 100), Vector2(96, 96), OUTLINE)
	_ellipse(image, Vector2(100, 100), Vector2(88, 88), PLAY)
	_triangle(image, Vector2(150, 100), Vector2(76, 54), Vector2(76, 146), Color.WHITE)
	return image


func _card_frame() -> Image:
	var image := _blank(Vector2i(96, 96))
	_rounded_rect(image, Rect2(0, 0, 96, 96), 22.0, OUTLINE)
	_rounded_rect(image, Rect2(5, 5, 86, 86), 18.0, Color.WHITE)
	return image


func _background() -> Image:
	var size := Vector2i(1800, 1000)
	var image := _blank(size)
	for y in size.y:
		image.fill_rect(Rect2i(0, y, size.x, 1), SKY_TOP.lerp(SKY_LOW, float(y) / 640.0))
	for x in size.x:
		var far_top: int = int(600.0 + 40.0 * sin(x / 230.0))
		image.fill_rect(Rect2i(x, far_top, 1, size.y - far_top), MEADOW_FAR)
		var near_top: int = int(700.0 + 30.0 * sin(x / 170.0 + 1.3))
		image.fill_rect(Rect2i(x, near_top, 1, size.y - near_top), MEADOW)
	return image

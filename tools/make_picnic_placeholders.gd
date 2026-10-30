extends SceneTree

## Draws the Picnic world's programmer-art placeholders into assets/sprites/picnic/ and the world
## icon into assets/sprites/ui/. Run from the project root:
##   Godot --path . --headless -s tools/make_picnic_placeholders.gd
## then `Godot --path . --headless --import` to create the .import files.

const OUT := "res://assets/sprites/picnic/"
const UI_OUT := "res://assets/sprites/ui/"

const SKY := Color(0.68, 0.85, 0.95)
const GRASS := Color(0.55, 0.76, 0.38)
const GRASS_DARK := Color(0.45, 0.66, 0.3)
const BLANKET_RED := Color(0.86, 0.32, 0.28)
const BLANKET_LIGHT := Color(0.98, 0.93, 0.84)
const PLATE := Color(0.98, 0.97, 0.93)
const PLATE_RIM := Color(0.8, 0.76, 0.68)
const WICKER := Color(0.8, 0.6, 0.32)
const WICKER_DARK := Color(0.6, 0.42, 0.2)
const STRAWBERRY := Color(0.9, 0.2, 0.22)
const APPLE := Color(0.52, 0.8, 0.26)
const BANANA := Color(0.98, 0.84, 0.25)
const LEAF := Color(0.3, 0.62, 0.25)
const OUTLINE := Color(0.24, 0.15, 0.09)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_background(), OUT + "bg_picnic.png")
	_save(_tray(), OUT + "tray.png")
	_save(_guest_plate(), OUT + "guest_plate.png")
	_save(_basket(), OUT + "basket.png")
	_save(_strawberry(64), OUT + "icon_strawberry.png")
	_save(_apple(64), OUT + "icon_apple.png")
	_save(_banana(64), OUT + "icon_banana.png")
	_save(_world_icon(), UI_OUT + "icon_world_picnic.png")
	quit()


func _save(image: Image, path: String) -> void:
	var err: Error = image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Could not save %s" % path)


func _blank(w: int, h: int) -> Image:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return image


func _rect(image: Image, r: Rect2i, color: Color) -> void:
	image.fill_rect(r.intersection(Rect2i(Vector2i.ZERO, image.get_size())), color)


func _ellipse(image: Image, center: Vector2, radii: Vector2, color: Color) -> void:
	var x0: int = maxi(0, floori(center.x - radii.x))
	var x1: int = mini(image.get_width() - 1, ceili(center.x + radii.x))
	var y0: int = maxi(0, floori(center.y - radii.y))
	var y1: int = mini(image.get_height() - 1, ceili(center.y + radii.y))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2((x + 0.5 - center.x) / radii.x, (y + 0.5 - center.y) / radii.y)
			if d.length_squared() <= 1.0:
				image.set_pixel(x, y, color)


func _outlined_ellipse(image: Image, center: Vector2, radii: Vector2, color: Color) -> void:
	_ellipse(image, center, radii + Vector2(3, 3), OUTLINE)
	_ellipse(image, center, radii, color)


func _triangle(image: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var x0: int = maxi(0, floori(minf(a.x, minf(b.x, c.x))))
	var x1: int = mini(image.get_width() - 1, ceili(maxf(a.x, maxf(b.x, c.x))))
	var y0: int = maxi(0, floori(minf(a.y, minf(b.y, c.y))))
	var y1: int = mini(image.get_height() - 1, ceili(maxf(a.y, maxf(b.y, c.y))))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.point_is_inside_triangle(p, a, b, c):
				image.set_pixel(x, y, color)


func _background() -> Image:
	var image := _blank(1800, 1000)
	_rect(image, Rect2i(0, 0, 1800, 1000), SKY)
	_rect(image, Rect2i(0, 300, 1800, 700), GRASS)
	for x in range(0, 1800, 90):
		_rect(image, Rect2i(x, 300 + (x / 90 % 3) * 40, 6, 14), GRASS_DARK)
	# Checked blanket under the play area (the 1280×720 view starts at (260, 140)).
	var blanket := Rect2i(330, 420, 1140, 500)
	for y in range(blanket.position.y, blanket.end.y, 50):
		for x in range(blanket.position.x, blanket.end.x, 50):
			var odd: bool = ((x - blanket.position.x) / 50 + (y - blanket.position.y) / 50) % 2 == 1
			_rect(image, Rect2i(x, y, 50, 50), BLANKET_RED if odd else BLANKET_LIGHT)
	return image


func _tray() -> Image:
	var image := _blank(640, 260)
	_rect(image, Rect2i(0, 0, 640, 260), OUTLINE)
	_rect(image, Rect2i(4, 4, 632, 252), PLATE_RIM)
	_rect(image, Rect2i(16, 16, 608, 228), PLATE)
	return image


func _guest_plate() -> Image:
	var image := _blank(170, 100)
	_outlined_ellipse(image, Vector2(85, 50), Vector2(80, 45), PLATE_RIM)
	_ellipse(image, Vector2(85, 50), Vector2(66, 34), PLATE)
	return image


func _basket() -> Image:
	var image := _blank(120, 80)
	_rect(image, Rect2i(6, 18, 108, 62), OUTLINE)
	_rect(image, Rect2i(10, 22, 100, 54), WICKER)
	for y in [36, 52, 68]:
		_rect(image, Rect2i(10, y, 100, 3), WICKER_DARK)
	for x in range(22, 110, 18):
		_rect(image, Rect2i(x, 22, 3, 54), WICKER_DARK)
	_rect(image, Rect2i(0, 12, 120, 10), WICKER_DARK)
	return image


func _strawberry(size: int) -> Image:
	var image := _blank(size, size)
	var s: float = size / 64.0
	_triangle(image, Vector2(8, 20) * s, Vector2(56, 20) * s, Vector2(32, 62) * s, OUTLINE)
	_outlined_ellipse(image, Vector2(32, 26) * s, Vector2(22, 12) * s, STRAWBERRY)
	_triangle(image, Vector2(12, 22) * s, Vector2(52, 22) * s, Vector2(32, 57) * s, STRAWBERRY)
	for p in [Vector2(24, 28), Vector2(40, 28), Vector2(32, 36), Vector2(26, 44), Vector2(38, 44)]:
		_ellipse(image, p * s, Vector2(1.8, 2.4) * s, BANANA)
	_ellipse(image, Vector2(32, 14) * s, Vector2(14, 5) * s, LEAF)
	return image


func _apple(size: int) -> Image:
	var image := _blank(size, size)
	var s: float = size / 64.0
	_outlined_ellipse(image, Vector2(32, 38) * s, Vector2(24, 22) * s, APPLE)
	_rect(image, Rect2i(Vector2i(Vector2(30, 6) * s), Vector2i(Vector2(4, 12) * s)), OUTLINE)
	_ellipse(image, Vector2(42, 12) * s, Vector2(8, 4) * s, LEAF)
	_ellipse(image, Vector2(24, 30) * s, Vector2(5, 7) * s, Color(0.75, 0.92, 0.5))
	return image


func _banana(size: int) -> Image:
	var image := _blank(size, size)
	var s: float = size / 64.0
	# A crescent: a big yellow ellipse with its top bitten out by a transparent one.
	_ellipse(image, Vector2(32, 26) * s, Vector2(29, 28) * s, OUTLINE)
	_ellipse(image, Vector2(32, 26) * s, Vector2(26, 25) * s, BANANA)
	_ellipse(image, Vector2(32, 14) * s, Vector2(30, 24) * s, Color(0, 0, 0, 0))
	_rect(image, Rect2i(Vector2i(Vector2(4, 22) * s), Vector2i(Vector2(6, 8) * s)), OUTLINE)
	return image


func _world_icon() -> Image:
	var image := _blank(128, 128)
	for y in range(20, 116, 24):
		for x in range(12, 116, 26):
			var odd: bool = ((x - 12) / 26 + (y - 20) / 24) % 2 == 1
			_rect(image, Rect2i(x, y, 26, 24), BLANKET_RED if odd else BLANKET_LIGHT)
	image.blend_rect(_strawberry(64), Rect2i(0, 0, 64, 64), Vector2i(14, 40))
	image.blend_rect(_apple(64), Rect2i(0, 0, 64, 64), Vector2i(52, 36))
	return image

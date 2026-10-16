extends SceneTree

## Draws the Market world's programmer-art placeholders into assets/sprites/market/ and the world
## icon into assets/sprites/ui/. Run from the project root:
##   Godot --path . --headless -s tools/make_market_placeholders.gd
## then `Godot --path . --headless --import` to create the .import files.

const OUT := "res://assets/sprites/market/"
const UI_OUT := "res://assets/sprites/ui/"

const WOOD := Color(0.62, 0.42, 0.24)
const WOOD_DARK := Color(0.42, 0.27, 0.14)
const PAPER := Color(0.93, 0.86, 0.7)
const PAPER_DARK := Color(0.72, 0.6, 0.42)
const TOMATO := Color(0.88, 0.22, 0.18)
const LEAF := Color(0.3, 0.62, 0.25)
const POTATO := Color(0.7, 0.52, 0.32)
const CARROT := Color(0.95, 0.52, 0.12)
const OUTLINE := Color(0.24, 0.15, 0.09)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_background(), OUT + "bg_market.png")
	_save(_table(), OUT + "table.png")
	_save(_crate(), OUT + "crate.png")
	_save(_bag(), OUT + "bag.png")
	_save(_bag_shadow(), OUT + "bag_shadow.png")
	_save(_order_slip(), OUT + "order_slip.png")
	_save(_tomato(64), OUT + "icon_tomato.png")
	_save(_potato(64), OUT + "icon_potato.png")
	_save(_carrot(64), OUT + "icon_carrot.png")
	_save(_splat(), OUT + "splat.png")
	_save(_world_icon(), UI_OUT + "icon_world_market.png")
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


func _outlined_rect(image: Image, r: Rect2i, color: Color, border: int = 4) -> void:
	_rect(image, r, OUTLINE)
	_rect(image, r.grow(-border), color)


func _background() -> Image:
	var image := _blank(1800, 1000)
	_rect(image, Rect2i(0, 0, 1800, 1000), Color(0.68, 0.85, 0.95))
	_rect(image, Rect2i(0, 640, 1800, 360), Color(0.78, 0.62, 0.42))
	for x in range(0, 1800, 120):
		_rect(image, Rect2i(x, 640, 4, 360), Color(0.68, 0.52, 0.34))
	for i in 15:
		var color: Color = Color(0.85, 0.25, 0.22) if i % 2 == 0 else Color(0.98, 0.95, 0.88)
		_rect(image, Rect2i(i * 120, 120, 120, 110), color)
		_ellipse(image, Vector2(i * 120 + 60, 230), Vector2(60, 26), color)
	_rect(image, Rect2i(0, 110, 1800, 12), WOOD_DARK)
	return image


func _table() -> Image:
	var image := _blank(760, 330)
	_outlined_rect(image, Rect2i(0, 0, 760, 330), WOOD, 6)
	for y in range(40, 330, 55):
		_rect(image, Rect2i(10, y, 740, 3), WOOD_DARK)
	return image


func _crate() -> Image:
	var image := _blank(150, 110)
	_outlined_rect(image, Rect2i(0, 10, 150, 100), WOOD, 5)
	_rect(image, Rect2i(5, 15, 140, 22), Color(0.3, 0.2, 0.12))
	for y in [55, 80]:
		_rect(image, Rect2i(5, y, 140, 4), WOOD_DARK)
	return image


func _bag_shape(image: Image, color: Color, edge: Color) -> void:
	_rect(image, Rect2i(10, 14, 76, 80), edge)
	_rect(image, Rect2i(14, 18, 68, 72), color)
	for i in 6:
		_triangle(image, Vector2(14 + i * 12, 18), Vector2(26 + i * 12, 18), Vector2(20 + i * 12, 8), edge)


func _bag() -> Image:
	var image := _blank(96, 96)
	_bag_shape(image, PAPER, PAPER_DARK)
	return image


func _bag_shadow() -> Image:
	var image := _blank(96, 96)
	var shade := Color(0, 0, 0, 0.3)
	_bag_shape(image, shade, shade)
	return image


func _order_slip() -> Image:
	var image := _blank(200, 230)
	_outlined_rect(image, Rect2i(0, 0, 200, 230), Color(1, 0.98, 0.92), 4)
	_rect(image, Rect2i(0, 0, 200, 14), Color(0.85, 0.25, 0.22))
	return image


func _tomato(size: int) -> Image:
	var image := _blank(size, size)
	var s: float = size / 64.0
	_outlined_ellipse(image, Vector2(32, 36) * s, Vector2(24, 21) * s, TOMATO)
	_ellipse(image, Vector2(32, 16) * s, Vector2(12, 5) * s, LEAF)
	return image


func _potato(size: int) -> Image:
	var image := _blank(size, size)
	var s: float = size / 64.0
	_outlined_ellipse(image, Vector2(32, 34) * s, Vector2(26, 18) * s, POTATO)
	for p in [Vector2(22, 30), Vector2(38, 38), Vector2(42, 28)]:
		_ellipse(image, p * s, Vector2(2.5, 2.5) * s, Color(0.5, 0.36, 0.2))
	return image


func _carrot(size: int) -> Image:
	var image := _blank(size, size)
	var s: float = size / 64.0
	_triangle(image, Vector2(14, 16) * s, Vector2(50, 16) * s, Vector2(32, 62) * s, OUTLINE)
	_triangle(image, Vector2(18, 19) * s, Vector2(46, 19) * s, Vector2(32, 56) * s, CARROT)
	_triangle(image, Vector2(22, 17) * s, Vector2(32, 17) * s, Vector2(22, 2) * s, LEAF)
	_triangle(image, Vector2(30, 17) * s, Vector2(40, 17) * s, Vector2(42, 2) * s, LEAF)
	return image


func _splat() -> Image:
	var image := _blank(200, 200)
	_ellipse(image, Vector2(100, 100), Vector2(62, 52), TOMATO)
	var blobs: Array[Vector3] = [
		Vector3(40, 60, 18), Vector3(160, 70, 16), Vector3(150, 150, 20), Vector3(50, 150, 15),
		Vector3(100, 30, 14), Vector3(100, 175, 12), Vector3(20, 105, 10), Vector3(182, 112, 9),
	]
	for b in blobs:
		_ellipse(image, Vector2(b.x, b.y), Vector2(b.z, b.z), TOMATO)
	_ellipse(image, Vector2(85, 85), Vector2(14, 9), Color(0.98, 0.5, 0.42))
	return image


func _world_icon() -> Image:
	var image := _blank(128, 128)
	_rect(image, Rect2i(18, 34, 92, 86), PAPER_DARK)
	_rect(image, Rect2i(23, 39, 82, 76), PAPER)
	image.blend_rect(_tomato(64), Rect2i(0, 0, 64, 64), Vector2i(32, 44))
	return image

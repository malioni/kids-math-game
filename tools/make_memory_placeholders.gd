extends SceneTree

## Draws the Memory Meadow world's programmer-art placeholders into assets/sprites/memory/ and the
## world icon into assets/sprites/ui/. Run from the project root:
##   Godot --path . --headless -s tools/make_memory_placeholders.gd
## then `Godot --path . --headless --import` to create the .import files.

const OUT := "res://assets/sprites/memory/"
const UI_OUT := "res://assets/sprites/ui/"

const SKY := Color(0.7, 0.86, 0.95)
const GRASS := Color(0.55, 0.76, 0.38)
const GRASS_DARK := Color(0.45, 0.66, 0.3)
const CLEARING := Color(0.66, 0.84, 0.48)
const FLOWER := Color(0.98, 0.92, 0.5)
const CARD_BACK := Color(0.33, 0.58, 0.32)
const CARD_LEAF := Color(0.5, 0.75, 0.4)
const CARD_FRONT := Color(0.99, 0.96, 0.87)
const CARD_RIM := Color(0.85, 0.78, 0.62)
const OUTLINE := Color(0.24, 0.15, 0.09)
const WHITE := Color(1, 1, 1)
const PINK := Color(0.96, 0.66, 0.72)
const CLEAR := Color(0, 0, 0, 0)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_background(), OUT + "bg_memory.png")
	_save(_card_back(), OUT + "card_back.png")
	_save(_card_front(), OUT + "card_front.png")
	var animals := {
		"fox": _fox,
		"rabbit": _rabbit,
		"bear": _bear,
		"owl": _owl,
		"frog": _frog,
		"hedgehog": _hedgehog,
		"mouse": _mouse,
		"duck": _duck,
		"pig": _pig,
		"cat": _cat,
		"deer": _deer,
		"squirrel": _squirrel,
	}
	for animal: String in animals:
		_save(animals[animal].call(), OUT + "animal_%s.png" % animal)
	_save(_world_icon(), UI_OUT + "icon_world_memory.png")
	quit()


func _save(image: Image, path: String) -> void:
	var err: Error = image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Could not save %s" % path)


func _blank(w: int, h: int) -> Image:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(CLEAR)
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


# A triangle with a dark outline, grown out from its centre.
func _outlined_triangle(image: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var mid: Vector2 = (a + b + c) / 3.0
	var grow := func(p: Vector2) -> Vector2: return p + (p - mid).normalized() * 4.0
	_triangle(image, grow.call(a), grow.call(b), grow.call(c), OUTLINE)
	_triangle(image, a, b, c, color)


func _eyes(image: Image, y: float, spread: float, radius: float = 6.0) -> void:
	for x in [64.0 - spread, 64.0 + spread]:
		_ellipse(image, Vector2(x, y), Vector2(radius, radius), OUTLINE)
		_ellipse(image, Vector2(x - radius * 0.3, y - radius * 0.3), Vector2(2, 2), WHITE)


func _nose(image: Image, center: Vector2, radii: Vector2 = Vector2(6, 4)) -> void:
	_ellipse(image, center, radii, OUTLINE)


func _background() -> Image:
	var image := _blank(1800, 1000)
	_rect(image, Rect2i(0, 0, 1800, 1000), SKY)
	_rect(image, Rect2i(0, 260, 1800, 740), GRASS)
	for x in range(0, 1800, 90):
		_rect(image, Rect2i(x, 260 + (x / 90 % 3) * 40, 6, 14), GRASS_DARK)
	# A lighter clearing behind the cards (the 1280×720 view starts at (260, 140)).
	_ellipse(image, Vector2(1040, 520), Vector2(560, 380), CLEARING)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 40:
		var p := Vector2(rng.randf_range(0, 1800), rng.randf_range(300, 1000))
		_ellipse(image, p, Vector2(5, 5), FLOWER)
	return image


func _card_back() -> Image:
	var image := _blank(160, 160)
	_rect(image, Rect2i(0, 0, 160, 160), OUTLINE)
	_rect(image, Rect2i(5, 5, 150, 150), CARD_BACK)
	for y in range(30, 160, 50):
		for x in range(30, 160, 50):
			_ellipse(image, Vector2(x, y), Vector2(14, 8), CARD_LEAF)
			_rect(image, Rect2i(x - 10, y - 1, 20, 2), CARD_BACK)
	return image


func _card_front() -> Image:
	var image := _blank(160, 160)
	_rect(image, Rect2i(0, 0, 160, 160), OUTLINE)
	_rect(image, Rect2i(5, 5, 150, 150), CARD_RIM)
	_rect(image, Rect2i(12, 12, 136, 136), CARD_FRONT)
	return image


func _fox() -> Image:
	var image := _blank(128, 128)
	var orange := Color(0.93, 0.5, 0.15)
	_outlined_triangle(image, Vector2(22, 54), Vector2(30, 8), Vector2(56, 38), orange)
	_outlined_triangle(image, Vector2(106, 54), Vector2(98, 8), Vector2(72, 38), orange)
	_outlined_ellipse(image, Vector2(64, 70), Vector2(46, 40), orange)
	_triangle(image, Vector2(26, 76), Vector2(102, 76), Vector2(64, 112), WHITE)
	_eyes(image, 62, 20)
	_nose(image, Vector2(64, 100))
	return image


func _rabbit() -> Image:
	var image := _blank(128, 128)
	var fur := Color(0.92, 0.92, 0.95)
	for x in [44.0, 84.0]:
		_outlined_ellipse(image, Vector2(x, 30), Vector2(12, 28), fur)
		_ellipse(image, Vector2(x, 32), Vector2(5, 20), PINK)
	_outlined_ellipse(image, Vector2(64, 82), Vector2(40, 36), fur)
	_eyes(image, 76, 16)
	_ellipse(image, Vector2(64, 94), Vector2(6, 4), PINK)
	_rect(image, Rect2i(56, 102, 16, 8), WHITE)
	return image


func _bear() -> Image:
	var image := _blank(128, 128)
	var brown := Color(0.45, 0.29, 0.18)
	for x in [28.0, 100.0]:
		_outlined_ellipse(image, Vector2(x, 32), Vector2(16, 16), brown)
	_outlined_ellipse(image, Vector2(64, 70), Vector2(48, 44), brown)
	_ellipse(image, Vector2(64, 88), Vector2(22, 16), Color(0.82, 0.68, 0.5))
	_eyes(image, 60, 20)
	_nose(image, Vector2(64, 82), Vector2(9, 6))
	return image


func _owl() -> Image:
	var image := _blank(128, 128)
	var feathers := Color(0.45, 0.5, 0.68)
	_outlined_triangle(image, Vector2(20, 40), Vector2(22, 6), Vector2(50, 28), feathers)
	_outlined_triangle(image, Vector2(108, 40), Vector2(106, 6), Vector2(78, 28), feathers)
	_outlined_ellipse(image, Vector2(64, 70), Vector2(48, 50), feathers)
	for x in [44.0, 84.0]:
		_ellipse(image, Vector2(x, 60), Vector2(18, 18), WHITE)
		_ellipse(image, Vector2(x, 60), Vector2(8, 8), OUTLINE)
	_triangle(image, Vector2(56, 78), Vector2(72, 78), Vector2(64, 96), Color(0.98, 0.72, 0.2))
	return image


func _frog() -> Image:
	var image := _blank(128, 128)
	var green := Color(0.4, 0.75, 0.3)
	for x in [38.0, 90.0]:
		_outlined_ellipse(image, Vector2(x, 38), Vector2(18, 18), green)
		_ellipse(image, Vector2(x, 38), Vector2(10, 10), WHITE)
		_ellipse(image, Vector2(x, 38), Vector2(5, 5), OUTLINE)
	_outlined_ellipse(image, Vector2(64, 78), Vector2(54, 36), green)
	_rect(image, Rect2i(36, 92, 56, 4), OUTLINE)
	return image


func _hedgehog() -> Image:
	var image := _blank(128, 128)
	var spikes := Color(0.38, 0.27, 0.2)
	for i in 9:
		var angle: float = PI + PI * (i + 0.5) / 9.0
		var tip := Vector2(64, 74) + Vector2(cos(angle), sin(angle)) * 64.0
		var side := Vector2(-sin(angle), cos(angle)) * 14.0
		var base := Vector2(64, 74) + Vector2(cos(angle), sin(angle)) * 36.0
		_triangle(image, base - side, base + side, tip, spikes)
	_outlined_ellipse(image, Vector2(64, 78), Vector2(42, 36), Color(0.93, 0.83, 0.64))
	_eyes(image, 72, 16)
	_nose(image, Vector2(64, 92), Vector2(8, 6))
	return image


func _mouse() -> Image:
	var image := _blank(128, 128)
	var grey := Color(0.7, 0.7, 0.72)
	for x in [26.0, 102.0]:
		_outlined_ellipse(image, Vector2(x, 38), Vector2(24, 24), grey)
		_ellipse(image, Vector2(x, 38), Vector2(15, 15), PINK)
	_outlined_ellipse(image, Vector2(64, 78), Vector2(38, 36), grey)
	_eyes(image, 72, 15, 5.0)
	_ellipse(image, Vector2(64, 96), Vector2(6, 5), PINK)
	return image


func _duck() -> Image:
	var image := _blank(128, 128)
	_outlined_ellipse(image, Vector2(64, 62), Vector2(46, 46), Color(0.98, 0.86, 0.25))
	_outlined_ellipse(image, Vector2(64, 92), Vector2(30, 12), Color(0.98, 0.55, 0.15))
	_eyes(image, 54, 18)
	return image


func _pig() -> Image:
	var image := _blank(128, 128)
	var pink := Color(0.98, 0.7, 0.76)
	_outlined_triangle(image, Vector2(20, 44), Vector2(22, 12), Vector2(50, 30), pink)
	_outlined_triangle(image, Vector2(108, 44), Vector2(106, 12), Vector2(78, 30), pink)
	_outlined_ellipse(image, Vector2(64, 70), Vector2(48, 44), pink)
	_outlined_ellipse(image, Vector2(64, 84), Vector2(20, 14), Color(0.95, 0.55, 0.62))
	for x in [57.0, 71.0]:
		_ellipse(image, Vector2(x, 84), Vector2(3, 5), OUTLINE)
	_eyes(image, 58, 20)
	return image


func _cat() -> Image:
	var image := _blank(128, 128)
	var dark := Color(0.28, 0.28, 0.32)
	_outlined_triangle(image, Vector2(18, 58), Vector2(22, 10), Vector2(54, 34), dark)
	_outlined_triangle(image, Vector2(110, 58), Vector2(106, 10), Vector2(74, 34), dark)
	_outlined_ellipse(image, Vector2(64, 72), Vector2(46, 40), dark)
	for x in [44.0, 84.0]:
		_ellipse(image, Vector2(x, 66), Vector2(10, 9), Color(0.55, 0.85, 0.35))
		_ellipse(image, Vector2(x, 66), Vector2(3, 8), OUTLINE)
	_triangle(image, Vector2(58, 84), Vector2(70, 84), Vector2(64, 91), PINK)
	for y in [86.0, 94.0]:
		_rect(image, Rect2i(16, int(y), 28, 2), WHITE)
		_rect(image, Rect2i(84, int(y), 28, 2), WHITE)
	return image


func _deer() -> Image:
	var image := _blank(128, 128)
	var tan := Color(0.8, 0.6, 0.38)
	var antler := Color(0.55, 0.4, 0.25)
	for side in [-1, 1]:
		var x: int = 64 + side * 26
		_rect(image, Rect2i(x - 3, 4, 6, 34), antler)
		_rect(image, Rect2i(mini(x, x + side * 14), 12, 14, 5), antler)
	_outlined_ellipse(image, Vector2(64, 74), Vector2(38, 46), tan)
	_ellipse(image, Vector2(64, 102), Vector2(18, 14), Color(0.95, 0.88, 0.76))
	_eyes(image, 66, 17)
	_nose(image, Vector2(64, 104), Vector2(8, 5))
	return image


func _squirrel() -> Image:
	var image := _blank(128, 128)
	var chestnut := Color(0.62, 0.33, 0.18)
	# The bushy tail curls up behind the head, so the squirrel reads differently from the fox.
	_outlined_ellipse(image, Vector2(100, 50), Vector2(24, 44), Color(0.75, 0.45, 0.25))
	_outlined_triangle(image, Vector2(26, 50), Vector2(30, 16), Vector2(50, 36), chestnut)
	_outlined_triangle(image, Vector2(84, 50), Vector2(80, 16), Vector2(60, 36), chestnut)
	_outlined_ellipse(image, Vector2(56, 76), Vector2(38, 36), chestnut)
	_ellipse(image, Vector2(56, 92), Vector2(18, 14), Color(0.95, 0.85, 0.7))
	for x in [42.0, 70.0]:
		_ellipse(image, Vector2(x, 70), Vector2(6, 6), OUTLINE)
	_nose(image, Vector2(56, 86), Vector2(5, 4))
	return image


func _world_icon() -> Image:
	var image := _blank(128, 128)
	var back: Image = _card_back()
	back.resize(64, 64)
	var front: Image = _card_front()
	front.resize(64, 64)
	var fox: Image = _fox()
	fox.resize(52, 52)
	front.blend_rect(fox, Rect2i(0, 0, 52, 52), Vector2i(6, 6))
	image.blend_rect(back, Rect2i(0, 0, 64, 64), Vector2i(10, 24))
	image.blend_rect(front, Rect2i(0, 0, 64, 64), Vector2i(54, 40))
	return image

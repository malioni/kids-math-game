extends SceneTree

## Draws the fox's car for Country Drive as SVG animation sheets into assets/sprites/drive/, and
## their SpriteFrames (car_frames.tres). Run from the project root:
##   Godot --path . --headless -s tools/make_car_sheets.gd
## then tools/import_svgs.sh to import them.
##
## The car is seen from straight above, facing right, with the fox's head in the open seat (seen
## from above and a little behind). It is built from parts, and each frame is one row of pose values
## in SHEETS, as in tools/make_fox_sheets.gd. The game rotates the car to face up, down and left, so
## every pose must leave the two outermost rows and columns of its cell empty
## (tests/test_car_frames.gd checks).

const OUT := "res://assets/sprites/drive/"
const CELL := 160
# Where the fox's head sits in the seat, behind the windscreen.
const HEAD := Vector2(60, 80)
# The head is drawn at full size and shrunk to fit the seat, keeping the outline width.
const HEAD_SCALE := 0.9

const OUTLINE := "#3D2617"
const HEADLIGHT := "#FFE08A"
const STAR := "#FFD84A"
const TREAD := "#A88B74"

# Every value a pose can set, with the car standing still. Lengths are in SVG units, angles in
# degrees.
const REST := {
	"bob": 0.0,  # body and head shifted up (the bounce)
	"ears": 0.0,  # ear angle; positive lifts them, negative droops them back
	"eyes": "open",  # open, closed (blink), dizzy, sad
	"tread": 0.0,  # wheel tread offset, as the wheels turn
	"jolt": 0.0,  # whole car knocked back (left) by this much
	"stars": -1.0,  # -1 for none, else the rotation of the dizzy stars circling the head
	"hold": 1.0,  # how long the frame shows, in frames at the sheet's speed (SpriteFrames duration)
}

# Each animation's speed (frames per second), whether it loops, and one pose per frame. A pose lists
# only what differs from REST.
const SHEETS := {
	"idle":
	{
		"speed": 6.0,
		"loop": true,
		"poses":
		[
			# The open-eyed frames are held, so the fox blinks about every 2 s, as in its own idle.
			{"hold": 4.0},
			{"bob": 1.0, "hold": 4.0},
			{"hold": 4.0},
			{"eyes": "closed"},
		],
	},
	"drive":
	{
		"speed": 10.0,
		"loop": true,
		"poses":
		[
			{"tread": 0.0, "bob": 1.0},
			{"tread": 4.0},
			{"tread": 8.0, "bob": 1.0},
			{"tread": 12.0},
		],
	},
	"celebrate":
	{
		"speed": 8.0,
		"loop": true,
		"poses":
		[
			{"bob": 4.0, "ears": 10.0},
			{"bob": 8.0, "ears": 20.0},
			{"bob": 4.0, "ears": 10.0},
			{"bob": 0.0, "ears": 0.0},
		],
	},
	# Knocked back off whatever it hit, then dizzy stars circle the fox's head.
	"bump":
	{
		"speed": 10.0,
		"loop": false,
		"poses":
		[
			{"jolt": 6.0, "eyes": "dizzy", "stars": 0.0},
			{"jolt": 3.0, "eyes": "dizzy", "stars": 40.0},
			{"jolt": 1.0, "eyes": "dizzy", "stars": 80.0},
			{"eyes": "dizzy", "stars": 120.0},
		],
	},
	"sad":
	{
		"speed": 4.0,
		"loop": true,
		"poses":
		[
			{"ears": -15.0, "eyes": "sad"},
			{"ears": -18.0, "eyes": "sad", "bob": -1.0},
			{"ears": -15.0, "eyes": "sad"},
			{"ears": -12.0, "eyes": "sad"},
		],
	},
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for sheet_name: String in SHEETS:
		_write("car_%s.svg" % sheet_name, _sheet(SHEETS[sheet_name]["poses"]))
	_write("car_frames.tres", _sprite_frames())
	quit()


func _write(file_name: String, text: String) -> void:
	var file := FileAccess.open(OUT + file_name, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % (OUT + file_name))
		return
	file.store_string(text)


func _n(value: float) -> String:
	return String.num(value, 2)


func _sheet(poses: Array) -> String:
	var width: int = CELL * poses.size()
	var svg: String = (
		'<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n'
		% [width, CELL, width, CELL]
	)
	svg += _defs()
	for i in poses.size():
		var pose: Dictionary = REST.merged(poses[i], true)
		svg += '<g transform="translate(%d 0)">\n%s</g>\n' % [i * CELL, _car(pose)]
	return svg + "</svg>\n"


# Each gradient runs from a highlight at the top left to a shade at the bottom right of whatever
# shape it fills.
func _defs() -> String:
	var defs := "<defs>\n"
	for gradient: Array in [
		["fur", "#F7A058", "#D96B28"],
		["cream", "#FFF6E3", "#EFD3A8"],
		["dark", "#5E3A24", "#3A2113"],
		["body", "#E8604A", "#B8382A"],
		["bonnet", "#F58A70", "#D24E3A"],
		["seat", "#8A5A3A", "#5A3622"],
		["glass", "#E4F4FB", "#9CCBE0"],
		["metal", "#D8D8D2", "#9C9C94"],
	]:
		defs += (
			'<radialGradient id="%s" cx="0.35" cy="0.3" r="0.9">' % gradient[0]
			+ '<stop offset="0" stop-color="%s"/>' % gradient[1]
			+ '<stop offset="1" stop-color="%s"/>' % gradient[2]
			+ "</radialGradient>\n"
		)
	return defs + "</defs>\n"


func _car(pose: Dictionary) -> String:
	return (
		(
			'<g transform="translate(%s 0)" stroke="%s" stroke-width="3.5"'
			% [_n(-pose["jolt"]), OUTLINE]
		)
		+ ' stroke-linejoin="round" stroke-linecap="round">\n'
		+ (
			'<ellipse cx="82" cy="84" rx="64" ry="40" fill="%s" fill-opacity="0.16" stroke="none"/>\n'
			% OUTLINE
		)
		+ _wheels(pose["tread"])
		+ '<g transform="translate(0 %s)">\n' % _n(-pose["bob"])
		+ _body()
		+ (
			'<g transform="translate(%s %s) scale(%s) translate(%s %s)" stroke-width="%s">\n'
			% [
				_n(HEAD.x),
				_n(HEAD.y),
				_n(HEAD_SCALE),
				_n(-HEAD.x),
				_n(-HEAD.y),
				_n(3.5 / HEAD_SCALE)
			]
		)
		+ _head(pose)
		+ "</g>\n"
		+ "</g>\n"
		+ _stars(pose["stars"], pose["bob"])
		+ "</g>\n"
	)


# Four dark tyres poking out at the corners, each with three light tread lines that slide back as
# the wheels turn.
func _wheels(tread: float) -> String:
	var wheels := ""
	for at: Vector2 in [Vector2(33, 38), Vector2(99, 38), Vector2(33, 108), Vector2(99, 108)]:
		wheels += (
			'<rect x="%s" y="%s" width="26" height="14" rx="6" fill="url(#dark)"/>\n'
			% [_n(at.x), _n(at.y)]
		)
		for i in 3:
			var x: float = at.x + 5.0 + fposmod(i * 8.0 - tread, 24.0) * 16.0 / 24.0
			wheels += (
				'<path d="M%s %s l0 6" fill="none" stroke="%s" stroke-width="2"/>\n'
				% [_n(x), _n(at.y + 4.0), TREAD]
			)
	return wheels


# A round body, the bonnet towards the front (right) with its headlights, a windscreen, the open
# seat behind it and the bumper at the back.
func _body() -> String:
	return (
		'<rect x="18" y="58" width="12" height="44" rx="5" fill="url(#metal)"/>\n'
		+ '<rect x="22" y="45" width="116" height="70" rx="30" fill="url(#body)"/>\n'
		+ (
			'<ellipse cx="135" cy="%s" rx="4" ry="6.5" fill="%s" stroke-width="2.5"/>\n'
			% ["59", HEADLIGHT]
		)
		+ (
			'<ellipse cx="135" cy="%s" rx="4" ry="6.5" fill="%s" stroke-width="2.5"/>\n'
			% ["101", HEADLIGHT]
		)
		+ '<path d="M106 57 C120 56 130 64 131 80 C130 96 120 104 106 103 Z" fill="url(#bonnet)"/>\n'
		+ '<path d="M92 55 C100 62 102 98 92 105 L99 105 C108 96 108 64 99 55 Z" fill="url(#glass)"/>\n'
		+ '<rect x="32" y="56" width="62" height="48" rx="22" fill="url(#seat)"/>\n'
		+ (
			'<path d="M30 56 C26 66 26 94 30 104" fill="none" stroke="#FFFFFF" stroke-opacity="0.35"'
			+ ' stroke-width="3"/>\n'
		)
		+ (
			'<path d="M44 49 L84 49 M112 60 Q121 62 125 70" fill="none" stroke="#FFFFFF"'
			+ ' stroke-opacity="0.45" stroke-width="3"/>\n'
		)
	)


# The fox's head from above and a little behind: a teardrop that narrows to the nose at the front
# (right), cream cheek tufts flaring out at its sides, and ears pointing back to each side.
func _head(pose: Dictionary) -> String:
	var ear := (
		'<g transform="rotate(%s 54 66)">\n' % _n(pose["ears"])
		+ '<path d="M64 62 Q46 46 26 48 Q34 66 48 76 Z" fill="url(#fur)"/>\n'
		+ '<path d="M56 63 Q44 54 34 54 Q39 64 47 70 Z" fill="url(#cream)" stroke="none"/>\n'
		+ "</g>\n"
	)
	var tuft := '<path d="M66 64 Q76 54 90 56 Q86 66 80 74 Z" fill="url(#cream)"/>\n'
	return (
		ear
		+ '<g transform="translate(0 160) scale(1 -1)">\n%s</g>\n' % ear
		+ tuft
		+ '<g transform="translate(0 160) scale(1 -1)">\n%s</g>\n' % tuft
		+ (
			'<path d="M58 58 C72 58 84 66 96 75 C101 78 101 82 96 85 C84 94 72 102 58 102'
			+ ' C45 102 36 92 36 80 C36 68 45 58 58 58 Z" fill="url(#fur)"/>\n'
		)
		+ '<ellipse cx="99" cy="80" rx="4.5" ry="5.5" fill="%s" stroke="none"/>\n' % OUTLINE
		+ (
			'<ellipse cx="50" cy="70" rx="9" ry="4.5" fill="#FFFFFF" fill-opacity="0.3" stroke="none"'
			+ ' transform="rotate(-25 50 70)"/>\n'
		)
		+ _eyes(pose["eyes"])
	)


func _eyes(kind: String) -> String:
	var eyes := ""
	for side: float in [-1.0, 1.0]:
		var at := Vector2(74, 80 + side * 9.0)
		match kind:
			"closed":
				eyes += (
					'<path d="M%s %s l8 0" fill="none" stroke-width="3"/>\n'
					% [_n(at.x - 4.0), _n(at.y)]
				)
			"sad":
				# Drooped arcs, sloping down towards the back of the head.
				eyes += (
					'<path d="M%s %s q4 %s 8 %s" fill="none" stroke-width="3"/>\n'
					% [_n(at.x - 4.0), _n(at.y - side * 3.0), _n(side * 4.0), _n(side * 3.0)]
				)
			"dizzy":
				eyes += (
					(
						'<path d="M%s %s a2 2 0 1 1 2 2 a3.5 3.5 0 1 1 -1 -6" fill="none"'
						% [_n(at.x), _n(at.y)]
					)
					+ ' stroke-width="1.8"/>\n'
				)
			_:
				eyes += (
					'<ellipse cx="%s" cy="%s" rx="3.8" ry="4.3" fill="%s" stroke="none"/>\n'
					% [_n(at.x), _n(at.y), OUTLINE]
				)
				eyes += (
					'<circle cx="%s" cy="%s" r="1.4" fill="#FFFFFF" stroke="none"/>\n'
					% [_n(at.x + 1.0), _n(at.y - 1.2)]
				)
	return eyes


# Three small stars circling the fox's head, turned by `angle`; none when it is negative.
func _stars(angle: float, bob: float) -> String:
	if angle < 0.0:
		return ""
	var stars := ""
	for i in 3:
		var a: float = deg_to_rad(angle + i * 120.0)
		var at: Vector2 = HEAD + Vector2(cos(a) * 30.0, sin(a) * 26.0 - bob)
		var points: PackedStringArray = []
		for p in 10:
			var r: float = 8.0 if p % 2 == 0 else 3.6
			var b: float = deg_to_rad(-90.0 + p * 36.0 + angle)
			points.append("%s,%s" % [_n(at.x + cos(b) * r), _n(at.y + sin(b) * r)])
		stars += ('<polygon points="%s" fill="%s" stroke-width="2"/>\n' % [" ".join(points), STAR])
	return stars


# The car's SpriteFrames, as a text resource: one AtlasTexture per frame of every sheet.
func _sprite_frames() -> String:
	var sheets := ""
	var cells := ""
	var animations: PackedStringArray = []
	for sheet_name: String in SHEETS:
		var sheet: Dictionary = SHEETS[sheet_name]
		sheets += (
			'[ext_resource type="Texture2D" path="%scar_%s.svg" id="%s"]\n'
			% [OUT, sheet_name, sheet_name]
		)
		var frames: PackedStringArray = []
		for i: int in sheet["poses"].size():
			cells += (
				'[sub_resource type="AtlasTexture" id="%s_%d"]\natlas = ExtResource("%s")\n'
				% [sheet_name, i, sheet_name]
			)
			cells += "region = Rect2(%d, 0, %d, %d)\n\n" % [i * CELL, CELL, CELL]
			var hold: float = REST.merged(sheet["poses"][i], true)["hold"]
			frames.append(
				'{\n"duration": %.1f,\n"texture": SubResource("%s_%d")\n}' % [hold, sheet_name, i]
			)
		animations.append(
			(
				'{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
				% [", ".join(frames), str(sheet["loop"]), sheet_name, sheet["speed"]]
			)
		)
	return (
		'[gd_resource type="SpriteFrames" format=3]\n\n%s\n%s[resource]\nanimations = [%s]\n'
		% [sheets, cells, ", ".join(animations)]
	)

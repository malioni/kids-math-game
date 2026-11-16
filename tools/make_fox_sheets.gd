extends SceneTree

## Draws the fox's animation sheets as SVG into assets/sprites/fox/, and the SpriteFrames every
## world shares (fox_frames.tres). Run from the project root:
##   Godot --path . --headless -s tools/make_fox_sheets.gd
## then tools/import_svgs.sh to import them.
##
## The fox is built from parts, and each frame is one row of pose values in SHEETS, so the frames
## can't drift apart. The fox faces right. Each frame is a CELL-sized square in a horizontal strip,
## and every pose must leave the two outermost columns of its cell empty (tests/test_fox_frames.gd
## checks).

const OUT := "res://assets/sprites/fox/"
const CELL := 160
# The lowest point of the feet. The feet sat on the bottom edge of the old 64 px cells, so this
# keeps the fox standing where it stood.
const BASELINE := 157.0
const SHOULDER_FRONT := Vector2(98, 102)
const SHOULDER_BACK := Vector2(64, 102)
const ARM_LENGTH := 30.0
# Where the legs join the body.
const LEG_TOP := 134.0
# How far past the shoulder a held item's centre sits.
const HOLD_REACH := 36.0
# The throw frame on which the paw lets go; scripts/worlds/market.gd uses the same number.
const RELEASE_FRAME := 3

const OUTLINE := "#3D2617"
const DARK := "#4A2C1A"
const MOUTH := "#7A2B22"
const TEAR := "#7CC4F0"

# Every value a pose can set, with the fox standing at rest. Lengths are in SVG units, angles in
# degrees.
const REST := {
	"hop": 0.0,  # whole fox lifted off the ground
	"squash": 0.0,  # body and head sinking as it breathes out
	"lean": 0.0,  # whole fox tipped about its feet; positive tips forward
	"head": 0.0,  # head tilted about the neck; positive nods down, negative looks up
	"arm_front": 15.0,  # 0 hangs down, 90 points forward, 180 up; negative reaches back
	"arm_back": -10.0,
	"leg_front": 0.0,  # foot swung forward (+) or back (-)
	"leg_back": 0.0,
	"lift_front": 0.0,  # foot raised off the ground, as it passes the other one
	"lift_back": 0.0,
	"tail": 0.0,  # positive lifts the tail
	"eyes": "open",  # open, closed, happy, wide
	"brows": "",  # "", worried, cross
	"mouth": "smile",  # smile, open, frown
	"tears": 0.0,  # 0 for none, up to 1 as the tears run down
	"held": "",  # "" or tomato, in the front paw
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
			{},
			{"squash": 1.0, "tail": 3.0},
			{"squash": 2.0, "tail": 6.0},
			{"squash": 1.0, "tail": 3.0, "eyes": "closed"},
		],
	},
	# Contact, down, passing (the back foot lifted), then the same with the other foot.
	"walk":
	{
		"speed": 10.0,
		"loop": true,
		"poses":
		[
			{"leg_front": 9.0, "leg_back": -9.0, "arm_front": -25.0, "arm_back": 30.0, "tail": 4.0},
			{"leg_front": 5.0, "leg_back": -5.0, "arm_front": -12.0, "squash": 1.5, "tail": 6.0},
			{"lift_back": 5.0, "arm_front": 10.0, "arm_back": 0.0, "hop": 3.0, "tail": 2.0},
			{"leg_front": -9.0, "leg_back": 9.0, "arm_front": 35.0, "arm_back": -25.0},
			{"leg_front": -5.0, "leg_back": 5.0, "arm_front": 22.0, "squash": 1.5, "tail": -2.0},
			{"lift_front": 5.0, "arm_front": 10.0, "arm_back": 0.0, "hop": 3.0, "tail": 2.0},
		],
	},
	# A crouch, then a hop with the arms out; the ears leave no room for a higher hop in the cell.
	"celebrate":
	{
		"speed": 8.0,
		"loop": true,
		"poses":
		[
			{
				"squash": 2.5,
				"arm_front": 80.0,
				"arm_back": -120.0,
				"head": -2.0,
				"eyes": "happy",
				"mouth": "open",
				"tail": 8.0
			},
			{
				"hop": 5.0,
				"arm_front": 100.0,
				"arm_back": -150.0,
				"head": -4.0,
				"eyes": "happy",
				"mouth": "open",
				"tail": 18.0,
				"lift_front": 2.0
			},
			{
				"hop": 8.0,
				"arm_front": 105.0,
				"arm_back": -165.0,
				"head": -4.0,
				"eyes": "happy",
				"mouth": "open",
				"tail": 22.0,
				"lift_front": 3.0,
				"lift_back": 2.0
			},
			{
				"hop": 3.0,
				"arm_front": 95.0,
				"arm_back": -145.0,
				"head": -3.0,
				"eyes": "happy",
				"mouth": "open",
				"tail": 14.0
			},
		],
	},
	"fall":
	{
		"speed": 8.0,
		"loop": false,
		"poses":
		[
			{"eyes": "wide", "mouth": "open", "arm_front": 70.0, "arm_back": -100.0, "tail": 10.0},
			{
				"lean": -8.0,
				"head": -6.0,
				"eyes": "wide",
				"mouth": "open",
				"arm_front": 100.0,
				"arm_back": -160.0,
				"tail": 20.0,
				"leg_front": 5.0,
				"leg_back": -5.0
			},
			{
				"lean": 6.0,
				"eyes": "wide",
				"mouth": "open",
				"arm_front": 85.0,
				"arm_back": -135.0,
				"tail": 30.0,
				"leg_front": -4.0,
				"leg_back": 4.0,
				"lift_front": 3.0
			},
		],
	},
	"sad":
	{
		"speed": 4.0,
		"loop": true,
		"poses":
		[
			{
				"head": 12.0,
				"eyes": "closed",
				"brows": "worried",
				"mouth": "frown",
				"tail": -12.0,
				"arm_front": 5.0,
				"arm_back": 0.0,
				"tears": 0.15
			},
			{
				"head": 12.0,
				"eyes": "closed",
				"brows": "worried",
				"mouth": "frown",
				"tail": -12.0,
				"arm_front": 5.0,
				"arm_back": 0.0,
				"squash": 1.5,
				"tears": 0.4
			},
			{
				"head": 12.0,
				"eyes": "closed",
				"brows": "worried",
				"mouth": "frown",
				"tail": -12.0,
				"arm_front": 5.0,
				"arm_back": 0.0,
				"squash": 2.5,
				"tears": 0.7
			},
			{
				"head": 12.0,
				"eyes": "closed",
				"brows": "worried",
				"mouth": "frown",
				"tail": -12.0,
				"arm_front": 5.0,
				"arm_back": 0.0,
				"squash": 1.5,
				"tears": 1.0
			},
		],
	},
	# An underhand lob: an overarm swing would cross the fox's face. Draw back, draw back further,
	# swing through low, let go (RELEASE_FRAME), follow through, settle.
	"throw":
	{
		"speed": 10.0,
		"loop": false,
		"poses":
		[
			{"lean": -4.0, "arm_front": -60.0, "held": "tomato", "brows": "cross"},
			{
				"lean": -10.0,
				"arm_front": -100.0,
				"held": "tomato",
				"brows": "cross",
				"tail": 10.0,
				"leg_back": -4.0
			},
			{"arm_front": 25.0, "held": "tomato", "brows": "cross", "leg_front": 4.0},
			{"lean": 8.0, "arm_front": 80.0, "mouth": "open", "leg_front": 6.0},
			{"lean": 10.0, "head": -6.0, "arm_front": 105.0, "mouth": "open", "leg_front": 6.0},
			{"lean": 4.0, "arm_front": 60.0},
		],
	},
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for sheet_name: String in SHEETS:
		_write("character_%s.svg" % sheet_name, _sheet(SHEETS[sheet_name]["poses"]))
	_write("fox_frames.tres", _sprite_frames())
	var release: Dictionary = REST.merged(SHEETS["throw"]["poses"][RELEASE_FRAME], true)
	print("Throw release, paw from the cell centre: ", _paw(release) - Vector2(CELL, CELL) / 2.0)
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
		svg += '<g transform="translate(%d 0)">\n%s</g>\n' % [i * CELL, _fox(pose)]
	return svg + "</svg>\n"


# Each gradient runs from a highlight at the top left to a shade at the bottom right of whatever
# shape it fills.
func _defs() -> String:
	var defs := "<defs>\n"
	for gradient: Array in [
		["fur", "#F7A058", "#D96B28"],
		["cream", "#FFF6E3", "#EFD3A8"],
		["dark", "#5E3A24", "#3A2113"],
		["tomato", "#F26B55", "#C92F22"],
	]:
		defs += (
			'<radialGradient id="%s" cx="0.35" cy="0.3" r="0.9">' % gradient[0]
			+ '<stop offset="0" stop-color="%s"/>' % gradient[1]
			+ '<stop offset="1" stop-color="%s"/>' % gradient[2]
			+ "</radialGradient>\n"
		)
	return defs + "</defs>\n"


func _fox(pose: Dictionary) -> String:
	return (
		(
			'<g transform="translate(0 %s) rotate(%s %s %s)" stroke="%s" stroke-width="3"'
			% [_n(-pose["hop"]), _n(pose["lean"]), _n(CELL / 2.0), _n(BASELINE), OUTLINE]
		)
		+ ' stroke-linejoin="round" stroke-linecap="round">\n'
		+ _tail(pose["tail"])
		+ _leg(66.0, pose["leg_back"], pose["lift_back"])
		+ _leg(90.0, pose["leg_front"], pose["lift_front"])
		+ _arm(SHOULDER_BACK, pose["arm_back"], "")
		+ _body(pose["squash"])
		+ _head(pose)
		+ _arm(SHOULDER_FRONT, pose["arm_front"], pose["held"])
		+ "</g>\n"
	)


# A fat teardrop from the lower back, swept up to the left, with a cream tip.
func _tail(lift: float) -> String:
	return (
		'<g transform="rotate(%s 56 128)">\n' % _n(lift)
		+ '<path d="M60 134 C44 142 22 136 17 116 C14 102 22 92 32 95 C30 106 42 116 60 114 Z"'
		+ ' fill="url(#fur)"/>\n'
		+ '<path d="M17 116 C14 102 22 92 32 95 C30 102 33 108 38 112 C31 119 22 120 17 116 Z"'
		+ ' fill="url(#cream)"/>\n'
		+ "</g>\n"
	)


# A leg hanging from its hip inside the body, swung so its foot moves `step` forward and raised by
# `lift`. Both legs sit behind the body, so only the feet show below it.
func _leg(hip_x: float, step: float, lift: float) -> String:
	var length: float = BASELINE - 1.5 - LEG_TOP
	return (
		(
			'<g transform="translate(0 %s) rotate(%s %s %s)">\n'
			% [_n(-lift), _n(-rad_to_deg(asin(step / length))), _n(hip_x), _n(LEG_TOP)]
		)
		+ (
			'<rect x="%s" y="%s" width="13" height="%s" rx="5" fill="url(#dark)"/>\n'
			% [_n(hip_x - 6.5), _n(LEG_TOP), _n(length)]
		)
		+ "</g>\n"
	)


# The body keeps its feet on the ground as it squashes: it gets shorter and a little wider.
func _body(squash: float) -> String:
	return (
		(
			'<ellipse cx="78" cy="%s" rx="%s" ry="%s" fill="url(#fur)"/>\n'
			% [_n(112.0 + squash), _n(30.0 + squash * 0.5), _n(34.0 - squash)]
		)
		+ (
			'<ellipse cx="86" cy="%s" rx="15" ry="%s" fill="url(#cream)" stroke="none"/>\n'
			% [_n(118.0 + squash), _n(19.0 - squash)]
		)
	)


# A round head with pointed ears and a cream snout. The snout pokes out past the round of the head,
# so it is filled without an outline and then outlined along its outer edge only, which keeps the
# line between cream and fur soft.
func _head(pose: Dictionary) -> String:
	var snout_outer := "M126.5 56.8 C133 60 135 70 132 79 C128 90 102 97 80 90.2"
	return (
		(
			'<g transform="translate(0 %s) rotate(%s 84 90)">\n'
			% [_n(pose["squash"]), _n(pose["head"])]
		)
		+ '<path d="M62 44 Q60 27 67 16 Q81 22 88 34 Z" fill="url(#fur)"/>\n'
		+ '<path d="M68 37 Q67 29 70 24 Q77 28 80 33 Z" fill="%s" stroke="none"/>\n' % DARK
		+ '<path d="M98 32 Q105 20 115 14 Q124 26 124 42 Z" fill="url(#fur)"/>\n'
		+ '<path d="M105 33 Q109 27 113 23 Q118 30 118 38 Z" fill="%s" stroke="none"/>\n' % DARK
		+ '<ellipse cx="92" cy="62" rx="35" ry="30" fill="url(#fur)"/>\n'
		+ (
			'<path d="%s C84 74 102 64 126.5 56.8 Z" fill="url(#cream)" stroke="none"/>\n'
			% snout_outer
		)
		+ '<path d="%s" fill="none"/>\n' % snout_outer
		+ '<ellipse cx="130" cy="68" rx="5.5" ry="4.5" fill="%s" stroke="none"/>\n' % OUTLINE
		+ _eyes(pose["eyes"])
		+ _brows(pose["brows"])
		+ _mouth(pose["mouth"])
		+ _tears(pose["tears"])
		+ "</g>\n"
	)


func _eyes(kind: String) -> String:
	var eyes := ""
	for at: Vector2 in [Vector2(86, 58), Vector2(109, 56)]:
		match kind:
			"closed":
				eyes += '<path d="M%s %s q5 4 10 0" fill="none"/>\n' % [_n(at.x - 5.0), _n(at.y)]
			"happy":
				eyes += (
					'<path d="M%s %s q5 -7 10 0" fill="none"/>\n' % [_n(at.x - 5.0), _n(at.y + 2.0)]
				)
			"wide":
				eyes += (
					'<circle cx="%s" cy="%s" r="7" fill="#FFFFFF" stroke-width="2"/>\n'
					% [_n(at.x), _n(at.y)]
				)
				eyes += (
					'<circle cx="%s" cy="%s" r="3" fill="%s" stroke="none"/>\n'
					% [_n(at.x + 1.0), _n(at.y), OUTLINE]
				)
			_:
				eyes += (
					'<ellipse cx="%s" cy="%s" rx="4.5" ry="5.5" fill="%s" stroke="none"/>\n'
					% [_n(at.x), _n(at.y), OUTLINE]
				)
				eyes += (
					'<circle cx="%s" cy="%s" r="1.6" fill="#FFFFFF" stroke="none"/>\n'
					% [_n(at.x + 1.5), _n(at.y - 2.0)]
				)
	return eyes


func _brows(kind: String) -> String:
	match kind:
		"worried":
			return '<path d="M79 50 L91 45 M104 44 L116 49" fill="none"/>\n'
		"cross":
			return '<path d="M79 45 L91 50 M104 49 L116 44" fill="none"/>\n'
	return ""


func _mouth(kind: String) -> String:
	match kind:
		"open":
			return '<ellipse cx="110" cy="83" rx="6" ry="5" fill="%s" stroke-width="2"/>\n' % MOUTH
		"frown":
			return '<path d="M101 87 q7.5 -6 15 0" fill="none"/>\n'
	return '<path d="M102 80 q8 7 16 0" fill="none"/>\n'


func _tears(amount: float) -> String:
	if amount <= 0.0:
		return ""
	var tears := ""
	for x: float in [84.0, 112.0]:
		tears += (
			'<path d="M%s %s q-4 7 0 9 q4 -2 0 -9 Z" fill="%s" stroke="none"/>\n'
			% [_n(x), _n(63.0 + amount * 9.0), TEAR]
		)
	return tears


# An arm hanging from a shoulder, turned by `angle`, with anything it holds drawn at the paw.
func _arm(shoulder: Vector2, angle: float, held: String) -> String:
	var arm: String = (
		'<g transform="rotate(%s %s %s)">\n' % [_n(-angle), _n(shoulder.x), _n(shoulder.y)]
	)
	if held == "tomato":
		arm += _tomato(shoulder + Vector2(0, HOLD_REACH))
	arm += (
		'<rect x="%s" y="%s" width="12" height="%s" rx="6" fill="url(#fur)"/>\n'
		% [_n(shoulder.x - 6.0), _n(shoulder.y - 5.0), _n(ARM_LENGTH + 5.0)]
	)
	arm += (
		'<ellipse cx="%s" cy="%s" rx="6" ry="5" fill="url(#dark)" stroke="none"/>\n'
		% [_n(shoulder.x), _n(shoulder.y + ARM_LENGTH - 5.0)]
	)
	return arm + "</g>\n"


# The tomato in the paw: the same colours as market/icon_tomato.svg, which takes over once it flies.
func _tomato(at: Vector2) -> String:
	return (
		'<circle cx="%s" cy="%s" r="14" fill="url(#tomato)"/>\n' % [_n(at.x), _n(at.y)]
		+ (
			'<path d="M%s %s l-6 -4 l5 -1 l1 -5 l1 5 l5 1 Z" fill="#4D9E40" stroke-width="2"/>\n'
			% [_n(at.x), _n(at.y - 9.0)]
		)
	)


# Where an item held in the front paw sits in the cell, for a pose.
func _paw(pose: Dictionary) -> Vector2:
	var arm: float = deg_to_rad(pose["arm_front"])
	var paw: Vector2 = SHOULDER_FRONT + Vector2(sin(arm), cos(arm)) * HOLD_REACH
	var feet := Vector2(CELL / 2.0, BASELINE)
	return feet + (paw - feet).rotated(deg_to_rad(pose["lean"])) - Vector2(0, pose["hop"])


# The shared SpriteFrames, as a text resource: one AtlasTexture per frame of every sheet.
func _sprite_frames() -> String:
	var sheets := ""
	var cells := ""
	var animations: PackedStringArray = []
	for sheet_name: String in SHEETS:
		var sheet: Dictionary = SHEETS[sheet_name]
		sheets += (
			'[ext_resource type="Texture2D" path="%scharacter_%s.svg" id="%s"]\n'
			% [OUT, sheet_name, sheet_name]
		)
		var frames: PackedStringArray = []
		for i: int in sheet["poses"].size():
			cells += (
				'[sub_resource type="AtlasTexture" id="%s_%d"]\natlas = ExtResource("%s")\n'
				% [sheet_name, i, sheet_name]
			)
			cells += "region = Rect2(%d, 0, %d, %d)\n\n" % [i * CELL, CELL, CELL]
			frames.append(
				'{\n"duration": 1.0,\n"texture": SubResource("%s_%d")\n}' % [sheet_name, i]
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

extends SceneTree

## Generates the placeholder sounds into assets/audio/: shared feedback sounds, each world's place,
## remove and background loop, and the menu's loop. Every sound is built in code, so nothing is
## downloaded or licensed; real sounds can replace them later under the same names. Run from the
## project root:
##   Godot --path . --headless -s tools/make_audio_placeholders.gd
## then `Godot --path . --headless --import` to create the .import files.

const OUT := "res://assets/audio/"
const RATE := 22050
## Length of each background loop, in seconds.
const LOOP_SECONDS := 8.0
## Extra audio generated past the loop's end and blended into its start, so it repeats gaplessly.
const BLEND_SECONDS := 1.0
## Pitch, in Hz, of each world's place sound; remove is higher and lighter.
const PLACE_HZ := {"forest": 180.0, "sky": 520.0, "market": 140.0, "picnic": 330.0}

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 8
	_save("win", _notes([523.25, 659.25, 783.99], 0.11, 0.45))
	_save("complete", _notes([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.13, 0.7))
	_save("lose", _thud(150.0, 85.0, 0.35, 0.7))
	_save("tap", _blip(1100.0, 0.06, 0.35))
	for world: String in PLACE_HZ:
		var hz: float = PLACE_HZ[world]
		_save(world + "/place", _thud(hz, hz * 0.7, 0.14, 0.75))
		_save(world + "/remove", _blip(hz * 2.5, 0.08, 0.4))
	_save("sky/remove", _pop())
	_save("forest/ambience", _seamless(_water()))
	_save("sky/ambience", _seamless(_wind()))
	_save("market/ambience", _seamless(_murmur()))
	_save("picnic/ambience", _seamless(_birds()))
	_save("menu/ambience", _seamless(_pad()))
	quit()


func _save(sound: String, samples: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	var path: String = ProjectSettings.globalize_path(OUT + sound + ".wav")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if wav.save_to_wav(path) != OK:
		push_error("Could not save %s" % path)


func _empty(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * RATE))
	return samples


# Adds a soft bell-like note starting at start seconds and fading out over length seconds.
func _add_note(
	samples: PackedFloat32Array, hz: float, start: float, length: float, gain: float
) -> void:
	var first: int = int(start * RATE)
	for i in int(length * RATE):
		if first + i >= samples.size():
			return
		var t: float = float(i) / RATE
		var envelope: float = minf(t / 0.005, 1.0) * exp(-4.0 * t / length)
		var wave: float = sin(TAU * hz * t) + 0.3 * sin(TAU * hz * 2.0 * t)
		samples[first + i] += wave * envelope * gain


# Notes played one after another, gap seconds apart, each ringing for tail seconds.
func _notes(hz: Array, gap: float, tail: float) -> PackedFloat32Array:
	var samples := _empty(gap * hz.size() + tail)
	for k in hz.size():
		_add_note(samples, hz[k], k * gap, tail, 0.35)
	return samples


# A short drop in pitch with a little noise: a soft knock or thud.
func _thud(from_hz: float, to_hz: float, length: float, gain: float) -> PackedFloat32Array:
	var samples := _empty(length)
	var phase: float = 0.0
	for i in samples.size():
		var t: float = float(i) / RATE
		var k: float = t / length
		phase += TAU * lerpf(from_hz, to_hz, k) / RATE
		var envelope: float = minf(t / 0.003, 1.0) * pow(1.0 - k, 3.0)
		samples[i] = (sin(phase) + 0.15 * _rng.randf_range(-1.0, 1.0)) * envelope * gain
	return samples


# A short, quickly fading tone: a click.
func _blip(hz: float, length: float, gain: float) -> PackedFloat32Array:
	var samples := _empty(length)
	for i in samples.size():
		var t: float = float(i) / RATE
		var envelope: float = minf(t / 0.002, 1.0) * exp(-6.0 * t / length)
		samples[i] = sin(TAU * hz * t) * envelope * gain
	return samples


# A burst of noise over a falling tone: a balloon popping.
func _pop() -> PackedFloat32Array:
	var samples := _empty(0.09)
	var phase: float = 0.0
	for i in samples.size():
		var t: float = float(i) / RATE
		phase += TAU * lerpf(900.0, 300.0, t / 0.09) / RATE
		var envelope: float = exp(-t / 0.018)
		samples[i] = (0.7 * _rng.randf_range(-1.0, 1.0) + 0.4 * sin(phase)) * envelope * 0.8
	return samples


# Blends the audio past LOOP_SECONDS into the start, so the end runs straight into the beginning.
func _seamless(raw: PackedFloat32Array) -> PackedFloat32Array:
	var length: int = int(LOOP_SECONDS * RATE)
	var blend: int = int(BLEND_SECONDS * RATE)
	var samples: PackedFloat32Array = raw.slice(0, length)
	for i in blend:
		var k: float = float(i) / blend
		samples[i] = raw[i] * k + raw[length + i] * (1.0 - k)
	return samples


func _loop_buffer() -> PackedFloat32Array:
	return _empty(LOOP_SECONDS + BLEND_SECONDS)


# Scales samples so their loudest point is peak.
func _normalize(samples: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var loudest: float = 0.0001
	for v in samples:
		loudest = maxf(loudest, absf(v))
	for i in samples.size():
		samples[i] *= peak / loudest
	return samples


# Low-passed noise that rises and falls a little: a river.
func _water() -> PackedFloat32Array:
	var samples := _loop_buffer()
	var low: float = 0.0
	var bubbles: float = 0.0
	for i in samples.size():
		var t: float = float(i) / RATE
		var noise: float = _rng.randf_range(-1.0, 1.0)
		low += 0.05 * (noise - low)
		bubbles += 0.3 * (noise - bubbles)
		var swell: float = 0.75 + 0.25 * sin(TAU * t * 0.3)
		samples[i] = (low * 3.0 + bubbles * 0.25) * swell
	return _normalize(samples, 0.5)


# Heavily low-passed noise with slow swells: wind.
func _wind() -> PackedFloat32Array:
	var samples := _loop_buffer()
	var low: float = 0.0
	for i in samples.size():
		var t: float = float(i) / RATE
		low += 0.015 * (_rng.randf_range(-1.0, 1.0) - low)
		samples[i] = low * (0.55 + 0.45 * sin(TAU * t / 4.5))
	return _normalize(samples, 0.5)


# Band-limited noise in short random bursts, like far-off voices: a market.
func _murmur() -> PackedFloat32Array:
	var samples := _loop_buffer()
	var low: float = 0.0
	var lower: float = 0.0
	var level: float = 0.0
	var target: float = 0.0
	var next_change: int = 0
	for i in samples.size():
		if i >= next_change:
			target = _rng.randf_range(0.2, 1.0)
			next_change = i + int(_rng.randf_range(0.15, 0.4) * RATE)
		level += 0.002 * (target - level)
		var noise: float = _rng.randf_range(-1.0, 1.0)
		low += 0.15 * (noise - low)
		lower += 0.02 * (noise - lower)
		samples[i] = (low - lower) * level
	return _normalize(samples, 0.4)


# A soft breeze with short rising chirps at random times: birds at a picnic.
func _birds() -> PackedFloat32Array:
	var samples := _loop_buffer()
	var low: float = 0.0
	for i in samples.size():
		low += 0.01 * (_rng.randf_range(-1.0, 1.0) - low)
		samples[i] = low * 0.6
	var start: float = 0.3
	while start < LOOP_SECONDS + BLEND_SECONDS - 0.5:
		for note in _rng.randi_range(2, 3):
			_add_chirp(samples, start + note * 0.14)
		start += _rng.randf_range(0.8, 2.0)
	return _normalize(samples, 0.45)


func _add_chirp(samples: PackedFloat32Array, start: float) -> void:
	var first: int = int(start * RATE)
	var length: int = int(0.1 * RATE)
	var phase: float = 0.0
	var from_hz: float = _rng.randf_range(2300.0, 2800.0)
	for i in length:
		if first + i >= samples.size():
			return
		var k: float = float(i) / length
		phase += TAU * lerpf(from_hz, from_hz * 1.35, k) / RATE
		samples[first + i] += sin(phase) * sin(PI * k) * 0.25


# Three quiet tones with a slow wobble: a calm menu loop.
func _pad() -> PackedFloat32Array:
	var samples := _loop_buffer()
	for i in samples.size():
		var t: float = float(i) / RATE
		var wobble: float = 0.8 + 0.2 * sin(TAU * t * 0.25)
		samples[i] = (
			(sin(TAU * 130.75 * t) + 0.7 * sin(TAU * 196.0 * t) + 0.5 * sin(TAU * 261.63 * t))
			* wobble
		)
	return _normalize(samples, 0.3)

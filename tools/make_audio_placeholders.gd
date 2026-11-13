extends SceneTree

## Generates the placeholder sounds into assets/audio/: shared feedback sounds, each world's place,
## remove and background loop, the market's splat, the memory match chime, and the menu's
## tune. Every sound is built in
## code, so nothing is downloaded or licensed; real sounds can replace them later under the same
## names. Run from the project root:
##   Godot --path . --headless -s tools/make_audio_placeholders.gd
## then `Godot --path . --headless --import` to create the .import files.

const OUT := "res://assets/audio/"
const RATE := 22050
## Length of each background loop, in seconds.
const LOOP_SECONDS := 8.0
## Extra audio generated past the loop's end and blended into its start, so it repeats gaplessly.
const BLEND_SECONDS := 1.0
## Pitch, in Hz, of each world's place sound; remove is higher and lighter.
const PLACE_HZ := {"forest": 180.0, "sky": 520.0, "market": 140.0, "picnic": 330.0, "memory": 400.0}
## The tunes, one bar per row: a low note, then the melody, one note per beat, as MIDI note numbers
## (0 is a rest). _tune says how often the low note sounds.
## The menu: slow and calm, a music box.
const MENU_BARS := [
	[48, [72, 76, 79, 76]],
	[53, [77, 76, 74, 0]],
	[55, [74, 77, 79, 77]],
	[48, [76, 74, 72, 0]],
	[45, [69, 72, 76, 72]],
	[53, [74, 72, 69, 0]],
	[55, [71, 74, 77, 74]],
	[48, [72, 0, 0, 0]],
]
## The market: quick and bouncy, with short plucked notes.
const MARKET_BARS := [
	[43, [67, 0, 71, 74, 79, 0, 74, 71]],
	[48, [72, 0, 76, 79, 76, 0, 72, 0]],
	[50, [74, 0, 78, 81, 78, 0, 74, 72]],
	[43, [71, 74, 71, 67, 0, 0, 67, 69]],
	[43, [71, 0, 71, 74, 72, 0, 71, 69]],
	[48, [67, 0, 72, 76, 74, 72, 71, 0]],
	[50, [69, 71, 72, 74, 76, 74, 72, 69]],
	[43, [67, 0, 0, 74, 67, 0, 0, 0]],
]

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_save("win", _notes.bind([523.25, 659.25, 783.99], 0.11, 0.45))
	_save("complete", _notes.bind([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.13, 0.7))
	_save("lose", _notes.bind([392.0, 349.23, 311.13], 0.2, 0.6))
	_save("tap", _blip.bind(1100.0, 0.06, 0.35))
	for world: String in PLACE_HZ:
		var hz: float = PLACE_HZ[world]
		_save(world + "/place", _thud.bind(hz, hz * 0.7, 0.14, 0.75))
		_save(world + "/remove", _blip.bind(hz * 2.5, 0.08, 0.4))
	_save("sky/remove", _pop)
	_save("market/splat", _splat)
	_save("memory/match", _notes.bind([659.25, 987.77], 0.09, 0.35))
	_save("forest/ambience", func() -> PackedFloat32Array: return _seamless(_water()))
	_save("sky/ambience", func() -> PackedFloat32Array: return _seamless(_wind()))
	_save("market/ambience", _tune.bind(MARKET_BARS, 0.25, 0.35, 4))
	_save("picnic/ambience", func() -> PackedFloat32Array: return _seamless(_birds()))
	_save("memory/ambience", func() -> PackedFloat32Array: return _seamless(_chimes()))
	_save("menu/ambience", _tune.bind(MENU_BARS, 0.5, 1.2, 4))
	quit()


# Makes a sound with make and saves it. Each sound seeds the random numbers from its own name, so
# changing one sound leaves the others byte-for-byte the same.
func _save(sound: String, make: Callable) -> void:
	_rng.seed = hash(sound)
	var samples: PackedFloat32Array = make.call()
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


# A steady, bright rush of water with lots of small gurgles: a river.
func _water() -> PackedFloat32Array:
	var samples := _loop_buffer()
	var bright: float = 0.0
	var dull: float = 0.0
	var level: float = 0.8
	var target: float = 0.8
	var next_change: int = 0
	for i in samples.size():
		if i >= next_change:
			target = _rng.randf_range(0.6, 1.0)
			next_change = i + int(_rng.randf_range(0.03, 0.08) * RATE)
		level += 0.01 * (target - level)
		var noise: float = _rng.randf_range(-1.0, 1.0)
		bright += 0.4 * (noise - bright)
		dull += 0.08 * (noise - dull)
		samples[i] = (bright - dull) * level * 0.5
	var start: float = 0.0
	while start < LOOP_SECONDS + BLEND_SECONDS - 0.1:
		_add_gurgle(samples, start)
		start += _rng.randf_range(0.02, 0.08)
	return _normalize(samples, 0.45)


# A short tone sliding up: one bubble in running water.
func _add_gurgle(samples: PackedFloat32Array, start: float) -> void:
	var first: int = int(start * RATE)
	var length: int = int(_rng.randf_range(0.02, 0.05) * RATE)
	var from_hz: float = _rng.randf_range(300.0, 900.0)
	var rise: float = _rng.randf_range(1.6, 2.2)
	var gain: float = _rng.randf_range(0.1, 0.35)
	var phase: float = 0.0
	for i in length:
		if first + i >= samples.size():
			return
		var k: float = float(i) / length
		phase += TAU * lerpf(from_hz, from_hz * rise, k) / RATE
		samples[first + i] += sin(phase) * pow(sin(PI * k), 2.0) * gain


# Heavily low-passed noise with slow swells: wind.
func _wind() -> PackedFloat32Array:
	var samples := _loop_buffer()
	var low: float = 0.0
	for i in samples.size():
		var t: float = float(i) / RATE
		low += 0.015 * (_rng.randf_range(-1.0, 1.0) - low)
		samples[i] = low * (0.55 + 0.45 * sin(TAU * t / 4.5))
	return _normalize(samples, 0.5)


# A wet thump with a hiss that dulls quickly, then a few droplets: a tomato splatting.
func _splat() -> PackedFloat32Array:
	var samples := _empty(0.45)
	var phase: float = 0.0
	var low: float = 0.0
	for i in int(0.2 * RATE):
		var t: float = float(i) / RATE
		phase += TAU * lerpf(220.0, 60.0, t / 0.2) / RATE
		low += lerpf(0.6, 0.05, t / 0.2) * (_rng.randf_range(-1.0, 1.0) - low)
		samples[i] = (0.6 * sin(phase) + 0.9 * low) * exp(-t / 0.05) * minf(t / 0.002, 1.0)
	for drop in 4:
		var start: int = int(_rng.randf_range(0.08, 0.35) * RATE)
		var hz: float = _rng.randf_range(900.0, 1600.0)
		for i in int(0.03 * RATE):
			if start + i >= samples.size():
				break
			var t: float = float(i) / RATE
			samples[start + i] += sin(TAU * hz * (1.0 + t * 8.0) * t) * exp(-t / 0.008) * 0.15
	return _normalize(samples, 0.85)


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


# A soft breeze with a few low chimes at random times: a calm meadow.
func _chimes() -> PackedFloat32Array:
	var samples := _loop_buffer()
	var low: float = 0.0
	for i in samples.size():
		low += 0.01 * (_rng.randf_range(-1.0, 1.0) - low)
		samples[i] = low * 0.5
	var chime_hz: Array[float] = [261.63, 329.63, 392.0, 440.0]
	var start: float = 0.4
	while start < LOOP_SECONDS + BLEND_SECONDS - 1.5:
		_add_note(samples, chime_hz[_rng.randi_range(0, chime_hz.size() - 1)], start, 1.5, 0.12)
		start += _rng.randf_range(1.2, 2.4)
	return _normalize(samples, 0.4)


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


# Plays bars (see MENU_BARS) at beat seconds per note, each note ringing for ring seconds, with the
# low note every bass_every beats. The last notes ring past the end; _fold wraps that onto the start
# so the tune loops seamlessly.
func _tune(bars: Array, beat: float, ring: float, bass_every: int) -> PackedFloat32Array:
	var beats_per_bar: int = bars[0][1].size()
	var seconds: float = bars.size() * beats_per_bar * beat
	var samples := _empty(seconds + 2.0)
	for bar in bars.size():
		var start: float = bar * beats_per_bar * beat
		for hit in range(0, beats_per_bar, bass_every):
			_add_note(samples, _midi_hz(bars[bar][0]), start + hit * beat, bass_every * beat, 0.18)
		for b in beats_per_bar:
			var note: int = bars[bar][1][b]
			if note != 0:
				_add_note(samples, _midi_hz(note), start + b * beat, ring, 0.3)
	return _fold(_normalize(samples, 0.35), seconds)


func _midi_hz(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


# Cuts samples to seconds and adds what rang past the end onto the start, so the loop repeats as if
# it had always been playing.
func _fold(raw: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var length: int = int(seconds * RATE)
	var samples: PackedFloat32Array = raw.slice(0, length)
	for i in raw.size() - length:
		samples[i] += raw[length + i]
	return samples

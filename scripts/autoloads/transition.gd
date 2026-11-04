extends CanvasLayer

## Fades the screen to a dark cover and back around level changes and scene changes, ignoring
## taps while the cover is up.
##
## run() fades the cover in, calls an action and fades back out; change_scene() does the same
## around a scene change. Calls made while a fade is running are queued and run in order under the
## same cover. The game starts covered and fades in on launch, so the first scene change at boot
## happens under that cover without a second fade.

## Emitted after the cover has faded away and nothing is left in the queue.
signal finished

## Seconds for each half of a fade (cover in, then cover out).
@export var half_duration: float = 0.15
## Colour of the cover.
@export var cover_color: Color = Color(0.12, 0.08, 0.05)

## When false, run() and change_scene() act at once with no fade. Turning it off hides the cover,
## lets taps through and drops anything queued (tests run with it off).
var enabled: bool = true:
	set = _set_enabled
## Changes the scene for change_scene(); defaults to SceneTree.change_scene_to_file. Tests replace
## it with a stub so a scene change doesn't replace the test runner's scene.
var scene_changer: Callable

# Each entry is [action: Callable, wait_frame: bool]; wait_frame lets a new scene enter the tree
# before the cover fades away.
var _queue: Array[Array] = []
var _running: bool = false
# Bumped whenever fades are turned off, so a fade coroutine started before that stops when it wakes.
var _generation: int = 0
var _tween: Tween
var _cover: ColorRect


func _ready() -> void:
	layer = 100
	_cover = ColorRect.new()
	_cover.name = "Cover"
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.color = Color(cover_color, 1.0)
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_cover)
	scene_changer = get_tree().change_scene_to_file
	_running = true
	_launch()


## Fades the cover in (unless the screen is already covered), calls action, then fades back out.
## An action whose object has been freed by then is skipped.
func run(action: Callable) -> void:
	_enqueue(action, false)


## Fades the cover in (unless the screen is already covered), changes to the scene at path, waits a
## frame for it to enter the tree, then fades back out.
func change_scene(path: String) -> void:
	_enqueue(scene_changer.bind(path), true)


## Returns true while the cover is fully opaque.
func is_covering() -> bool:
	return _cover.visible and _cover.color.a >= 1.0


## Returns true while a fade is running or actions are still queued.
func is_busy() -> bool:
	return _running or not _queue.is_empty()


func _enqueue(action: Callable, wait_frame: bool) -> void:
	if not enabled:
		if action.is_valid():
			action.call()
		return
	_queue.append([action, wait_frame])
	if not _running:
		_drain()


# Boot changes scene in a deferred call, which can land after the first process_frame, so wait two
# frames before deciding there is nothing to run under the launch cover.
func _launch() -> void:
	var generation: int = _generation
	await get_tree().process_frame
	await get_tree().process_frame
	if generation != _generation:
		return
	_drain()


func _drain() -> void:
	var generation: int = _generation
	_running = true
	while true:
		while not _queue.is_empty():
			if not is_covering():
				await _fade_to(1.0)
				if generation != _generation:
					return
			var entry: Array = _queue.pop_front()
			var action: Callable = entry[0]
			if action.is_valid():
				action.call()
			if entry[1]:
				await get_tree().process_frame
				if generation != _generation:
					return
		await _fade_to(0.0)
		if generation != _generation:
			return
		if _queue.is_empty():
			break
	_running = false
	finished.emit()


func _fade_to(alpha: float) -> void:
	_cover.visible = true
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_tween = create_tween()
	_tween.tween_property(_cover, "color:a", alpha, half_duration)
	await _tween.finished
	if alpha <= 0.0:
		_hide_cover()


func _hide_cover() -> void:
	_cover.color.a = 0.0
	_cover.visible = false
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_enabled(value: bool) -> void:
	enabled = value
	if value:
		return
	_generation += 1
	if _tween:
		_tween.kill()
	_queue.clear()
	_running = false
	if _cover:
		_hide_cover()

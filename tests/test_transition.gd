extends GutTest

## Transition runs with fades off for the rest of the suite; these tests turn them on.

const _TIMEOUT := 2.0


class Recorder:
	extends Node

	func record(calls: Array) -> void:
		calls.append(name)


var _scene_changer: Callable
var _half_duration: float
var _scene_calls: Array = []


func before_each() -> void:
	_scene_changer = Transition.scene_changer
	_half_duration = Transition.half_duration
	_scene_calls = []
	Transition.scene_changer = func(path: String) -> void:
		_scene_calls.append([path, Transition.is_covering()])
	Transition.half_duration = 0.05
	Transition.enabled = true


func after_each() -> void:
	Transition.enabled = false
	Transition.scene_changer = _scene_changer
	Transition.half_duration = _half_duration


func _cover() -> ColorRect:
	return Transition.get_node("Cover")


func test_transition_disabled_runs_action_immediately() -> void:
	Transition.enabled = false
	var calls: Array = []
	Transition.run(func() -> void: calls.append(1))
	assert_eq(calls, [1])
	assert_false(Transition.is_busy())


func test_transition_run_covers_screen_before_calling_action() -> void:
	var covered_at_call: Array = []
	Transition.run(func() -> void: covered_at_call.append(Transition.is_covering()))
	assert_eq(covered_at_call, [], "the action waits for the cover")
	await wait_for_signal(Transition.finished, _TIMEOUT)
	assert_eq(covered_at_call, [true])


func test_transition_run_calls_action_once_then_uncovers_and_emits_finished() -> void:
	var calls: Array = []
	watch_signals(Transition)
	Transition.run(func() -> void: calls.append(1))
	await wait_for_signal(Transition.finished, _TIMEOUT)
	assert_eq(calls, [1])
	assert_signal_emit_count(Transition, "finished", 1)
	assert_false(Transition.is_covering())
	assert_false(_cover().visible)


func test_transition_blocks_input_only_while_covering() -> void:
	assert_eq(_cover().mouse_filter, Control.MOUSE_FILTER_IGNORE)
	Transition.run(func() -> void: pass)
	assert_eq(_cover().mouse_filter, Control.MOUSE_FILTER_STOP)
	await wait_for_signal(Transition.finished, _TIMEOUT)
	assert_eq(_cover().mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_transition_overlapping_runs_call_actions_in_order() -> void:
	var calls: Array = []
	Transition.run(func() -> void: calls.append("a"))
	Transition.run(func() -> void: calls.append("b"))
	await wait_for_signal(Transition.finished, _TIMEOUT)
	assert_eq(calls, ["a", "b"])


func test_transition_skips_action_whose_object_was_freed() -> void:
	var calls: Array = []
	var recorder := Recorder.new()
	Transition.run(recorder.record.bind(calls))
	recorder.free()
	await wait_for_signal(Transition.finished, _TIMEOUT)
	assert_eq(calls, [])


func test_transition_full_fade_is_under_half_a_second() -> void:
	Transition.half_duration = _half_duration
	var start: int = Time.get_ticks_msec()
	Transition.run(func() -> void: pass)
	await wait_for_signal(Transition.finished, _TIMEOUT)
	assert_lt(Time.get_ticks_msec() - start, 500)
	assert_lt(_half_duration * 2.0, 0.5)


func test_transition_disabling_hides_cover_and_lets_input_through() -> void:
	var calls: Array = []
	Transition.run(func() -> void: calls.append(1))
	await wait_frames(2)
	assert_true(_cover().visible)
	Transition.enabled = false
	assert_false(_cover().visible)
	assert_eq(_cover().mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_false(Transition.is_busy())
	await wait_seconds(0.2)
	assert_eq(calls, [], "a queued action is dropped")


func test_transition_change_scene_covers_then_calls_scene_changer_once() -> void:
	Transition.change_scene("res://scenes/ui/main_menu.tscn")
	await wait_for_signal(Transition.finished, _TIMEOUT)
	assert_eq(_scene_calls, [["res://scenes/ui/main_menu.tscn", true]])


func test_transition_change_scene_while_covered_does_not_fade_in_again() -> void:
	var lowest: Array = [1.0]
	var phase: Array = ["waiting"]
	Transition.scene_changer = func(_path: String) -> void: phase[0] = "changed"
	Transition.run(
		func() -> void:
			phase[0] = "covered"
			Transition.change_scene("res://scenes/ui/main_menu.tscn")
	)
	while Transition.is_busy():
		if phase[0] == "covered":
			lowest[0] = minf(lowest[0], _cover().color.a)
		await wait_frames(1)
	assert_eq(phase[0], "changed")
	assert_eq(lowest[0], 1.0, "the cover stays up between the two actions")


func test_transition_is_busy_until_queue_is_empty() -> void:
	assert_false(Transition.is_busy())
	Transition.run(func() -> void: pass)
	Transition.run(func() -> void: pass)
	assert_true(Transition.is_busy())
	await wait_for_signal(Transition.finished, _TIMEOUT)
	assert_false(Transition.is_busy())

extends GutHookScript

## Runs before the suite: turns fades off so level and scene changes happen at once, as the tests
## expect. test_transition.gd turns them back on per test.


func run() -> void:
	Transition.enabled = false

extends GutHookScript

## Runs before the suite: turns fades off so level and scene changes happen at once, as the tests
## expect (test_transition.gd turns them back on per test), and moves saves to a test file so the
## suite leaves the real save alone, with sound settings read from it.


func run() -> void:
	Transition.enabled = false
	SaveManager.save_path = "user://test_save.cfg"
	SaveManager.reload()
	AudioManager.apply_saved_settings()

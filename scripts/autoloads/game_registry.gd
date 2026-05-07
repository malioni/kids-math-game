extends Node

## Global registry for worlds and mechanics available in the game.
##
## Also handles the application quit flow. Because [member auto_accept_quit]
## is disabled in project settings, the OS quit request is routed here via
## [constant NOTIFICATION_WM_CLOSE_REQUEST] so the game can save state before
## exiting.

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

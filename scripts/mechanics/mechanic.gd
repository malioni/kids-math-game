class_name Mechanic
extends Node2D

## A puzzle a world can play. Each mechanic has its own setup() for its puzzle's shape; everything a
## world needs after that is here, so WorldBase can run any mechanic.

## Emitted when the player solves the puzzle.
signal correct
## Emitted when the player's answer is wrong.
signal incorrect


## Puts the current puzzle back to its start. Subclasses must override.
func reset() -> void:
	push_error("Mechanic: reset() not overridden")


## Enables or disables player input. Subclasses must override.
func set_interactive(_enabled: bool) -> void:
	push_error("Mechanic: set_interactive() not overridden")

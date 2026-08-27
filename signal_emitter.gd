class_name SignalEmitter
extends Area2D 

signal toggled(is_active: bool)

var is_active: bool = false

# Call this from your button/lever scripts whenever the state changes
func set_state(new_state: bool) -> void:
	if is_active != new_state:
		is_active = new_state
		toggled.emit(is_active)

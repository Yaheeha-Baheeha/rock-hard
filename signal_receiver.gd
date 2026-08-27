class_name SignalReceiver
extends Node2D 

@export var target_switch: SignalEmitter ## Drag your Button or Lever here!
@export var invert_signal: bool = false ## If true, an ON button turns this OFF.

var is_active: bool = false

func _ready() -> void:
	if target_switch:
		# Tell Godot to listen to the switch's 'toggled' signal
		target_switch.toggled.connect(_process_signal)
		
		# Grab the exact initial state right as the level loads
		_process_signal(target_switch.is_active)

func _process_signal(switch_state: bool) -> void:
	if invert_signal:
		is_active = !switch_state
	else:
		is_active = switch_state
		
	# Trigger the specific logic for whatever child class this is
	_on_state_changed()

# Virtual function meant to be overridden by your Spawners/Trapdoors
func _on_state_changed() -> void:
	pass

extends Node2D

## Emitted whenever the lever fully clicks to a new state.
signal toggled(is_active: bool)

@export_category("Lever Settings")
@export var activation_angle: float = 30.0 ## How many degrees the lever must be pushed to switch states
@export var lever_friction: float = 15.0 ## Higher number = heavier lever that stops moving quickly

@onready var switch_body = $Switch
@onready var base_body = $Base

# Assuming your lights have a PointLight2D as a child
@onready var green_light = $GreenLight/PointLight2D
@onready var red_light = $RedLight/PointLight2D

var is_active: bool = false

func _ready() -> void:
	# 1. Apply heavy friction/air resistance to the handle so it doesn't flop around
	if switch_body is RigidBody2D:
		switch_body.angular_damp = lever_friction
	
	# 2. Set the initial light states
	_update_visuals()

func _physics_process(_delta: float) -> void:
	# 1. Calculate the exact angle difference between the base and the handle
	# Using wrapf keeps the angle strictly between -180 and 180 degrees
	@warning_ignore("shadowed_global_identifier")
	var angle_difference = wrapf(rad_to_deg(switch_body.global_rotation - base_body.global_rotation), -180.0, 180.0)
	
	var previous_state = is_active
	
	# 2. Check if the lever has been pushed past the activation threshold
	if angle_difference > activation_angle:
		is_active = true
	elif angle_difference < -activation_angle:
		is_active = false
		
	# 3. If the state just changed this exact frame, trigger our logic!
	if is_active != previous_state:
		_update_visuals()
		toggled.emit(is_active)

func _update_visuals() -> void:
	if is_active:
		green_light.enabled = true
		red_light.enabled = false
	else:
		green_light.enabled = false
		red_light.enabled = true

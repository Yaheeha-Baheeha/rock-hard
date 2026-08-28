extends SignalEmitter

@export_category("Lever Settings")
@export var start_active: bool = false ## Check this to make the lever start in the ON position!
@export var activation_angle: float = 30.0 ## How many degrees the lever must be pushed to switch states
@export var lever_friction: float = 15.0 ## Higher number = heavier lever that stops moving quickly
@export var movement_threshold: float = 0.1 ## Velocity required to trigger movement audio

@onready var switch_body = $Switch
@onready var base_body = $Base

# Assuming your lights have a PointLight2D as a child
@onready var green_light = $GreenLight/PointLight2D
@onready var red_light = $RedLight/PointLight2D
@onready var lever_sound = $AudioStreamPlayer2D

func _ready() -> void:
	super._ready()
	
	# Apply heavy friction/air resistance to the handle so it doesn't flop around
	if switch_body is RigidBody2D:
		switch_body.angular_damp = lever_friction
		
	# --- AUTO-ADJUST STARTING ANGLE ---
	# We add 5 extra degrees so it sits safely past the threshold line
	var angle_offset = activation_angle + 5.0 
	
	if start_active:
		switch_body.global_rotation = base_body.global_rotation + deg_to_rad(angle_offset)
	else:
		switch_body.global_rotation = base_body.global_rotation - deg_to_rad(angle_offset)
	
	# Tell the parent script (and all connected receivers) what state we are starting in
	set_state(start_active)
	_update_visuals()

func _physics_process(_delta: float) -> void:
	# 1. Continuous movement sound handling
	if switch_body is RigidBody2D:
		var is_moving: bool = abs(switch_body.angular_velocity) > movement_threshold
		
		if is_moving and not lever_sound.playing:
			lever_sound.play()
		elif not is_moving and lever_sound.playing:
			lever_sound.stop()

	# 2. Angle calculation and state switching
	@warning_ignore("shadowed_global_identifier")
	var angle_difference = wrapf(rad_to_deg(switch_body.global_rotation - base_body.global_rotation), -180.0, 180.0)
	
	if angle_difference > activation_angle and not is_active:
		set_state(true)
		_update_visuals()
	elif angle_difference < -activation_angle and is_active:
		set_state(false)
		_update_visuals()

func _update_visuals() -> void:
	if is_active:
		green_light.enabled = true
		red_light.enabled = false
	else:
		green_light.enabled = false
		red_light.enabled = true

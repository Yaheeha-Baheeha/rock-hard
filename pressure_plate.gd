extends Node2D

signal toggled(is_active: bool)

# Adjust these threshold values in the Inspector to match your Switch's local Y position
@export var max_down_y: float = 120.0  # Local Y position when pressed fully down

var is_active: bool = false

@onready var switch: RigidBody2D = $Switch

func _process(_delta: float) -> void:
	# In Godot 2D, moving down increases the positive Y axis
	var previous_state = is_active
	if switch.position.y >= max_down_y:
		is_active = false
		print(false)
	else:
		is_active = true
		print(true)
	
	if is_active != previous_state:
		toggled.emit(is_active)

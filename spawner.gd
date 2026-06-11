extends Area2D

@export var water_drop_scene: PackedScene = preload("res://lava_drop.tscn")

@export_category("Spawner Settings")
@export var fluid_type: LavaDroplet.FluidType = LavaDroplet.FluidType.HOT ## Choose the fluid type!
@export var spawn_rate: float = 0.05 ## Time in seconds between spawns

@export_category("Direction & Speed")
@export_range(0, 360) var spawn_angle: float = 90.0 ## Direction in degrees (90 is straight down)
@export var angle_variance: float = 15.0 ## +/- spread of the angle
@export var spawn_speed: float = 300.0 ## How fast the droplet shoots out
@export var speed_variance: float = 50.0 ## +/- randomization of the speed

@onready var spawn_shape = $CollisionShape2D ## Grabs the collision shape to determine the region area
@onready var hot_fluid_group = $"../HotFluid"
@onready var medium_fluid_group = $"../MediumFluid"
@onready var cold_fluid_group = $"../ColdFluid"

var spawn_timer: float = 0.0

func _process(delta: float) -> void:
	# Keep the internal clock ticking
	spawn_timer += delta
	
	# Hold down Spacebar/Enter to emit water
	if Input.is_action_pressed("ui_accept"):
		# Only trigger the spawn if the cooldown time has been reached
		if spawn_timer >= spawn_rate:
			spawn_timer = 0.0 # Reset the clock
			spawn_drop()

func spawn_drop() -> void:
	# Instantiate and cast to our custom class
	var drop = water_drop_scene.instantiate() as LavaDroplet
	
	# 1. Set the fluid type chosen in the Inspector
	if drop != null:
		drop.type = fluid_type
	# Route the droplet to the correct CanvasGroup based on its type!
	match drop.type:
		LavaDroplet.FluidType.HOT:
			hot_fluid_group.add_child(drop)
		LavaDroplet.FluidType.MEDIUM:
			medium_fluid_group.add_child(drop)
		LavaDroplet.FluidType.COLD:
			cold_fluid_group.add_child(drop)
	
	# 2. Calculate random position inside the Area2D's RectangleShape2D
	var random_pos = global_position
	if spawn_shape and spawn_shape.shape is RectangleShape2D:
		var extents = spawn_shape.shape.size / 2.0
		var rand_x = randf_range(-extents.x, extents.x)
		var rand_y = randf_range(-extents.y, extents.y)
		random_pos += Vector2(rand_x, rand_y)
		
	drop.global_position = random_pos
	
	# 3. Calculate Velocity from Angle and Speed
	var final_angle = spawn_angle + randf_range(-angle_variance, angle_variance)
	var final_speed = spawn_speed + randf_range(-speed_variance, speed_variance)
	
	# Convert the angle to radians, rotate a baseline "RIGHT" vector, and multiply by speed
	var velocity_dir = Vector2.RIGHT.rotated(deg_to_rad(final_angle))
	drop.linear_velocity = velocity_dir * final_speed

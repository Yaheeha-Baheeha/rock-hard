extends Marker2D

@export var water_drop_scene: PackedScene = preload("res://water_drop.tscn")

@export_category("Spawner Settings")
@export var spawn_rate: float = 0.05 ## Time in seconds between spawns
@export var base_velocity: Vector2 = Vector2.ZERO ## The default directional push applied to the drop
@export var velocity_variance: Vector2 = Vector2(20.0, 0.0) ## How much random spread to add to the velocity

@onready var water_fluid_group = $"../WaterFluid"

var spawn_timer: float = 0.0

func _process(delta):
	# Keep the internal clock ticking
	spawn_timer += delta
	
	# Hold down Spacebar/Enter to emit water
	if Input.is_action_pressed("ui_accept"):
		# Only trigger the spawn if the cooldown time has been reached
		if spawn_timer >= spawn_rate:
			spawn_timer = 0.0 # Reset the clock
			spawn_drop()

func spawn_drop():
	var drop = water_drop_scene.instantiate()
	
	# Add the drop as a child of CanvasGroup so the shader acts on it
	water_fluid_group.add_child(drop)
	drop.global_position = global_position
	
	# Calculate random variation on both X and Y axes
	var random_x = randf_range(-velocity_variance.x, velocity_variance.x)
	var random_y = randf_range(-velocity_variance.y, velocity_variance.y)
	
	# Combine base velocity with the random variance
	drop.linear_velocity = base_velocity + Vector2(random_x, random_y)

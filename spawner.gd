extends Area2D

@export var water_drop_scene: PackedScene = preload("res://lava_drop.tscn")

# --- NEW: SPAWNER BEHAVIOR ---
enum SpawnMode { ALWAYS, TOGGLED }

@export_category("Spawner Settings")
@export var spawn_mode: SpawnMode = SpawnMode.ALWAYS ## Choose if it's always on or needs a lever!
@export var target_lever: Node2D ## Easily drag and drop your Lever node here!
@export var is_active: bool = false ## If set to TOGGLED, is it currently spraying?
@export var fluid_type: LavaDroplet.FluidType = LavaDroplet.FluidType.HOT ## Choose the fluid type!
@export var despawn_rule: LavaDroplet.DespawnRule = LavaDroplet.DespawnRule.NEVER ## Choose how it despawns!
@export var spawn_rate: float = 0.05 ## Time in seconds between spawns

@export_category("Direction & Speed")
@export_range(0, 360) var spawn_angle: float = 90.0 ## Direction in degrees (90 is straight down)
@export var angle_variance: float = 15.0 ## +/- spread of the angle
@export var spawn_speed: float = 300.0 ## How fast the droplet shoots out
@export var speed_variance: float = 50.0 ## +/- randomization of the speed

@onready var spawn_shape = $CollisionShape2D 
@onready var hot_fluid_group = $"../HotFluid"
@onready var medium_fluid_group = $"../MediumFluid"
@onready var cold_fluid_group = $"../ColdFluid"

var spawn_timer: float = 0.0

func _ready() -> void:
	# If a lever is assigned in the Inspector, connect its signal automatically
	if target_lever != null and target_lever.has_signal("toggled"):
		target_lever.toggled.connect(set_spawner_active)

func _process(delta: float) -> void:
	# 1. Check if we are allowed to spawn based on our mode
	var can_spawn: bool = false
	
	if spawn_mode == SpawnMode.ALWAYS:
		can_spawn = true
	elif spawn_mode == SpawnMode.TOGGLED and is_active:
		can_spawn = true
		
	# 2. If allowed, run the timer and spawn
	if can_spawn:
		spawn_timer += delta
		if spawn_timer >= spawn_rate:
			spawn_timer = 0.0 
			spawn_drop()
	else:
		# Reset timer when turned off so it spawns instantly when turned back on
		spawn_timer = spawn_rate 

func spawn_drop() -> void:
	var drop = water_drop_scene.instantiate() as LavaDroplet
	
	if drop != null:
		drop.type = fluid_type
		drop.despawn_rule = despawn_rule
		
		match drop.type:
			LavaDroplet.FluidType.HOT:
				hot_fluid_group.add_child(drop)
			LavaDroplet.FluidType.MEDIUM:
				medium_fluid_group.add_child(drop)
			LavaDroplet.FluidType.COLD:
				cold_fluid_group.add_child(drop)
		
		var random_pos = global_position
		if spawn_shape and spawn_shape.shape is RectangleShape2D:
			var extents = spawn_shape.shape.size / 2.0
			var rand_x = randf_range(-extents.x, extents.x)
			var rand_y = randf_range(-extents.y, extents.y)
			random_pos += Vector2(rand_x, rand_y)
			
		drop.global_position = random_pos
		
		var final_angle = spawn_angle + randf_range(-angle_variance, angle_variance)
		var final_speed = spawn_speed + randf_range(-speed_variance, speed_variance)
		
		var velocity_dir = Vector2.RIGHT.rotated(deg_to_rad(final_angle))
		drop.linear_velocity = velocity_dir * final_speed

# --- NEW: LEVER FUNCTIONS ---
# Your lever node can call these functions when it gets flipped!

## Toggles the spawner on and off
func toggle_spawner() -> void:
	is_active = !is_active

## Explicitly turns the spawner on or off (great for one-way switches)
func set_spawner_active(state: bool) -> void:
	is_active = state

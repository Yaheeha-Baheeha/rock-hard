extends Area2D

@export var water_drop_scene: PackedScene = preload("res://lava_drop.tscn")

@export_category("Spawner Settings")
@export var spawn_when_lever_on: bool = true ## If true, lava spawns when the lever is on; if false, it spawns when the lever is off.
@export var target_lever: Node2D ## Easily drag and drop your Lever node here!
@export var is_active: bool = false ## Current spawn state when a lever is connected.
@export var fluid_type: LavaDroplet.FluidType = LavaDroplet.FluidType.HOT ## Choose the fluid type!
@export var despawn_rule: LavaDroplet.DespawnRule = LavaDroplet.DespawnRule.NEVER ## Choose how it despawns!
@export var lava_melts_corpses: bool = true ## Toggle whether this spawner's lava melts corpses!
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
	if target_lever != null and target_lever.has_signal("toggled"):
		target_lever.toggled.connect(set_spawner_active)
		is_active = _is_spawn_enabled_for_lever(target_lever.is_active)

func _process(delta: float) -> void:
	var can_spawn: bool = target_lever == null or is_active
		
	if can_spawn:
		spawn_timer += delta
		if spawn_timer >= spawn_rate:
			spawn_timer = 0.0 
			spawn_drop()
	else:
		spawn_timer = spawn_rate 

func spawn_drop() -> void:
	var drop = water_drop_scene.instantiate() as LavaDroplet
	
	if drop != null:
		drop.type = fluid_type
		drop.despawn_rule = despawn_rule
		drop.can_melt_corpses = lava_melts_corpses
		
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
		

func toggle_spawner() -> void:
	is_active = !is_active

func set_spawner_active(state: bool) -> void:
	is_active = _is_spawn_enabled_for_lever(state)

func _is_spawn_enabled_for_lever(lever_is_active: bool) -> bool:
	return lever_is_active == spawn_when_lever_on

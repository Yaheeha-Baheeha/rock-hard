extends SignalReceiver

@export var water_drop_scene: PackedScene = preload("res://lava_drop.tscn")

@export_category("Spawner Settings")
@export var auto_spawn: bool = false ## Check this if you want lava to pour without needing a button!
@export var fluid_type: LavaDroplet.FluidType = LavaDroplet.FluidType.HOT 
@export var despawn_rule: LavaDroplet.DespawnRule = LavaDroplet.DespawnRule.NEVER 
@export var lava_melts_corpses: bool = true 
@export var spawn_rate: float = 0.05 

@export_category("Direction & Speed")
@export_range(0, 360) var spawn_angle: float = 90.0 
@export var angle_variance: float = 15.0 
@export var spawn_speed: float = 300.0 
@export var speed_variance: float = 50.0 

@onready var spawn_shape = $CollisionShape2D 
@onready var hot_fluid_group = $"../HotFluid"
@onready var medium_fluid_group = $"../MediumFluid"
@onready var cold_fluid_group = $"../ColdFluid"

var spawn_timer: float = 0.0

func _ready() -> void:
	# Call the parent class so it sets up the shader outline material!
	super._ready()
	
	# If auto_spawn is enabled, add itself as a permanent active emitter
	if auto_spawn:
		active_emitters[self] = true
	
	# Evaluate the initial active state based on the emitters dictionary
	is_active = (active_emitters.size() % 2 == 1)

func _process(delta: float) -> void:
	if is_active:
		spawn_timer += delta
		if spawn_timer >= spawn_rate:
			spawn_timer = 0.0 
			spawn_drop()
	else:
		# Keep the timer primed so it instantly fires when activated
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

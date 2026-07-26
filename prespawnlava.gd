extends Area2D

@export var water_drop_scene: PackedScene = preload("res://lava_drop.tscn")

@export_category("Pool Settings")
@export var particle_count: int = 100 ## How many fluid particles to instantly spawn
@export var fluid_type: LavaDroplet.FluidType = LavaDroplet.FluidType.HOT ## Choose the fluid type!
@export var despawn_rule: LavaDroplet.DespawnRule = LavaDroplet.DespawnRule.NEVER ## Choose how it despawns

@onready var spawn_shape = $CollisionShape2D 

# Ensure these paths match your scene structure!
@onready var hot_fluid_group = $"../HotFluid"
@onready var medium_fluid_group = $"../MediumFluid"
@onready var cold_fluid_group = $"../ColdFluid"

func _ready() -> void:
	# As soon as the level loads, fill the pool!
	_spawn_fluid_pool()

func _spawn_fluid_pool() -> void:
	# 1. Safety check to ensure we have a shape to spawn inside of
	if not spawn_shape or not spawn_shape.shape is RectangleShape2D:
		push_warning("LavaPool requires a CollisionShape2D with a RectangleShape2D to work!")
		return
		
	var extents = spawn_shape.shape.size / 2.0
	
	# 2. Loop through and spawn the exact number of particles requested
	for i in range(particle_count):
		var drop = water_drop_scene.instantiate() as LavaDroplet
		
		if drop != null:
			drop.type = fluid_type
			drop.despawn_rule = despawn_rule
			
			# 3. Pick a random X and Y coordinate strictly inside the RectangleShape2D
			var rand_x = randf_range(-extents.x, extents.x)
			var rand_y = randf_range(-extents.y, extents.y)
			drop.global_position = global_position + Vector2(rand_x, rand_y)
			
			# 4. Give the droplet a tiny bit of random initial velocity so they don't spawn perfectly still and stack weirdly
			drop.linear_velocity = Vector2(randf_range(-10, 10), randf_range(-10, 10))
			
			# 5. Add to the correct CanvasGroup for rendering
			match drop.type:
				LavaDroplet.FluidType.HOT:
					if hot_fluid_group: hot_fluid_group.add_child(drop)
				LavaDroplet.FluidType.MEDIUM:
					if medium_fluid_group: medium_fluid_group.add_child(drop)
				LavaDroplet.FluidType.COLD:
					if cold_fluid_group: cold_fluid_group.add_child(drop)

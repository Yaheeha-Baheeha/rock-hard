extends Area2D

@export var water_drop_scene: PackedScene = preload("res://lava_drop.tscn")

@export_category("Pool Settings")
@export var particle_count: int = 100
@export var fluid_type: LavaDroplet.FluidType = LavaDroplet.FluidType.HOT
@export var despawn_rule: LavaDroplet.DespawnRule = LavaDroplet.DespawnRule.NEVER
@export var lava_melts_corpses: bool = true
@export var collide_with_corpses: bool = true
@export_range(1, 32) var corpse_physics_layer: int = 4

@onready var spawn_shape: CollisionShape2D = $CollisionShape2D 

@onready var hot_fluid_group = get_node_or_null("../HotFluid")
@onready var medium_fluid_group = get_node_or_null("../MediumFluid")
@onready var cold_fluid_group = get_node_or_null("../ColdFluid")

func _ready() -> void:
	# Connect boundary exit signals
	body_exited.connect(_on_node_exited_area)
	area_exited.connect(_on_node_exited_area)
	call_deferred("_spawn_fluid_pool")

func _on_node_exited_area(node: Node) -> void:
	# Delete the droplet when it leaves the Area2D bounds
	if node is LavaDroplet or "despawn_rule" in node:
		node.queue_free()

func _spawn_fluid_pool() -> void:
	if water_drop_scene == null:
		push_error("LavaPool: water_drop_scene is not assigned!")
		return
		
	if not spawn_shape or not spawn_shape.shape is RectangleShape2D:
		push_error("LavaPool: Requires a CollisionShape2D child with a RectangleShape2D!")
		return
		
	var rect_shape = spawn_shape.shape as RectangleShape2D
	var shape_size = rect_shape.size
	var extents = shape_size / 2.0
	
	var aspect_ratio: float = shape_size.x / max(shape_size.y, 0.001)
	var cols: int = int(ceil(sqrt(particle_count * aspect_ratio)))
	var rows: int = int(ceil(float(particle_count) / float(max(cols, 1))))
	
	var step_x: float = shape_size.x / max(cols, 1)
	var step_y: float = shape_size.y / max(rows, 1)
	
	var spawned_count: int = 0
	
	for r in range(rows):
		for c in range(cols):
			if spawned_count >= particle_count:
				break
				
			var drop = water_drop_scene.instantiate() as LavaDroplet
			if drop != null:
				drop.type = fluid_type
				drop.despawn_rule = despawn_rule
				drop.can_melt_corpses = lava_melts_corpses
				
				if not collide_with_corpses:
					drop.set_collision_mask_value(corpse_physics_layer, false)
				
				var local_x = -extents.x + (c + 0.5) * step_x
				var local_y = -extents.y + (r + 0.5) * step_y
				
				_assign_parent_group(drop)
				drop.global_position = spawn_shape.to_global(Vector2(local_x, local_y))
				drop.linear_velocity = Vector2.ZERO
				
			spawned_count += 1

func _assign_parent_group(drop: Node) -> void:
	var target_parent: Node = null
	
	match drop.type:
		LavaDroplet.FluidType.HOT:
			target_parent = hot_fluid_group
		LavaDroplet.FluidType.MEDIUM:
			target_parent = medium_fluid_group
		LavaDroplet.FluidType.COLD:
			target_parent = cold_fluid_group

	if target_parent != null:
		target_parent.add_child(drop)
	else:
		get_tree().current_scene.add_child(drop)

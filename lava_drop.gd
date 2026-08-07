class_name LavaDroplet
extends RigidBody2D

# --- FLUID TYPES & BEHAVIORS ---
enum FluidType { HOT, MEDIUM, COLD }
@export var type: FluidType = FluidType.HOT

enum DespawnRule { NEVER, ON_GROUND, ON_FALL, ON_CORPSE_OR_GROUND }
@export var despawn_rule: DespawnRule = DespawnRule.NEVER

# The variable the player will read to take damage
var damage_rate: float = 0.0
var is_despawning: bool = false # Tracks if it's currently melting

# --- SPH PHYSICS VARIABLES ---
@export var target_density: float = 1.0
@export var smoothing_radius: float = 45.0

# These will be overwritten in _ready() based on the fluid type
var repulsion_strength: float = 800.0
var viscosity: float = 0.45 
var cohesion_strength: float = 30.0 
var max_speed: float = 6000000.0 

@onready var neighbor_detector = $NeighborDetector
@onready var sprite = $Sprite2D
@onready var radius_squared: float = smoothing_radius * smoothing_radius

func _ready() -> void:
	# Force the engine to report what this body is touching
	contact_monitor = true
	max_contacts_reported = 5
	
	match type:
		FluidType.HOT:
			modulate = Color(1.0, 0.2, 0.0) # Bright Red
			damage_rate = 1000.0 # Kills very fast
			repulsion_strength = 4000.0
			viscosity = 0.05 
			cohesion_strength = 5.0
			max_speed = 8000000000000000.0
			
		FluidType.MEDIUM:
			modulate = Color(1.0, 0.6, 0.0) # Orange
			damage_rate = 360.0 # Standard kill time
			repulsion_strength = 2000.0
			viscosity = 0.5
			cohesion_strength = 50.0
			max_speed = 900000.0
			
		FluidType.COLD:
			modulate = Color(0.4, 0.4, 0.4) # Dark Grey Crust
			damage_rate = 300.0 # Kills slowly
			repulsion_strength = 1000.0
			viscosity = 0.15 
			cohesion_strength = 50.0
			max_speed = 300000.0

func _physics_process(delta: float) -> void:
	# 1. Only check for despawn rules if we aren't already shrinking
	if not is_despawning:
		_handle_despawning()
		
	# Optimization: Throttling stationary lava (resting pools don't need CPU)
	if linear_velocity.length_squared() < 2.0 and Engine.get_physics_frames() % 5 != 0:
		return

	var neighbors = neighbor_detector.get_overlapping_bodies()
	var density: float = 0.0
	var push_vector := Vector2.ZERO
	var avg_velocity := Vector2.ZERO
	var center_of_mass := Vector2.ZERO
	var valid_neighbor_count: float = 0.0
	
	for neighbor in neighbors:
		if neighbor == self: 
			continue
			
		var dist_sq = global_position.distance_squared_to(neighbor.global_position)
		
		if dist_sq < radius_squared:
			var overlap_factor = 1.0 - (dist_sq / radius_squared)
			density += overlap_factor
			
			if dist_sq > 0.1:
				var dir = (global_position - neighbor.global_position).normalized()
				push_vector += dir * overlap_factor
				
				avg_velocity += neighbor.linear_velocity
				center_of_mass += neighbor.global_position
				valid_neighbor_count += 1.0

	# Apply Sludge Repulsion (Pressure)
	if density > target_density:
		var pressure = (density - target_density) * repulsion_strength
		var acceleration = push_vector * pressure * delta
		acceleration = acceleration.limit_length(300.0)
		linear_velocity += acceleration

	# Apply Extreme Viscosity and Cohesion (The Sludge Effect)
	if valid_neighbor_count > 0.0:
		avg_velocity /= valid_neighbor_count
		center_of_mass /= valid_neighbor_count
		
		linear_velocity = linear_velocity.lerp(avg_velocity, viscosity)
		
		var to_center = global_position.direction_to(center_of_mass)
		var dist_to_center = global_position.distance_to(center_of_mass)
		linear_velocity += to_center * (dist_to_center * cohesion_strength) * delta
		
	linear_velocity = linear_velocity.limit_length(max_speed)

# --- DESPAWN LOGIC ---
func _handle_despawning() -> bool:
	if despawn_rule == DespawnRule.NEVER:
		return false
		
	if despawn_rule == DespawnRule.ON_FALL and linear_velocity.y > 50.0:
		_start_despawn_animation()
		return true

	var touching_ground = false
	var touching_corpse = false
	
	for body in get_colliding_bodies():
		if body is TileMapLayer or body.is_in_group("ground"):
			touching_ground = true
		
		if body.is_in_group("corpse"):
			touching_corpse = true

	match despawn_rule:
		DespawnRule.ON_GROUND:
			if touching_ground:
				_start_despawn_animation()
				return true
				
		DespawnRule.ON_CORPSE_OR_GROUND:
			if touching_corpse or touching_ground:
				_start_despawn_animation()
				return true
				
	return false

func _start_despawn_animation() -> void:
	is_despawning = true
	
	# Smoothly shrink the VISUAL SPRITE ONLY! 
	# Leaving the RigidBody2D untouched lets the physics keep flowing perfectly.
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(queue_free) 

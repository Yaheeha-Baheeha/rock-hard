class_name LavaDroplet
extends RigidBody2D

# --- FLUID TYPES ---
enum FluidType { HOT, MEDIUM, COLD }
@export var type: FluidType = FluidType.HOT

# The variable the player will read to take damage
var damage_rate: float = 0.0

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
	match type:
		FluidType.HOT:
			modulate = Color(1.0, 0.2, 0.0) # Bright Red
			damage_rate = 240.0 # Kills very fast
			
			# Physics: Acts like boiling water. Fast, low cohesion, flows everywhere.
			repulsion_strength = 4000.0
			viscosity = 0.05 
			cohesion_strength = 5.0
			max_speed = 8000000000000000.0
			
		FluidType.MEDIUM:
			modulate = Color(1.0, 0.6, 0.0) # Orange
			damage_rate = 120.0 # Standard kill time
			
			# Physics: Standard lava. Thicker, clumps together nicely.
			repulsion_strength = 2000.0
			viscosity = 0.2
			cohesion_strength = 30.0
			max_speed = 500.0
			
		FluidType.COLD:
			modulate = Color(0.4, 0.4, 0.4) # Dark Grey Crust
			damage_rate = 60.0 # Kills slowly
			
			# Physics: Pure sludge. Aggressively matches speeds and clumps tightly. Barely moves.
			repulsion_strength = 1000.0
			viscosity = 0.15 
			cohesion_strength = 50.0
			max_speed = 150.0

func _physics_process(delta: float) -> void:
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
				# Lower distance bias in repulsion makes it spread slower
				push_vector += dir * overlap_factor
				
				avg_velocity += neighbor.linear_velocity
				center_of_mass += neighbor.global_position
				valid_neighbor_count += 1.0

	# 1. Apply Sludge Repulsion (Pressure)
	if density > target_density:
		var pressure = (density - target_density) * repulsion_strength
		var acceleration = push_vector * pressure * delta
		# Limit length to prevent explosion spikes
		acceleration = acceleration.limit_length(300.0)
		linear_velocity += acceleration

	# 2. Apply Extreme Viscosity and Cohesion (The Sludge Effect)
	if valid_neighbor_count > 0.0:
		avg_velocity /= valid_neighbor_count
		center_of_mass /= valid_neighbor_count
		
		# Viscosity: Turn movement into syrup based on fluid type
		linear_velocity = linear_velocity.lerp(avg_velocity, viscosity)
		
		# Cohesion: Pull intensely toward stream center based on fluid type
		var to_center = global_position.direction_to(center_of_mass)
		var dist_to_center = global_position.distance_to(center_of_mass)
		linear_velocity += to_center * (dist_to_center * cohesion_strength) * delta
		
	linear_velocity = linear_velocity.limit_length(max_speed)

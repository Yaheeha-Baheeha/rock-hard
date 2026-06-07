extends RigidBody2D

@export var repulsion_strength: float = 800.0 ## Lowered: Lava compresses easily
@export var target_density: float = 1.0
@export var smoothing_radius: float = 45.0
@export var viscosity: float = 0.45 ## MAXED: Particles now aggressively match speeds (looks like sludge)
@export var cohesion_strength: float = 30.0 ## HIGHER: Strong surface tension keeps the sludge stream locked together
@export var max_speed: float = 600.0 ## The absolute maximum speed the droplet can travel
@onready var neighbor_detector = $NeighborDetector
@onready var sprite = $Sprite2D
@onready var radius_squared: float = smoothing_radius * smoothing_radius

func _physics_process(delta):
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
		
		# Viscosity: Turn movement into syrup
		linear_velocity = linear_velocity.lerp(avg_velocity, viscosity)
		
		# Cohesion: Pull intensely toward stream center
		var to_center = global_position.direction_to(center_of_mass)
		var dist_to_center = global_position.distance_to(center_of_mass)
		linear_velocity += to_center * (dist_to_center * cohesion_strength) * delta
	linear_velocity = linear_velocity.limit_length(max_speed)

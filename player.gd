extends Node2D

@export_category("Softbody Configuration")
@export var radius: float = 48.0
@export var num_points: int = 32
@export var target_pressure: float = 16000.0 
@export var spring_stiffness: float = 40000.0
@export var spring_damping: float = 1000.0 
@export var global_drag: float = 0.99 

@export_category("Engine Stability")
@export var sub_steps: int = 32 # Divides the frame into micro-frames

@export_category("Texture")
@export var texture: Texture2D 
@export var texture_tint: Color = Color.WHITE

@export_category("Controls Configuration")
@export var move_force: float = 1200.0
@export var max_speed: float = 600.0 
@export var jump_strength: float = 550.0 
@export var crouch_strength: float = 1500.0 

@export_category("Obstacles")
@export var obstacle_markers: Array[Node2D]

# --- NEW: DAMAGE CONFIGURATION ---
@export_category("Damage System")
@export var max_health: float = 100.0
@export var lava_damage_rate: float = 40.0 ## Health lost per second while touching lava
@export var cooling_rate: float = 20.0 ## Health regained per second when safe
@export var damage_color: Color = Color(0.0, 1.0, 0.0, 1.0) ## Pure red

@onready var soft_body = $SoftBodySphere
@onready var center_tracker = $CenterTracker

# Make sure to add an Area2D named "LavaDetector" as a child of CenterTracker!
@onready var lava_detector = $CenterTracker/LavaDetector 

var current_health: float
var base_color: Color

func _ready() -> void:
	# Initialize health and save the original safe color
	current_health = max_health
	base_color = texture_tint
	
	if soft_body:
		soft_body.radius = radius
		soft_body.num_points = num_points
		soft_body.target_pressure = target_pressure
		soft_body.spring_stiffness = spring_stiffness
		soft_body.spring_damping = spring_damping
		soft_body.global_drag = global_drag
		soft_body.sub_steps = sub_steps
		soft_body.texture = texture
		soft_body.texture_tint = texture_tint
		soft_body.move_force = move_force
		soft_body.max_speed = max_speed
		soft_body.jump_strength = jump_strength
		soft_body.crouch_strength = crouch_strength
		soft_body.obstacle_markers = obstacle_markers
		soft_body.initialize()

func _physics_process(delta: float) -> void:
	if soft_body:
		var center = Vector2.ZERO
		if soft_body.points.size() > 0:
			for p in soft_body.points:
				center += p.position
			center /= soft_body.points.size()
		else:
			center = soft_body.position
			
		if center_tracker:
			center_tracker.position = center
			
		# --- NEW: RUN DAMAGE LOGIC ---
		_process_lava_damage(delta)

# --- NEW: DAMAGE LOGIC FUNCTION ---
func _process_lava_damage(delta: float) -> void:
	if not lava_detector: 
		return
		
	var is_touching_lava = false
	var highest_damage_taken = 0.0
	
	# Check all overlapping bodies to find the most dangerous droplet we are touching
	for body in lava_detector.get_overlapping_bodies():
		if body is LavaDroplet:
			is_touching_lava = true
			# If we are touching multiple drops, take damage from the deadliest one
			if body.damage_rate > highest_damage_taken:
				highest_damage_taken = body.damage_rate
			
	# Apply damage or healing
	if is_touching_lava:
		current_health -= highest_damage_taken * delta
	else:
		current_health += cooling_rate * delta
		
	# Keep health locked between 0 and Max
	current_health = clamp(current_health, 0.0, max_health)
	
	# Calculate a percentage from 0.0 (full health) to 1.0 (dead)
	var damage_percent = 1.0 - (current_health / max_health)
	
	# Smoothly transition the tint towards red based on damage percentage
	soft_body.texture_tint = base_color.lerp(damage_color, damage_percent)
	
	# Check for death
	if current_health <= 0.0:
		_die()

func _die() -> void:
	# 1. Spawn the corpse right before we reset the player's softbody
	_spawn_corpse()
	
	# 2. Reset health, reset color, and fire your respawn logic
	current_health = max_health
	soft_body.texture_tint = base_color

	# Note: Replace Vector2.ZERO with your actual spawn point variable
	respawn($"../RespawnPoint".position)

# --- POLYGON SMOOTHING (CHAIKIN'S ALGORITHM) ---
func _smooth_polygon(poly: PackedVector2Array, iterations: int = 1) -> PackedVector2Array:
	var current_poly = poly
	
	for i in range(iterations):
		var smoothed = PackedVector2Array()
		var count = current_poly.size()
		
		for j in range(count):
			var p1 = current_poly[j]
			var p2 = current_poly[(j + 1) % count] 
			
			var q = p1.lerp(p2, 0.25)
			var r = p1.lerp(p2, 0.75)
			
			smoothed.append(q)
			smoothed.append(r)
			
		current_poly = smoothed
		
	return current_poly

# --- SPAWN CORPSE ---
func _spawn_corpse() -> void:
	if not soft_body or soft_body.points.size() < 3:
		return
		
	# 1. Get the exact shape of the blob right as it dies
	var raw_global_poly = soft_body.get_current_polygon_global()
	
	# 2. Smooth out the jagged physics spikes 
	# (Change '2' to '1' if it looks too round, or '3' if it's still spiky)
	var global_poly = _smooth_polygon(raw_global_poly, 2)
	
	# 3. Find the mathematical center (Centroid) so it rotates properly
	var centroid = Vector2.ZERO
	for pt in global_poly:
		centroid += pt
	centroid /= global_poly.size()
	
	# 4. Convert the global points to local points around that centroid
	var local_poly = PackedVector2Array()
	for pt in global_poly:
		local_poly.append(pt - centroid)
		
	# 5. Create the RigidBody2D container
	var corpse = RigidBody2D.new()
	corpse.add_to_group("corpse")
	
	# Detach the corpse completely from the player's movement
	corpse.top_level = true 
	
	corpse.global_position = centroid
	corpse.mass = 5.0 # Give it some weight to settle on the ground
	
	# 6. Create the physical collision shape
	var coll_shape = CollisionPolygon2D.new()
	coll_shape.polygon = local_poly
	corpse.add_child(coll_shape)
	
	# 7. Create the visual representation
	var visual = Polygon2D.new()
	visual.polygon = local_poly
	visual.color = damage_color # Tint it red (or whatever your color variable is)
	corpse.add_child(visual)
	
	# 8. Safely drop it into the absolute root of the level, ignoring the player tree
	get_tree().current_scene.call_deferred("add_child", corpse)

func respawn(target_position: Vector2) -> void:
	global_position = target_position
	
	if soft_body:
		soft_body.respawn(Vector2.ZERO)

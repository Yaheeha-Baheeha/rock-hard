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
@export var damage_color: Color = Color(1.0, 0.0, 0.0, 1.0) ## Pure red

@onready var soft_body = $SoftBodySphere
@onready var center_tracker = $CenterTracker

# --- NEW: LAVA DETECTOR REFERENCE ---
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
	# Reset health, reset color, and fire your respawn logic
	current_health = max_health
	soft_body.texture_tint = base_color
	
	# Note: Replace Vector2.ZERO with your actual spawn point variable
	respawn(Vector2.ZERO) 

func respawn(target_position: Vector2) -> void:
	global_position = target_position
	if soft_body:
		soft_body.respawn(Vector2.ZERO)

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

@onready var soft_body = $SoftBodySphere
@onready var center_tracker = $CenterTracker

func _ready() -> void:
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

func respawn(target_position: Vector2) -> void:
    global_position = target_position
    if soft_body:
        soft_body.respawn(Vector2.ZERO)


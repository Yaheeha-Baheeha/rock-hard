extends Area2D
class_name StaticLavaLake

@export_category("Lake Settings")
@export var damage_rate: float = 20.0 ## How much damage per second this lake deals
@export var viscosity: float = 0.85 ## How much it slows down objects (1.0 = no slowdown, lower = thicker)
@export var buoyancy_force: float = 2500.0 ## How hard it pushes upward

@export_category("Visuals")
@export var splash_scene: PackedScene ## Drag a GPUParticles2D saved scene here!

@onready var shape = $CollisionShape2D

func _ready() -> void:
	# Connect the signal through code so it detects when standard bodies fall in
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Trigger a splash when a physics body falls in!
	_create_splash_at(body.global_position.x)

## Call this to manually trigger a splash (useful for your custom soft body!)
func trigger_splash(x_position: float) -> void:
	_create_splash_at(x_position)

func _create_splash_at(x_position: float) -> void:
	if splash_scene == null or not shape or not shape.shape is RectangleShape2D:
		return
		
	# Find the exact Y-coordinate of the top of the lava lake
	var extents = shape.shape.size / 2.0
	var surface_y = global_position.y - extents.y
	
	# Instantiate the splash particles
	var splash = splash_scene.instantiate() as Node2D
	add_child(splash)
	
	# Move the splash to the surface of the lake, matching the X position of the object
	splash.global_position = Vector2(x_position, surface_y)
	
	# Optional: If your splash is a GPUParticles2D, tell it to emit and free itself when done
	if splash is GPUParticles2D:
		splash.emitting = true
		get_tree().create_timer(splash.lifetime).timeout.connect(splash.queue_free)

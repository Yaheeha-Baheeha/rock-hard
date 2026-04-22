extends Node2D

class_name LavaSystem

# Hybrid lava system: GPUParticles2D for visuals + collision zones for gameplay

@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var lava_surface: StaticBody2D = $LavaSurface
@onready var damage_zone: Area2D = $DamageZone

signal player_touched_lava

func _ready():
	setup_particles()
	setup_surface()
	setup_damage_zone()
	
	# Connect damage zone signals
	damage_zone.body_entered.connect(_on_damage_zone_entered)
	damage_zone.area_entered.connect(_on_damage_zone_entered)

func setup_particles():
	"""Configure the particle system for lava flow"""
	particles.emitting = true
	particles.amount = 200
	particles.lifetime = 4.0
	
	var material = ParticleProcessMaterial.new()
	material.emission_shape = 3  # BOX/RECTANGLE: emits from a box volume
	material.emission_box_extents = Vector3(80, 10, 1)
	material.spread = 15.0
	material.gravity = Vector3(0, 250, 0)
	material.initial_velocity_min = 30.0
	material.initial_velocity_max = 80.0
	material.angular_velocity_min = -5.0
	material.angular_velocity_max = 5.0
	material.scale_min = 0.8
	material.scale_max = 1.5
	material.color = Color(1.0, 0.3, 0.0, 0.9)
	
	# Add color ramp for fade out effect
	var ramp = Gradient.new()
	ramp.colors = [Color(1, 0.8, 0, 1), Color(1, 0.2, 0, 0.3)]
	ramp.offsets = [0.0, 1.0]
	material.color_ramp = ramp
	
	# Add damping to slow down particles
	material.linear_accel_min = -20.0
	material.linear_accel_max = 20.0
	
	particles.process_material = material
	particles.texture = preload("res://Textures/Lava/fall/lavafall_00.png")

func setup_surface():
	"""Setup collision surface for lava pool"""
	# The surface is already in the scene tree with collision shapes
	# This just ensures it's properly configured
	lava_surface.collision_layer = 1
	lava_surface.collision_mask = 0  # Only for visual collision, not physics

func setup_damage_zone():
	"""Setup invisible damage zone where lava is deadly"""
	damage_zone.collision_layer = 2
	damage_zone.collision_mask = 1  # Detect player (should be on layer 1)
	damage_zone.monitoring = true
	damage_zone.monitorable = true

func _on_damage_zone_entered(area_or_body: Node2D):
	"""Handle when something enters the lava damage zone"""
	print("Damage zone touched by: ", area_or_body.name)
	# Check if it's the player (Node2D is the player instance)
	if area_or_body.name == "Node2D" or area_or_body.is_in_group("player"):
		emit_signal("player_touched_lava")
		print("Player touched lava!")

func set_emission_enabled(enabled: bool):
	"""Control particle emission"""
	particles.emitting = enabled

func create_splash(position: Vector2, force: float = 100.0):
	"""Create a splash effect at a specific position"""
	var splash_particles = particles.duplicate()
	splash_particles.global_position = position
	splash_particles.one_shot = true
	splash_particles.explosiveness = 0.5
	add_child(splash_particles)
	splash_particles.emitting = true
	
	# Clean up after particles finish
	await get_tree().create_timer(splash_particles.lifetime).timeout
	splash_particles.queue_free()

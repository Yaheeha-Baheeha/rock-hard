extends Node2D

class_name LavaSystem

# Hybrid lava system: GPUParticles2D for visuals + collision zones for gameplay

@onready var lava_surface: StaticBody2D = $LavaSurface
@onready var damage_zone: Area2D = $DamageZone
@onready var physical_particles_holder: Node2D = $PhysicalParticles

@export var physical_emission_rate: float = 400.0
@export var physical_particle_lifetime: float = 5.0
@export var physical_particle_size: Vector2 = Vector2(5, 5)
@export var physical_particle_max: int = 2000

var _physical_spawn_accumulator: float = 0.0

signal player_touched_lava

func _ready():
	setup_surface()
	setup_damage_zone()
	
	# Connect damage zone signals
	damage_zone.body_entered.connect(_on_damage_zone_entered)
	damage_zone.area_entered.connect(_on_damage_zone_entered)
	set_physics_process(true)
	# Spawn a few initial physical droplets so the runtime container is visible in-game
	for i in range(3):
		spawn_physical_particle()
	print("LavaSystem ready, spawned initial particles. PhysicalParticles children: ", physical_particles_holder.get_child_count())

func setup_surface():
	"""Setup collision surface for lava pool"""
	# The surface is already in the scene tree with collision shapes
	# This just ensures it's properly configured
	lava_surface.collision_layer = 1
	lava_surface.collision_mask = 1  # Let physical lava droplets collide with it

func setup_damage_zone():
	"""Setup invisible damage zone where lava is deadly"""
	damage_zone.collision_layer = 2
	damage_zone.collision_mask = 1  # Detect player (should be on layer 1)
	damage_zone.monitoring = true
	damage_zone.monitorable = true

func _physics_process(delta: float) -> void:
	_physical_spawn_accumulator += physical_emission_rate * delta
	while _physical_spawn_accumulator >= 1.0:
		_physical_spawn_accumulator -= 1.0
		if physical_particles_holder.get_child_count() < physical_particle_max:
			spawn_physical_particle()

func spawn_physical_particle() -> void:
	print("Spawning physical lava particle")
	# Hardcoded material properties (previously from GPUParticles2D)
	var extents = Vector3(10, 10, 1)
	var spread = 2.0
	var initial_velocity_min = 30.0
	var initial_velocity_max = 80.0
	var start_position = global_position + Vector2(randf_range(-extents.x, extents.x), randf_range(-extents.y, extents.y))

	var particle = RigidBody2D.new()
	particle.name = "LavaParticle"
	particle.global_position = start_position
	particle.gravity_scale = 0.5
	particle.linear_damp = 2.0
	particle.angular_damp = 4.0
	particle.collision_layer = 1
	particle.collision_mask = 1
	particle.physics_material_override = PhysicsMaterial.new()
	particle.physics_material_override.bounce = 0.2
	particle.physics_material_override.friction = 2.0

	var sprite = Sprite2D.new()
	sprite.texture = preload("res://Textures/Lava/fall/lavafall_00.png")
	var scale = randf_range(0.8, 1.2)
	var visual_scale = scale * 2.5  # Make texture bigger than collision
	sprite.scale = Vector2.ONE * visual_scale
	sprite.centered = true
	particle.add_child(sprite)

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = physical_particle_size * scale
	shape.shape = rect
	particle.add_child(shape)

	var speed = randf_range(initial_velocity_min, initial_velocity_max)
	var spread_angle = deg_to_rad(randf_range(-spread * 0.5, spread * 0.5))
	particle.linear_velocity = Vector2.DOWN.rotated(spread_angle) * speed
	particle.angular_velocity = randf_range(-5.0, 5.0)

	var timer = Timer.new()
	timer.wait_time = physical_particle_lifetime
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(Callable(particle, "queue_free"))
	particle.add_child(timer)

	physical_particles_holder.add_child(particle)

func _on_damage_zone_entered(area_or_body: Node2D):
	"""Handle when something enters the lava damage zone"""
	print("Damage zone touched by: ", area_or_body.name)
	# Check if it's the player (Node2D is the player instance)
	if area_or_body.name == "Node2D" or area_or_body.is_in_group("player"):
		emit_signal("player_touched_lava")
		print("Player touched lava!")

func create_splash(position: Vector2, force: float = 100.0):
	"""Create a splash effect at a specific position"""
	# For now, just spawn extra physical particles at the position
	for i in range(5):
		var particle = RigidBody2D.new()
		particle.global_position = position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		particle.gravity_scale = 0.5
		particle.linear_damp = 2.0
		particle.angular_damp = 4.0
		particle.collision_layer = 1
		particle.collision_mask = 1
		particle.physics_material_override = PhysicsMaterial.new()
		particle.physics_material_override.bounce = 0.8
		particle.physics_material_override.friction = 0.5
		
		var sprite = Sprite2D.new()
		sprite.texture = preload("res://Textures/Lava/fall/lavafall_00.png")
		var scale = randf_range(0.8, 1.2)
		var visual_scale = scale * 1.5  # Make texture bigger than collision
		sprite.scale = Vector2.ONE * visual_scale
		sprite.centered = true
		particle.add_child(sprite)
		
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = physical_particle_size * scale
		shape.shape = rect
		particle.add_child(shape)
		
		particle.linear_velocity = Vector2(randf_range(-force, force), randf_range(-force, force))
		particle.angular_velocity = randf_range(-5.0, 5.0)
		
		var timer = Timer.new()
		timer.wait_time = physical_particle_lifetime
		timer.one_shot = true
		timer.autostart = true
		timer.timeout.connect(Callable(particle, "queue_free"))
		particle.add_child(timer)
		
		physical_particles_holder.add_child(particle)

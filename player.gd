extends Node2D

@export_category("Softbody Configuration")
@export var radius: float = 48.0
@export var num_points: int = 32
@export var target_pressure: float = 16000.0 
@export var spring_stiffness: float = 40000.0
@export var spring_damping: float = 1000.0 
@export var global_drag: float = 0.99 

@export_category("Feature Toggles")
@export var enable_pressure_system: bool = true 
@export var enable_shape_matching: bool = true 
@export var shape_match_stiffness: float = 10.0 
@export var shape_match_damping: float = 3.0 

@export_category("Engine Stability")
@export var sub_steps: int = 32 

@export_category("Texture")
@export var texture: Texture2D 
@export var texture_tint: Color = Color.WHITE

@export_category("Controls Configuration")
@export var move_force: float = 1200.0
@export var max_speed: float = 600.0 
@export var jump_strength: float = 550.0 
@export var crouch_strength: float = 1500.0 
@export var allow_respawn: bool = true

@export_category("Obstacles")
@export var obstacle_markers: Array[Node2D]

@export_category("Damage System")
@export var max_health: float = 100.0
@export var lava_damage_rate: float = 40.0 
@export var cooling_rate: float = 20.0 
@export var damage_color: Color = Color(0.0, 1.0, 0.0, 1.0) 

@export_category("Corpse Settings")
@export var corpse_texture: Texture2D ## Optional texture for the corpse!
@export var corpse_texture_region: Rect2 = Rect2(0, 0, 0, 0) ## Set W and H > 0 to use a specific region of the texture
@export var corpse_texture_repeat: bool = false
@export var corpse_polygon_color: Color = Color.WHITE

@onready var soft_body = $SoftBodySphere
@onready var center_tracker = $CenterTracker
@onready var lava_detector = $CenterTracker/LavaDetector 

var current_health: float
var base_color: Color
var start_position: Vector2

func _ready() -> void:
	current_health = max_health
	base_color = texture_tint
	start_position = global_position
	
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
		
		soft_body.enable_pressure_system = enable_pressure_system
		soft_body.enable_shape_matching = enable_shape_matching
		soft_body.shape_match_stiffness = shape_match_stiffness
		soft_body.shape_match_damping = shape_match_damping
		
		soft_body.initialize()

func _physics_process(delta: float) -> void:
	if soft_body:
		soft_body.enable_pressure_system = enable_pressure_system
		soft_body.enable_shape_matching = enable_shape_matching
		soft_body.shape_match_stiffness = shape_match_stiffness
		soft_body.shape_match_damping = shape_match_damping
		
		var center = Vector2.ZERO
		if soft_body.points.size() > 0:
			for p in soft_body.points:
				center += p.position
			center /= soft_body.points.size()
		else:
			center = soft_body.position
			
		if center_tracker:
			center_tracker.position = center
			
		_process_lava_damage(delta)

func _process_lava_damage(delta: float) -> void:
	if not lava_detector: 
		return
		
	var is_touching_lava = false
	var highest_damage_taken = 0.0
	
	for body in lava_detector.get_overlapping_bodies():
		if "damage_rate" in body:
			is_touching_lava = true
			if body.damage_rate > highest_damage_taken:
				highest_damage_taken = body.damage_rate
		elif body.is_in_group("lava"):
			is_touching_lava = true
			if lava_damage_rate > highest_damage_taken:
				highest_damage_taken = lava_damage_rate
			
	if is_touching_lava:
		current_health -= highest_damage_taken * delta
	else:
		current_health += cooling_rate * delta
		
	current_health = clamp(current_health, 0.0, max_health)
	
	var damage_percent = 1.0 - (current_health / max_health)
	soft_body.texture_tint = base_color.lerp(damage_color, damage_percent)
	
	if current_health <= 0.0:
		_die()

func _die() -> void:
	var is_holding_static = Input.is_action_pressed("static")
	_spawn_corpse(is_holding_static)
	
	current_health = max_health
	soft_body.texture_tint = base_color
	
	var respawn_node = get_node_or_null("../RespawnPoint")
	var target_pos = respawn_node.position if respawn_node else start_position
	respawn(target_pos)

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

func _spawn_corpse(is_static: bool = false) -> void:
	if not soft_body or soft_body.points.size() < 3:
		return
		
	var raw_global_poly = soft_body.get_current_polygon_global()
	var global_poly = _smooth_polygon(raw_global_poly, 2)
	
	var centroid = Vector2.ZERO
	for pt in global_poly:
		centroid += pt
	centroid /= global_poly.size()
	
	var local_poly = PackedVector2Array()
	for pt in global_poly:
		local_poly.append(pt - centroid)
		
	var corpse: PhysicsBody2D
	if is_static:
		corpse = StaticBody2D.new()
	else:
		corpse = RigidBody2D.new()
		corpse.mass = 5.0
		
	corpse.add_to_group("corpse")
	corpse.add_to_group("hammer_smashable")
	corpse.top_level = true 
	corpse.global_position = centroid
	
	var coll_shape = CollisionPolygon2D.new()
	coll_shape.polygon = local_poly
	corpse.add_child(coll_shape)
	
	var visual = Polygon2D.new()
	visual.polygon = local_poly
	visual.color = corpse_polygon_color
	
	if corpse_texture:
		var tex_to_use := corpse_texture
		var region_center := Vector2.ZERO
		# If a region was provided (non-zero size) create an AtlasTexture to use only that portion
		if corpse_texture_region.size != Vector2.ZERO:
			var atlas := AtlasTexture.new()
			atlas.atlas = corpse_texture
			atlas.region = corpse_texture_region
			tex_to_use = atlas
			region_center = corpse_texture_region.position + (corpse_texture_region.size / 2.0)
		else:
			region_center = corpse_texture.get_size() / 2.0
		visual.texture = tex_to_use
		visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED if corpse_texture_repeat else CanvasItem.TEXTURE_REPEAT_DISABLED
		# Keep color as a modulate so user can tint the texture if desired
		visual.color = corpse_polygon_color
		# Center the texture on the polygon by offsetting UVs by the texture/region center
		var uvs := PackedVector2Array()
		for pt in local_poly:
			uvs.append(pt + region_center)
		visual.uv = uvs
	else:
		visual.color = damage_color
		
	corpse.add_child(visual)
	
	get_tree().current_scene.call_deferred("add_child", corpse)

func respawn(target_position: Vector2) -> void:
	global_position = target_position
	if soft_body:
		soft_body.respawn(Vector2.ZERO)

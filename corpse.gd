extends RigidBody2D

const FIRE_SCENE = preload("res://fire_particles.tscn")
@export_category("Corpse Settings")
@export var is_static: bool = false
@export var max_durability: float = 100.0
@export var flame_texture: Texture2D ## DRAG "flame_particle.png" HERE IN THE INSPECTOR!

@export_category("Break Settings")
@export var corpse_fragment_count: int = 14
@export var corpse_fragment_lifetime: float = 0.65
@export var corpse_fragment_min_size: Vector2 = Vector2(4, 4)
@export var corpse_fragment_max_size: Vector2 = Vector2(12, 12)
@export var corpse_fragment_speed: float = 220.0

var base_color: Color

# Data stored from setup_corpse to be applied once nodes are ready
var _spawn_poly: PackedVector2Array
var _spawn_color: Color
var _spawn_texture: Texture
var _spawn_texture_region: Rect2
var _spawn_texture_repeat: bool

# --- Interaction State ---
var _hammer_progress: float = 0.0
var _next_threshold: float = 0.0

var _melt_progress: float = 0.0
var _current_melt_time: float = 1.0 # Avoid divide by zero
var _next_melt_crack_threshold: float = 0.2
var _fire_instances: Array[Node] = []
var _lava_detector: Area2D

var _cracks_node: Node2D = null
var _is_destroying: bool = false


func _ready() -> void:
	add_to_group("corpse")
	add_to_group("hammer_smashable") 
	
	# Fallback: re-enable rigid body contacts just in case
	contact_monitor = true
	max_contacts_reported = 10
	
	if is_static:
		freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		freeze = true
	else:
		freeze = false
		
	# Build the physical collision shape
	var collision_poly = CollisionPolygon2D.new()
	collision_poly.polygon = _spawn_poly
	add_child(collision_poly)
	
	# Build the visual polygon and apply textures
	var visual_poly = Polygon2D.new()
	visual_poly.name = "DeathShapePolygon"
	visual_poly.polygon = _spawn_poly
	
	if _spawn_texture:
		var tex_to_use := _spawn_texture
		if _spawn_texture_region.size != Vector2.ZERO:
			var atlas := AtlasTexture.new()
			atlas.atlas = _spawn_texture
			atlas.region = _spawn_texture_region
			tex_to_use = atlas
		
		visual_poly.texture = tex_to_use
		visual_poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED if _spawn_texture_repeat else CanvasItem.TEXTURE_REPEAT_DISABLED
		visual_poly.texture_offset = tex_to_use.get_size() / 2.0
		visual_poly.color = _spawn_color
	else:
		visual_poly.color = _spawn_color
		
	add_child(visual_poly)
	
	_setup_flame_particles()
	_setup_lava_detector()


func setup_corpse(poly: PackedVector2Array, color: Color, spawn_global_pos: Vector2, make_static: bool, tex: Texture = null, tex_reg: Rect2 = Rect2(), tex_rep: bool = false, custom_flame: Texture2D = null) -> void:
	global_position = spawn_global_pos
	base_color = color
	is_static = make_static
	
	_spawn_poly = poly
	_spawn_color = color
	_spawn_texture = tex
	_spawn_texture_region = tex_reg
	_spawn_texture_repeat = tex_rep
	
	# If spawned by code (like the player), apply the passed texture!
	if custom_flame:
		flame_texture = custom_flame


func _setup_lava_detector() -> void:
	_lava_detector = Area2D.new()
	_lava_detector.name = "LavaDetector"
	
	# FIX: Make the Area2D scan ALL 32 physics layers so it doesn't miss the lava!
	_lava_detector.collision_layer = 0
	_lava_detector.collision_mask = 4294967295
	
	var det_shape = CollisionPolygon2D.new()
	det_shape.polygon = _spawn_poly
	_lava_detector.add_child(det_shape)
	
	add_child(_lava_detector)


func _setup_flame_particles() -> void:
	if not FIRE_SCENE or _spawn_poly.size() < 3: # <-- Changed this line to use FIRE_SCENE
		return

	# 1. Find the highest and lowest Y points to determine where the "middle" is
	var min_y = INF
	var max_y = -INF
	for pt in _spawn_poly:
		if pt.y < min_y: min_y = pt.y
		if pt.y > max_y: max_y = pt.y

	var mid_y = (min_y + max_y) / 2.0
	
	# 2. Gather only the points that exist in the top half of the body
	var top_points: Array[Vector2] = []
	for pt in _spawn_poly:
		if pt.y <= mid_y:
			top_points.append(pt)

	# Fallback just in case it's a super flat shape
	if top_points.size() < 3:
		top_points = Array(_spawn_poly)

	# 3. Sort the top points from left to right (based on X axis)
	top_points.sort_custom(func(a, b): return a.x < b.x)

	# 4. Pick the far left, exact middle, and far right points
	var spawn_positions = [
		top_points[0], 
		top_points[top_points.size() / 2], 
		top_points[top_points.size() - 1]
	]

	# 5. Spawn the 3 fire scenes and attach them to those points
	for pos in spawn_positions:
		var fire = FIRE_SCENE.instantiate() # <-- Changed this line
		fire.position = pos
		add_child(fire)
		_fire_instances.append(fire)
		
		# Force them to start completely OFF!
		if "emitting" in fire:
			fire.emitting = false # <-- Changed to false

func _physics_process(delta: float) -> void:
	if _is_destroying: return
	
	var is_in_lava = false
	var fastest_melt_time = INF
	
	# Combine both the Area2D overlap AND the physical contacts to be 100% sure
	var overlapping_bodies = _lava_detector.get_overlapping_bodies()
	var colliding_bodies = get_colliding_bodies()
	var all_bodies = overlapping_bodies + colliding_bodies
	
	for body in all_bodies:
		if body.is_in_group("lava") and body.get("can_melt_corpses") == true:
			is_in_lava = true
			if body.get("corpse_melt_time") < fastest_melt_time:
				fastest_melt_time = body.get("corpse_melt_time")
				
	if is_in_lava:
		_current_melt_time = fastest_melt_time
		_process_lava_melting(delta, fastest_melt_time)
	else:
		for fire in _fire_instances:
			if "emitting" in fire:
				fire.emitting = false


func _process_lava_melting(delta: float, melt_time: float) -> void:
	_melt_progress += delta
	var melt_ratio = clamp(_melt_progress / melt_time, 0.0, 1.0)
	
	# Darken visually
	var poly_node = get_node_or_null("DeathShapePolygon")
	if poly_node:
		poly_node.color = base_color.lerp(Color(0.08, 0.08, 0.08, 1.0), melt_ratio)
		
	# Ignite!
	for fire in _fire_instances:
		# Check if the root of your scene is a GPUParticles2D, or find the node that is
		if "emitting" in fire:
			fire.emitting = true # (or false, depending on what the code here is doing!)
		
	# Trigger procedural cracks at intervals
	if melt_ratio >= _next_melt_crack_threshold and melt_ratio < 1.0:
		_spawn_procedural_crack()
		_next_melt_crack_threshold += 0.2
		
	if _melt_progress >= melt_time:
		_is_destroying = true
		_break_apart()


# ==========================================
# UI PROGRESS HELPERS
# ==========================================

func get_melt_progress_ratio() -> float:
	# Call this from your hammer script to get a value from 0.0 to 1.0
	if _is_destroying: return 1.0
	return clamp(_melt_progress / _current_melt_time, 0.0, 1.0)

func get_hammer_progress(max_time: float) -> float:
	return clamp(_hammer_progress / max_time, 0.0, 1.0)


# ==========================================
# HAMMER INTERACTION LOGIC
# ==========================================

func take_hammer_damage(delta: float, break_hold_time: float, hits_during_hold: int) -> void:
	if _is_destroying:
		return
		
	_hammer_progress += delta
	var p_ratio: float = clamp(_hammer_progress / break_hold_time, 0.0, 1.0)
	
	if p_ratio >= _next_threshold and p_ratio < 1.0:
		_spawn_procedural_crack()
		_next_threshold += 1.0 / (hits_during_hold + 1.0)
		
	if _hammer_progress >= break_hold_time:
		_is_destroying = true
		_break_apart()


# ==========================================
# UNIVERSAL BREAK LOGIC
# ==========================================

func _spawn_procedural_crack() -> void:
	if not is_instance_valid(_cracks_node):
		_cracks_node = Node2D.new()
		add_child(_cracks_node)
		
	var crack := Line2D.new()
	crack.width = randf_range(1.5, 3.5)
	crack.default_color = Color(0.05, 0.05, 0.05, 0.95)
	crack.joint_mode = Line2D.LINE_JOINT_SHARP
	crack.begin_cap_mode = Line2D.LINE_CAP_ROUND
	crack.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	var current_pos := Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
	crack.add_point(current_pos)
	
	var main_dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	var segments := randi_range(2, 4)
	
	for i in range(segments):
		var angle_offset: float = randf_range(-0.6, 0.6)
		current_pos += main_dir.rotated(angle_offset) * randf_range(6.0, 14.0)
		crack.add_point(current_pos)
		
	_cracks_node.add_child(crack)

func _break_apart() -> void:
	_disable_collision(self)
	_spawn_corpse_break_fragments()

func _disable_collision(root: Node) -> void:
	if root is CollisionObject2D:
		root.set_deferred("collision_layer", 0)
		root.set_deferred("collision_mask", 0)

	for child in root.find_children("*", "CollisionShape2D", true, false):
		(child as CollisionShape2D).set_deferred("disabled", true)

	for child in root.find_children("*", "CollisionPolygon2D", true, false):
		(child as CollisionPolygon2D).set_deferred("disabled", true)

func _spawn_corpse_break_fragments() -> void:
	var source_texture := _get_corpse_texture()
	if not source_texture:
		queue_free()
		return

	var source_size := _get_corpse_texture_size(source_texture)
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		queue_free()
		return

	var fragment_parent := get_parent()
	if not fragment_parent:
		fragment_parent = get_tree().current_scene

	var fragment_origin := global_position
	var fragment_root := Node2D.new()
	fragment_root.global_position = fragment_origin
	fragment_parent.add_child(fragment_root)

	for i in range(corpse_fragment_count):
		var fragment := Sprite2D.new()
		fragment.texture = source_texture
		fragment.centered = true
		fragment.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if source_size.length() <= 64.0 else CanvasItem.TEXTURE_FILTER_LINEAR

		var fragment_size := Vector2(
			randf_range(corpse_fragment_min_size.x, corpse_fragment_max_size.x),
			randf_range(corpse_fragment_min_size.y, corpse_fragment_max_size.y)
		)
		fragment.region_enabled = true

		var max_x := maxf(0.0, source_size.x - fragment_size.x)
		var max_y := maxf(0.0, source_size.y - fragment_size.y)
		var region_origin := Vector2(randf_range(0.0, max_x), randf_range(0.0, max_y))
		fragment.region_rect = Rect2(region_origin, fragment_size)
		fragment.position = Vector2(
			randf_range(-source_size.x * 0.2, source_size.x * 0.2),
			randf_range(-source_size.y * 0.2, source_size.y * 0.2)
		)
		fragment.rotation = randf_range(0.0, TAU)
		fragment.scale = Vector2.ONE * randf_range(0.75, 1.25)
		fragment.modulate = Color(1, 1, 1, randf_range(0.75, 1.0))

		fragment_root.add_child(fragment)

		var tween := fragment.create_tween() 
		tween.set_parallel(true)
		var fling_dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		if fling_dir == Vector2.ZERO:
			fling_dir = Vector2.UP
		var fling_velocity := fling_dir * randf_range(corpse_fragment_speed * 0.45, corpse_fragment_speed)
		fling_velocity.y -= corpse_fragment_speed * 0.35
		tween.tween_property(fragment, "position", fragment.position + fling_velocity * corpse_fragment_lifetime, corpse_fragment_lifetime)
		tween.tween_property(fragment, "rotation", fragment.rotation + randf_range(-TAU, TAU), corpse_fragment_lifetime)
		tween.tween_property(fragment, "scale", Vector2.ONE * randf_range(0.2, 0.55), corpse_fragment_lifetime)
		tween.tween_property(fragment, "modulate:a", 0.0, corpse_fragment_lifetime)
		tween.finished.connect(Callable(fragment, "queue_free"), CONNECT_ONE_SHOT)

	var cleanup_timer := Timer.new()
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = corpse_fragment_lifetime
	cleanup_timer.timeout.connect(Callable(fragment_root, "queue_free"), CONNECT_ONE_SHOT)
	fragment_root.add_child(cleanup_timer)
	cleanup_timer.start()
	queue_free()

func _get_corpse_texture() -> Texture2D:
	for child in find_children("*", "Polygon2D", true, false):
		var polygon := child as Polygon2D
		if polygon.texture:
			if polygon.texture is AtlasTexture:
				return (polygon.texture as AtlasTexture).atlas
			return polygon.texture
	return null

func _get_corpse_texture_size(texture: Texture2D) -> Vector2:
	for child in find_children("*", "Polygon2D", true, false):
		var polygon := child as Polygon2D
		if polygon.texture:
			if polygon.texture is AtlasTexture:
				var atlas := polygon.texture as AtlasTexture
				return atlas.region.size
			return texture.get_size()
	return texture.get_size()

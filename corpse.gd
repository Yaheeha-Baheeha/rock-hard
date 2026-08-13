extends RigidBody2D

@export_category("Corpse Settings")
@export var is_static: bool = false
@export var max_durability: float = 100.0

@export_category("Break Settings")
@export var corpse_fragment_count: int = 14
@export var corpse_fragment_lifetime: float = 0.65
@export var corpse_fragment_min_size: Vector2 = Vector2(4, 4)
@export var corpse_fragment_max_size: Vector2 = Vector2(12, 12)
@export var corpse_fragment_speed: float = 220.0

var current_durability: float
var base_color: Color

# Data stored from setup_corpse to be applied once nodes are ready
var _spawn_poly: PackedVector2Array
var _spawn_color: Color
var _spawn_texture: Texture
var _spawn_texture_region: Rect2
var _spawn_texture_repeat: bool

# --- Hammer Interaction State ---
var _hammer_progress: float = 0.0
var _next_threshold: float = 0.0
var _cracks_node: Node2D = null
var _is_destroying: bool = false

func _ready() -> void:
	current_durability = max_durability
	add_to_group("corpse")
	add_to_group("hammer_smashable") # Ensure the hammer fallback picks it up if needed
	
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

func setup_corpse(poly: PackedVector2Array, color: Color, spawn_global_pos: Vector2, make_static: bool, tex: Texture = null, tex_reg: Rect2 = Rect2(), tex_rep: bool = false) -> void:
	global_position = spawn_global_pos
	base_color = color
	is_static = make_static
	
	# Store these for _ready() to use when building the nodes
	_spawn_poly = poly
	_spawn_color = color
	_spawn_texture = tex
	_spawn_texture_region = tex_reg
	_spawn_texture_repeat = tex_rep

func take_lava_damage(amount: float, delta: float) -> void:
	if _is_destroying: return
	current_durability -= amount * delta
	
	var burn_percent = 1.0 - (current_durability / max_durability)
	var poly_node = get_node_or_null("DeathShapePolygon")
	if poly_node:
		poly_node.color = base_color.lerp(Color(0.1, 0.1, 0.1, 1.0), burn_percent)
		
	if current_durability <= 0.0:
		queue_free()

# ==========================================
# HAMMER INTERACTION LOGIC
# ==========================================

func get_hammer_progress(max_time: float) -> float:
	return clamp(_hammer_progress / max_time, 0.0, 1.0)

func take_hammer_damage(delta: float, break_hold_time: float, hits_during_hold: int) -> void:
	if _is_destroying:
		return
		
	if not is_instance_valid(_cracks_node):
		_cracks_node = Node2D.new()
		add_child(_cracks_node)
		_next_threshold = 1.0 / (hits_during_hold + 1.0)
		
	_hammer_progress += delta
	var p_ratio: float = clamp(_hammer_progress / break_hold_time, 0.0, 1.0)
	
	if p_ratio >= _next_threshold and p_ratio < 1.0:
		_spawn_procedural_crack()
		_next_threshold += 1.0 / (hits_during_hold + 1.0)
		
	if _hammer_progress >= break_hold_time:
		_is_destroying = true
		_break_apart()

func _spawn_procedural_crack() -> void:
	if not is_instance_valid(_cracks_node): return
		
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

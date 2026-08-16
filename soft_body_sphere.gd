extends Node2D

enum ShapeType { TRIANGLE, CIRCLE, RECTANGLE, HEXAGON }
var current_shape: ShapeType = ShapeType.CIRCLE

class PointMass:
	var position: Vector2
	var prev_position: Vector2 
	var velocity: Vector2
	var mass: float = 1.0
	var uv: Vector2 
	var base_rest_offset: Vector2
	
	func _init(pos: Vector2, local_uv: Vector2, rest_off: Vector2):
		position = pos
		prev_position = pos
		uv = local_uv
		base_rest_offset = rest_off

class Spring:
	var point_a: PointMass
	var point_b: PointMass
	var rest_length: float
	var stiffness: float
	var damping: float 
	
	func _init(a: PointMass, b: PointMass, k: float, d: float):
		point_a = a
		point_b = b
		rest_length = a.position.distance_to(b.position)
		stiffness = k
		damping = d

@export_flags_2d_physics var collision_mask: int = 1 
@export var fluid_layer: int = 3

var radius: float = 64.0
var num_points: int = 32
var target_pressure: float = 2500.0 
var spring_stiffness: float = 1500.0
var spring_damping: float = 40.0 
var global_drag: float = 0.99 

var enable_pressure_system: bool = true
var enable_shape_matching: bool = true
var shape_match_stiffness: float = 10.0
var shape_match_damping: float = 3.0

var sub_steps: int = 4 

var texture: Texture2D 
var _bg_texture: CanvasTexture
var texture_tint: Color = Color.WHITE

var move_force: float = 1200.0
var max_speed: float = 600.0 
var jump_strength: float = 550.0 
var crouch_strength: float = 1500.0 

var obstacle_markers: Array[Node2D]

var obstacle_polygons: Array[PackedVector2Array] = []
var points: Array[PointMass] = []
var springs: Array[Spring] = []
var show_debug: bool = false 
var start_position: Vector2
var is_grounded: bool = false
var grounded_timer: float = 0.0

var hazard_polygons: Array[Dictionary] = []
var collectible_polygons: Array[Dictionary] = []
var win_polygons: Array[Dictionary] = []

func _extract_node_polygons(node: Node) -> Array[PackedVector2Array]:
	var polys: Array[PackedVector2Array] = []
	if node is TileMapLayer:
		return _extract_tilemap_polygons(node)
	elif node is Polygon2D:
		var p = PackedVector2Array()
		for pt in node.polygon:
			p.append(to_local(node.to_global(pt)))
		polys.append(p)
	elif (node as CollisionShape2D) != null and (node as CollisionShape2D).shape is RectangleShape2D:
		var shape = (node as CollisionShape2D).shape as RectangleShape2D
		var ext = shape.size / 2.0
		var p = PackedVector2Array()
		var pts = [Vector2(-ext.x, -ext.y), Vector2(ext.x, -ext.y), Vector2(ext.x, ext.y), Vector2(-ext.x, ext.y)]
		for pt in pts:
			p.append(to_local((node as CollisionShape2D).to_global(pt)))
		polys.append(p)
	elif node is Sprite2D:
		var ext = node.texture.get_size() / 2.0 * node.scale
		var p = PackedVector2Array()
		var pts = [Vector2(-ext.x, -ext.y), Vector2(ext.x, -ext.y), Vector2(ext.x, ext.y), Vector2(-ext.x, ext.y)]
		for pt in pts:
			p.append(to_local(node.to_global(pt)))
		polys.append(p)
	else:
		for child in node.get_children():
			polys.append_array(_extract_node_polygons(child))
	return polys

func initialize() -> void:
	start_position = position 
	call_deferred("_initialize_trigger_zones")
	
	var raw_polygon = PackedVector2Array()
	for node in obstacle_markers:
		if node != null:
			if node is Marker2D:
				raw_polygon.append(to_local(node.global_position))
			elif node is TileMapLayer:
				var polys = _extract_tilemap_polygons(node)
				obstacle_polygons.append_array(polys)
				
	if raw_polygon.size() > 2:
		obstacle_polygons.append(raw_polygon)
		
	var merged = true
	while merged:
		merged = false
		for i in range(obstacle_polygons.size()):
			for j in range(i + 1, obstacle_polygons.size()):
				var result = Geometry2D.merge_polygons(obstacle_polygons[i], obstacle_polygons[j])
				if result.size() == 1:
					obstacle_polygons[i] = result[0]
					obstacle_polygons.remove_at(j)
					merged = true
					break
			if merged:
				break
				
	_build_shape(current_shape)

func _initialize_trigger_zones() -> void:
	hazard_polygons.clear()
	collectible_polygons.clear()
	win_polygons.clear()
	
	for node in get_tree().get_nodes_in_group("hazards"):
		var polys = _extract_node_polygons(node)
		for p in polys:
			hazard_polygons.append({"poly": p, "node": node})
			
	for node in get_tree().get_nodes_in_group("collectibles"):
		var polys = _extract_node_polygons(node)
		for p in polys:
			collectible_polygons.append({"poly": p, "node": node})
			
	for node in get_tree().get_nodes_in_group("win_zones"):
		var polys = _extract_node_polygons(node)
		for p in polys:
			win_polygons.append({"poly": p, "node": node})

func _physics_process(delta: float) -> void:
	if not is_inside_tree(): return
	var world = get_world_2d()
	if not world: return
	var space_state = world.direct_space_state

	is_grounded = false 
	
	for p in points:
		p.prev_position = p.position

	var sub_delta = delta / float(sub_steps)
	var step_drag = pow(global_drag, 1.0 / float(sub_steps))

	for step in range(sub_steps):
		if not is_inside_tree():
			break
			
		if enable_pressure_system:
			_apply_gas_pressure(sub_delta)
			
		if enable_shape_matching:
			_apply_shape_matching(sub_delta)
			
		_solve_springs(sub_delta)
		
		for p in points:
			p.velocity.y += 980.0 * sub_delta 
			p.velocity *= step_drag 
			var pre_pos = p.position
			p.position += p.velocity * sub_delta
			if fluid_layer != 0:
				var fluid_query = PhysicsPointQueryParameters2D.new()
				fluid_query.position = to_global(p.position)
				fluid_query.collision_mask = fluid_layer
				fluid_query.collide_with_bodies = true
				
				var fluid_hits = space_state.intersect_point(fluid_query)
				for hit in fluid_hits:
					var fluid_drop = hit.collider as RigidBody2D
					if fluid_drop:
						p.velocity = p.velocity.lerp(fluid_drop.linear_velocity, 0.15)
						p.velocity.y -= 3500.0 * sub_delta
						var push_dir = (fluid_drop.global_position - to_global(p.position)).normalized()
						if push_dir == Vector2.ZERO: push_dir = Vector2.UP
						fluid_drop.apply_central_impulse(push_dir * p.velocity.length() * p.mass * 0.03)
			for poly in obstacle_polygons:
				if poly.size() > 0 and _is_point_in_polygon(p.position, poly):
					_resolve_collision(p, poly)
					
			var is_dead = false
			for hazard in hazard_polygons:
				if hazard.poly.size() > 0 and _is_point_in_polygon(p.position, hazard.poly):
					if is_instance_valid(hazard.node):
						hazard.node.trigger_death(to_global(p.position))
					is_dead = true
					break
			if is_dead:
				break
			
			if p.position != pre_pos:
				var query = PhysicsRayQueryParameters2D.create(to_global(pre_pos), to_global(p.position))
				query.collision_mask = collision_mask
				
				var result = space_state.intersect_ray(query)
				if result:
					p.position = to_local(result.position + result.normal * 0.5)
					var normal_local = result.normal.rotated(-global_rotation)
					
					if result.collider is RigidBody2D:
						var hit_force = p.velocity.dot(-normal_local)
						if hit_force > 0:
							result.collider.apply_impulse(-normal_local * hit_force * p.mass * 0.02, result.position - result.collider.global_position)
							
					var vel_dot = p.velocity.dot(normal_local)
					if vel_dot < 0:
						p.velocity -= normal_local * vel_dot * 1.2
					p.velocity *= 0.85
					if normal_local.y < -0.2:
						is_grounded = true

	if is_grounded:
		grounded_timer = 0.15
	else:
		grounded_timer -= delta

	_handle_input_controls(delta)
	is_grounded = false

func _process(_delta: float) -> void:
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			show_debug = !show_debug

func _handle_input_controls(delta: float) -> void:
	var horizontal_input = Input.get_axis("left", "right")
	
	if horizontal_input != 0.0:
		var center = Vector2.ZERO
		for p in points:
			center += p.position
		center /= points.size()
		
		for p in points:
			p.velocity.x += horizontal_input * move_force * delta
			p.velocity.x = clamp(p.velocity.x, -max_speed, max_speed)
			
			var dir = (p.position - center).normalized()
			var tangent = Vector2(-dir.y, dir.x)
			p.velocity += tangent * (horizontal_input * move_force * 0.6 * delta)

	if Input.is_action_pressed("crouch"):
		for p in points:
			p.velocity.y += crouch_strength * delta

	if Input.is_action_just_pressed("jump") and grounded_timer > 0.0:
		grounded_timer = 0.0
		for p in points:
			p.velocity.y -= jump_strength

	if Input.is_action_just_pressed("reset"):
		_reset_softbody()
		
	if Input.is_action_just_pressed("test"):
		cycle_shape()

func cycle_shape() -> void:
	var center = Vector2.ZERO
	var avg_vel = Vector2.ZERO
	if points.size() > 0:
		for p in points:
			center += p.position
			avg_vel += p.velocity
		center /= float(points.size())
		avg_vel /= float(points.size())
	else:
		center = position
		
	current_shape = (current_shape + 1) % ShapeType.size() as ShapeType
	
	points.clear()
	springs.clear()
	_build_shape(current_shape, center, avg_vel)

func _reset_softbody() -> void:
	points.clear()
	springs.clear()
	position = start_position
	_build_shape(current_shape)

func respawn(target_position: Vector2) -> void:
	position = target_position
	start_position = target_position
	points.clear()
	springs.clear()
	_build_shape(current_shape, target_position)

func get_current_polygon_global() -> PackedVector2Array:
	var poly = PackedVector2Array()
	for p in points:
		poly.append(to_global(p.position))
	return poly

func _extract_tilemap_polygons(tilemap: TileMapLayer) -> Array[PackedVector2Array]:
	var polys: Array[PackedVector2Array] = []
	var used_cells = tilemap.get_used_cells()
	var tile_set = tilemap.tile_set
	if not tile_set: return polys
	
	for cell in used_cells:
		var tile_data = tilemap.get_cell_tile_data(cell)
		if not tile_data: continue
		for i in range(tile_data.get_collision_polygons_count(0)):
			var p = PackedVector2Array()
			for pt in tile_data.get_collision_polygon_points(0, i):
				var cell_pos = tilemap.map_to_local(cell)
				var global_pt = tilemap.to_global(cell_pos + pt)
				p.append(to_local(global_pt))
			polys.append(p)
	return polys

func should_enable_pressure_system() -> bool:
	return current_shape == ShapeType.CIRCLE

func _build_shape(shape_type: ShapeType, spawn_center: Vector2 = position, initial_vel: Vector2 = Vector2.ZERO) -> void:
	var rest_offsets: Array[Vector2] = []
	
	match shape_type:
		ShapeType.TRIANGLE:
			var corners = PackedVector2Array()
			var triangle_radius = radius * (4.0 / 3.3) 
			for i in range(3):
				var angle = i * (PI * 2.0 / 3.0) - (PI / 2.0)
				corners.append(Vector2(cos(angle), sin(angle)) * triangle_radius)
			rest_offsets = _sample_polygon_perimeter(corners, num_points)
			
		ShapeType.CIRCLE:
			for i in range(num_points):
				var angle = i * PI * 2.0 / num_points
				rest_offsets.append(Vector2(cos(angle), sin(angle)) * radius)
				
		ShapeType.RECTANGLE:
			var w = radius * 1.4
			var h = radius * 0.7
			var corners = PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)])
			rest_offsets = _sample_polygon_perimeter(corners, num_points)
			
			
		ShapeType.HEXAGON:
			var corners = PackedVector2Array()
			for i in range(6):
				var angle = i * (PI * 2.0 / 6.0)
				corners.append(Vector2(cos(angle), sin(angle)) * radius)
			rest_offsets = _sample_polygon_perimeter(corners, num_points)

	enable_pressure_system = should_enable_pressure_system()

	# 1. Find the single absolute largest dimension to scale uniformly
	var max_offset := 0.0
	for offset in rest_offsets:
		max_offset = maxf(max_offset, abs(offset.x))
		max_offset = maxf(max_offset, abs(offset.y))
		
	var uv_scale := max_offset * 2.0
	if uv_scale == 0: 
		uv_scale = 0.001

	# 2. Map the UVs uniformly so the face stays perfectly round but covers the bounds!
	for offset in rest_offsets:
		var pos = spawn_center + offset
		
		var uv = Vector2(
			(offset.x / uv_scale) + 0.5,
			(offset.y / uv_scale) + 0.5
		)
		
		var point = PointMass.new(pos, uv, offset)
		point.velocity = initial_vel
		points.append(point)
		
	_build_springs()

func _sample_polygon_perimeter(corners: PackedVector2Array, count: int) -> Array[Vector2]:
	var total_len = 0.0
	var edge_lengths: Array[float] = []
	
	for i in range(corners.size()):
		var len = corners[i].distance_to(corners[(i + 1) % corners.size()])
		edge_lengths.append(len)
		total_len += len
		
	var step = total_len / float(count)
	var result: Array[Vector2] = []
	
	for i in range(count):
		var target_dist = i * step
		var accum = 0.0
		for e in range(corners.size()):
			if accum + edge_lengths[e] >= target_dist or e == corners.size() - 1:
				var remainder = target_dist - accum
				var t = 0.0
				if edge_lengths[e] > 0.0:
					t = remainder / edge_lengths[e]
				t = clamp(t, 0.0, 1.0)
				var p1 = corners[e]
				var p2 = corners[(e + 1) % corners.size()]
				result.append(p1.lerp(p2, t))
				break
			accum += edge_lengths[e]
			
	return result

func _build_springs() -> void:
	for i in range(num_points):
		var n1 = (i + 1) % num_points
		var n2 = (i + 2) % num_points 
		springs.append(Spring.new(points[i], points[n1], spring_stiffness, spring_damping))
		springs.append(Spring.new(points[i], points[n2], spring_stiffness * 0.8, spring_damping))

func _apply_gas_pressure(delta: float) -> void:
	var volume = 0.0
	for i in range(num_points):
		var p1 = points[i].position
		var p2 = points[(i + 1) % num_points].position
		volume += (p1.x * p2.y) - (p2.x * p1.y)
	volume = abs(volume * 0.5)
	
	var actual_pressure = target_pressure * 1000.0
	var pressure_force = actual_pressure / max(volume, 100.0) 
	
	for i in range(num_points):
		var p1 = points[i]
		var p2 = points[(i + 1) % num_points]
		var edge = p2.position - p1.position
		var normal = Vector2(edge.y, -edge.x).normalized() 
		var force = normal * pressure_force * edge.length()
		
		p1.velocity += (force * 0.5) / p1.mass * delta
		p2.velocity += (force * 0.5) / p2.mass * delta

func _apply_shape_matching(delta: float) -> void:
	if points.size() == 0: return
	
	var center = Vector2.ZERO
	var avg_vel = Vector2.ZERO
	for p in points:
		center += p.position
		avg_vel += p.velocity
	center /= float(points.size())
	avg_vel /= float(points.size())
	
	var sin_sum = 0.0
	var cos_sum = 0.0
	
	for p in points:
		var current_offset = p.position - center
		sin_sum += p.base_rest_offset.x * current_offset.y - p.base_rest_offset.y * current_offset.x
		cos_sum += p.base_rest_offset.x * current_offset.x + p.base_rest_offset.y * current_offset.y
		
	var current_angle = atan2(sin_sum, cos_sum)
	
	for p in points:
		var target_pos = center + p.base_rest_offset.rotated(current_angle)
		var offset = target_pos - p.position
		
		var spring_force = offset * shape_match_stiffness
		var relative_vel = p.velocity - avg_vel
		var damping_force = -relative_vel * shape_match_damping
		
		var total_force = spring_force + damping_force
		p.velocity += (total_force / p.mass) * delta

func _solve_springs(delta: float) -> void:
	for spring in springs:
		var dist = spring.point_a.position.distance_to(spring.point_b.position)
		if dist == 0.0: continue
			
		var dir = (spring.point_b.position - spring.point_a.position).normalized()
		var spring_force_mag = (dist - spring.rest_length) * spring.stiffness
		var relative_vel = spring.point_b.velocity - spring.point_a.velocity
		var damp_force_mag = relative_vel.dot(dir) * spring.damping
		var total_force = dir * (spring_force_mag + damp_force_mag)
		
		spring.point_a.velocity += (total_force / spring.point_a.mass) * delta
		spring.point_b.velocity -= (total_force / spring.point_b.mass) * delta

func _is_point_in_polygon(test_point: Vector2, poly: PackedVector2Array) -> bool:
	var is_inside = false
	var j = poly.size() - 1
	for i in range(poly.size()):
		var pi = poly[i]
		var pj = poly[j]
		if (pi.y < test_point.y and pj.y >= test_point.y) or (pj.y < test_point.y and pi.y >= test_point.y):
			var intersect_x = pi.x + (test_point.y - pi.y) / (pj.y - pi.y) * (pj.x - pi.x)
			if intersect_x > test_point.x:
				is_inside = !is_inside 
		j = i
	return is_inside

func _resolve_collision(point: PointMass, poly: PackedVector2Array) -> void:
	var closest_dist = INF
	var closest_pt = point.position
	var poly_size = poly.size()
	
	for i in range(poly_size):
		var p1 = poly[i]
		var p2 = poly[(i + 1) % poly_size]
		var edge = p2 - p1
		var edge_len_sq = edge.length_squared()
		if edge_len_sq == 0: continue
		
		var t = clamp((point.position - p1).dot(edge) / edge_len_sq, 0.0, 1.0)
		var proj = p1 + edge * t
		var dist = point.position.distance_squared_to(proj)
		
		if dist < closest_dist:
			closest_dist = dist
			closest_pt = proj

	var push_dir = (closest_pt - point.position).normalized()
	if push_dir == Vector2.ZERO: 
		push_dir = Vector2.UP

	if push_dir.y < -0.2:
		is_grounded = true

	point.position = closest_pt
	var vel_dot = point.velocity.dot(push_dir)
	if vel_dot < 0:
		point.velocity -= push_dir * vel_dot * 1.2
	point.velocity *= 0.85

func _draw() -> void:
	if points.size() < 3:
		return
		
	var fraction = Engine.get_physics_interpolation_fraction()
	
	var render_positions = PackedVector2Array()
	var center_pos = Vector2.ZERO
	
	for p in points:
		var r_pos = p.prev_position.lerp(p.position, fraction)
		render_positions.append(r_pos)
		center_pos += r_pos
		
	center_pos /= float(points.size())
	var center_uv = Vector2(0.5, 0.5)
	
	if texture != null and not show_debug:
		var clay_color = Color(0.937, 0.894, 0.690) * texture_tint
		
		# If the main texture has normal/specular maps (is a CanvasTexture), 
		# we create a blank texture that copies those maps for the background!
		var current_bg_tex = null
		if texture is CanvasTexture:
			if _bg_texture == null:
				_bg_texture = CanvasTexture.new()
			_bg_texture.normal_texture = texture.normal_texture
			_bg_texture.specular_texture = texture.specular_texture
			current_bg_tex = _bg_texture

		# Draw the shape using triangle fans
		for i in range(num_points):
			var next_i = (i + 1) % num_points
			var tri_points = PackedVector2Array([center_pos, render_positions[i], render_positions[next_i]])
			var tri_uvs = PackedVector2Array([center_uv, points[i].uv, points[next_i].uv])
			
			# 1. Draw the background clay color FIRST, using the same UVs so the normal maps perfectly align!
			var bg_colors = PackedColorArray([clay_color, clay_color, clay_color])
			if current_bg_tex:
				draw_polygon(tri_points, bg_colors, tri_uvs, current_bg_tex)
			else:
				draw_polygon(tri_points, bg_colors, tri_uvs) # Fallback if no normal maps exist
				
			# 2. Draw the actual cute face texture ON TOP
			var face_colors = PackedColorArray([texture_tint, texture_tint, texture_tint])
			draw_polygon(tri_points, face_colors, tri_uvs, texture)
	else:
		var fill_color = Color(0.2, 0.6, 1.0, 0.3) if show_debug else Color(0.2, 0.6, 1.0, 0.8)
		draw_colored_polygon(render_positions, fill_color)
		
	var outline_points = render_positions.duplicate()
	outline_points.append(render_positions[0]) 
	draw_polyline(outline_points, Color.WHITE, 2.0, true)
	
	if not show_debug:
		return
		
	if enable_shape_matching:
		var sin_sum = 0.0
		var cos_sum = 0.0
		for p in points:
			var current_offset = p.position - center_pos
			sin_sum += p.base_rest_offset.x * current_offset.y - p.base_rest_offset.y * current_offset.x
			cos_sum += p.base_rest_offset.x * current_offset.x + p.base_rest_offset.y * current_offset.y
		var current_angle = atan2(sin_sum, cos_sum)
		
		var target_poly = PackedVector2Array()
		for p in points:
			target_poly.append(center_pos + p.base_rest_offset.rotated(current_angle))
		target_poly.append(target_poly[0])
		draw_polyline(target_poly, Color(0.0, 1.0, 1.0, 0.5), 2.0)
		
	for poly in obstacle_polygons:
		if poly.size() >= 3:
			draw_colored_polygon(poly, Color(0.8, 0.2, 0.2, 0.3))
			var obs_line = poly.duplicate()
			obs_line.append(poly[0]) 
			draw_polyline(obs_line, Color(1.0, 0.2, 0.2, 0.8), 2.0, true)
		
	for spring in springs:
		var pos_a = spring.point_a.prev_position.lerp(spring.point_a.position, fraction)
		var pos_b = spring.point_b.prev_position.lerp(spring.point_b.position, fraction)
		draw_line(pos_a, pos_b, Color(0.5, 1.0, 0.5, 0.4), 1.0)
		
	for i in range(num_points):
		var p1 = render_positions[i]
		var p2 = render_positions[(i + 1) % num_points]
		var edge = p2 - p1
		var normal = Vector2(edge.y, -edge.x).normalized()
		var edge_center = p1 + (edge * 0.5)
		draw_line(edge_center, edge_center + (normal * 25.0), Color.RED, 2.0)
		draw_circle(edge_center + (normal * 25.0), 3.0, Color.RED)
		
	for pos in render_positions:
		draw_circle(pos, 3.0, Color.YELLOW)

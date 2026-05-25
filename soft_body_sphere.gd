extends Node2D

# ---------------------------------------------------------
# CUSTOM CLASSES
# ---------------------------------------------------------

class PointMass:
	var position: Vector2
	var velocity: Vector2
	var mass: float = 1.0
	var uv: Vector2 
	
	func _init(pos: Vector2, local_uv: Vector2):
		position = pos
		uv = local_uv

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

# ---------------------------------------------------------
# EXPORT VARIABLES
# ---------------------------------------------------------

@export_category("Softbody Configuration")
@export var radius: float = 64.0
@export var num_points: int = 32
@export var target_pressure: float = 2500.0 
@export var spring_stiffness: float = 1500.0
@export var spring_damping: float = 40.0 
@export var global_drag: float = 0.99 

@export_category("Engine Stability")
@export var sub_steps: int = 4 # Divides the frame into 4 micro-frames

@export_category("Texture")
@export var texture: Texture2D 
@export var texture_tint: Color = Color.WHITE

@export_category("Controls Configuration")
@export var move_force: float = 1200.0
@export var max_speed: float = 600.0 # Prevents the jelly from accelerating to infinity
@export var jump_strength: float = 550.0 # Additive physical impulse
@export var crouch_strength: float = 1500.0 # Force pushing down

@export_category("Obstacles")
@export var obstacle_markers: Array[Marker2D]

# ---------------------------------------------------------
# STATE VARIABLES
# ---------------------------------------------------------

var obstacle_polygon: PackedVector2Array 
var points: Array[PointMass] = []
var springs: Array[Spring] = []
var show_debug: bool = false 
var start_position: Vector2

# NEW: The true physical ground state
var is_grounded: bool = false 

# ---------------------------------------------------------
# LIFECYCLE FUNCTIONS
# ---------------------------------------------------------

func _ready() -> void:
	start_position = position 
	for marker in obstacle_markers:
		if marker != null:
			obstacle_polygon.append(to_local(marker.global_position))
	_build_sphere()

func _physics_process(delta: float) -> void:
	is_grounded = false 
	
	# Cut the frame time into tiny pieces for stability
	var sub_delta = delta / float(sub_steps)
	# Adjust the drag so it applies smoothly across the smaller steps
	var step_drag = pow(global_drag, 1.0 / float(sub_steps))
	
	# Run the physics engine multiple times per frame
	for step in range(sub_steps):
		_apply_gas_pressure(sub_delta)
		_solve_springs(sub_delta)
		
		for p in points:
			p.velocity.y += 980.0 * sub_delta 
			p.velocity *= step_drag 
			p.position += p.velocity * sub_delta
			
			if obstacle_polygon.size() > 0 and _is_point_in_polygon(p.position, obstacle_polygon):
				_resolve_collision(p)
				
	# Handle inputs exactly once per main frame
	_handle_input_controls(delta)

func _process(_delta: float) -> void:
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			show_debug = !show_debug

# ---------------------------------------------------------
# INPUT HANDLING
# ---------------------------------------------------------

func _handle_input_controls(delta: float) -> void:
	var horizontal_input = Input.get_axis("left", "right")
	
	# Left / Right Movement
	if horizontal_input != 0.0:
		for p in points:
			p.velocity.x += horizontal_input * move_force * delta
			# Cap the speed so it doesn't slide like a frictionless hockey puck forever
			p.velocity.x = clamp(p.velocity.x, -max_speed, max_speed)

	# Crouch Input (Adds downward force)
	if Input.is_action_pressed("crouch"):
		for p in points:
			p.velocity.y += crouch_strength * delta

	# Jump Input (Only works if a point is touching an upward-facing surface)
	if Input.is_action_just_pressed("jump") and is_grounded:
		for p in points:
			# We use -= here to ADD an impulse to current velocity, like real physics
			p.velocity.y -= jump_strength

	# Reset Input
	if Input.is_action_just_pressed("reset"):
		_reset_softbody()

func _reset_softbody() -> void:
	points.clear()
	springs.clear()
	position = start_position
	_build_sphere()

# ---------------------------------------------------------
# SETUP & PHYSICS LOGIC
# ---------------------------------------------------------

func _build_sphere() -> void:
	for i in range(num_points):
		var angle = i * PI * 2.0 / num_points
		var cos_a = cos(angle)
		var sin_a = sin(angle)
		var pos = position + Vector2(cos_a, sin_a) * radius
		var uv = Vector2(cos_a * 0.5 + 0.5, sin_a * 0.5 + 0.5) 
		points.append(PointMass.new(pos, uv))
		
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

# ---------------------------------------------------------
# COLLISION LOGIC
# ---------------------------------------------------------

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

func _resolve_collision(point: PointMass) -> void:
	var closest_dist = INF
	var closest_pt = point.position
	var poly_size = obstacle_polygon.size()
	
	for i in range(poly_size):
		var p1 = obstacle_polygon[i]
		var p2 = obstacle_polygon[(i + 1) % poly_size]
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

	# NEW: TRUE GROUND DETECTION
	# If the surface pushes the point upwards (y is negative in Godot), it's the ground!
	# We use < -0.4 so it can still jump off slopes, but won't jump off perfectly vertical walls.
	if push_dir.y < -0.4:
		is_grounded = true

	point.position = closest_pt
	var vel_dot = point.velocity.dot(push_dir)
	if vel_dot < 0:
		point.velocity -= push_dir * vel_dot * 1.2
	point.velocity *= 0.85

# ---------------------------------------------------------
# VISUAL RENDERING
# ---------------------------------------------------------

func _draw() -> void:
	if points.size() < 3:
		return
		
	var poly_points = PackedVector2Array()
	var poly_uvs = PackedVector2Array()
	var poly_colors = PackedColorArray()
	
	for p in points:
		poly_points.append(p.position)
		poly_uvs.append(p.uv)
		poly_colors.append(texture_tint)
		
	if texture != null and not show_debug:
		draw_polygon(poly_points, poly_colors, poly_uvs, texture)
	else:
		var fill_color = Color(0.2, 0.6, 1.0, 0.3) if show_debug else Color(0.2, 0.6, 1.0, 0.8)
		draw_colored_polygon(poly_points, fill_color)
		
	poly_points.append(points[0].position) 
	draw_polyline(poly_points, Color.WHITE, 2.0, true)
	
	if not show_debug:
		return
		
	if obstacle_polygon.size() >= 3:
		draw_colored_polygon(obstacle_polygon, Color(0.8, 0.2, 0.2, 0.3))
		var obs_line = obstacle_polygon.duplicate()
		obs_line.append(obstacle_polygon[0]) 
		draw_polyline(obs_line, Color(1.0, 0.2, 0.2, 0.8), 2.0, true)
		
	for spring in springs:
		draw_line(spring.point_a.position, spring.point_b.position, Color(0.5, 1.0, 0.5, 0.4), 1.0)
		
	for i in range(num_points):
		var p1 = points[i].position
		var p2 = points[(i + 1) % num_points].position
		var edge = p2 - p1
		var normal = Vector2(edge.y, -edge.x).normalized()
		var edge_center = p1 + (edge * 0.5)
		draw_line(edge_center, edge_center + (normal * 25.0), Color.RED, 2.0)
		draw_circle(edge_center + (normal * 25.0), 3.0, Color.RED)
		
	for p in points:
		draw_circle(p.position, 3.0, Color.YELLOW)

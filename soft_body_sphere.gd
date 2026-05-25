extends Node2D

# ---------------------------------------------------------
# CUSTOM CLASSES
# ---------------------------------------------------------

class PointMass:
	var position: Vector2
	var velocity: Vector2
	var mass: float = 1.0
	
	func _init(pos: Vector2):
		position = pos

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

@export var radius: float = 64.0
@export var num_points: int = 32
# Cranked way up because Godot gravity is 980!
@export var target_pressure: float = 2_500_000.0 
@export var spring_stiffness: float = 1500.0
@export var spring_damping: float = 40.0 
@export var global_drag: float = 0.99 

@export var obstacle_markers: Array[Marker2D]

# ---------------------------------------------------------
# STATE VARIABLES
# ---------------------------------------------------------

var obstacle_polygon: PackedVector2Array 
var points: Array[PointMass] = []
var springs: Array[Spring] = []

# ---------------------------------------------------------
# LIFECYCLE FUNCTIONS
# ---------------------------------------------------------

func _ready() -> void:
	for marker in obstacle_markers:
		if marker != null:
			obstacle_polygon.append(to_local(marker.global_position))
			
	_build_sphere()

func _physics_process(delta: float) -> void:
	_apply_gas_pressure(delta)
	_solve_springs(delta)
	
	for p in points:
		p.velocity.y += 980.0 * delta 
		p.velocity *= global_drag 
		p.position += p.velocity * delta
		
		if obstacle_polygon.size() > 0 and _is_point_in_polygon(p.position, obstacle_polygon):
			_resolve_collision(p)

func _process(_delta: float) -> void:
	queue_redraw()

# ---------------------------------------------------------
# SETUP & PHYSICS LOGIC
# ---------------------------------------------------------

func _build_sphere() -> void:
	# 1. Create the points
	for i in range(num_points):
		var angle = i * PI * 2.0 / num_points
		var pos = position + Vector2(cos(angle), sin(angle)) * radius
		points.append(PointMass.new(pos))
		
	# 2. Build the hollow skin
	for i in range(num_points):
		var n1 = (i + 1) % num_points
		var n2 = (i + 2) % num_points 
		
		# The Skin (Immediate neighbors)
		springs.append(Spring.new(points[i], points[n1], spring_stiffness, spring_damping))
		
		# Surface Tension (Local diagonals) - keeps the skin from folding
		springs.append(Spring.new(points[i], points[n2], spring_stiffness * 0.8, spring_damping))
		
		# We completely removed the cross-center connections!

func _apply_gas_pressure(delta: float) -> void:
	var volume = 0.0
	
	for i in range(num_points):
		var p1 = points[i].position
		var p2 = points[(i + 1) % num_points].position
		volume += (p1.x * p2.y) - (p2.x * p1.y)
	volume = abs(volume * 0.5)
	
	var pressure_force = target_pressure / max(volume, 100.0) 
	
	for i in range(num_points):
		var p1 = points[i]
		var p2 = points[(i + 1) % num_points]
		
		var edge = p2.position - p1.position
		var normal = Vector2(edge.y, -edge.x).normalized() 
		
		var force = normal * pressure_force * edge.length()
		
		# Split the force evenly between the two points making up the edge
		p1.velocity += (force * 0.5) / p1.mass * delta
		p2.velocity += (force * 0.5) / p2.mass * delta

func _solve_springs(delta: float) -> void:
	for spring in springs:
		var dist = spring.point_a.position.distance_to(spring.point_b.position)
		if dist == 0.0: 
			continue
			
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
	if point.velocity.y > 0:
		point.velocity.y *= -0.5 
	point.velocity.x *= 0.8     
	point.position.y -= 2.0 

# ---------------------------------------------------------
# VISUAL RENDERING
# ---------------------------------------------------------

# ---------------------------------------------------------
# VISUAL RENDERING
# ---------------------------------------------------------

func _draw() -> void:
	if points.size() < 3:
		return
		
	# 1. Draw the semi-transparent jelly skin
	var poly_points = PackedVector2Array()
	for p in points:
		poly_points.append(p.position)
		
	# Lowered the alpha to 0.3 so we can see the internal structure
	draw_colored_polygon(poly_points, Color(0.2, 0.6, 1.0, 0.3))
	
	# 2. Visualize ALL internal and structural springs
	for spring in springs:
		# Draw lines between the connected point masses
		draw_line(spring.point_a.position, spring.point_b.position, Color(0.5, 1.0, 0.5, 0.4), 1.0)
		
	# 3. Visualize Outward Gas Pressure Forces
	for i in range(num_points):
		var p1 = points[i].position
		var p2 = points[(i + 1) % num_points].position
		
		var edge = p2 - p1
		# Calculate the outward-facing normal of the edge
		var normal = Vector2(edge.y, -edge.x).normalized()
		# Find the exact middle of the edge to draw the arrow from
		var edge_center = p1 + (edge * 0.5)
		
		# Draw a red line showing the outward pressure direction
		draw_line(edge_center, edge_center + (normal * 25.0), Color.RED, 2.0)
		# Draw a little dot at the end to make it look like an arrow
		draw_circle(edge_center + (normal * 25.0), 3.0, Color.RED)
	
	# 4. Draw the thick white wireframe outline
	poly_points.append(points[0].position) 
	draw_polyline(poly_points, Color.WHITE, 2.0, true)
	
	# 5. Draw the actual Point Masses (Vertices)
	for p in points:
		draw_circle(p.position, 3.0, Color.YELLOW)

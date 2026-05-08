extends Area2D

enum CeramicType {
	RIGID,
	STATIC,
}

@export var player_root_path: NodePath = NodePath("../SoftBody2D")
@export var softbody_path: NodePath = NodePath("../SoftBody2D")
@export var player_controller_path: NodePath = NodePath("../SoftBodyController")
@export var respawn_point_path: NodePath = NodePath("../RespawnPoint")
@export var spawn_parent_path: NodePath = NodePath("..")
@export var ceramic_type: CeramicType = CeramicType.RIGID
@export var spawn_offset: Vector2 = Vector2.ZERO
@export var trigger_cooldown: float = 0.15
@export var shape_polygon_color: Color = Color(0.88, 0.33, 0.22, 0.65)
@export var shape_physics_material: PhysicsMaterial = preload("res://resources/ceramic_material.tres")
@export_range(8, 64, 1) var circle_approximation_segments: int = 20

var _is_handling_trigger: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _is_handling_trigger:
		return
	if not _is_player_body(body):
		return

	_is_handling_trigger = true
	_spawn_at_collision(body)
	_respawn_player()

	if trigger_cooldown > 0.0:
		await get_tree().create_timer(trigger_cooldown).timeout
	_is_handling_trigger = false


func _is_player_body(body: Node) -> bool:
	var player_root := get_node_or_null(player_root_path)
	if not player_root:
		return false

	var current: Node = body
	while current != null:
		if current == player_root:
			return true
		current = current.get_parent()
	return false


func _spawn_at_collision(body: Node) -> void:
	var parent := get_node_or_null(spawn_parent_path)
	if not parent:
		return

	_spawn_shape_polygon(body, parent)


func _spawn_shape_polygon(body: Node, parent: Node) -> void:
	if not (parent is Node2D):
		return

	var polygon_points := _build_polygon_points_from_body(body, parent as Node2D)
	if polygon_points.size() < 3:
		return
	for i in polygon_points.size():
		polygon_points[i] += spawn_offset

	var body_node: PhysicsBody2D
	if ceramic_type == CeramicType.STATIC:
		body_node = StaticBody2D.new()
	else:
		var rigid_body := RigidBody2D.new()
		rigid_body.lock_rotation = true
		rigid_body.mass = 1.0
		body_node = rigid_body

	body_node.name = "DeathShapeBody"
	body_node.position = Vector2.ZERO
	body_node.physics_material_override = shape_physics_material
	body_node.add_to_group("hammer_smashable")

	var collision_polygon := CollisionPolygon2D.new()
	collision_polygon.polygon = polygon_points
	body_node.add_child(collision_polygon)

	var polygon_node := Polygon2D.new()
	polygon_node.name = "DeathShapePolygon"
	polygon_node.color = shape_polygon_color
	polygon_node.polygon = polygon_points
	body_node.add_child(polygon_node)
	(parent as Node2D).add_child(body_node)


func _build_polygon_points_from_body(body: Node, target_parent: Node2D) -> PackedVector2Array:
	var points := PackedVector2Array()
	for shape_node in _get_collision_shape_nodes(body):
		points.append_array(_shape_node_points_in_parent_space(shape_node, target_parent))

	if points.size() < 3:
		return PackedVector2Array()

	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.resize(hull.size() - 1)
	return hull


func _get_collision_shape_nodes(body: Node) -> Array[Node]:
	var root := body
	var player_root := get_node_or_null(player_root_path)
	if player_root and _is_descendant_of(body, player_root):
		root = player_root

	var shape_nodes: Array[Node] = []
	_collect_shape_nodes_recursive(root, shape_nodes)
	return shape_nodes


func _collect_shape_nodes_recursive(current: Node, out_nodes: Array[Node]) -> void:
	if current is CollisionShape2D or current is CollisionPolygon2D:
		out_nodes.append(current)

	for child in current.get_children():
		if child is Node:
			_collect_shape_nodes_recursive(child, out_nodes)


func _shape_node_points_in_parent_space(shape_node: Node, target_parent: Node2D) -> PackedVector2Array:
	var local_points := PackedVector2Array()

	if shape_node is CollisionPolygon2D:
		local_points = (shape_node as CollisionPolygon2D).polygon
	elif shape_node is CollisionShape2D:
		var collision_shape := shape_node as CollisionShape2D
		if collision_shape.shape:
			local_points = _shape_to_local_points(collision_shape.shape)

	if local_points.is_empty():
		return PackedVector2Array()

	var result := PackedVector2Array()
	var shape_node_2d := shape_node as Node2D
	for point in local_points:
		var global_point := shape_node_2d.to_global(point)
		result.append(target_parent.to_local(global_point))
	return result


func _shape_to_local_points(shape: Shape2D) -> PackedVector2Array:
	if shape is RectangleShape2D:
		var size := (shape as RectangleShape2D).size * 0.5
		return PackedVector2Array([
			Vector2(-size.x, -size.y),
			Vector2(size.x, -size.y),
			Vector2(size.x, size.y),
			Vector2(-size.x, size.y),
		])

	if shape is CircleShape2D:
		var radius := (shape as CircleShape2D).radius
		return _build_circle_points(radius)

	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		return _build_capsule_points(capsule.radius, capsule.height)

	if shape is ConvexPolygonShape2D:
		return (shape as ConvexPolygonShape2D).points

	if shape is ConcavePolygonShape2D:
		var concave := shape as ConcavePolygonShape2D
		var points := PackedVector2Array()
		for segment_point in concave.segments:
			points.append(segment_point)
		return points

	return PackedVector2Array()


func _build_circle_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segments := maxi(circle_approximation_segments, 8)
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _build_capsule_points(radius: float, height: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var half_segment := maxf(0.0, height * 0.5 - radius)
	var arc_steps := maxi(circle_approximation_segments / 2, 4)

	for i in arc_steps + 1:
		var t := float(i) / float(arc_steps)
		var angle := PI + PI * t
		points.append(Vector2(cos(angle), sin(angle)) * radius + Vector2(0, -half_segment))

	for i in arc_steps + 1:
		var t := float(i) / float(arc_steps)
		var angle := PI * t
		points.append(Vector2(cos(angle), sin(angle)) * radius + Vector2(0, half_segment))

	return points


func _is_descendant_of(node: Node, possible_ancestor: Node) -> bool:
	var current := node
	while current != null:
		if current == possible_ancestor:
			return true
		current = current.get_parent()
	return false


func _respawn_player() -> void:
	var respawn_point := get_node_or_null(respawn_point_path) as Node2D
	if not respawn_point:
		return

	var target_position := respawn_point.global_position
	var softbody := get_node_or_null(softbody_path)
	if softbody and softbody.has_method("get_bones_center_position") and softbody.has_method("get_rigid_bodies"):
		# Move the whole softbody cluster by delta to preserve its shape.
		var center: Vector2 = softbody.call("get_bones_center_position")
		var delta := target_position - center
		for body_data in softbody.call("get_rigid_bodies"):
			var rigidbody := body_data.rigidbody as RigidBody2D
			if not rigidbody:
				continue
			rigidbody.global_position += delta
			rigidbody.linear_velocity = Vector2.ZERO
			rigidbody.angular_velocity = 0.0
			rigidbody.sleeping = false

	if softbody is Node2D:
		(softbody as Node2D).global_position = target_position

	var controller := get_node_or_null(player_controller_path) as Node2D
	if controller:
		controller.global_position = target_position

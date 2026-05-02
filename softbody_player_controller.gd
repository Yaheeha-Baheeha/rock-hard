extends Node2D

@export var softbody_path: NodePath = NodePath("../SoftBody2D")
@export var move_force_jump: float = 50.0
@export var move_force_crouch: float = 100.0
@export var move_force_left: float = 100.0
@export var move_force_right: float = 100.0
@export var ground_check_distance: float = 18.0
@export var ground_normal_threshold: float = 0.5
@export var ground_push_impulse: float = 50.0

@onready var softbody: SoftBody2D = get_node_or_null(softbody_path)

signal softbody_broken

var is_softbody_broken: bool = false

func _ready() -> void:
	if softbody:
		softbody.joint_removed.connect(_on_softbody_joint_removed)
		global_position = softbody.get_bones_center_position()

func _physics_process(_delta: float) -> void:
	if not softbody:
		return

	var center_position := softbody.get_bones_center_position()

	var left_strength := Input.get_action_strength("left")
	var right_strength := Input.get_action_strength("right")
	var crouch_strength := Input.get_action_strength("crouch")

	var force := Vector2(
		right_strength * move_force_right - left_strength * move_force_left,
		crouch_strength * move_force_crouch
	)

	if force != Vector2.ZERO:
		softbody.apply_force(force)

	var ground_hit := _get_ground_hit(center_position)
	var is_grounded: bool = false
	if not ground_hit.is_empty() and ground_hit.has("normal"):
		var ground_normal: Vector2 = ground_hit["normal"]
		is_grounded = ground_normal.dot(Vector2.UP) >= ground_normal_threshold

	if is_grounded and Input.is_action_just_pressed("jump"):
		softbody.apply_impulse(Vector2(0, -move_force_jump))
		_apply_downward_impulse_to_ground(ground_hit)

	global_position = center_position

func _get_ground_hit(center_position: Vector2) -> Dictionary:
	if not softbody:
		return {}

	var bodies := softbody.get_rigid_bodies()
	if bodies.is_empty():
		return {}

	var min_x := center_position.x
	var max_x := center_position.x
	var max_y := center_position.y
	var exclude_rids: Array[RID] = []

	for body_data in bodies:
		var body := body_data.rigidbody as PhysicsBody2D
		if not body:
			continue
		var body_position := body.global_position
		min_x = minf(min_x, body_position.x)
		max_x = maxf(max_x, body_position.x)
		max_y = maxf(max_y, body_position.y)
		exclude_rids.append(body.get_rid())

	var sample_points := [
		Vector2(center_position.x, max_y),
		Vector2(min_x, max_y),
		Vector2(max_x, max_y)
	]

	var best_hit := {}
	var best_distance := INF
	var space_state := get_world_2d().direct_space_state

	for origin in sample_points:
		var query := PhysicsRayQueryParameters2D.create(origin, origin + Vector2.DOWN * ground_check_distance)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.exclude = exclude_rids

		var hit := space_state.intersect_ray(query)
		if hit.is_empty():
			continue

		var hit_position: Vector2 = hit["position"]
		var distance: float = origin.distance_to(hit_position)
		if distance < best_distance:
			best_distance = distance
			best_hit = hit

	return best_hit

func _apply_downward_impulse_to_ground(ground_hit: Dictionary) -> void:
	if ground_hit.is_empty() or not ground_hit.has("collider"):
		return

	var collider = ground_hit.collider
	if collider is RigidBody2D:
		(collider as RigidBody2D).apply_central_impulse(Vector2.DOWN * ground_push_impulse)

func _on_softbody_joint_removed(_rigid_body_a: SoftBody2D.SoftBodyChild, _rigid_body_b: SoftBody2D.SoftBodyChild) -> void:
	if is_softbody_broken:
		return
	is_softbody_broken = true
	softbody_broken.emit()

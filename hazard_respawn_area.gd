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
@export var rigid_spawn_scene: PackedScene = preload("res://ceramics/normal_rigid_ceramic.tscn")
@export var static_spawn_scene: PackedScene = preload("res://ceramics/normal_static_ceramic.tscn")
@export var spawn_offset: Vector2 = Vector2.ZERO
@export var trigger_cooldown: float = 0.15

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
	var scene_to_spawn := _get_spawn_scene()
	if not scene_to_spawn:
		return

	var parent := get_node_or_null(spawn_parent_path)
	if not parent:
		return

	var instance := scene_to_spawn.instantiate()
	if instance is Node2D:
		var spawn_position := global_position
		if body is Node2D:
			spawn_position = (body as Node2D).global_position
		(instance as Node2D).global_position = spawn_position + spawn_offset
	parent.add_child(instance)


func _get_spawn_scene() -> PackedScene:
	if ceramic_type == CeramicType.STATIC:
		return static_spawn_scene
	return rigid_spawn_scene


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

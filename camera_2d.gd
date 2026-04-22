extends Camera2D

@export var speed: float = 2000.0
@export var target_path: NodePath

@onready var target: Node2D = _resolve_target()

func _ready() -> void:
	if not target:
		target = _resolve_target()

func _resolve_target() -> Node2D:
	if not target_path.is_empty():
		var explicit_target := get_node_or_null(target_path)
		if explicit_target is Node2D:
			return explicit_target

	var parent_node := get_parent()
	if parent_node:
		var controller := parent_node.get_node_or_null("SoftBodyController")
		if controller is Node2D:
			return controller
		if parent_node is Node2D:
			return parent_node

	return null

func _process(delta):
	if not is_instance_valid(target):
		target = _resolve_target()

	if target:
		global_position = target.global_position
		return

	var direction := Vector2.ZERO
	
	if Input.is_action_pressed("jump") or Input.is_key_pressed(KEY_W):
		direction.y -= 1
	if Input.is_action_pressed("crouch") or Input.is_key_pressed(KEY_S):
		direction.y += 1
	if Input.is_action_pressed("left") or Input.is_key_pressed(KEY_A):
		direction.x -= 1
	if Input.is_action_pressed("right") or Input.is_key_pressed(KEY_D):
		direction.x += 1
	
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		position += direction * speed * delta

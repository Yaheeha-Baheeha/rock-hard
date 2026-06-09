extends Camera2D

@export var speed: float = 2000.0
@export var target_path: NodePath
@export var zoom_step: float = 0.1
@export var min_zoom: float = 0.35
@export var max_zoom: float = 1.5

@onready var target: Node2D = _resolve_target()

func _ready() -> void:
	if not target:
		target = _resolve_target()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if Input.is_action_pressed("zoom in"):
			_set_zoom_scale(zoom.x + zoom_step)
		elif Input.is_action_pressed("zoom out"):
			_set_zoom_scale(zoom.x - zoom_step)


func _set_zoom_scale(value: float) -> void:
	var clamped: float = clampf(value, min_zoom, max_zoom)
	zoom = Vector2(clamped, clamped)

func _resolve_target() -> Node2D:
	if not target_path.is_empty():
		var explicit_target: Node = get_node_or_null(target_path)
		if explicit_target is Node2D:
			return explicit_target

	var parent_node: Node = get_parent()
	if parent_node:
		var controller: Node = parent_node.get_node_or_null("SoftBodyController")
		if controller is Node2D:
			return controller
		if parent_node is Node2D:
			return parent_node

	return null

func _process(delta: float) -> void:
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

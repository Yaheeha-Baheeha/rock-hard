extends Node2D

@export var max_hits_per_click: int = 1
@export var smash_duration: float = 0.35
@export var spin_rotations: float = 2.5
@export var shrink_scale: float = 0.2

@onready var swing_animation_player: AnimationPlayer = $SwingAnimationPlayer

var _destroying_targets: Dictionary = {}

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	z_index = 200

func _exit_tree() -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(_delta: float) -> void:
	global_position = get_global_mouse_position()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_play_swing_animation()
		_smash_under_cursor()

func _play_swing_animation() -> void:
	swing_animation_player.play("swing")

func _smash_under_cursor() -> void:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hits := space_state.intersect_point(query, 32)
	if hits.is_empty():
		return

	var smash_count := 0
	for hit in hits:
		if smash_count >= max_hits_per_click:
			break

		var collider: Node = hit.get("collider")
		var smashable_target := _find_smashable_target(collider)
		if smashable_target:
			_start_smash_animation(smashable_target)
			smash_count += 1


func _find_smashable_target(start_node: Node) -> Node2D:
	var current: Node = start_node
	while current:
		if current is Node2D and (current.is_in_group("hammer_smashable") or current.name == "DeathShapeBody"):
			return current as Node2D
		current = current.get_parent()

	return _find_ceramic_scene_root(start_node)

func _find_ceramic_scene_root(start_node: Node) -> Node2D:
	var current: Node = start_node
	while current:
		if current is Node2D and current.scene_file_path.begins_with("res://ceramics/"):
			return current as Node2D
		current = current.get_parent()
	return null

func _start_smash_animation(target: Node2D) -> void:
	if _destroying_targets.has(target):
		return

	_destroying_targets[target] = true
	_disable_collision(target)
	_play_smash_animation(target)

func _play_smash_animation(target: Node2D) -> void:
	var animation_player := target.get_node_or_null("SmashAnimationPlayer") as AnimationPlayer
	if not animation_player:
		_play_tween_smash_animation(target)
		return

	animation_player.animation_finished.connect(_on_smash_animation_finished.bind(target), CONNECT_ONE_SHOT)
	animation_player.play("smash")


func _play_tween_smash_animation(target: Node2D) -> void:
	if not is_instance_valid(target):
		_destroying_targets.erase(target)
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(target, "rotation", target.rotation + TAU * spin_rotations, smash_duration)
	tween.tween_property(target, "scale", Vector2.ONE * shrink_scale, smash_duration)
	if target is CanvasItem:
		tween.tween_property(target, "modulate:a", 0.0, smash_duration)
	tween.finished.connect(_on_tween_smash_finished.bind(target), CONNECT_ONE_SHOT)


func _on_tween_smash_finished(target: Node2D) -> void:
	if is_instance_valid(target):
		target.queue_free()
	_destroying_targets.erase(target)

func _on_smash_animation_finished(anim_name: StringName, target: Node2D) -> void:
	if anim_name != &"smash":
		return
	if is_instance_valid(target):
		target.queue_free()
	_destroying_targets.erase(target)

func _disable_collision(root: Node) -> void:
	if root is CollisionObject2D:
		var collision_object := root as CollisionObject2D
		collision_object.set_deferred("collision_layer", 0)
		collision_object.set_deferred("collision_mask", 0)

	for child in root.find_children("*", "CollisionShape2D", true, false):
		(child as CollisionShape2D).set_deferred("disabled", true)

	for child in root.find_children("*", "CollisionPolygon2D", true, false):
		(child as CollisionPolygon2D).set_deferred("disabled", true)

extends Node2D

@export var max_hits_per_click: int = 1
@export var smash_duration: float = 0.35
@export var spin_rotations: float = 2.5
@export var shrink_scale: float = 0.2
@export var corpse_fragment_count: int = 14
@export var corpse_fragment_lifetime: float = 0.65
@export var corpse_fragment_min_size: Vector2 = Vector2(4, 4)
@export var corpse_fragment_max_size: Vector2 = Vector2(12, 12)
@export var corpse_fragment_speed: float = 220.0

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
	if _should_spawn_texture_fragments(target):
		_spawn_corpse_break_fragments(target)
		return
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


func _should_spawn_texture_fragments(target: Node2D) -> bool:
	if target.is_in_group("corpse"):
		return true
	return target.name == "DeathShapeBody"


func _spawn_corpse_break_fragments(target: Node2D) -> void:
	var source_texture := _get_corpse_texture(target)
	if not source_texture:
		if is_instance_valid(target):
			target.queue_free()
		_destroying_targets.erase(target)
		return

	var source_size := _get_corpse_texture_size(target, source_texture)
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		if is_instance_valid(target):
			target.queue_free()
		_destroying_targets.erase(target)
		return

	var fragment_parent := target.get_parent()
	if not fragment_parent:
		fragment_parent = get_tree().current_scene

	var fragment_origin := target.global_position
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

		var tween := create_tween()
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

	if is_instance_valid(target):
		target.queue_free()
	_destroying_targets.erase(target)


func _get_corpse_texture(target: Node2D) -> Texture2D:
	for child in target.get_children():
		if child is Polygon2D:
			var polygon := child as Polygon2D
			if polygon.texture:
				if polygon.texture is AtlasTexture:
					return (polygon.texture as AtlasTexture).atlas
				return polygon.texture
	return null


func _get_corpse_texture_size(target: Node2D, texture: Texture2D) -> Vector2:
	for child in target.get_children():
		if child is Polygon2D:
			var polygon := child as Polygon2D
			if polygon.texture:
				if polygon.texture is AtlasTexture:
					var atlas := polygon.texture as AtlasTexture
					return atlas.region.size
				return texture.get_size()
	return texture.get_size()

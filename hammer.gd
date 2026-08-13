extends Node2D

@export var smash_duration: float = 0.35
@export var spin_rotations: float = 2.5
@export var shrink_scale: float = 0.2

# --- Hold-to-Break Variables ---
@export var break_hold_time: float = 0.5
@export var hits_during_hold: int = 3 

var _is_holding: bool = false
var _swing_timer: float = 0.0

# Fallback dictionary for older breakables (like ceramics) that don't have their own damage script yet.
var _fallback_body_data: Dictionary = {}
var _destroying_targets: Dictionary = {}

@onready var swing_animation_player: AnimationPlayer = $SwingAnimationPlayer
@onready var progress_bar: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	z_index = 200
	progress_bar.visible = false
	progress_bar.frame = 0

func _exit_tree() -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float) -> void:
	global_position = get_global_mouse_position()
	var current_target: Node2D = _get_target_under_cursor()
	
	# 1. Handle Hover & Progress Bar Display
	if is_instance_valid(current_target) and not _destroying_targets.has(current_target):
		progress_bar.visible = true
		var p_ratio: float = 0.0
		
		# Duck Typing: Check if the target is handling its own hammer logic (like our new corpse)
		if current_target.has_method("get_hammer_progress"):
			p_ratio = current_target.get_hammer_progress(break_hold_time)
		else:
			# Fallback for old objects
			var data: Dictionary = _get_or_create_fallback_data(current_target)
			p_ratio = clamp(data.progress / break_hold_time, 0.0, 1.0)
		
		if progress_bar.sprite_frames:
			var total_frames: int = progress_bar.sprite_frames.get_frame_count("default")
			progress_bar.frame = int(p_ratio * (total_frames - 1))
	else:
		progress_bar.visible = false
		
	# 2. Handle Global Swinging & Target Damaging
	if _is_holding:
		_swing_timer += delta
		var swing_interval: float = break_hold_time / float(hits_during_hold + 1.0)
		
		# Loop the swing animation globally while holding
		if _swing_timer >= swing_interval:
			_play_swing_animation()
			_swing_timer = 0.0
			
		# Apply damage ONLY if hovering over a valid target
		if is_instance_valid(current_target) and not _destroying_targets.has(current_target):
			
			if current_target.has_method("take_hammer_damage"):
				# Let the corpse handle its own cracking and breaking!
				current_target.take_hammer_damage(delta, break_hold_time, hits_during_hold)
				
				# Trigger a final swing visually on the hammer if the corpse just maxed out
				if current_target.get_hammer_progress(break_hold_time) >= 1.0:
					_play_swing_animation()
			else:
				# FALLBACK logic for objects that don't have the take_hammer_damage method yet
				var data: Dictionary = _get_or_create_fallback_data(current_target)
				data.progress += delta
				var p_ratio: float = clamp(data.progress / break_hold_time, 0.0, 1.0)
				
				if p_ratio >= data.next_threshold and p_ratio < 1.0:
					_spawn_procedural_crack(data.cracks_node)
					data.next_threshold += 1.0 / (hits_during_hold + 1.0)
				
				if data.progress >= break_hold_time:
					_play_swing_animation()
					_start_smash_animation(current_target)
					_fallback_body_data.erase(current_target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_holding = true
			_swing_timer = break_hold_time # Force an immediate swing on click
		else:
			_is_holding = false
			_swing_timer = 0.0

func _get_target_under_cursor() -> Node2D:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hits := space_state.intersect_point(query, 32)
	for hit in hits:
		var collider: Node = hit.get("collider")
		
		# --- ADD THIS PRINT ---
		print("HAMMER HIT: ", collider.name, " | Script: ", collider.get_script())
		
		var smashable_target := _find_smashable_target(collider)
		if smashable_target:
			
			# --- ADD THIS PRINT ---
			print("TARGET CHOSEN: ", smashable_target.name, " | Script: ", smashable_target.get_script())
			
			return smashable_target
			
	return null

func _play_swing_animation() -> void:
	swing_animation_player.stop()
	swing_animation_player.play("swing")

func _find_smashable_target(start_node: Node) -> Node2D:
	var current: Node = start_node
	
	# PASS 1: Prioritize looking for our new script up the tree
	while current:
		if current.has_method("take_hammer_damage"):
			return current as Node2D
		current = current.get_parent()
		
	# PASS 2: If we didn't find the new script, look for the old legacy targets
	current = start_node
	while current:
		if current is Node2D and (current.is_in_group("hammer_smashable") or current.name == "DeathShapeBody" or current.is_in_group("corpse")):
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

# ==========================================
# FALLBACK LOGIC FOR OLDER NON-CORPSE OBJECTS
# ==========================================
func _get_or_create_fallback_data(target: Node2D) -> Dictionary:
	if not _fallback_body_data.has(target):
		var cracks = Node2D.new()
		target.add_child(cracks)
		_fallback_body_data[target] = {
			"progress": 0.0,
			"next_threshold": 1.0 / (hits_during_hold + 1.0),
			"cracks_node": cracks
		}
	return _fallback_body_data[target]

func _spawn_procedural_crack(crack_parent: Node2D) -> void:
	if not is_instance_valid(crack_parent): return
	var crack := Line2D.new()
	crack.width = randf_range(1.5, 3.5)
	crack.default_color = Color(0.05, 0.05, 0.05, 0.95)
	crack.joint_mode = Line2D.LINE_JOINT_SHARP
	crack.begin_cap_mode = Line2D.LINE_CAP_ROUND
	crack.end_cap_mode = Line2D.LINE_CAP_ROUND
	var current_pos := Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
	crack.add_point(current_pos)
	var main_dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	var segments := randi_range(2, 4)
	for i in range(segments):
		var angle_offset: float = randf_range(-0.6, 0.6)
		current_pos += main_dir.rotated(angle_offset) * randf_range(6.0, 14.0)
		crack.add_point(current_pos)
	crack_parent.add_child(crack)

func _start_smash_animation(target: Node2D) -> void:
	if _destroying_targets.has(target): return
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
	if is_instance_valid(target): target.queue_free()
	_destroying_targets.erase(target)

func _on_smash_animation_finished(anim_name: StringName, target: Node2D) -> void:
	if anim_name != &"smash": return
	if is_instance_valid(target): target.queue_free()
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

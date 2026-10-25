extends Sprite2D
# Member variables (place these near the top of your script)
var active_clone: Sprite2D = null
var can_spawn: bool = true

func summon_clone() -> void:
	if not can_spawn:
		return

	if is_instance_valid(active_clone):
		active_clone.queue_free()
		active_clone = null

	# Duplicate the sprite and capture its world position.
	var clone = self.duplicate() as Sprite2D
	var current_pos = global_position
	
	# Add to main scene root so the flag stays where it was placed.
	get_tree().current_scene.add_child(clone)
	
	# Position it, make it visible, and strip its script.
	clone.global_position = current_pos
	clone.visible = true
	clone.set_script(null)
	
	# Track this new clone as the active flag.
	active_clone = clone
	
	await _play_flag_animation()

func teleport_to_flag() -> void:
	if not can_spawn or not is_instance_valid(active_clone):
		return

	_teleport_to_flag()
	await _play_flag_animation()

func _teleport_to_flag() -> void:
	var player := get_parent().get_parent() as Node2D
	if not player or not is_instance_valid(active_clone):
		return

	var teleport_offset := active_clone.global_position - global_position
	if player.has_method("teleport_by"):
		player.teleport_by(teleport_offset)
	else:
		player.global_position += teleport_offset

func _play_flag_animation() -> void:
	can_spawn = false
	var flag_animation := get_node_or_null("/root/HUD/FlagAnimation") as AnimatedSprite2D
	var hud_flag := get_node_or_null("/root/HUD/Container/FLAG") as Sprite2D
	if not flag_animation:
		can_spawn = true
		return

	if hud_flag:
		hud_flag.modulate.a = 0.2

	flag_animation.stop()
	flag_animation.frame = 0
	flag_animation.play("default")
	await flag_animation.animation_finished
	if hud_flag:
		hud_flag.modulate.a = 1.0
	can_spawn = true

func _ready() -> void:
	var hud_flag := get_node_or_null("/root/HUD/Container/FLAG") as Sprite2D
	if hud_flag:
		hud_flag.modulate.a = 1.0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_handle_input_controls(1)

func _handle_input_controls(delta: float) -> void:
	if Input.is_action_just_pressed("flag"):
		summon_clone()
	elif Input.is_action_just_pressed("flagspawn"):
		teleport_to_flag()
		

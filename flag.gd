extends Sprite2D
# Member variables (place these near the top of your script)
var active_clone: Sprite2D = null
var can_spawn: bool = true
@export var cooldown_time: float = 1.0  # Adjust this in seconds as needed

func summon_clone() -> void:
	# 1. Block spawning if we are still on cooldown
	if not can_spawn:
		return
	
	# 2. If a previous clone already exists, destroy it immediately
	if is_instance_valid(active_clone):
		active_clone.queue_free()
		active_clone = null
	
	# 3. Duplicate the sprite and capture its world position
	var clone = self.duplicate() as Sprite2D
	var current_pos = global_position
	
	# 4. Add to main scene root (detaching from the moving parent)
	get_tree().current_scene.add_child(clone)
	
	# 5. Position it, make it visible, and strip its script
	clone.global_position = current_pos
	clone.visible = true
	clone.set_script(null)
	
	# Track this new clone as the active one
	active_clone = clone
	
	# 6. Start the cooldown timer
	can_spawn = false
	get_tree().create_timer(cooldown_time).timeout.connect(func():
		can_spawn = true
	)

func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_handle_input_controls(1)

func _handle_input_controls(delta: float) -> void:
	if Input.is_action_just_pressed("flag"):
		summon_clone()
		

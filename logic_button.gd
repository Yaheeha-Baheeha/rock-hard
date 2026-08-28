extends SignalEmitter

@export var pulse_duration: float = 2.0 ## How long the button stays pressed
var player_in_range: bool = false

@export_category("Visuals")
@export var texture_on: Texture2D ## Drag your pressed sprite here
@export var texture_off: Texture2D ## Drag your unpressed sprite here

@onready var sprite = $Sprite2D # Make sure this matches the exact name of your Sprite node!
@onready var timer = $ActiveTimer

# Audio Node References
@onready var sfx_fail: AudioStreamPlayer2D = $Fail
@onready var sfx_pressed: AudioStreamPlayer2D = $Pressed
@onready var sfx_tick: AudioStreamPlayer2D = $Tick


func _on_interaction_range_body_entered(body: Node2D) -> void:
	# Make sure your player character is in the "player" group!
	if body.is_in_group("player"):
		player_in_range = true

func _on_interaction_range_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var is_click = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	
	if is_click:
		if not player_in_range:
			# Play Fail audio when clicked outside the interaction range
			sfx_fail.play()
		elif not is_active:
			# 1. Turn ON and play initial press sound
			set_state(true) 
			_update_visuals()
			sfx_pressed.play()
			
			# Start the timing phase sound
			sfx_tick.play()
			
			# 2. WAIT for pulse duration
			await get_tree().create_timer(pulse_duration).timeout
			
			# 3. Turn OFF and stop ticking sound
			sfx_tick.stop()
			set_state(false)
			_update_visuals()

func _update_visuals() -> void:
	if sprite == null:
		return
		
	if is_active:
		sprite.texture = texture_on
	else:
		sprite.texture = texture_off

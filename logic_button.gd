extends SignalEmitter

@export var pulse_duration: float = 2.0 ## How long the button stays pressed
var player_in_range: bool = false
@export_category("Visuals")
@export var texture_on: Texture2D ## Drag your pressed sprite here
@export var texture_off: Texture2D ## Drag your unpressed sprite here

@onready var sprite = $Sprite2D # Make sure this matches the exact name of your Sprite node!

@onready var timer = $ActiveTimer


func _on_interaction_range_body_entered(body: Node2D) -> void:
	# Make sure your player character is in the "player" group!
	if body.is_in_group("player"):
		player_in_range = true

func _on_interaction_range_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("The Area2D heard a click!")
		print("Is player in range? ", player_in_range)
		
	var is_click = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	
	if is_click and player_in_range and not is_active:
		# 1. Turn ON
		set_state(true) 
		_update_visuals()
		
		# 2. WAIT
		await get_tree().create_timer(pulse_duration).timeout
		
		# 3. Turn OFF
		set_state(false)
		_update_visuals()

func _update_visuals() -> void:
	if sprite == null:
		return
		
	if is_active:
		sprite.texture = texture_on
	else:
		sprite.texture = texture_off

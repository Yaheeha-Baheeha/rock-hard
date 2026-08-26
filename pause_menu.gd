extends ColorRect


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().paused = false
	visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _input(event: InputEvent) -> void:
	if Input.is_action_pressed("pause"):
		if get_tree().paused == false:
			get_tree().paused = true
			visible = true
		else:
			get_tree().paused = false
			visible = false

func _on_back_pressed() -> void:
	get_tree().paused = false
	visible = false

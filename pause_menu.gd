extends ColorRect

@onready var settings = $"../Settings"
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
		elif settings.visible == true:
			_on_back_2_pressed()
		elif get_tree().paused == true and settings.visible == false:
			get_tree().paused = false
			visible = false

func _on_back_pressed() -> void:
	get_tree().paused = false
	visible = false


func _on_menu_pressed() -> void:
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file("res://menu.tscn")


func _on_settings_pressed() -> void:
	visible = false
	settings.visible = true
	get_tree().paused = true
	


func _on_back_2_pressed() -> void:
	settings.visible = false
	visible = true

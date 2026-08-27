extends ColorRect

@onready var settings = $"../Settings"
@onready var hover_sound = $"../HoverSound"
@onready var click_sound = $"../Click"

func _ready() -> void:
	get_tree().paused = false
	visible = false
	
	# Connect hover sounds to buttons in PauseMenu and Settings automatically
	_connect_hover_sounds(self)
	if settings:
		_connect_hover_sounds(settings)

func _connect_hover_sounds(parent_node: Node) -> void:
	for child in parent_node.get_children():
		if child is BaseButton:
			child.mouse_entered.connect(_play_hover_sound)
		if child.get_child_count() > 0:
			_connect_hover_sounds(child)

func _play_hover_sound() -> void:
	if hover_sound and hover_sound.stream:
		hover_sound.stop()
		hover_sound.play()

func _play_click_sound() -> void:
	if click_sound and click_sound.stream:
		click_sound.stop()
		click_sound.play()

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
	_play_click_sound()
	get_tree().paused = false
	visible = false

func _on_menu_pressed() -> void:
	_play_click_sound()
	if click_sound and click_sound.stream:
		await click_sound.finished
	get_tree().paused = false
	visible = false
	if GameManager:
		GameManager.reset_temporary_collectibles()
	get_tree().change_scene_to_file("res://menu.tscn")

func _on_settings_pressed() -> void:
	_play_click_sound()
	visible = false
	settings.visible = true
	get_tree().paused = true

func _on_back_2_pressed() -> void:
	_play_click_sound()
	settings.visible = false
	visible = true

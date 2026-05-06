extends Control

# Which levels are unlocked (by default only level 1).
# Replace this later with a save-system lookup.
var unlocked_levels: int = 1

@onready var grid: GridContainer = %LevelGrid
@onready var back_button: TextureButton = %BackButton


func _ready() -> void:
	_configure_level_buttons()
	back_button.pressed.connect(_on_back_pressed)


func _configure_level_buttons() -> void:
	for i in range(grid.get_child_count()):
		var btn := grid.get_child(i) as TextureButton
		if btn == null:
			continue

		var level := i + 1
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(64, 64)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.disabled = level > unlocked_levels
		if not btn.disabled:
			btn.pressed.connect(_on_level_pressed.bind(level))


func _on_level_pressed(level: int) -> void:
	var scene_path := "res://level_%d.tscn" % level
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		push_warning("Level scene not found: %s" % scene_path)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")

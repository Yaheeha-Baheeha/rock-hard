extends Control

# Which levels are unlocked (by default only level 1).
# Replace this later with a save-system lookup.
var unlocked_levels: int = 1

@onready var grid: GridContainer = %LevelGrid
@onready var back_button: TextureButton = %BackButton


func _ready() -> void:
	_populate_levels()
	back_button.pressed.connect(_on_back_pressed)


func _populate_levels() -> void:
	for i in range(1, 29):
		var idx := i - 1
		var btn := TextureButton.new()
		btn.texture_normal = load("res://level_icons/normal/level_%d.png" % idx)
		btn.texture_pressed = load("res://level_icons/pressed/pressed_%d.png" % idx)
		btn.texture_hover = load("res://level_icons/overlayed/overlayed%d.png" % idx)
		btn.texture_focused = load("res://level_icons/focused/focused_%d.png" % idx)
		btn.texture_disabled = load("res://level_icons/disabled/disabled_%d.png" % idx)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(64, 64)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if i <= unlocked_levels:
			btn.pressed.connect(_on_level_pressed.bind(i))
		else:
			btn.disabled = true
		grid.add_child(btn)


func _on_level_pressed(level: int) -> void:
	print("Loading level ", level)
	# TODO: load the actual level scene, e.g.:
	#get_tree().change_scene_to_file("res://levels/level_{i}.tscn" % level)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")

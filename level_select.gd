extends Control

# Which levels are unlocked (by default only level 1).
# Replace this later with a save-system lookup.
var unlocked_levels: int = 1

@onready var grid: GridContainer = %LevelGrid
@onready var back_button: Button = %BackButton


func _ready() -> void:
	_populate_levels()
	back_button.pressed.connect(_on_back_pressed)


func _populate_levels() -> void:
	for i in range(1, 29):
		var btn := Button.new()
		btn.text = str(i)
		btn.custom_minimum_size = Vector2(64, 64)
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

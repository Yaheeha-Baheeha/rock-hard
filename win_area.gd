extends Sprite2D

@export var next_level_number: int = 2

func _ready():
	add_to_group("win_zones")

func trigger_win():
	print("Player detected!")
	GameManager.unlock_level(next_level_number)
	get_tree().change_scene_to_file("res://menu.tscn")

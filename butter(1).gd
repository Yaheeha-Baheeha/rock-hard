extends Sprite2D

@export var next_level_number: int = 2
var has_won: bool = false

func _ready():
	add_to_group("win_zones")

func trigger_win():
	if has_won:
		return
	has_won = true
	print("Player detected!")
	GameManager.unlock_level(next_level_number)
	get_tree().call_deferred("change_scene_to_file", "res://WIN.tscn")

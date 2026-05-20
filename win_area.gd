extends Sprite2D

@export var next_level_number: int = 2

func _ready():
	# Ensure there is an Area2D child
	var area_2d = find_child("Area2D")
	if area_2d and area_2d is Area2D:
		print("Area2D found, connecting signal.")
		area_2d.body_entered.connect(_on_body_entered)
	else:
		print("Error: No Area2D child found for win_area.gd")

func _on_body_entered(body):
	print("Body entered: ", body.name)
	if body.owner and body.owner.name == "Player":
		print("Player detected!")
		GameManager.unlock_level(next_level_number)
		get_tree().change_scene_to_file("res://menu.tscn")
	else:
		print("Body is not the player.")

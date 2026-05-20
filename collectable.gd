extends Sprite2D

@export var level_number: int = 1

func _ready():
	var area_2d = find_child("Area2D")
	if area_2d and area_2d is Area2D:
		area_2d.body_entered.connect(_on_body_entered)
	else:
		print("Error: No Area2D child found for collectable.gd")

func _on_body_entered(body):
	if body.owner and body.owner.name == "Player":
		var collectable_id = "collectable in level_%d" % level_number
		GameManager.add_collectable(collectable_id)
		queue_free()

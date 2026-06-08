extends Sprite2D

@export var level_number: int = 1

func _ready():
	add_to_group("collectibles")

func trigger_collection():
	var collectable_id = "collectable in level_%d" % level_number
	GameManager.add_collectable(collectable_id)
	queue_free()

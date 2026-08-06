extends Node2D

@export var level_number: int = 1
@export var collectible_key: String = ""

func _ready():
	add_to_group("collectibles")

func trigger_collection():
	var collectable_id = collectible_key if collectible_key != "" else "collectable in level_%d" % level_number
	GameManager.add_collectable(collectable_id)
	queue_free()

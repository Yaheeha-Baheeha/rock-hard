extends Node2D

@export var level_number: int = 1
@export var collectible_key: String = ""
@export var pickup_radius: float = 100.0 ## Adjust this in the Inspector for a tighter hitbox!

var _player_node: Node2D

func _ready():
	add_to_group("collectibles")
	# Grab a reference to the player when the level loads
	_player_node = get_tree().get_first_node_in_group("player")

func _process(_delta):
	if not is_instance_valid(_player_node): 
		return
		
	# Check the exact distance from the item to the center of the player
	var distance_to_player = global_position.distance_to(_player_node.center_tracker.global_position)
	
	if distance_to_player <= pickup_radius:
		trigger_collection()

func trigger_collection():
	var collectable_id = collectible_key if collectible_key != "" else "collectable in level_%d" % level_number
	GameManager.add_collectable(collectable_id)
	queue_free()

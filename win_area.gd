extends Sprite2D

@export var next_level_number: int = 2
@export var win_radius: float = 120.0 ## Adjust this in the Inspector!

var has_won: bool = false
var _player_node: Node2D
@onready var chime = $Chime

func _ready():
	add_to_group("win_zones")
	_player_node = get_tree().get_first_node_in_group("player")
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta):
	if has_won or not is_instance_valid(_player_node): 
		return
		
	var distance_to_player = global_position.distance_to(_player_node.center_tracker.global_position)
	
	if distance_to_player <= win_radius:
		trigger_win()

func trigger_win():
	has_won = true
	print("Player detected!")
	GameManager.unlock_level(next_level_number)
	var anim = _player_node.get_node("CenterTracker/LavaDetector/CollisionShape2D/AnimatedSprite2D")
	
	if anim:
		anim.show()
		get_tree().paused = true
		if chime:
			chime.play()
		anim.play("default")
		await anim.animation_finished
		anim.hide()
		get_tree().paused = false
		
	get_tree().call_deferred("change_scene_to_file", "res://menu.tscn")

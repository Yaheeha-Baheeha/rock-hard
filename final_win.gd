extends Sprite2D

@export var win_radius: float = 120.0 ## Radius distance to trigger win condition
@export_file("*.tscn") var win_scene_path: String = "res://menu.tscn" ## Scene to change to on win

var has_won: bool = false
var _player_node: Node2D

@onready var chime = get_node_or_null("Chime")
@onready var animationplayer = get_node_or_null("AnimationPlayer")
@onready var area_2d = get_node_or_null("Area2D")

func _ready() -> void:
	add_to_group("win_zones")
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect collision detection signals if Area2D exists
	if area_2d:
		area_2d.body_entered.connect(_on_area_entered)
		area_2d.area_entered.connect(_on_area_entered)

func _process(_delta: float) -> void:
	if has_won:
		return
		
	# Continuously attempt to find the player if not cached yet
	if not is_instance_valid(_player_node):
		_player_node = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(_player_node):
			return

	# Use Area2D global position if present (in case child Area2D is offset from parent)
	var win_center = area_2d.global_position if area_2d else global_position
	
	# Target the player's center tracker position
	var target_pos = _player_node.global_position
	if _player_node.has_node("CenterTracker"):
		target_pos = _player_node.get_node("CenterTracker").global_position
		
	var distance_to_player = win_center.distance_to(target_pos)
	if distance_to_player <= win_radius:
		trigger_win()

func _on_area_entered(node: Node) -> void:
	if has_won:
		return
	# Trigger win if player body or soft body point enters the area
	if node.is_in_group("player") or (node.get_parent() and node.get_parent().is_in_group("player")):
		trigger_win()

func trigger_win() -> void:
	if has_won:
		return
	has_won = true
	
	if animationplayer:
		animationplayer.stop()
		
	if not is_instance_valid(_player_node):
		_player_node = get_tree().get_first_node_in_group("player")
		
	if is_instance_valid(_player_node):
		var anim = _player_node.get_node_or_null("CenterTracker/LavaDetector/CollisionShape2D/AnimatedSprite2D")
		if anim:
			anim.show()
			get_tree().paused = true
			if chime:
				chime.play()
			anim.play("default")
			await anim.animation_finished
			anim.hide()
			get_tree().paused = false

	get_tree().call_deferred("change_scene_to_file", win_scene_path)

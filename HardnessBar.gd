extends CanvasLayer

@onready var progress_bar: AnimatedSprite2D = $TextureProgressBar/Progress
@onready var pentagon_slot: TextureButton = $PentagonSlot
@onready var hexagon_slot: TextureButton = $HexagonSlot
@onready var rectangle_slot: TextureButton = $RectangleSlot
@onready var circle_slot: TextureButton = $CircleSlot

var selected_slot_index: int = 0

var player_node: Node = null
var progress_start_x: float = 0.0
var progress_travel_x: float = 128.0

func _ready() -> void:
	progress_bar.play("default")
	progress_start_x = progress_bar.position.x
	
	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_signal("collectable_added"):
		game_manager.collectable_added.connect(_on_collectable_added)
	
	pentagon_slot.pressed.connect(_on_slot_pressed.bind(0))
	hexagon_slot.pressed.connect(_on_slot_pressed.bind(1))
	rectangle_slot.pressed.connect(_on_slot_pressed.bind(2))
	circle_slot.pressed.connect(_on_slot_pressed.bind(3))
	
	_refresh_collectible_slots()
	_update_selected_slot(0)
	_sync_scene_visibility()

func _process(_delta: float) -> void:
	_sync_scene_visibility()
	_sync_stiffness_meter()
	_refresh_collectible_slots()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_update_selected_slot(0)
		elif event.keycode == KEY_2:
			_update_selected_slot(1)
		elif event.keycode == KEY_3:
			_update_selected_slot(2)
		elif event.keycode == KEY_4:
			_update_selected_slot(3)

func _on_collectable_added(_item_name: String) -> void:
	_refresh_collectible_slots()

func _sync_scene_visibility() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		visible = false
		return

	var scene_path := current_scene.scene_file_path
	visible = not (scene_path.ends_with("menu.tscn") or scene_path.ends_with("level_select.tscn"))

func _refresh_collectible_slots() -> void:
	if not has_node("/root/GameManager"):
		return

	var game_manager := get_node("/root/GameManager")
	pentagon_slot.visible = game_manager.has_collectable("pentagon")
	hexagon_slot.visible = game_manager.has_collectable("hexagon")
	rectangle_slot.visible = game_manager.has_collectable("rectangle")
	circle_slot.visible = pentagon_slot.visible or hexagon_slot.visible or rectangle_slot.visible

	if pentagon_slot.visible or hexagon_slot.visible or rectangle_slot.visible or circle_slot.visible:
		if not _is_slot_visible(selected_slot_index):
			_update_selected_slot(_first_visible_slot_index())

func _sync_stiffness_meter() -> void:
	if not progress_bar:
		return

	if player_node == null or not is_instance_valid(player_node):
		player_node = get_tree().get_first_node_in_group("player")

	if player_node == null:
		return

	var stiffness_value = player_node.get("current_stiffness_percent")
	if stiffness_value == null:
		return

	var stiffness_percent: float = clamp(float(stiffness_value), 0.0, 1.0)
	var target_x := progress_start_x - (progress_travel_x * stiffness_percent)
	progress_bar.position.x = target_x

func _on_slot_pressed(index: int) -> void:
	if _is_slot_visible(index):
		_update_selected_slot(index)

func _update_selected_slot(index: int) -> void:
	if not _is_slot_visible(index):
		index = _first_visible_slot_index()
	selected_slot_index = index
	pentagon_slot.modulate = Color(1, 1, 1, 0.65)
	hexagon_slot.modulate = Color(1, 1, 1, 0.65)
	rectangle_slot.modulate = Color(1, 1, 1, 0.65)
	circle_slot.modulate = Color(1, 1, 1, 0.65)
	if selected_slot_index == 0:
		pentagon_slot.modulate = Color(1.0, 1.0, 0.75, 1.0)
	elif selected_slot_index == 1:
		hexagon_slot.modulate = Color(1.0, 1.0, 0.75, 1.0)
	elif selected_slot_index == 2:
		rectangle_slot.modulate = Color(1.0, 1.0, 0.75, 1.0)
	elif selected_slot_index == 3:
		circle_slot.modulate = Color(1.0, 1.0, 0.75, 1.0)

func _is_slot_visible(index: int) -> bool:
	match index:
		0:
			return pentagon_slot.visible
		1:
			return hexagon_slot.visible
		2:
			return rectangle_slot.visible
		3:
			return circle_slot.visible
		_:
			return false

func _first_visible_slot_index() -> int:
	if pentagon_slot.visible:
		return 0
	if hexagon_slot.visible:
		return 1
	if rectangle_slot.visible:
		return 2
	if circle_slot.visible:
		return 3
	return 0

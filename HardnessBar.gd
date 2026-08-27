extends CanvasLayer

# --- HUD VARIABLES ---
@onready var progress_bar: AnimatedSprite2D = $TextureProgressBar/Progress
@onready var triangle_slot: TextureButton = $TriangleSlot
@onready var hexagon_slot: TextureButton = $HexagonSlot
@onready var rectangle_slot: TextureButton = $RectangleSlot
@onready var circle_slot: TextureButton = $CircleSlot

# --- SETTINGS & FILTER VARIABLES ---
@onready var filters: ColorRect = $Filters

@onready var mode_slider: VSlider = $Settings/BoxContainer/VBoxContainer3/ColorBlindness/VSlider
@onready var intensity_slider: VSlider = $Settings/BoxContainer/VBoxContainer3/ColorBlindness/VSlider2

@onready var master_slider: HSlider = $Settings/BoxContainer/Audio/HSlider
@onready var sfx_slider: HSlider = $Settings/BoxContainer/Audio/HSlider2
@onready var env_slider: HSlider = $Settings/BoxContainer/Audio/HSlider3
@onready var player_slider: HSlider = $Settings/BoxContainer/Audio/HSlider4
@onready var music_slider: HSlider = $Settings/BoxContainer/Audio/HSlider5

var selected_slot_index: int = 1 
var player_node: Node = null
var progress_start_x: float = 0.0
var progress_travel_x: float = 128.0

func _ready() -> void:
	progress_bar.play("default")
	progress_start_x = progress_bar.position.x
	GameManager.reset_temporary_collectibles()
	if GameManager and GameManager.has_signal("collectable_added"):
		GameManager.collectable_added.connect(_on_collectable_added)
	
	triangle_slot.pressed.connect(_on_slot_pressed.bind(0))
	circle_slot.pressed.connect(_on_slot_pressed.bind(1))
	rectangle_slot.pressed.connect(_on_slot_pressed.bind(2))
	hexagon_slot.pressed.connect(_on_slot_pressed.bind(3))
	
	_refresh_collectible_slots()
	_update_selected_slot(1)
	_sync_scene_visibility()
	
	# Wire up the settings sliders
	_init_settings()

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
	triangle_slot.visible = game_manager.has_collectable("triangle")
	circle_slot.visible = triangle_slot.visible or hexagon_slot.visible or rectangle_slot.visible
	rectangle_slot.visible = game_manager.has_collectable("rectangle")
	hexagon_slot.visible = game_manager.has_collectable("hexagon")

	if triangle_slot.visible or hexagon_slot.visible or rectangle_slot.visible or circle_slot.visible:
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
	
	triangle_slot.modulate = Color(1, 1, 1, 0.65)
	circle_slot.modulate = Color(1, 1, 1, 0.65)
	rectangle_slot.modulate = Color(1, 1, 1, 0.65)
	hexagon_slot.modulate = Color(1, 1, 1, 0.65)
	
	if selected_slot_index == 0:
		triangle_slot.modulate = Color(1.0, 1.0, 0.75, 1.0)
	elif selected_slot_index == 1:
		circle_slot.modulate = Color(1.0, 1.0, 0.75, 1.0)
	elif selected_slot_index == 2:
		rectangle_slot.modulate = Color(1.0, 1.0, 0.75, 1.0)
	elif selected_slot_index == 3:
		hexagon_slot.modulate = Color(1.0, 1.0, 0.75, 1.0)

	if player_node == null or not is_instance_valid(player_node):
		player_node = get_tree().get_first_node_in_group("player")
		
	if player_node and player_node.has_method("set_player_shape"):
		player_node.set_player_shape(selected_slot_index)

func _is_slot_visible(index: int) -> bool:
	match index:
		0: return triangle_slot.visible
		1: return circle_slot.visible
		2: return rectangle_slot.visible
		3: return hexagon_slot.visible
		_: return false

func _first_visible_slot_index() -> int:
	if triangle_slot.visible: return 0
	if circle_slot.visible: return 1
	if rectangle_slot.visible: return 2
	if hexagon_slot.visible: return 3
	return 1

# ==========================================
# --- SETTINGS, AUDIO, AND FILTERS LOGIC ---
# ==========================================

func _init_settings() -> void:
	var gm = get_node_or_null("/root/GameManager")
	filters.material.set_shader_parameter("intensity", 0)
	filters.material.set_shader_parameter("mode", 2)
	if not gm:
		return
		
	# 1. Set slider values from GameManager data without triggering signals yet
	mode_slider.value = gm.settings_data["colorblind_mode"]
	intensity_slider.value = gm.settings_data["colorblind_intensity"]
	
	master_slider.value = gm.settings_data["volume_master"]
	sfx_slider.value = gm.settings_data["volume_SFX"]
	env_slider.value = gm.settings_data["volume_Enviroment"]
	player_slider.value = gm.settings_data["volume_Player"]
	music_slider.value = gm.settings_data["volume_Music"]

	# Apply shader settings immediately on launch
	_on_mode_changed(mode_slider.value)
	_on_intensity_changed(intensity_slider.value)

	# 2. Connect signals for runtime changes
	mode_slider.value_changed.connect(_on_mode_changed)
	intensity_slider.value_changed.connect(_on_intensity_changed)
	
	master_slider.value_changed.connect(func(val): _update_audio_setting("master", "volume_master", val))
	sfx_slider.value_changed.connect(func(val): _update_audio_setting("SFX", "volume_SFX", val))
	env_slider.value_changed.connect(func(val): _update_audio_setting("Enviroment", "volume_Enviroment", val))
	player_slider.value_changed.connect(func(val): _update_audio_setting("Player", "volume_Player", val))
	music_slider.value_changed.connect(func(val): _update_audio_setting("Music", "volume_Music", val))

func _on_mode_changed(value: float) -> void:
	var mode_int = int(value)
	if filters and filters.material:
		filters.material.set_shader_parameter("mode", mode_int)
	
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.settings_data["colorblind_mode"] != mode_int:
		gm.settings_data["colorblind_mode"] = mode_int
		gm.save_game()

func _on_intensity_changed(value: float) -> void:
	if filters and filters.material:
		filters.material.set_shader_parameter("intensity", value)
		
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.settings_data["colorblind_intensity"] != value:
		gm.settings_data["colorblind_intensity"] = value
		gm.save_game()

func _update_audio_setting(bus_name: String, setting_key: String, linear_value: float) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm._apply_bus_volume(bus_name, linear_value)
		gm.settings_data[setting_key] = linear_value
		gm.save_game()

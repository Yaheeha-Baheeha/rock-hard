extends Control

# --- AUDIO & FILTERS ---
@onready var filters: ColorRect = $Filters
@onready var hover_sound: AudioStreamPlayer2D = $HoverSound
@onready var click_sound: AudioStreamPlayer2D = $Click

# --- SETTINGS SLIDERS ---
@onready var mode_slider: VSlider = $Settings/BoxContainer/VBoxContainer3/ColorBlindness/VSlider
@onready var intensity_slider: VSlider = $Settings/BoxContainer/VBoxContainer3/ColorBlindness/VSlider2
@onready var master_slider: HSlider = $Settings/BoxContainer/Audio/HSlider
@onready var sfx_slider: HSlider = $Settings/BoxContainer/Audio/HSlider2
@onready var env_slider: HSlider = $Settings/BoxContainer/Audio/HSlider3
@onready var player_slider: HSlider = $Settings/BoxContainer/Audio/HSlider4
@onready var music_slider: HSlider = $Settings/BoxContainer/Audio/HSlider5

func _ready() -> void:
	_init_settings()
	_connect_hover_sounds(self)

# --- BUTTON ACTIONS WITH AUDIO AWAIT ---

func _on_play_pressed() -> void:
	await _play_click_sound()
	get_tree().change_scene_to_file("res://level_select.tscn")

func _on_quit_pressed() -> void:
	await _play_click_sound()
	get_tree().quit()

func _on_settings_pressed() -> void:
	_play_click_sound()
	$VBoxContainer.visible = false
	$Settings.visible = true

func _on_back_2_pressed() -> void:
	_play_click_sound()
	$Settings.visible = false
	$VBoxContainer.visible = true

# --- AUDIO & HOVER LOGIC ---

func _play_click_sound() -> void:
	if click_sound and click_sound.stream:
		click_sound.stop()
		click_sound.play()
		await click_sound.finished

func _play_hover_sound() -> void:
	if hover_sound and hover_sound.stream:
		hover_sound.stop()
		hover_sound.play()

func _connect_hover_sounds(parent_node: Node) -> void:
	for child in parent_node.get_children():
		if child is BaseButton:
			child.mouse_entered.connect(_play_hover_sound)
		if child.get_child_count() > 0:
			_connect_hover_sounds(child)

# --- SETTINGS LOGIC ---

func _init_settings() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm: return
		
	mode_slider.value = gm.settings_data["colorblind_mode"]
	intensity_slider.value = gm.settings_data["colorblind_intensity"]
	master_slider.value = gm.settings_data["volume_master"]
	sfx_slider.value = gm.settings_data["volume_SFX"]
	env_slider.value = gm.settings_data["volume_Enviroment"]
	player_slider.value = gm.settings_data["volume_Player"]
	music_slider.value = gm.settings_data["volume_Music"]

	_on_mode_changed(mode_slider.value)
	_on_intensity_changed(intensity_slider.value)

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

extends Control

@onready var grid: GridContainer = %LevelGrid
@onready var back_button: TextureButton = %BackButton
@onready var filters: ColorRect = $Filters

@onready var hover_sound: AudioStreamPlayer2D = $HoverSound
@onready var no_hover_sound: AudioStreamPlayer2D = $NoHoverSound
@onready var click_sound: AudioStreamPlayer2D = $Click
@onready var no_click_sound: AudioStreamPlayer2D = $NoClick

const STAR_TEXTURE: Texture2D = preload("res://Textures/star.png")
var star_badges: Dictionary = {}

func _ready() -> void:
	_configure_level_buttons()
	_refresh_star_badges()
	_apply_filter_settings()
	
	back_button.pressed.connect(_on_back_pressed)
	back_button.mouse_entered.connect(_play_hover_sound)
	
	if GameManager.has_signal("collectable_added"):
		GameManager.collectable_added.connect(_on_collectable_added)


func _on_level_pressed(level: int) -> void:
	if GameManager.is_level_unlocked(level):
		await _play_click_sound() # Wait for audio before switching scene
		var scene_path := "res://level_%d.tscn" % level
		if ResourceLoader.exists(scene_path):
			get_tree().change_scene_to_file(scene_path)
		else:
			push_warning("Level scene not found: %s" % scene_path)
	else:
		_play_no_click_sound()

func _on_back_pressed() -> void:
	await _play_click_sound() # Wait for audio before switching scene
	if GameManager:
		GameManager.reset_temporary_collectibles()
	get_tree().change_scene_to_file("res://menu.tscn")

func _play_click_sound() -> void:
	if click_sound and click_sound.stream:
		click_sound.stop()
		click_sound.play()
		await click_sound.finished

func _play_no_click_sound() -> void:
	if no_click_sound and no_click_sound.stream:
		no_click_sound.stop()
		no_click_sound.play()


func _apply_filter_settings() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not filters or not filters.material:
		return
		
	var mode_int: int = gm.settings_data.get("colorblind_mode", 0)
	var intensity_val: float = gm.settings_data.get("colorblind_intensity", 1.0)
	
	filters.material.set_shader_parameter("mode", mode_int)
	filters.material.set_shader_parameter("intensity", intensity_val)


func _configure_level_buttons() -> void:
	for i in range(grid.get_child_count()):
		var btn := grid.get_child(i) as TextureButton
		if btn == null:
			continue

		var level := i + 1
		var is_unlocked := GameManager.is_level_unlocked(level)
		
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(64, 64)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.disabled = not is_unlocked
		
		# Connect the appropriate hover sound based on unlock state
		if is_unlocked:
			btn.pressed.connect(_on_level_pressed.bind(level))
			btn.mouse_entered.connect(_play_hover_sound)
		else:
			btn.mouse_entered.connect(_play_no_hover_sound)

		_ensure_star_badge(btn, level)


func _play_hover_sound() -> void:
	if hover_sound and hover_sound.stream:
		hover_sound.stop()
		hover_sound.play()


func _play_no_hover_sound() -> void:
	if no_hover_sound and no_hover_sound.stream:
		no_hover_sound.stop()
		no_hover_sound.play()


func _ensure_star_badge(btn: TextureButton, level: int) -> void:
	if star_badges.has(level):
		return

	var star := TextureRect.new()
	star.name = "StarBadge"
	star.texture = STAR_TEXTURE
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	star.visible = false
	btn.add_child(star)
	star_badges[level] = star


func _refresh_star_badges() -> void:
	for level in star_badges.keys():
		var star := star_badges[level] as TextureRect
		if star:
			star.visible = GameManager.has_level_collectable(int(level))


func _on_collectable_added(_item_name: String) -> void:
	_refresh_star_badges()

extends Control

@onready var grid: GridContainer = %LevelGrid
@onready var back_button: TextureButton = %BackButton

const STAR_TEXTURE: Texture2D = preload("res://Textures/star.png")

var star_badges: Dictionary = {}


func _ready() -> void:
	_configure_level_buttons()
	_refresh_star_badges()
	back_button.pressed.connect(_on_back_pressed)
	if GameManager.has_signal("collectable_added"):
		GameManager.collectable_added.connect(_on_collectable_added)


func _configure_level_buttons() -> void:
	for i in range(grid.get_child_count()):
		var btn := grid.get_child(i) as TextureButton
		if btn == null:
			continue

		var level := i + 1
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(64, 64)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.disabled = not GameManager.is_level_unlocked(level)
		if not btn.disabled:
			btn.pressed.connect(_on_level_pressed.bind(level))
		_ensure_star_badge(btn, level)


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


func _on_level_pressed(level: int) -> void:
	var scene_path := "res://level_%d.tscn" % level
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		push_warning("Level scene not found: %s" % scene_path)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")

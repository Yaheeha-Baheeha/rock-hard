class_name SignalEmitter
extends Node2D

signal toggled(is_active: bool)

@export_category("Connections")
@export var targets: Array[SignalReceiver] = []
@export var interaction_area: Area2D 

var is_active: bool = false
var sprites: Array[Sprite2D] = []

func _ready() -> void:
	# 1. Scan for all sprites as before
	_collect_sprites(self)
	for sprite in sprites:
		if sprite.material:
			sprite.material = sprite.material.duplicate()
			
	# 2. If not explicitly assigned in the Inspector, auto-find an Area2D
	if not interaction_area:
		# Check for a specific node named "InteractionArea" first
		interaction_area = get_node_or_null("InteractionArea") as Area2D
		
		# Fallback: grab the first Area2D child found directly under this node
		if not interaction_area:
			for child in get_children():
				if child is Area2D:
					interaction_area = child
					break

	# 3. Connect hover signals if an Area2D was found
	if interaction_area:
		interaction_area.mouse_entered.connect(_on_hover_started)
		interaction_area.mouse_exited.connect(_on_hover_ended)

# Recursive loop that searches all nested children
func _collect_sprites(parent_node: Node) -> void:
	for child in parent_node.get_children():
		if child is Sprite2D:
			sprites.append(child)
		_collect_sprites(child)

func _on_hover_started() -> void:
	_set_outline(true)
	for target in targets:
		if is_instance_valid(target):
			target.set_outline(true)

func _on_hover_ended() -> void:
	_set_outline(false)
	for target in targets:
		if is_instance_valid(target):
			target.set_outline(false)

func _set_outline(active: bool) -> void:
	for sprite in sprites:
		if sprite and sprite.material:
			sprite.material.set_shader_parameter("is_active", active)

func set_state(new_state: bool) -> void:
	if is_active != new_state:
		is_active = new_state
		toggled.emit(is_active)
		
		for target in targets:
			if is_instance_valid(target):
				target.process_signal(self, is_active)

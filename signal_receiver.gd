class_name SignalReceiver
extends Node2D 

var is_active: bool = false
var active_emitters: Dictionary = {}
var sprites: Array[Sprite2D] = []

func _ready() -> void:
	_collect_sprites(self)
	for sprite in sprites:
		if sprite.material:
			sprite.material = sprite.material.duplicate()

func _collect_sprites(parent_node: Node) -> void:
	for child in parent_node.get_children():
		if child is Sprite2D:
			sprites.append(child)
		_collect_sprites(child)

func set_outline(active: bool) -> void:
	for sprite in sprites:
		if sprite and sprite.material:
			sprite.material.set_shader_parameter("is_active", active)

func process_signal(emitter: SignalEmitter, switch_state: bool) -> void:
	if switch_state:
		active_emitters[emitter] = true
	else:
		active_emitters.erase(emitter)
		
	# Odd count of active signals = ON (1 active input)
	# Even count of active signals = OFF (0 or 2 active inputs)
	var should_be_active = (active_emitters.size() % 2 == 1)
	
	if is_active != should_be_active:
		is_active = should_be_active
		_on_state_changed()

func _on_state_changed() -> void:
	pass

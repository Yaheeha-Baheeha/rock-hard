extends SignalReceiver

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var open_sound: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	super._ready()
	
	if not anim_player or not anim_player.has_animation("open"):
		push_error("Trapdoor: Missing AnimationPlayer or 'open' animation!")
		return
		
	# Instantly snap the trapdoor to the correct state when the level loads
	if is_active:
		# Play and skip instantly to the end
		anim_player.play("open")
		anim_player.seek(anim_player.get_animation("open").length, true)
	else:
		# Snap to the beginning
		anim_player.play("open")
		anim_player.seek(0.0, true)
		anim_player.stop()

# This is automatically called by your SignalReceiver base class
func _on_state_changed() -> void:
	if not anim_player:
		return
		
	if is_active:
		anim_player.play("open")
		if open_sound:
			open_sound.play()
	else:
		anim_player.play_backwards("open")

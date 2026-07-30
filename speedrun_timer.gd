extends CanvasLayer

@onready var time_label = $MarginContainer/TimeLabel

var time_elapsed: float = 0.0
var is_running: bool = true

func _process(delta: float) -> void:
	if is_running:
		time_elapsed += delta
		update_ui()

func update_ui() -> void:
	# Calculate minutes, seconds, and milliseconds
	var minutes = int(time_elapsed) / 60
	var seconds = int(time_elapsed) % 60
	var milliseconds = int(fmod(time_elapsed, 1.0) * 1000)
	
	# Format the string to look like 00:00.000
	var time_string = "%02d:%02d.%03d" % [minutes, seconds, milliseconds]
	time_label.text = time_string

func stop_timer() -> void:
	is_running = false

func reset_timer() -> void:
	time_elapsed = 0.0
	is_running = true

extends Node

@export var playlist: Array[AudioStream] = []
@export var min_delay_seconds: float = 3.0
@export var max_delay_seconds: float = 10.0
@export var shuffle: bool = true

@onready var audio_player: AudioStreamPlayer2D = $"../AudioStreamPlayer"
@onready var delay_timer: Timer = $DelayTimer

var current_index: int = 0

func _ready() -> void:
	audio_player.finished.connect(_on_song_finished)
	delay_timer.timeout.connect(_play_next_song)

	if shuffle:
		playlist.shuffle()

	_schedule_next_song()

func _play_next_song() -> void:
	if playlist.is_empty():
		return

	audio_player.stream = playlist[current_index]
	audio_player.play()

	current_index = (current_index + 1) % playlist.size()

func _on_song_finished() -> void:
	_schedule_next_song()

func _schedule_next_song() -> void:
	var wait_time = randf_range(min_delay_seconds, max_delay_seconds)
	delay_timer.start(wait_time)

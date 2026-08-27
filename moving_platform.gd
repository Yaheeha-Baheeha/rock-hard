extends SignalReceiver

@export_category("Platform Settings")
@export var auto_move: bool = false
@export var cycle_duration: float = 4.0 
@export var wait_time: float = 1.0 
@export var closed_loop: bool = false 

var internal_path: Path2D = null
var user_path: Path2D = null
var path_follow: PathFollow2D = null
var platform_tween: Tween
var is_moving: bool = false

func _ready() -> void:
	super._ready()
	
	# 1. Sort the Path2D nodes
	for child in get_children():
		if child is Path2D:
			# Check if this Path2D has the PathFollow2D inside it
			var has_follow = false
			for subchild in child.get_children():
				if subchild is PathFollow2D:
					internal_path = child
					path_follow = subchild
					has_follow = true
					break
			
			# If it doesn't have a PathFollow2D, it must be the track you drew!
			if not has_follow:
				user_path = child
				
	# 2. Transfer the curve from your drawn path to the mechanical path
	if user_path and user_path.curve:
		if internal_path:
			internal_path.curve = user_path.curve.duplicate()
			user_path.queue_free() # Delete the drawn path so it doesn't clutter the game
		else:
			push_error("MovingPlatform: Core mechanical Path2D is missing from the saved scene!")
			return
	
	# 3. Final safety check
	if not internal_path or not internal_path.curve or internal_path.curve.get_point_count() == 0:
		push_warning("MovingPlatform: No track found! Add a Path2D child and draw your points.")
		return
		
	if auto_move:
		is_active = true
		
	_setup_path_tween()

func _setup_path_tween() -> void:
	platform_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	platform_tween.set_loops()
	
	if closed_loop:
		platform_tween.tween_property(path_follow, "progress_ratio", 1.0, cycle_duration).from(0.0)
	else:
		platform_tween.tween_property(path_follow, "progress_ratio", 1.0, cycle_duration)\
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		platform_tween.tween_interval(wait_time)
		
		platform_tween.tween_property(path_follow, "progress_ratio", 0.0, cycle_duration)\
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		platform_tween.tween_interval(wait_time)
		
	if not is_active:
		platform_tween.pause()
		is_moving = false
	else:
		is_moving = true

func _on_state_changed() -> void:
	_update_movement()

func _update_movement() -> void:
	if not platform_tween:
		return
		
	var should_move = is_active or auto_move
	
	if should_move and not is_moving:
		platform_tween.play()
		is_moving = true
	elif not should_move and is_moving:
		platform_tween.pause()
		is_moving = false

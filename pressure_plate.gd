extends SignalEmitter

@export_category("Physics Trigger")
@export var activation_distance: float = 5.0 ## How many pixels down the plate must be pushed to turn ON

@onready var top_plate = $TopPlateBody
@onready var active_sound: AudioStreamPlayer2D = $Active

var resting_y_position: float = 0.0
var locked_x_position: float = 0.0 # <-- To store the starting X position

func _ready() -> void:
	super._ready()
	
	# Record exactly where the plate starts before anything touches it
	if top_plate:
		resting_y_position = top_plate.global_position.y
		locked_x_position = top_plate.global_position.x # <-- Save initial X

func _physics_process(_delta: float) -> void:
	if not top_plate:
		return
		
	# --- HARD LOCK THE X AXIS ---
	# Force it back to the exact starting X coordinate
	top_plate.global_position.x = locked_x_position
	# Kill any horizontal velocity so it doesn't build up invisible momentum
	top_plate.linear_velocity.x = 0.0
	# -----------------------------
		
	# Check how far down the plate has been physically pushed
	var current_compression = top_plate.global_position.y - resting_y_position
	
	# If the spring is compressed past our threshold, it activates!
	var should_be_active = current_compression >= activation_distance
	
	if is_active != should_be_active:
		set_state(should_be_active)
		
		# Play audio when switching to the activated state
		if is_active:
			active_sound.play()

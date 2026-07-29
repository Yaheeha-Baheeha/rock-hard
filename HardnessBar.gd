extends Node2D

@onready var progress_bar = $TextureProgressBar/Progress

# Using floats (decimals) here makes the percentage math work properly!
var max_health = 100.0 
var current_health = 100.0

# We need to know where it starts and how far it needs to travel
var start_pos_x = 0.0
var total_width_in_pixels = 128.0 

func _ready():
	# Save the exact starting position when the game launches
	start_pos_x = progress_bar.position.x

func take_damage(amount):
	# Clamp keeps health strictly between 0 and your max_health
	current_health = clamp(current_health - amount, 0.0, max_health)
	
	# 1. Figure out what percentage of health is left
	var health_percent = current_health / max_health
	
	# 2. Figure out the percentage of health MISSING
	var missing_percent = 1.0 - health_percent
	
	# 3. Calculate the exact pixel coordinate we WANT the bar to end up at
	var target_position_x = start_pos_x - (total_width_in_pixels * missing_percent)
	
	# --- NEW TWEEN CODE HERE ---
	# Create a new Tween
	var tween = create_tween()
	
	# Tell the tween to animate "position:x" to our target over 0.3 seconds
	# .set_trans() and .set_ease() make the slide feel natural (starts fast, slows down at the end)
	tween.tween_property(progress_bar, "position:x", target_position_x, 0.3)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	
	print("Health is now: ", current_health)

func _input(event):
	if event.is_action_pressed("left"): 
		take_damage(10)
	elif event.is_action_pressed("right"):
		take_damage(-10)

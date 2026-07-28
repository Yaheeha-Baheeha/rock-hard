extends Node2D

@onready var progress_bar = $TextureProgressBar/Progress

# Using floats (decimals) here makes the percentage math work properly!
var max_health = 100.0 
var current_health = 100.0

# We need to know where it starts and how far it needs to travel
var start_pos_x = 0.0
var total_width_in_pixels = 128.0 # <--- CHANGE THIS to the actual width of your texture!

func _ready():
	# Save the exact starting position when the game launches
	start_pos_x = progress_bar.position.x

func take_damage(amount):
	current_health -= amount
	
	# Clamp the health so it never drops below 0 (prevents it from sliding too far!)
	current_health = max(current_health, 0)
	
	# 1. Figure out what percentage of health is left (e.g., 50 health = 0.5)
	var health_percent = current_health / max_health
	
	# 2. Figure out the percentage of health MISSING (e.g., 0.5)
	var missing_percent = 1.0 - health_percent
	
	# 3. Move the bar left based on how much health is missing
	progress_bar.position.x = start_pos_x - (total_width_in_pixels * missing_percent)
	
	print("Health is now: ", current_health)

func _input(event):
	if event.is_action_pressed("left"): 
		take_damage(10)

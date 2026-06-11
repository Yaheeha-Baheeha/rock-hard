extends PinJoint2D

signal turned_on
signal turned_off


func _physics_process(_delta: float) -> void:
	# 1. Calculate the relative angle between Body A and Body B
	var body_a = get_node_or_null(node_a) as Node2D
	var body_b = get_node_or_null(node_b) as Node2D
	
	if body_a and body_b:
		# Calculate difference in radians, then convert to degrees
		var relative_angle_rad = body_b.global_rotation - body_a.global_rotation
		var relative_angle_deg = rad_to_deg(relative_angle_rad)
		
		# Keep the angle cleanly bounded between -180 and 180 degrees
		var wrapped_angle = wrapf(relative_angle_deg, -180.0, 180.0)
		#print("Relative Joint Angle: ", wrapped_angle)
		if wrapped_angle <= -60:
			turned_on.emit()
			#print('on') #on
			#maybe add signal to trigger lava
		else:
			turned_off.emit()
			#print("off") #off
	else:
		print("Assigned physics nodes not found.")
		
		#63.5223643755735 <- off
		#-66.8435165387356 <- on
	

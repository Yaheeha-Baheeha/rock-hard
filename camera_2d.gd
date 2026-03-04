extends Camera2D

@export var speed: float = 2000.0

func _process(delta):
	var direction := Vector2.ZERO
	
	if Input.is_action_pressed("jump") or Input.is_key_pressed(KEY_W):
		direction.y -= 1
	if Input.is_action_pressed("crouch") or Input.is_key_pressed(KEY_S):
		direction.y += 1
	if Input.is_action_pressed("left") or Input.is_key_pressed(KEY_A):
		direction.x -= 1
	if Input.is_action_pressed("right") or Input.is_key_pressed(KEY_D):
		direction.x += 1
	
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		position += direction * speed * delta

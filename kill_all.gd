extends Area2D

func _ready() -> void:
	# Connects the signal automatically through code so you don't have to do it in the editor
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Check if the node that entered is actually a RigidBody2D
	if body is RigidBody2D:
		# "Kill" / destroy the rigidbody
		body.queue_free()

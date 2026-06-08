extends Node2D

signal on
signal off

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_pin_joint_2d_turned_off() -> void:
	off.emit()


func _on_pin_joint_2d_turned_on() -> void:
	on.emit()

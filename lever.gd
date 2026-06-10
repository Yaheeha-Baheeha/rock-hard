extends Node2D

signal on
signal off

# Grab the PinJoint2D node based on your scene tree hierarchy
@onready var pin_joint = $RigidBody2D3/PinJoint2D

func _ready() -> void:
	# Connect the joint's signals to this script's functions
	$PinJoint2D.turned_on.connect(_on_pin_joint_2d_turned_on)
	$PinJoint2D.turned_off.connect(_on_pin_joint_2d_turned_off)

func _process(delta: float) -> void:
	pass


func _on_pin_joint_2d_turned_off() -> void:
	off.emit()
	print("off")


func _on_pin_joint_2d_turned_on() -> void:
	on.emit()

@tool
extends Node3D

@export var speed: float = 0.5


func _process(delta):
	rotate_y(speed * delta)

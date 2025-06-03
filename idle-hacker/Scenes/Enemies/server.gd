extends Node2D

@export var server_health: float = 100.0
@export var server_type: String = "BasicServer"

func _ready():
	# Create a simple server visualization
	var sprite = ColorRect.new()
	sprite.size = Vector2(48, 48)
	sprite.position = Vector2(-24, -24)
	sprite.color = Color.ORANGE
	add_child(sprite)
	
	# Add a simple label
	var label = Label.new()
	label.text = "SRV"
	label.position = Vector2(-12, -8)
	add_child(label)

func take_damage(amount: float):
	server_health -= amount
	if server_health <= 0:
		die()

func die():
	queue_free()

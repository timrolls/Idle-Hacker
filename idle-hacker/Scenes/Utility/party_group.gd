extends Node2D

var agents: Array[Node2D] = []

func _ready():
	# Get all agent nodes
	for child in get_children():
		if child.name.begins_with("Agent"):
			agents.append(child)
	
	# Position agents in formation
	setup_formation()

func setup_formation():
	# Arrange agents vertically
	for i in range(agents.size()):
		agents[i].position.y = i * 40 - 40  # Spread them vertically
		
		# Set up simple colored rectangles
		var sprite = agents[i].get_node("Sprite2D")
		sprite.texture.size = Vector2(32, 32)
		sprite.position = Vector2(-16, -16)  # Center the rectangle
		
		# Different colors for each agent type
		match i:
			0: sprite.modulate = Color.BLUE    # Brute Force Agent
			1: sprite.modulate = Color.GREEN   # Firewall Agent  
			2: sprite.modulate = Color.RED     # Packet Sniffer Agent

func get_agent_health(agent_index: int) -> float:
	if agent_index < agents.size():
		# For now, return a placeholder health value
		# This will be replaced with actual agent health system
		return 100.0
	return 0.0

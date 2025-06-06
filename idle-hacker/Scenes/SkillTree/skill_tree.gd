# SkillTree.gd - Main controller script
extends Control

@onready var diamond_grid: DiamondGridContainer = $HSplitContainer/TreeContainer/DiamondGridContainer
@onready var node_name_label: Label = $HSplitContainer/InfoPanel/NodeInfoPanel/InfoContainer/NodeName
@onready var node_description: RichTextLabel = $HSplitContainer/InfoPanel/NodeInfoPanel/InfoContainer/NodeDescription
@onready var purchase_button: Button = $HSplitContainer/InfoPanel/NodeInfoPanel/InfoContainer/PurchaseButton
@onready var stats_list: VBoxContainer = $HSplitContainer/InfoPanel/StatsPanel/StatsContainer/StatsList

@export var skill_tree_data: SkillTreeData
@export_group("Grid Generation")
@export var grid_width: int = 7
@export var grid_height: int = 7
@export var max_rings: int = 3  # How many rings around the center

var current_stats: Dictionary = {
	"cpu_speed": 0.0,        # Attack speed multiplier
	"ram_capacity": 0.0,     # Agent capacity
	"network_bandwidth": 0.0, # Movement speed
	"cooling_efficiency": 0.0, # Defense
	"gpu_power": 0.0,        # Damage multiplier
	"storage_speed": 0.0     # Special abilities cooldown reduction
}

func _ready():
	print("SkillTree _ready() called")
	
	if not skill_tree_data:
		print("Creating default skill tree...")
		create_default_skill_tree()
	
	print("Skill tree data has ", skill_tree_data.skill_nodes.size(), " nodes")
	
	if diamond_grid:
		print("DiamondGridContainer found, setting up...")
		diamond_grid.skill_tree_data = skill_tree_data
		diamond_grid.node_selected.connect(_on_node_clicked)
		diamond_grid.node_hovered.connect(_on_node_hovered)
		diamond_grid.node_purchased.connect(_on_node_purchased)
	else:
		print("ERROR: DiamondGridContainer not found!")
	
	if purchase_button:
		purchase_button.pressed.connect(_on_purchase_button_pressed)
	
	# Calculate stats from any pre-allocated nodes (like the starting node)
	calculate_total_stats()
	update_stats_display()

func create_default_skill_tree():
	# Use the exported grid size variables
	var center_x = grid_width / 2
	var center_y = grid_height / 2
	
	skill_tree_data = SkillTreeData.new()
	skill_tree_data.grid_width = grid_width
	skill_tree_data.grid_height = grid_height
	
	# Define hardware component templates
	var hardware_templates = {
		"cpu": {
			"name_prefix": "CPU",
			"description": "Improves agent processing speed and attack rates",
			"bonuses": {"cpu_speed": randf_range(0.1, 0.3)},
			"cost": 1,
			"names": ["Intel i3", "Intel i5", "Intel i7", "Intel i9", "AMD Ryzen 3", "AMD Ryzen 5", "AMD Ryzen 7", "AMD Ryzen 9"]
		},
		"ram": {
			"name_prefix": "RAM", 
			"description": "Increases capacity for deploying more agents",
			"bonuses": {"ram_capacity": randf_range(2.0, 6.0)},
			"cost": 1,
			"names": ["8GB DDR4", "16GB DDR4", "32GB DDR4", "64GB DDR5", "128GB DDR5", "ECC Memory", "Server RAM"]
		},
		"network": {
			"name_prefix": "Network",
			"description": "Increases agent movement and deployment speed", 
			"bonuses": {"network_bandwidth": randf_range(0.15, 0.4)},
			"cost": 1,
			"names": ["Ethernet", "Gigabit", "10G Fiber", "WiFi 6", "5G Modem", "Satellite Link", "Quantum Network"]
		},
		"cooling": {
			"name_prefix": "Cooling",
			"description": "Improves system stability and agent defense",
			"bonuses": {"cooling_efficiency": randf_range(0.1, 0.25)},
			"cost": 2,
			"names": ["Stock Cooler", "Tower Cooler", "AIO Liquid", "Custom Loop", "LN2 Cooling", "Immersion Cooling"]
		},
		"gpu": {
			"name_prefix": "GPU",
			"description": "Accelerates agent damage and parallel processing",
			"bonuses": {"gpu_power": randf_range(0.2, 0.5)},
			"cost": 2,
			"names": ["GTX 1660", "RTX 3070", "RTX 4080", "RTX 4090", "AMD RX 6800", "AMD RX 7900", "Tesla V100", "H100"]
		},
		"storage": {
			"name_prefix": "Storage",
			"description": "Reduces ability cooldowns and improves data access",
			"bonuses": {"storage_speed": randf_range(0.1, 0.3)},
			"cost": 2,
			"names": ["SATA SSD", "NVMe SSD", "PCIe 4.0", "PCIe 5.0", "Optane", "RAID Array", "Enterprise NVMe"]
		}
	}
	
	# Create center starting node - Basic Computer
	var starting_node = create_skill_node(
		"Basic Computer", 
		"Your starting development machine with basic specs",
		center_x, center_y, 
		{"cpu_speed": 0.1, "ram_capacity": 4.0, "network_bandwidth": 0.1}, 
		0, true, true
	)
	skill_tree_data.skill_nodes.append(starting_node)
	
	# Create nodes in rings around the center
	for ring in range(1, max_rings + 1):  # Use exported max_rings
		var positions = get_ring_positions(center_x, center_y, ring)
		
		for i in range(positions.size()):
			var pos = positions[i]
			# Don't create nodes outside grid bounds
			if pos.x < 0 or pos.x >= grid_width or pos.y < 0 or pos.y >= grid_height:
				continue
				
			# Choose hardware component based on ring and position
			var component_type = choose_hardware_component(ring, i)
			var template = hardware_templates[component_type]
			
			# Pick a specific name for this component
			var component_names = template.names
			var specific_name = component_names[i % component_names.size()]
			
			var node = create_skill_node(
				specific_name,
				template.description,
				pos.x, pos.y,
				template.bonuses,
				template.cost + (ring - 1),  # Higher cost for outer rings (better hardware)
				false, false
			)
			skill_tree_data.skill_nodes.append(node)

func create_skill_node(name: String, desc: String, x: int, y: int, bonuses: Dictionary, cost: int, starting: bool, allocated: bool) -> SkillNode:
	var node = SkillNode.new()
	node.skill_name = name
	node.description = desc
	node.grid_x = x
	node.grid_y = y
	node.stat_bonuses = bonuses
	node.cost = cost
	node.is_starting_node = starting
	node.is_allocated = allocated
	return node

func get_ring_positions(center_x: int, center_y: int, ring: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	
	# Create a diamond ring by iterating around the perimeter
	# Start from the top and go clockwise
	
	# Top to top-right
	for i in range(ring + 1):
		positions.append(Vector2i(center_x - ring + i, center_y - i))
	
	# Top-right to bottom-right (skip corner to avoid duplicate)
	for i in range(1, ring + 1):
		positions.append(Vector2i(center_x + i, center_y - ring + i))
	
	# Bottom-right to bottom-left (skip corner)
	for i in range(1, ring + 1):
		positions.append(Vector2i(center_x + ring - i, center_y + i))
	
	# Bottom-left to top-left (skip corner)
	for i in range(1, ring):
		positions.append(Vector2i(center_x - i, center_y + ring - i))
	
	return positions

func choose_hardware_component(ring: int, position_index: int) -> String:
	# Choose hardware component based on ring and position
	var components = ["cpu", "ram", "network", "cooling", "gpu", "storage"]
	
	match ring:
		1: return ["cpu", "ram", "network"][position_index % 3]  # Basic components first
		2: return ["cpu", "ram", "network", "cooling"][position_index % 4]  # Add cooling
		3: return components[position_index % components.size()]  # All components available
		_: return components[position_index % components.size()]

# Remove the old get_skill_suffix function since we're using specific hardware names now

func _on_node_hovered(node: SkillNode):
	print("Node hovered: ", node.skill_name)
	update_node_info_panel(node)

func _on_node_clicked(node: SkillNode):
	print("Node clicked: ", node.skill_name)
	update_node_info_panel(node)

func _on_node_purchased(node: SkillNode):
	calculate_total_stats()
	update_stats_display()

func _on_purchase_button_pressed():
	if diamond_grid.selected_node:
		diamond_grid.purchase_node(diamond_grid.selected_node)

# Safe version that doesn't cause recursion
func can_unlock_node_safe(node: SkillNode) -> bool:
	if node.is_allocated:
		return false
		
	# Starting node is always available
	if node.is_starting_node:
		return true
		
	# Check adjacent positions manually without calling SkillTreeData functions
	var adjacent_positions = [
		Vector2i(node.grid_x + 1, node.grid_y),     # Right
		Vector2i(node.grid_x - 1, node.grid_y),     # Left
		Vector2i(node.grid_x, node.grid_y + 1),     # Down
		Vector2i(node.grid_x, node.grid_y - 1)      # Up
	]
	
	# Check if any adjacent node is allocated
	for pos in adjacent_positions:
		# Find node at this position manually
		for check_node in skill_tree_data.skill_nodes:
			if check_node.grid_x == pos.x and check_node.grid_y == pos.y and check_node.is_allocated:
				return true
	
	return false

func update_node_info_panel(node: SkillNode):
	print("update_node_info_panel called for: ", node.skill_name if node else "null")
	
	if not node:
		print("Node is null, returning")
		return
		
	print("Setting node name...")
	if node_name_label:
		node_name_label.text = node.skill_name
	else:
		print("node_name_label is null!")
	
	print("Setting description...")
	if node_description:
		var full_description = node.description
		
		# Add bonuses from the actual node with clean formatting
		if not node.stat_bonuses.is_empty():
			full_description += "\n\n[b]Bonuses:[/b]\n"
			for stat_name in node.stat_bonuses:
				var value = node.stat_bonuses[stat_name]
				if value > 0:
					var formatted_value = format_number(value)
					full_description += "• " + stat_name.capitalize() + ": +" + formatted_value + "\n"
		
		node_description.text = full_description
	else:
		print("node_description is null!")
	
	print("Setting button...")
	if purchase_button:
		if node.is_allocated:
			purchase_button.text = "OWNED"
			purchase_button.disabled = true
		else:
			# Check if the node can actually be unlocked
			if can_unlock_node_safe(node):
				purchase_button.text = "HOLD CLICK TO PURCHASE"
				purchase_button.disabled = true  # Disable since we use hold-to-purchase now
			else:
				purchase_button.text = "LOCKED"
				purchase_button.disabled = true
	else:
		print("purchase_button is null!")
	
	print("update_node_info_panel completed")

func calculate_total_stats():
	# Reset stats
	for stat in current_stats:
		current_stats[stat] = 0.0
	
	# Sum up all allocated node bonuses
	for node in skill_tree_data.skill_nodes:
		if node.is_allocated:
			for stat in node.stat_bonuses:
				if stat in current_stats:
					current_stats[stat] += node.stat_bonuses[stat]

# Helper function to format numbers cleanly
func format_number(value: float) -> String:
	# Format to 2 decimal places, but remove trailing zeros
	if value == int(value):
		return str(int(value))  # Show as integer if whole number
	else:
		var formatted = "%.2f" % value  # 2 decimal places
		# Remove trailing zeros
		while formatted.ends_with("0") and formatted.contains("."):
			formatted = formatted.substr(0, formatted.length() - 1)
		if formatted.ends_with("."):
			formatted = formatted.substr(0, formatted.length() - 1)
		return formatted

func update_stats_display():
	# Clear existing stat labels
	for child in stats_list.get_children():
		child.queue_free()
	
	# Add current stats with proper formatting
	for stat in current_stats:
		var label = Label.new()
		var formatted_value = format_number(current_stats[stat])
		label.text = stat.capitalize() + ": " + formatted_value
		stats_list.add_child(label)

# DiamondGridContainer.gd - Custom container for diamond grid layout
extends Control
class_name DiamondGridContainer

@export var node_size: int = 60
@export var grid_spacing: int = 60
@export var skill_tree_data: SkillTreeData : set = set_skill_tree_data

var skill_buttons: Dictionary = {}  # grid_pos -> SkillButton
var selected_node: SkillNode = null

signal node_selected(node: SkillNode)
signal node_hovered(node: SkillNode)
signal node_purchased(node: SkillNode)

func set_skill_tree_data(new_data: SkillTreeData):
	skill_tree_data = new_data
	if skill_tree_data and is_inside_tree():
		print("Skill tree data set, creating grid...")
		create_skill_grid()

func _ready():
	print("DiamondGridContainer _ready() called")
	if skill_tree_data:
		print("Skill tree data found, creating grid...")
		create_skill_grid()
	else:
		print("No skill tree data set yet")

func create_skill_grid():
	print("Creating skill grid with ", skill_tree_data.skill_nodes.size(), " nodes")
	
	# Clear existing buttons
	for child in get_children():
		child.queue_free()
	skill_buttons.clear()
	
	# Create buttons for each skill node
	for i in range(skill_tree_data.skill_nodes.size()):
		var skill_node = skill_tree_data.skill_nodes[i]
		print("Creating button for node: ", skill_node.skill_name, " at (", skill_node.grid_x, ",", skill_node.grid_y, ")")
		create_skill_button(skill_node)
	
	# Update visual states
	update_all_button_states()
	print("Skill grid creation complete")

func create_skill_button(skill_node: SkillNode) -> void:
	print("Creating button for: ", skill_node.skill_name)
	
	var button = SkillButton.new()
	button.skill_node = skill_node
	button.custom_minimum_size = Vector2(node_size, node_size)
	
	# Position in diamond grid
	var pos = grid_to_world_position(skill_node.grid_x, skill_node.grid_y)
	button.position = pos
	print("Button positioned at: ", pos)
	
	# Connect signals
	button.pressed.connect(_on_skill_button_pressed.bind(skill_node))
	button.mouse_entered.connect(_on_skill_button_hovered.bind(skill_node))
	button.purchase_completed.connect(_on_skill_button_purchased.bind(skill_node))
	
	add_child(button)
	skill_buttons[Vector2i(skill_node.grid_x, skill_node.grid_y)] = button
	print("Button added to scene, total children: ", get_child_count())

func grid_to_world_position(grid_x: int, grid_y: int) -> Vector2:
	# Diamond lattice - adjacent diamonds touch at corners
	# Transform grid coordinates to diamond lattice coordinates using exported spacing
	var spacing = float(grid_spacing)  # Use the exported grid_spacing value
	
	# Convert grid to diamond lattice coordinates
	var world_x = (grid_x - grid_y) * spacing * 0.5
	var world_y = (grid_x + grid_y) * spacing * 0.5
	
	# Center the grid in the container
	var container_center = get_rect().size / 2
	
	# Calculate the actual center of the current grid
	var actual_grid_width = skill_tree_data.grid_width if skill_tree_data else 5
	var actual_grid_height = skill_tree_data.grid_height if skill_tree_data else 5
	var grid_center = Vector2(actual_grid_width / 2, actual_grid_height / 2)
	
	var grid_center_world_x = (grid_center.x - grid_center.y) * spacing * 0.5
	var grid_center_world_y = (grid_center.x + grid_center.y) * spacing * 0.5
	var grid_center_world = Vector2(grid_center_world_x, grid_center_world_y)
	
	# Offset so grid center aligns with container center
	var offset = container_center - grid_center_world
	
	return Vector2(world_x, world_y) + offset

func update_all_button_states():
	print("Updating button states...")
	
	for pos in skill_buttons:
		var button = skill_buttons[pos]
		var node = button.skill_node
		
		if node.is_allocated:
			button.set_state(SkillButton.State.ALLOCATED)
		elif can_unlock_node_safe(node):
			button.set_state(SkillButton.State.AVAILABLE)
		else:
			button.set_state(SkillButton.State.LOCKED)

# Safe version that doesn't use recursion
func can_unlock_node_safe(node: SkillNode) -> bool:
	if node.is_allocated:
		return false
		
	# Starting node is always available
	if node.is_starting_node:
		return true
		
	# Check adjacent positions manually
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

func _on_skill_button_purchased(node: SkillNode):
	print("Purchase completed for node: ", node.skill_name)
	
	# Only purchase if it's actually available
	if can_unlock_node_safe(node) and can_afford_node(node):
		purchase_node(node)

func _on_skill_button_pressed(node: SkillNode):
	print("Button pressed for node: ", node.skill_name)
	selected_node = node
	node_selected.emit(node)
	
	# Note: Purchase is now handled by the hold system, not immediate click

func _on_skill_button_hovered(node: SkillNode):
	print("Hover on node: ", node.skill_name)
	node_hovered.emit(node)

func can_afford_node(node: SkillNode) -> bool:
	# Add your currency/point checking logic here
	return true  # Placeholder

func purchase_node(node: SkillNode):
	node.is_allocated = true
	update_all_button_states()
	node_purchased.emit(node)

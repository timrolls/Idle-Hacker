# SkillTreeData.gd - Resource to define skill nodes and connections
class_name SkillTreeData
extends Resource

@export var grid_width: int = 10
@export var grid_height: int = 10
@export var skill_nodes: Array[SkillNode] = []

# Helper to get node at grid position
func get_node_at(x: int, y: int) -> SkillNode:
	for node in skill_nodes:
		if node.grid_x == x and node.grid_y == y:
			return node
	return null

# Get adjacent positions in diamond pattern
func get_adjacent_positions(x: int, y: int) -> Array[Vector2i]:
	return [
		Vector2i(x + 1, y),     # Right
		Vector2i(x - 1, y),     # Left
		Vector2i(x, y + 1),     # Down
		Vector2i(x, y - 1)      # Up
	]

# Check if a node can be unlocked (has adjacent allocated node)
func can_unlock_node(node: SkillNode, allocated_nodes: Array[SkillNode]) -> bool:
	if node.is_allocated:
		return false
		
	# Starting node is always available
	if node.is_starting_node:
		return true
		
	# Check if any adjacent node is allocated
	var adjacent_positions = get_adjacent_positions(node.grid_x, node.grid_y)
	for pos in adjacent_positions:
		var adjacent_node = get_node_at(pos.x, pos.y)
		if adjacent_node and adjacent_node.is_allocated:
			return true
	
	return false

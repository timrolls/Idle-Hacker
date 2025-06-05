extends Node
class_name HardwareUpgradeSystem

# Hardware node types
enum NodeType {
	CPU,      # Attack speed
	RAM,      # Agent capacity
	GPU,      # Damage
	NETWORK,  # Movement speed
	STORAGE,  # Special effects
	COOLING   # Defense
}

# Upgrade node structure
var upgrade_nodes: Dictionary = {}
var unlocked_nodes: Array[String] = []
var upgrade_points: int = 0

# Current hardware stats
var current_stats = {
	"cpu_speed": 1.0,        # Attack speed multiplier
	"ram_capacity": 20,       # Max RAM for agents
	"gpu_power": 1.0,        # Damage multiplier
	"network_speed": 1.0,    # Movement speed multiplier
	"storage_bonus": 0.0,    # Bonus loot chance
	"cooling_efficiency": 1.0 # Defense multiplier
}

signal node_unlocked(node_id: String)
signal stats_updated(stats: Dictionary)

func _ready():
	initialize_upgrade_tree()

func initialize_upgrade_tree():
	# Starting node - Basic CPU
	add_node("cpu_basic", {
		"name": "Basic CPU Upgrade",
		"type": NodeType.CPU,
		"tier": 0,
		"cost": 0,
		"effect": {"cpu_speed": 0.1},
		"description": "+10% Agent Attack Speed",
		"position": Vector2(0, 0),
		"prerequisites": [],
		"unlocked": true
	})
	
	# Tier 1 Nodes
	add_node("cpu_1", {
		"name": "Overclocked CPU",
		"type": NodeType.CPU,
		"tier": 1,
		"cost": 1,
		"effect": {"cpu_speed": 0.15},
		"description": "+15% Agent Attack Speed",
		"position": Vector2(-100, -80),
		"prerequisites": ["cpu_basic"]
	})
	
	add_node("ram_1", {
		"name": "RAM Expansion",
		"type": NodeType.RAM,
		"tier": 1,
		"cost": 1,
		"effect": {"ram_capacity": 4},
		"description": "+4 RAM Capacity",
		"position": Vector2(0, -80),
		"prerequisites": ["cpu_basic"]
	})
	
	add_node("gpu_1", {
		"name": "Graphics Accelerator",
		"type": NodeType.GPU,
		"tier": 1,
		"cost": 1,
		"effect": {"gpu_power": 0.2},
		"description": "+20% Agent Damage",
		"position": Vector2(100, -80),
		"prerequisites": ["cpu_basic"]
	})
	
	# Tier 2 Nodes - CPU Branch
	add_node("cpu_2", {
		"name": "Quantum Processor",
		"type": NodeType.CPU,
		"tier": 2,
		"cost": 2,
		"effect": {"cpu_speed": 0.25},
		"description": "+25% Agent Attack Speed",
		"position": Vector2(-150, -160),
		"prerequisites": ["cpu_1"]
	})
	
	add_node("cpu_special", {
		"name": "Parallel Threading",
		"type": NodeType.CPU,
		"tier": 2,
		"cost": 2,
		"effect": {"cpu_speed": 0.1, "special": "double_strike"},
		"description": "+10% Speed, Agents can double strike",
		"position": Vector2(-50, -160),
		"prerequisites": ["cpu_1", "ram_1"]
	})
	
	# Tier 2 Nodes - RAM Branch
	add_node("ram_2", {
		"name": "DDR6 Memory",
		"type": NodeType.RAM,
		"tier": 2,
		"cost": 2,
		"effect": {"ram_capacity": 8},
		"description": "+8 RAM Capacity",
		"position": Vector2(0, -160),
		"prerequisites": ["ram_1"]
	})
	
	add_node("ram_efficiency", {
		"name": "Memory Compression",
		"type": NodeType.RAM,
		"tier": 2,
		"cost": 2,
		"effect": {"ram_efficiency": 0.2},
		"description": "Agents cost 20% less RAM",
		"position": Vector2(50, -200),
		"prerequisites": ["ram_1", "gpu_1"]
	})
	
	# Tier 2 Nodes - GPU Branch
	add_node("gpu_2", {
		"name": "RTX 9090",
		"type": NodeType.GPU,
		"tier": 2,
		"cost": 2,
		"effect": {"gpu_power": 0.3},
		"description": "+30% Agent Damage",
		"position": Vector2(150, -160),
		"prerequisites": ["gpu_1"]
	})
	
	add_node("gpu_crit", {
		"name": "Ray Tracing",
		"type": NodeType.GPU,
		"tier": 2,
		"cost": 2,
		"effect": {"crit_chance": 0.15},
		"description": "+15% Critical Hit Chance",
		"position": Vector2(100, -200),
		"prerequisites": ["gpu_1"]
	})
	
	# Tier 3 Nodes - Advanced
	add_node("network_1", {
		"name": "Fiber Optic Network",
		"type": NodeType.NETWORK,
		"tier": 3,
		"cost": 3,
		"effect": {"network_speed": 0.5},
		"description": "+50% Movement Speed",
		"position": Vector2(-100, -280),
		"prerequisites": ["cpu_2", "ram_2"]
	})
	
	add_node("storage_1", {
		"name": "RAID Array",
		"type": NodeType.STORAGE,
		"tier": 3,
		"cost": 3,
		"effect": {"storage_bonus": 0.25},
		"description": "+25% Loot Drop Chance",
		"position": Vector2(0, -280),
		"prerequisites": ["ram_2", "gpu_2"]
	})
	
	add_node("cooling_1", {
		"name": "Liquid Cooling",
		"type": NodeType.COOLING,
		"tier": 3,
		"cost": 3,
		"effect": {"cooling_efficiency": 0.3},
		"description": "+30% Agent Defense",
		"position": Vector2(100, -280),
		"prerequisites": ["gpu_2", "gpu_crit"]
	})
	
	# Tier 4 - Ultimate Nodes
	add_node("quantum_core", {
		"name": "Quantum Core",
		"type": NodeType.CPU,
		"tier": 4,
		"cost": 5,
		"effect": {"cpu_speed": 0.5, "gpu_power": 0.5, "special": "quantum_entanglement"},
		"description": "+50% Speed & Damage, Quantum Entanglement",
		"position": Vector2(-50, -360),
		"prerequisites": ["network_1", "storage_1"]
	})
	
	add_node("neural_processor", {
		"name": "Neural Processor",
		"type": NodeType.GPU,
		"tier": 4,
		"cost": 5,
		"effect": {"gpu_power": 0.75, "special": "ai_targeting"},
		"description": "+75% Damage, AI Auto-Targeting",
		"position": Vector2(50, -360),
		"prerequisites": ["storage_1", "cooling_1"]
	})
	
	# Initialize first node as unlocked
	unlock_node("cpu_basic", true)

func add_node(node_id: String, data: Dictionary):
	upgrade_nodes[node_id] = data
	upgrade_nodes[node_id]["id"] = node_id
	upgrade_nodes[node_id]["unlocked"] = data.get("unlocked", false)

func can_unlock_node(node_id: String) -> bool:
	if not upgrade_nodes.has(node_id):
		return false
	
	var node = upgrade_nodes[node_id]
	
	# Check if already unlocked
	if node.unlocked:
		return false
	
	# Check cost
	if upgrade_points < node.cost:
		return false
	
	# Check prerequisites
	for prereq in node.prerequisites:
		if not upgrade_nodes[prereq].unlocked:
			return false
	
	return true

func unlock_node(node_id: String, free: bool = false) -> bool:
	if not can_unlock_node(node_id) and not free:
		return false
	
	var node = upgrade_nodes[node_id]
	
	# Spend points
	if not free:
		upgrade_points -= node.cost
	
	# Mark as unlocked
	node.unlocked = true
	unlocked_nodes.append(node_id)
	
	# Apply effects
	apply_node_effects(node)
	
	# Emit signals
	node_unlocked.emit(node_id)
	stats_updated.emit(current_stats)
	
	EventBus.emit_log_entry("Hardware Upgraded: %s" % node.name, Globals.success_color)
	
	return true

func apply_node_effects(node: Dictionary):
	var effects = node.effect
	
	for key in effects:
		if key == "special":
			continue  # Handle special effects separately
		
		if current_stats.has(key):
			current_stats[key] += effects[key]
		else:
			# Handle special stats like crit_chance
			match key:
				"ram_efficiency":
					# This would be applied when calculating RAM costs
					pass
				"crit_chance":
					# This would be passed to agents
					pass

func get_node_connections() -> Array:
	var connections = []
	
	for node_id in upgrade_nodes:
		var node = upgrade_nodes[node_id]
		for prereq in node.prerequisites:
			connections.append({
				"from": prereq,
				"to": node_id,
				"unlocked": node.unlocked
			})
	
	return connections

func get_total_stat_bonus(stat: String) -> float:
	var total = 0.0
	
	for node_id in unlocked_nodes:
		var node = upgrade_nodes[node_id]
		if node.effect.has(stat):
			total += node.effect[stat]
	
	return total

func add_upgrade_points(amount: int):
	upgrade_points += amount
	EventBus.emit_log_entry("Gained %d upgrade points!" % amount, Globals.success_color)

func get_ram_cost_multiplier() -> float:
	var efficiency = get_total_stat_bonus("ram_efficiency")
	return 1.0 - efficiency  # 20% efficiency = 0.8x cost

func get_special_effects() -> Array[String]:
	var effects = []
	
	for node_id in unlocked_nodes:
		var node = upgrade_nodes[node_id]
		if node.effect.has("special"):
			effects.append(node.effect.special)
	
	return effects

func reset_tree():
	# Reset all nodes except the basic one
	for node_id in upgrade_nodes:
		if node_id != "cpu_basic":
			upgrade_nodes[node_id].unlocked = false
	
	unlocked_nodes = ["cpu_basic"]
	
	# Reset stats
	current_stats = {
		"cpu_speed": 1.1,  # Basic node gives 0.1
		"ram_capacity": 8,
		"gpu_power": 1.0,
		"network_speed": 1.0,
		"storage_bonus": 0.0,
		"cooling_efficiency": 1.0
	}
	
	# Refund all points
	var refunded = 0
	for node_id in upgrade_nodes:
		if upgrade_nodes[node_id].unlocked and node_id != "cpu_basic":
			refunded += upgrade_nodes[node_id].cost
	
	upgrade_points += refunded
	EventBus.emit_log_entry("Hardware reset! Refunded %d points." % refunded, Globals.success_color)
	stats_updated.emit(current_stats)

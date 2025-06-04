extends Node
class_name CombatManager

# Combat state
var active_agents: Array[Agent] = []
var current_server: EnemyServer = null
var is_combat_active: bool = false

# Combat stats
var total_damage_dealt: float = 0.0
var combat_start_time: float = 0.0

signal combat_started(agents: Array[Agent], server: EnemyServer)
signal combat_ended(victory: bool, stats: Dictionary)

func _ready():
	# Connect to global events
	EventBus.agent_died.connect(_on_agent_died)

func start_combat(agents: Array[Agent], server: EnemyServer):
	if is_combat_active:
		return
	
	active_agents = agents
	current_server = server
	is_combat_active = true
	combat_start_time = Time.get_ticks_msec() / 1000.0
	total_damage_dealt = 0.0
	
	# Connect server defeat signal
	server.server_defeated.connect(_on_server_defeated, CONNECT_ONE_SHOT)
	
	# Start agent attacks
	for agent in active_agents:
		if is_instance_valid(agent):
			agent.start_combat(server)
			agent.attack_performed.connect(_on_attack_performed)
	
	# Server starts defending
	for agent in active_agents:
		server.engage_attacker(agent)
	
	# Connect server counter attack
	server.counter_attack.connect(_on_server_counter_attack)
	
	# Emit combat start
	EventBus.combat_started.emit(active_agents, server)
	combat_started.emit(active_agents, server)
	
	# Initial combat log
	EventBus.emit_log_entry("=== COMBAT INITIATED ===", Color.YELLOW, 2.0)
	EventBus.emit_log_entry("Deploying %d agents against %s" % [active_agents.size(), server.server_name], Color.CYAN)

func end_combat(victory: bool):
	if not is_combat_active:
		return
	
	is_combat_active = false
	
	# Stop all agent attacks
	for agent in active_agents:
		if is_instance_valid(agent):
			agent.stop_combat()
			if agent.attack_performed.is_connected(_on_attack_performed):
				agent.attack_performed.disconnect(_on_attack_performed)
	
	# Calculate combat stats
	var combat_duration = (Time.get_ticks_msec() / 1000.0) - combat_start_time
	var stats = {
		"duration": combat_duration,
		"total_damage": total_damage_dealt,
		"agents_lost": 3 - active_agents.size(),
		"victory": victory
	}
	
	# Emit end signal
	var result = "VICTORY" if victory else "DEFEAT"
	EventBus.combat_ended.emit(result)
	combat_ended.emit(victory, stats)
	
	# Combat summary
	EventBus.emit_log_entry("=== COMBAT %s ===" % result, Color.GREEN if victory else Color.RED, 2.0)
	EventBus.emit_log_entry("Duration: %.1fs | Damage Dealt: %d" % [combat_duration, int(total_damage_dealt)], Color.WHITE)
	
	# Clear references
	active_agents.clear()
	current_server = null

func _on_agent_died(agent: Agent):
	active_agents.erase(agent)
	
	if current_server and is_instance_valid(current_server):
		current_server.disengage_attacker(agent)
	
	# Check for defeat
	if active_agents.is_empty() and is_combat_active:
		EventBus.emit_log_entry("All agents have been neutralized!", Color.RED, 2.0)
		end_combat(false)

func _on_server_defeated(server: EnemyServer, loot: Dictionary):
	if server == current_server:
		# Log loot
		EventBus.emit_log_entry("Server breached! Extracting data...", Color.GREEN, 1.5)
		EventBus.emit_log_entry("Credits earned: $%d" % loot.money, Color.YELLOW, 1.0)
		
		if not loot.items.is_empty():
			for item in loot.items:
				EventBus.loot_gained.emit(item.name, item.rarity)
				EventBus.emit_log_entry("Item found: %s [%s]" % [item.name, item.rarity], Color.CYAN, 1.0)
		
		end_combat(true)

func _on_attack_performed(target: Node2D, damage: float):
	total_damage_dealt += damage

func _on_server_counter_attack(target: Node2D, damage: float):
	# Server counter attacks are already handled by the server
	pass

# Helper function to check if combat can start
func can_start_combat() -> bool:
	return not is_combat_active and not active_agents.is_empty()

# Get current combat status
func get_combat_status() -> Dictionary:
	return {
		"active": is_combat_active,
		"agents_alive": active_agents.size(),
		"server_health": current_server.current_health if current_server else 0,
		"duration": (Time.get_ticks_msec() / 1000.0) - combat_start_time if is_combat_active else 0
	}

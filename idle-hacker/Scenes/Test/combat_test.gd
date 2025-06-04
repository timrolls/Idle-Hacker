extends Node2D

@export var agent_scene: PackedScene
@export var server_scene: PackedScene

@onready var agents_container = $AgentsContainer
@onready var server_position = $ServerPosition
@onready var ui_layer = $UILayer
@onready var start_button = $UILayer/StartButton
@onready var recruit_button = $UILayer/RecruitButton
@onready var hardware_button = $UILayer/HardwareButton

var recruitment_system: AgentRecruitmentSystem
var hardware_system: HardwareUpgradeSystem
var combat_manager: CombatManager

var deployed_agents: Array[Agent] = []
var current_server: EnemyServer = null

func _ready():
	# Initialize systems
	setup_systems()
	
	# Connect UI
	start_button.pressed.connect(_on_start_combat_pressed)
	recruit_button.pressed.connect(_on_recruit_pressed)
	hardware_button.pressed.connect(_on_hardware_pressed)
	
	# Add command handler for ability activation
	EventBus.command_input.connect(_on_command_input)
	
	# Give player some starting resources
	hardware_system.add_upgrade_points(5)
	
	# Create starter agents
	create_starter_agents()
	
	# Spawn first server
	spawn_server()

func setup_systems():
	# Create recruitment system
	recruitment_system = AgentRecruitmentSystem.new()
	recruitment_system.name = "RecruitmentSystem"
	add_child(recruitment_system)
	
	# Create hardware system  
	hardware_system = HardwareUpgradeSystem.new()
	hardware_system.name = "HardwareSystem"
	add_child(hardware_system)
	
	# Create combat manager
	combat_manager = CombatManager.new()
	combat_manager.name = "CombatManager"
	add_child(combat_manager)
	
	# Connect combat end to spawn next server
	combat_manager.combat_ended.connect(_on_combat_ended)

func create_starter_agents():
	var starters = recruitment_system.generate_starter_agents()
	
	var positions = [Vector2(-50, -50), Vector2(-50, 0), Vector2(-50, 50)]
	
	for i in range(starters.size()):
		var agent_data = starters[i]
		deploy_agent(agent_data, positions[i])

func deploy_agent(agent_data: Dictionary, position: Vector2):
	# Check RAM capacity
	var current_ram = recruitment_system.get_total_ram_usage()
	if current_ram + agent_data.stats.ram_cost > hardware_system.current_stats.ram_capacity:
		EventBus.emit_log_entry("Not enough RAM to deploy agent!", Color.RED)
		return
	
	if not agent_scene:
		EventBus.emit_log_entry("Agent scene not assigned!", Color.RED)
		return
	
	# Create agent instance
	var agent = agent_scene.instantiate() as Agent
	if not agent:
		EventBus.emit_log_entry("Failed to instantiate agent!", Color.RED)
		return
		
	agent.position = position
	agent.load_from_data(agent_data)
	
	# Apply hardware bonuses
	agent.apply_hardware_upgrades(
		hardware_system.current_stats.cpu_speed,
		hardware_system.current_stats.gpu_power,
		hardware_system.current_stats.cooling_efficiency
	)
	
	agents_container.add_child(agent)
	deployed_agents.append(agent)
	
	EventBus.emit_log_entry("Deployed: %s" % agent_data.name, agent_data.color)

func spawn_server():
	if current_server and is_instance_valid(current_server):
		current_server.queue_free()
	
	if not server_scene:
		EventBus.emit_log_entry("Server scene not assigned!", Color.RED)
		return
	
	# Create new server with scaling difficulty
	current_server = server_scene.instantiate() as EnemyServer
	if not current_server:
		EventBus.emit_log_entry("Failed to instantiate server!", Color.RED)
		return
		
	current_server.position = server_position.position
	
	# Random server type
	current_server.server_type = randi() % EnemyServer.ServerType.size()
	
	# Scale difficulty based on defeated servers
	current_server.difficulty_tier = 1 + (get_tree().get_nodes_in_group("defeated_servers").size() / 3)
	
	add_child(current_server)
	current_server.apply_server_type_stats()
	
	EventBus.emit_log_entry("New target identified: %s [Tier %d]" % [current_server.server_name, current_server.difficulty_tier], Color.ORANGE)

func _on_start_combat_pressed():
	if combat_manager.is_combat_active:
		EventBus.emit_log_entry("Combat already in progress!", Color.RED)
		return
	
	if deployed_agents.is_empty():
		EventBus.emit_log_entry("No agents deployed!", Color.RED)
		return
	
	# Filter out dead agents
	var alive_agents: Array[Agent] = []
	for agent in deployed_agents:
		if is_instance_valid(agent) and agent.current_health > 0:
			alive_agents.append(agent)
	
	deployed_agents = alive_agents
	
	if deployed_agents.is_empty():
		EventBus.emit_log_entry("All agents are down!", Color.RED)
		return
	
	# Start combat
	combat_manager.start_combat(deployed_agents, current_server)
	start_button.disabled = true

func _on_combat_ended(victory: bool, stats: Dictionary):
	start_button.disabled = false
	
	if victory:
		# Add to defeated servers group for difficulty scaling
		var marker = Node.new()
		marker.add_to_group("defeated_servers")
		add_child(marker)
		
		# Award upgrade points
		hardware_system.add_upgrade_points(1)
		
		# Spawn next server after delay
		await get_tree().create_timer(2.0).timeout
		spawn_server()
	else:
		EventBus.emit_log_entry("Mission Failed. Recruit new agents and try again.", Color.RED)

func _on_recruit_pressed():
	# Simple recruitment for testing
	var available = recruitment_system.get_available_recruits()
	if available.is_empty():
		return
	
	# Recruit first available
	var recruited = recruitment_system.recruit_agent(0)
	if recruited:
		var pos = Vector2(-50, randf_range(-100, 100))
		deploy_agent(recruited, pos)

func _on_hardware_pressed():
	# Toggle hardware tree visibility (would open full UI in real game)
	EventBus.emit_log_entry("Hardware tree not implemented in test scene", Color.YELLOW)
	EventBus.emit_log_entry("Current Stats: CPU x%.2f, RAM %d, GPU x%.2f" % [
		hardware_system.current_stats.cpu_speed,
		hardware_system.current_stats.ram_capacity,
		hardware_system.current_stats.gpu_power
	], Color.CYAN)

func _on_command_input(command: String):
	# Parse ability commands
	var parts = command.split(" ")
	if parts.size() < 2:
		return
	
	var ability_command = parts[0]
	var target = parts[1]
	
	# Find agent by name or index
	var agent_found = false
	for agent in deployed_agents:
		if not is_instance_valid(agent):
			continue
			
		if agent.agent_name.to_lower().contains(target.to_lower()) or target == str(deployed_agents.find(agent) + 1):
			# Try to activate ability
			for ability in agent.abilities:
				if ability.has("command") and ability.command == ability_command:
					if agent.activate_ability(ability.name):
						agent_found = true
					break
			break
	
	if not agent_found:
		EventBus.emit_log_entry("Agent or ability not found", Color.RED)

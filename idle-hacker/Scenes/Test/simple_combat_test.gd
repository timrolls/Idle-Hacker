extends Node2D

# This test version creates agents and servers dynamically without needing .tscn files

@onready var agents_container = $AgentsContainer  
@onready var server_container = $ServerContainer
@onready var ui_layer = $UILayer
@onready var start_button = $UILayer/StartButton

var recruitment_system: AgentRecruitmentSystem
var hardware_system: HardwareUpgradeSystem
var combat_manager: CombatManager

var deployed_agents: Array[Agent] = []
var current_server: EnemyServer = null

func _ready():
	# Create containers if they don't exist
	if not agents_container:
		agents_container = Node2D.new()
		agents_container.name = "AgentsContainer"
		agents_container.position = Vector2(200, 270)
		add_child(agents_container)
		
	if not server_container:
		server_container = Node2D.new()
		server_container.name = "ServerContainer"
		server_container.position = Vector2(760, 270)
		add_child(server_container)
	
	# Create UI if needed
	create_ui()
	
	# Initialize systems
	setup_systems()
	
	# Give player some starting resources
	hardware_system.add_upgrade_points(5)
	
	# Create starter agents
	create_starter_agents()
	
	# Spawn first server
	spawn_server()
	
	# Add info text
	EventBus.emit_log_entry("=== COMBAT TEST MODE ===", Color.YELLOW)
	EventBus.emit_log_entry("Click 'Start Combat' to begin", Color.CYAN)
	EventBus.emit_log_entry("Type ability commands like: 'overload 1' or 'shield 2'", Color.CYAN)

func create_ui():
	if not ui_layer:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UILayer"
		add_child(ui_layer)
	
	if not start_button:
		start_button = Button.new()
		start_button.name = "StartButton"
		start_button.text = "Start Combat"
		start_button.position = Vector2(10, 10)
		start_button.size = Vector2(140, 40)
		ui_layer.add_child(start_button)
	
	start_button.pressed.connect(_on_start_combat_pressed)
	
	# Add background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1)
	bg.size = Vector2(960, 540)
	bg.z_index = -10
	add_child(bg)
	move_child(bg, 0)

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
	
	# Connect command input
	EventBus.command_input.connect(_on_command_input)

func create_starter_agents():
	var starters = recruitment_system.generate_starter_agents()
	
	var positions = [Vector2(-50, -50), Vector2(-50, 0), Vector2(-50, 50)]
	
	for i in range(starters.size()):
		var agent_data = starters[i]
		create_agent_from_data(agent_data, positions[i])

func create_agent_from_data(agent_data: Dictionary, position: Vector2):
	# Create agent dynamically
	var agent = Agent.new()
	agent.position = position
	
	# Create visual components
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	var texture = PlaceholderTexture2D.new()
	texture.size = Vector2(32, 32)
	sprite.texture = texture
	agent.add_child(sprite)
	
	var health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.modulate = Color(1, 1, 1, 0.8)
	health_bar.position = Vector2(-20, -30)
	health_bar.size = Vector2(40, 6)
	health_bar.show_percentage = false
	agent.add_child(health_bar)
	
	var attack_timer = Timer.new()
	attack_timer.name = "AttackTimer"
	attack_timer.one_shot = false
	agent.add_child(attack_timer)
	
	# Load agent data
	agent.load_from_data(agent_data)
	
	# Apply hardware bonuses
	agent.apply_hardware_upgrades(
		hardware_system.current_stats.cpu_speed,
		hardware_system.current_stats.gpu_power,
		hardware_system.current_stats.cooling_efficiency
	)
	
	agents_container.add_child(agent)
	deployed_agents.append(agent)
	
	EventBus.emit_log_entry("Deployed: %s [%s]" % [agent_data.name, agent_data.rarity], agent_data.color)

func spawn_server():
	if current_server and is_instance_valid(current_server):
		current_server.queue_free()
	
	# Create server dynamically
	current_server = EnemyServer.new()
	
	# Create visual components
	var sprite = ColorRect.new()
	sprite.name = "Sprite"
	sprite.size = Vector2(48, 48)
	sprite.position = Vector2(-24, -24)
	sprite.color = Color.ORANGE
	current_server.add_child(sprite)
	
	var type_label = Label.new()
	type_label.name = "TypeLabel"
	type_label.position = Vector2(-24, -8)
	type_label.size = Vector2(48, 24)
	type_label.text = "SRV"
	type_label.add_theme_font_size_override("font_size", 10)
	current_server.add_child(type_label)
	
	var health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.modulate = Color(1, 0.2, 0.2, 0.8)
	health_bar.position = Vector2(-24, -36)
	health_bar.size = Vector2(48, 6)
	health_bar.show_percentage = false
	current_server.add_child(health_bar)
	
	var attack_timer = Timer.new()
	attack_timer.name = "AttackTimer"
	current_server.add_child(attack_timer)
	
	var special_timer = Timer.new()
	special_timer.name = "SpecialTimer"
	current_server.add_child(special_timer)
	
	# Random server type
	current_server.server_type = randi() % EnemyServer.ServerType.size()
	
	# Scale difficulty
	current_server.difficulty_tier = 1 + (get_tree().get_nodes_in_group("defeated_servers").size() / 3)
	
	server_container.add_child(current_server)
	current_server.apply_server_type_stats()
	
	EventBus.emit_log_entry("New target: %s [Tier %d]" % [current_server.server_name, current_server.difficulty_tier], Color.ORANGE)

func _on_start_combat_pressed():
	if combat_manager.is_combat_active:
		EventBus.emit_log_entry("Combat already in progress!", Color.RED)
		return
	
	# Filter out dead agents
	var alive_agents = []
	for agent in deployed_agents:
		if is_instance_valid(agent) and agent.current_health > 0:
			alive_agents.append(agent)
	
	deployed_agents = alive_agents
	
	if deployed_agents.is_empty():
		EventBus.emit_log_entry("No agents available!", Color.RED)
		return
	
	# Start combat
	combat_manager.start_combat(deployed_agents, current_server)
	start_button.disabled = true

func _on_combat_ended(victory: bool, stats: Dictionary):
	start_button.disabled = false
	
	if victory:
		# Add to defeated servers group
		var marker = Node.new()
		marker.add_to_group("defeated_servers")
		add_child(marker)
		
		# Award upgrade points
		hardware_system.add_upgrade_points(1)
		
		# Spawn next server after delay
		await get_tree().create_timer(2.0).timeout
		spawn_server()
		
		# Respawn dead agents for testing
		for i in range(deployed_agents.size()):
			var agent = deployed_agents[i]
			if not is_instance_valid(agent) or agent.current_health <= 0:
				# Recreate the agent
				var agent_data = recruitment_system.owned_agents[i]
				var pos = Vector2(-50, -50 + i * 50)
				create_agent_from_data(agent_data, pos)

func _on_command_input(command: String):
	# Parse ability commands
	var parts = command.split(" ")
	if parts.size() < 2:
		return
	
	var ability_command = parts[0]
	var target = parts[1]
	
	# Find agent by name or index
	for i in range(deployed_agents.size()):
		var agent = deployed_agents[i]
		if not is_instance_valid(agent):
			continue
			
		# Check if target matches agent name or index
		if agent.agent_name.to_lower().contains(target.to_lower()) or target == str(i + 1):
			# Try to activate ability
			for ability in agent.abilities:
				if ability.has("command") and ability.command == ability_command:
					if agent.activate_ability(ability.name):
						return
					break
			break

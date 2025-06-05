extends Node2D

# Views - These will be set in the editor
@export var taskbar: OSTaskbar
@export var terminal_view: Control  # Combined terminal + combat
@export var hardware_view: Control
@export var recruitment_view: Control

# Systems
var recruitment_system: AgentRecruitmentSystem
var hardware_system: HardwareUpgradeSystem
var combat_manager: CombatManager

# Combat specific
var deployed_agents: Array[Agent] = []
var current_server: EnemyServer = null

func _ready():
	# Get node references if not set in editor
	if not taskbar:
		taskbar = $UILayer/OSTaskbar
	if not terminal_view:
		terminal_view = $UILayer/TerminalView
	if not hardware_view:
		hardware_view = $UILayer/HardwareView
	if not recruitment_view:
		recruitment_view = $UILayer/RecruitmentView
	
	# Create systems
	setup_systems()
	
	# Wait for systems to initialize
	await get_tree().process_frame
	
	# Setup UI connections
	setup_ui_connections()
	
	# Initialize game
	hardware_system.add_upgrade_points(5)
	create_starter_agents()
	spawn_server()
	
	# Setup terminal view panels
	setup_terminal_panels()

func setup_systems():
	# Create recruitment system as autoload
	recruitment_system = get_node_or_null("/root/RecruitmentSystem")
	if not recruitment_system:
		recruitment_system = AgentRecruitmentSystem.new()
		recruitment_system.name = "RecruitmentSystem"
		get_tree().root.call_deferred("add_child", recruitment_system)
	
	# Create hardware system as autoload
	hardware_system = get_node_or_null("/root/HardwareSystem")  
	if not hardware_system:
		hardware_system = HardwareUpgradeSystem.new()
		hardware_system.name = "HardwareSystem"
		get_tree().root.call_deferred("add_child", hardware_system)
	
	# Create combat manager
	combat_manager = CombatManager.new()
	combat_manager.name = "CombatManager"
	add_child(combat_manager)
	
	# Connect combat events
	combat_manager.combat_ended.connect(_on_combat_ended)
	EventBus.command_input.connect(_on_command_input)

func setup_ui_connections():
	# Register views with taskbar
	taskbar.register_view_container(OSTaskbar.AppMode.TERMINAL, terminal_view)
	taskbar.register_view_container(OSTaskbar.AppMode.HARDWARE, hardware_view)
	taskbar.register_view_container(OSTaskbar.AppMode.RECRUITMENT, recruitment_view)
	
	# Connect taskbar app switching
	taskbar.app_switched.connect(_on_app_switched)
	
	# Add taskbar resources and icons
	taskbar.add_resource_label("Resources")
	taskbar.add_system_tray_icon("📡", "Network Status: ONLINE")
	taskbar.add_system_tray_icon("🛡️", "Security: ACTIVE")
	taskbar.add_alert_box()
	
	# Connect recruitment refresh
	var refresh_btn = recruitment_view.get_node("Panel/RefreshButton")
	refresh_btn.pressed.connect(_on_recruitment_refresh)
	
	# Setup recruitment UI
	setup_recruitment_display()

func setup_terminal_panels():
	# Create/update the terminal view layout panels
	var enemy_info = terminal_view.get_node_or_null("EnemyInfo")
	if not enemy_info:
		enemy_info = create_info_panel("EnemyInfo", "Enemy Info")
		terminal_view.add_child(enemy_info)
	
	var combat_preview = terminal_view.get_node_or_null("CombatPreview")
	if not combat_preview:
		combat_preview = create_combat_preview_panel()
		terminal_view.add_child(combat_preview)
	
	var agent_info = terminal_view.get_node_or_null("AgentInfo")
	if not agent_info:
		agent_info = create_info_panel("AgentInfo", "Agent Info")
		terminal_view.add_child(agent_info)
	
	# Update panels with initial data
	update_terminal_panels()

func create_info_panel(name: String, title: String) -> Panel:
	var panel = Panel.new()
	panel.name = name
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15)
	style.border_color = Color(0.3, 0.3, 0.3)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	
	# Title
	var title_label = Label.new()
	title_label.name = "Title"
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(title_label)
	
	# Container for cards
	var card_container = HBoxContainer.new()
	card_container.name = "CardContainer"
	card_container.add_theme_constant_override("separation", 10)
	panel.add_child(card_container)
	
	return panel

func create_combat_preview_panel() -> Panel:
	var panel = Panel.new()
	panel.name = "CombatPreview"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1)
	style.border_color = Color(0.3, 0.3, 0.3)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	
	# Title
	var title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "Combat preview"
	title_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(title_label)
	
	# Combat visualization area
	var combat_area = Control.new()
	combat_area.name = "CombatArea"
	combat_area.custom_minimum_size = Vector2(600, 300)
	panel.add_child(combat_area)
	
	# Agent container
	var agents_container = Node2D.new()
	agents_container.name = "AgentsContainer"
	combat_area.add_child(agents_container)
	
	# Server container
	var server_container = Node2D.new()
	server_container.name = "ServerContainer"
	combat_area.add_child(server_container)
	
	return panel

func create_entity_card(entity_name: String, entity_type: String) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(150, 100)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2)
	style.border_color = Color(0.4, 0.4, 0.4)
	style.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)
	
	# Name
	var name_label = Label.new()
	name_label.text = entity_name
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)
	
	# Type
	var type_label = Label.new()
	type_label.text = entity_type
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(type_label)
	
	# Stats
	var stats_label = Label.new()
	stats_label.text = "Stats and HP"
	stats_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(stats_label)
	
	return card

func update_terminal_panels():
	# Update enemy info cards
	var enemy_container = terminal_view.get_node("EnemyInfo/CardContainer")
	for child in enemy_container.get_children():
		child.queue_free()
	
	# Add placeholder enemy cards
	enemy_container.add_child(create_entity_card("Node", "Defense"))
	if current_server:
		enemy_container.add_child(create_entity_card(current_server.server_name, "Server"))
	else:
		enemy_container.add_child(create_entity_card("Server", "Target"))
	enemy_container.add_child(create_entity_card("Node", "Defense"))
	
	# Update agent info cards
	var agent_container = terminal_view.get_node("AgentInfo/CardContainer")
	for child in agent_container.get_children():
		child.queue_free()
	
	# Add agent cards
	for agent in deployed_agents:
		if is_instance_valid(agent):
			agent_container.add_child(create_entity_card(agent.agent_name, agent.agent_type))

func setup_recruitment_display():
	# Initial recruitment display update
	update_recruitment_display()
	
	# Connect recruitment system signals
	recruitment_system.recruitment_pool_refreshed.connect(update_recruitment_display)
	recruitment_system.agent_recruited.connect(_on_agent_recruited)

func update_recruitment_display():
	var recruits_container = recruitment_view.get_node("Panel/ScrollContainer/RecruitsContainer")
	var owned_list = recruitment_view.get_node("Panel/OwnedAgentsList")
	var money_label = recruitment_view.get_node("Panel/MoneyLabel")
	var ram_label = recruitment_view.get_node("Panel/RAMLabel")
	
	# Clear existing cards
	for child in recruits_container.get_children():
		child.queue_free()
	
	# Create recruit cards
	var available = recruitment_system.get_available_recruits()
	for i in range(available.size()):
		var agent_data = available[i]
		var card = create_recruit_card(agent_data, i)
		recruits_container.add_child(card)
	
	# Update owned agents list
	owned_list.clear()
	var owned = recruitment_system.get_owned_agents()
	for agent in owned:
		var text = "%s [%s] - RAM: %d" % [agent.name, agent.rarity, agent.stats.ram_cost]
		owned_list.add_item(text)
		var idx = owned_list.get_item_count() - 1
		owned_list.set_item_custom_fg_color(idx, agent.color)
	
	# Update resource labels
	money_label.text = "Credits: $1000"  # TODO: Connect to currency
	var used_ram = recruitment_system.get_total_ram_usage()
	var max_ram = hardware_system.current_stats.ram_capacity
	ram_label.text = "RAM: %d / %d" % [used_ram, max_ram]
	
	# Color code RAM
	var usage_percent = float(used_ram) / float(max_ram)
	if usage_percent > 0.9:
		ram_label.add_theme_color_override("font_color", Color.RED)
	elif usage_percent > 0.7:
		ram_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		ram_label.add_theme_color_override("font_color", Color.GREEN)

func create_recruit_card(agent_data: Dictionary, index: int) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(180, 220)
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15)
	style.border_color = agent_data.color
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	card.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.position = Vector2(10, 10)
	vbox.size = Vector2(160, 200)
	card.add_child(vbox)
	
	# Agent info
	var name_label = Label.new()
	name_label.text = agent_data.name
	name_label.add_theme_color_override("font_color", agent_data.color)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)
	
	var rarity_label = Label.new()
	rarity_label.text = "[%s]" % agent_data.rarity.to_upper()
	rarity_label.add_theme_color_override("font_color", agent_data.color)
	rarity_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(rarity_label)
	
	var type_label = Label.new()
	type_label.text = agent_data.type
	type_label.add_theme_font_size_override("font_size", 9)
	vbox.add_child(type_label)
	
	var stats_label = Label.new()
	stats_label.text = "HP: %.0f\nDMG: %.0f\nSPD: %.1f\nRAM: %d" % [
		agent_data.stats.max_health,
		agent_data.stats.damage,
		agent_data.stats.attack_speed,
		agent_data.stats.ram_cost
	]
	stats_label.add_theme_font_size_override("font_size", 9)
	vbox.add_child(stats_label)
	
	# Spacer
	vbox.add_spacer(true)
	
	# Recruit button
	var recruit_btn = Button.new()
	recruit_btn.text = "RECRUIT $%d" % agent_data.recruitment_cost
	recruit_btn.pressed.connect(_on_recruit_pressed.bind(index))
	vbox.add_child(recruit_btn)
	
	return card

func create_starter_agents():
	var starters = recruitment_system.generate_starter_agents()
	var positions = [Vector2(-50, -50), Vector2(-50, 0), Vector2(-50, 50)]
	
	for i in range(starters.size()):
		var agent_data = starters[i]
		deploy_agent_to_combat(agent_data, positions[i])

func deploy_agent_to_combat(agent_data: Dictionary, _position: Vector2):
	var combat_area = terminal_view.get_node("CombatPreview/CombatArea")
	var agents_container = combat_area.get_node("AgentsContainer")
	
	# Create agent dynamically
	var agent = Agent.new()
	agent.position = Vector2(100 + deployed_agents.size() * 60, 150)
	
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
	
	EventBus.emit_log_entry("Deployed: %s [%s]" % [agent_data.name, agent_data.rarity])
	
	# Update terminal panels
	update_terminal_panels()

func spawn_server():
	var combat_area = terminal_view.get_node("CombatPreview/CombatArea")
	var server_container = combat_area.get_node("ServerContainer")
	
	if current_server and is_instance_valid(current_server):
		current_server.queue_free()
	
	# Create server dynamically
	current_server = EnemyServer.new()
	current_server.position = Vector2(400, 150)
	
	# Create visual components
	var sprite = ColorRect.new()
	sprite.name = "Sprite"
	sprite.size = Vector2(48, 48)
	sprite.position = Vector2(-24, -24)
	current_server.add_child(sprite)
	
	var type_label = Label.new()
	type_label.name = "TypeLabel"
	type_label.position = Vector2(-24, -8)
	type_label.size = Vector2(48, 24)
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
	
	# Setup server
	current_server.server_type = randi() % EnemyServer.ServerType.size()
	current_server.difficulty_tier = 1 + (get_tree().get_nodes_in_group("defeated_servers").size() / 3)
	
	server_container.add_child(current_server)
	current_server.apply_server_type_stats()
	
	EventBus.emit_log_entry("Target: %s [Tier %d]" % [current_server.server_name, current_server.difficulty_tier])
	
	# Update terminal panels
	update_terminal_panels()

func start_combat():
	if combat_manager.is_combat_active:
		EventBus.emit_log_entry("Combat already in progress!")
		return
	
	var alive_agents: Array[Agent] = []
	for agent in deployed_agents:
		if is_instance_valid(agent) and agent.current_health > 0:
			alive_agents.append(agent)
	
	if alive_agents.is_empty():
		EventBus.emit_log_entry("No agents available!")
		EventBus.emit_log_entry("Deploy agents from the Recruitment app!")
		return
	
	deployed_agents = alive_agents
	combat_manager.start_combat(deployed_agents, current_server)

# UI Event Handlers
func _on_app_switched(app_mode: OSTaskbar.AppMode):
	match app_mode:
		OSTaskbar.AppMode.HARDWARE:
			if hardware_view.has_method("update_display"):
				hardware_view.update_display()
		OSTaskbar.AppMode.RECRUITMENT:
			update_recruitment_display()

func _on_combat_ended(victory: bool, stats: Dictionary):
	if victory:
		var marker = Node.new()
		marker.add_to_group("defeated_servers")
		add_child(marker)
		
		hardware_system.add_upgrade_points(1)
		EventBus.emit_log_entry("Victory! +1 Hardware Point earned.")
		
		await get_tree().create_timer(2.0).timeout
		spawn_server()
		update_terminal_panels()
	else:
		EventBus.emit_log_entry("Mission Failed. Recruit new agents.")

func _on_recruit_pressed(index: int):
	var recruited = recruitment_system.recruit_agent(index)
	if recruited:
		EventBus.emit_log_entry("Agent recruited: %s" % recruited.name)
		update_recruitment_display()

func _on_recruitment_refresh():
	recruitment_system.refresh_recruitment_pool()

func _on_agent_recruited(agent_data: Dictionary):
	update_recruitment_display()

func _on_command_input(command: String):
	var parts = command.split(" ")
	
	# Check for combat commands
	if command == "start" or command == "attack":
		start_combat()
		return
	
	# Check for ability commands
	if parts.size() < 2:
		return
	
	var ability_command = parts[0]
	var target = parts[1]
	
	for i in range(deployed_agents.size()):
		var agent = deployed_agents[i]
		if not is_instance_valid(agent):
			continue
			
		if agent.agent_name.to_lower().contains(target.to_lower()) or target == str(i + 1):
			for ability in agent.abilities:
				if ability.has("command") and ability.command == ability_command:
					if agent.activate_ability(ability.name):
						return
					break
			break

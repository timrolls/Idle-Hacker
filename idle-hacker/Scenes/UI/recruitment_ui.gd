extends Control
class_name RecruitmentUI

@onready var recruit_slots_container: GridContainer = $Panel/ScrollContainer/RecruitsContainer
@onready var owned_agents_list: ItemList = $Panel/OwnedAgentsList
@onready var money_label: Label = $Panel/MoneyLabel
@onready var ram_label: Label = $Panel/RAMLabel
@onready var refresh_button: Button = $Panel/RefreshButton

var recruitment_system: AgentRecruitmentSystem
var hardware_system: HardwareUpgradeSystem
var recruit_cards: Array[Control] = []

signal agent_recruited(agent_data: Dictionary)

func _ready():
	# Get system references
	recruitment_system = get_node("/root/RecruitmentSystem")
	hardware_system = get_node("/root/HardwareSystem")
	
	if not recruitment_system:
		push_error("RecruitmentSystem not found!")
		return
		
	# Connect signals
	recruitment_system.recruitment_pool_refreshed.connect(_on_pool_refreshed)
	recruitment_system.agent_recruited.connect(_on_agent_recruited)
	refresh_button.pressed.connect(_on_refresh_pressed)
	
	# Initial display
	update_display()

func update_display():
	# Clear existing cards
	for card in recruit_cards:
		card.queue_free()
	recruit_cards.clear()
	
	# Create cards for available recruits
	var available = recruitment_system.get_available_recruits()
	for i in range(available.size()):
		var agent_data = available[i]
		var card = create_recruit_card(agent_data, i)
		recruit_slots_container.add_child(card)
		recruit_cards.append(card)
	
	# Update owned agents list
	update_owned_agents_list()
	
	# Update resource labels
	update_resource_labels()

func create_recruit_card(agent_data: Dictionary, index: int) -> Control:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(200, 250)
	
	# Card background style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15)
	style.border_color = agent_data.color
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	card.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)
	
	# Agent name
	var name_label = Label.new()
	name_label.text = agent_data.name
	name_label.add_theme_color_override("font_color", agent_data.color)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_label)
	
	# Rarity
	var rarity_label = Label.new()
	rarity_label.text = "[%s]" % agent_data.rarity.to_upper()
	rarity_label.add_theme_color_override("font_color", agent_data.color)
	rarity_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(rarity_label)
	
	# Type and description
	var type_label = Label.new()
	type_label.text = "Type: %s" % agent_data.type
	type_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(type_label)
	
	var desc_label = Label.new()
	desc_label.text = agent_data.description
	desc_label.add_theme_font_size_override("font_size", 9)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)
	
	# Stats
	var stats_label = Label.new()
	stats_label.text = "HP: %.0f | DMG: %.0f | SPD: %.1f\nRAM: %d" % [
		agent_data.stats.max_health,
		agent_data.stats.damage,
		agent_data.stats.attack_speed,
		agent_data.stats.ram_cost
	]
	stats_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(stats_label)
	
	# Abilities preview
	var abilities_label = Label.new()
	var ability_names = []
	for ability in agent_data.abilities:
		if ability.type == "active":
			ability_names.append(ability.name)
	abilities_label.text = "Abilities: %s" % ", ".join(ability_names)
	abilities_label.add_theme_font_size_override("font_size", 9)
	abilities_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	abilities_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(abilities_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Recruit button
	var recruit_btn = Button.new()
	recruit_btn.text = "RECRUIT - $%d" % agent_data.recruitment_cost
	recruit_btn.pressed.connect(_on_recruit_pressed.bind(index))
	vbox.add_child(recruit_btn)
	
	return card

func update_owned_agents_list():
	owned_agents_list.clear()
	
	var owned = recruitment_system.get_owned_agents()
	for agent in owned:
		var text = "%s [%s] - RAM: %d" % [agent.name, agent.rarity, agent.stats.ram_cost]
		owned_agents_list.add_item(text)
		owned_agents_list.set_item_custom_fg_color(owned_agents_list.get_item_count() - 1, agent.color)

func update_resource_labels():
	# TODO: Connect to actual currency system
	money_label.text = "Credits: $1000"
	
	var used_ram = recruitment_system.get_total_ram_usage()
	var max_ram = hardware_system.current_stats.ram_capacity
	ram_label.text = "RAM: %d / %d" % [used_ram, max_ram]
	
	# Color code RAM based on usage
	var usage_percent = float(used_ram) / float(max_ram)
	if usage_percent > 0.9:
		ram_label.add_theme_color_override("font_color", Color.RED)
	elif usage_percent > 0.7:
		ram_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		ram_label.add_theme_color_override("font_color", Color.GREEN)

func _on_recruit_pressed(index: int):
	var recruited = recruitment_system.recruit_agent(index)
	if recruited:
		agent_recruited.emit(recruited)
		update_display()

func _on_refresh_pressed():
	# TODO: Check if player can afford refresh cost
	recruitment_system.refresh_recruitment_pool()
	update_display()

func _on_pool_refreshed():
	update_display()

func _on_agent_recruited(agent_data: Dictionary):
	update_display()

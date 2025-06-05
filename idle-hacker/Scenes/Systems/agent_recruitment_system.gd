extends Node
class_name AgentRecruitmentSystem

# Agent templates for different types
const AGENT_TEMPLATES = {
	"BruteForce": {
		"base_health": 100,
		"base_damage": 15,
		"base_attack_speed": 0.8,
		"ram_cost": 2,
		"description": "High damage, slower attacks",
		"rarity_weights": {"common": 70, "uncommon": 25, "rare": 5}
	},
	"Firewall": {
		"base_health": 150,
		"base_damage": 8,
		"base_attack_speed": 1.0,
		"ram_cost": 3,
		"description": "Tanky defender with damage reduction",
		"rarity_weights": {"common": 60, "uncommon": 30, "rare": 10}
	},
	"PacketSniffer": {
		"base_health": 80,
		"base_damage": 10,
		"base_attack_speed": 1.5,
		"ram_cost": 2,
		"description": "Fast attacker with escalating damage",
		"rarity_weights": {"common": 65, "uncommon": 28, "rare": 7}
	},
	"Cryptominer": {
		"base_health": 90,
		"base_damage": 12,
		"base_attack_speed": 1.2,
		"ram_cost": 4,
		"description": "Generates bonus credits during combat",
		"rarity_weights": {"common": 50, "uncommon": 35, "rare": 15}
	},
	"Botnet": {
		"base_health": 70,
		"base_damage": 8,
		"base_attack_speed": 2.0,
		"ram_cost": 1,
		"description": "Cheap, fast, but fragile",
		"rarity_weights": {"common": 80, "uncommon": 18, "rare": 2}
	}
}

# Rarity modifiers
const RARITY_MODIFIERS = {
	"common": {"stat_mult": 1.0, "color": Color.WHITE},
	"uncommon": {"stat_mult": 1.2, "color": Color.GREEN},
	"rare": {"stat_mult": 1.5, "color": Color.BLUE},
	"epic": {"stat_mult": 2.0, "color": Color.PURPLE},
	"legendary": {"stat_mult": 3.0, "color": Color.ORANGE}
}

# Name prefixes/suffixes for variety
const NAME_PREFIXES = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta", "Sigma", "Omega"]
const NAME_SUFFIXES = ["v1.0", "v2.0", "X", "Z", "Prime", "Plus", "Pro", "Elite", "Max", "Ultra"]

# Current recruitment pool
var available_recruits: Array[Dictionary] = []
var owned_agents: Array[Dictionary] = []
var recruitment_refresh_cost: int = 50
var max_recruitment_slots: int = 3

signal agent_recruited(agent_data: Dictionary)
signal recruitment_pool_refreshed()

func _ready():
	# Generate initial recruitment pool
	refresh_recruitment_pool()

func generate_random_agent(type_override: String = "") -> Dictionary:
	# Pick random type if not specified
	var agent_type = type_override
	if agent_type == "":
		agent_type = AGENT_TEMPLATES.keys().pick_random()
	
	var template = AGENT_TEMPLATES[agent_type]
	var rarity = roll_rarity(template.rarity_weights)
	var rarity_mod = RARITY_MODIFIERS[rarity]
	
	# Generate unique name
	var prefix = NAME_PREFIXES.pick_random()
	var suffix = NAME_SUFFIXES.pick_random()
	var agent_name = "%s_%s_%s" % [prefix, agent_type, suffix]
	
	# Calculate stats with variance
	var health_variance = randf_range(0.9, 1.1)
	var damage_variance = randf_range(0.9, 1.1)
	var speed_variance = randf_range(0.95, 1.05)
	
	var agent_data = {
		"id": generate_unique_id(),
		"name": agent_name,
		"type": agent_type,
		"rarity": rarity,
		"level": 1,
		"experience": 0,
		"stats": {
			"max_health": template.base_health * rarity_mod.stat_mult * health_variance,
			"damage": template.base_damage * rarity_mod.stat_mult * damage_variance,
			"attack_speed": template.base_attack_speed * speed_variance,
			"ram_cost": template.ram_cost
		},
		"abilities": generate_abilities(agent_type, rarity),
		"description": template.description,
		"color": rarity_mod.color,
		"recruitment_cost": calculate_recruitment_cost(agent_type, rarity)
	}
	
	return agent_data

func generate_abilities(agent_type: String, rarity: String): #-> Array[Dictionary]:
	var abilities = []
	
	# Base ability for all agents
	abilities.append({
		"name": "Basic Attack",
		"cooldown": 0,
		"type": "passive",
		"description": "Standard attack protocol"
	})
	
	# Type-specific abilities
	match agent_type:
		"BruteForce":
			abilities.append({
				"name": "Overload",
				"cooldown": 10.0,
				"type": "active",
				"description": "Next 3 attacks deal 200% damage",
				"command": "overload"
			})
			
		"Firewall":
			abilities.append({
				"name": "Shield Wall",
				"cooldown": 15.0,
				"type": "active",
				"description": "Blocks next 5 attacks for all agents",
				"command": "shield"
			})
			
		"PacketSniffer":
			abilities.append({
				"name": "Analyze",
				"cooldown": 8.0,
				"type": "active",
				"description": "Reveals enemy weaknesses, +50% crit chance",
				"command": "analyze"
			})
			
		"Cryptominer":
			abilities.append({
				"name": "Mine",
				"cooldown": 20.0,
				"type": "active",
				"description": "Generate 50-100 bonus credits",
				"command": "mine"
			})
			
		"Botnet":
			abilities.append({
				"name": "Swarm",
				"cooldown": 12.0,
				"type": "active",
				"description": "Attack speed x3 for 5 seconds",
				"command": "swarm"
			})
	
	# Bonus ability for higher rarities
	if rarity in ["rare", "epic", "legendary"]:
		abilities.append({
			"name": "Emergency Protocol",
			"cooldown": 30.0,
			"type": "active",
			"description": "Heal 50% HP instantly",
			"command": "emergency"
		})
	
	return abilities

func roll_rarity(weights: Dictionary) -> String:
	var total_weight = 0
	for weight in weights.values():
		total_weight += weight
	
	var roll = randi() % total_weight
	var current_weight = 0
	
	for rarity in weights:
		current_weight += weights[rarity]
		if roll < current_weight:
			return rarity
	
	return "common"  # Fallback

func calculate_recruitment_cost(agent_type: String, rarity: String) -> int:
	var base_cost = 2
	var type_multiplier = 1.0
	
	match agent_type:
		"Cryptominer":
			type_multiplier = 1.5
		"Firewall":
			type_multiplier = 1.3
		"Botnet":
			type_multiplier = 0.7
	
	var rarity_multiplier = 1.0
	match rarity:
		"uncommon":
			rarity_multiplier = 2.0
		"rare":
			rarity_multiplier = 4.0
		"epic":
			rarity_multiplier = 8.0
		"legendary":
			rarity_multiplier = 16.0
	
	return int(base_cost * type_multiplier * rarity_multiplier)

func refresh_recruitment_pool(free: bool = false):
	available_recruits.clear()
	
	# Generate new agents
	for i in range(max_recruitment_slots):
		# Ensure variety by trying to avoid duplicates
		var attempts = 0
		var new_agent
		var types_used = []
		
		while attempts < 10:
			new_agent = generate_random_agent()
			if not new_agent.type in types_used or attempts > 5:
				types_used.append(new_agent.type)
				break
			attempts += 1
		
		available_recruits.append(new_agent)
	
	recruitment_pool_refreshed.emit()
	
	if not free:
		EventBus.emit_log_entry("Recruitment pool refreshed!", Globals.success_color)

func recruit_agent(index: int) -> Dictionary:
	if index < 0 or index >= available_recruits.size():
		return {}
	
	var agent_data = available_recruits[index]
	
	# Check if player can afford it (would connect to currency system)
	# For now, just add to owned
	owned_agents.append(agent_data)
	available_recruits.remove_at(index)
	
	# Add a new recruit to fill the slot
	available_recruits.insert(index, generate_random_agent())
	
	agent_recruited.emit(agent_data)
	EventBus.emit_log_entry("Recruited: %s [%s]" % [agent_data.name, agent_data.rarity], RARITY_MODIFIERS[agent_data.rarity].color)
	
	return agent_data

func generate_unique_id() -> String:
	return "agent_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000)

func get_total_ram_usage() -> int:
	var total = 0
	for agent in owned_agents:
		total += agent.stats.ram_cost
	return total

func get_available_recruits() -> Array[Dictionary]:
	return available_recruits

func get_owned_agents() -> Array[Dictionary]:
	return owned_agents

func generate_starter_agents() -> Array[Dictionary]:
	var starters: Array[Dictionary] = []
	
	# Give player 3 starter agents
	starters.append(generate_random_agent("BruteForce"))
	starters.append(generate_random_agent("Firewall"))
	starters.append(generate_random_agent("PacketSniffer"))
	
	# Make sure they're at least common rarity
	for agent in starters:
		agent.recruitment_cost = 0  # Free starters
		owned_agents.append(agent)
	
	return starters

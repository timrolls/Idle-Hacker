extends Node2D
class_name Agent

# Agent stats
@export_group("Base Stats")
@export var agent_name: String = "Agent"
@export var agent_type: String = "BruteForce"
@export var max_health: float = 100.0
@export var base_damage: float = 10.0
@export var base_attack_speed: float = 1.0  # Attacks per second
@export var ram_cost: int = 2

# Current state
var current_health: float
var is_attacking: bool = false
var current_target: Node2D = null
var agent_data: Dictionary = {}  # Full agent data from recruitment
var level: int = 1
var experience: int = 0

# Abilities
#var abilities: Array[Dictionary] = []
var abilities: Array = []
var ability_cooldowns: Dictionary = {}  # Track cooldowns
var active_buffs: Array[Dictionary] = []  # Active ability effects

# Visuals
@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var attack_timer: Timer = $AttackTimer

# Upgrade modifiers (from hardware)
var cpu_speed_multiplier: float = 1.0
var damage_multiplier: float = 1.0
var defense_multiplier: float = 1.0

signal agent_died(agent: Agent)
signal attack_performed(target: Node2D, damage: float)

func _ready():
	current_health = max_health
	setup_health_bar()
	setup_attack_timer()
	
	# Apply visual style based on agent type
	#apply_agent_style()
	
	# Initialize ability cooldowns
	setup_abilities()

func setup_health_bar():
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.show_percentage = false
	health_bar.size = Vector2(40, 6)
	health_bar.position = Vector2(-20, -30)

func setup_attack_timer():
	attack_timer.wait_time = 1.0 / (base_attack_speed * cpu_speed_multiplier)
	attack_timer.timeout.connect(_on_attack_timer_timeout)

#func apply_agent_style():
	#match agent_type:
		#"BruteForce":
			#sprite.modulate = Color.BLUE
			#agent_name = "BruteForce_Agent" if agent_name == "Agent" else agent_name
		#"Firewall":
			#sprite.modulate = Color.GREEN
			#agent_name = "Firewall_Agent" if agent_name == "Agent" else agent_name
		#"PacketSniffer":
			#sprite.modulate = Color.RED
			#agent_name = "PacketSniffer_Agent" if agent_name == "Agent" else agent_name
		#"Cryptominer":
			#sprite.modulate = Color.YELLOW
			#agent_name = "Cryptominer_Agent" if agent_name == "Agent" else agent_name
		#"Botnet":
			#sprite.modulate = Color.PURPLE
			#agent_name = "Botnet_Agent" if agent_name == "Agent" else agent_name
	#
	## Apply rarity color if we have agent data
	#if agent_data.has("color"):
		#sprite.modulate = sprite.modulate.blend(agent_data.color)

func start_combat(target: Node2D):
	if not is_attacking and is_instance_valid(target):
		current_target = target
		is_attacking = true
		attack_timer.start()
		
		# Announce action
		EventBus.emit_agent_action(agent_name, "Engaging target", target.name)

func stop_combat():
	is_attacking = false
	current_target = null
	attack_timer.stop()

func perform_attack():
	if not is_instance_valid(current_target):
		stop_combat()
		return
	
	var damage = calculate_damage()
	attack_performed.emit(current_target, damage)
	
	# Visual feedback
	_play_attack_animation()
	
	# Log the attack
	EventBus.emit_damage(agent_name, current_target.name, int(damage))
	
	# Deal damage to target
	if current_target.has_method("take_damage"):
		current_target.take_damage(damage)



func take_damage(amount: float):
	# Apply defense modifier
	var actual_damage = amount / defense_multiplier
	
	# Firewall agents have damage reduction
	if agent_type == "Firewall":
		actual_damage *= 0.7
	
	current_health -= actual_damage
	health_bar.value = current_health
	
	# Visual feedback
	_play_hurt_animation()
	
	# Emit health change signal
	EventBus.agent_health_changed.emit(agent_name, current_health, max_health)
	
	if current_health <= 0:
		die()

func die():
	stop_combat()
	EventBus.agent_died.emit(self)
	EventBus.emit_agent_action(agent_name, "SYSTEM FAILURE", "")
	
	# Death animation
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func heal(amount: float):
	current_health = min(current_health + amount, max_health)
	health_bar.value = current_health
	EventBus.agent_health_changed.emit(agent_name, current_health, max_health)

func apply_hardware_upgrades(cpu_mult: float, dmg_mult: float, def_mult: float):
	cpu_speed_multiplier = cpu_mult
	damage_multiplier = dmg_mult
	defense_multiplier = def_mult
	
	# Update attack speed
	if attack_timer:
		attack_timer.wait_time = 1.0 / (base_attack_speed * cpu_speed_multiplier)

func _play_attack_animation():
	var tween = get_tree().create_tween()
	tween.tween_property(sprite, "position:x", sprite.position.x + 10, 0.1)
	tween.tween_property(sprite, "position:x", sprite.position.x, 0.1)

func _play_hurt_animation():
	var tween = get_tree().create_tween()
	tween.tween_property(sprite, "modulate:v", 0.5, 0.1)
	tween.tween_property(sprite, "modulate:v", 1.0, 0.1)

func _on_attack_timer_timeout():
	if is_attacking:
		perform_attack()

func get_status_info() -> Dictionary:
	return {
		"name": agent_name,
		"type": agent_type,
		"health": current_health,
		"max_health": max_health,
		"damage": base_damage * damage_multiplier,
		"attack_speed": base_attack_speed * cpu_speed_multiplier,
		"ram_cost": ram_cost
	}

# New ability system functions
func setup_abilities():
	if agent_data.has("abilities"):
		abilities = agent_data.abilities
		
		# Initialize cooldown timers
		for ability in abilities:
			if ability.type == "active":
				ability_cooldowns[ability.name] = 0.0

func load_from_data(data: Dictionary):
	agent_data = data
	agent_name = data.name
	agent_type = data.type
	level = data.level
	experience = data.experience
	
	# Load stats
	if data.has("stats"):
		max_health = data.stats.max_health
		base_damage = data.stats.damage
		base_attack_speed = data.stats.attack_speed
		ram_cost = data.stats.ram_cost
	
	current_health = max_health
	
	# Setup abilities from data
	setup_abilities()
	#apply_agent_style()

func activate_ability(ability_name: String) -> bool:
	for ability in abilities:
		if ability.name == ability_name and ability.type == "active":
			# Check cooldown
			if ability_cooldowns[ability_name] > 0:
				EventBus.emit_log_entry("%s: %s on cooldown (%.1fs)" % [agent_name, ability_name, ability_cooldowns[ability_name]], Color.ORANGE)
				return false
			
			# Activate ability
			_execute_ability(ability)
			ability_cooldowns[ability_name] = ability.cooldown
			return true
	
	return false

func _execute_ability(ability: Dictionary):
	EventBus.emit_agent_action(agent_name, "ACTIVATING: " + ability.name, "")
	
	match ability.command:
		"overload":
			_activate_overload()
		"shield":
			_activate_shield()
		"analyze":
			_activate_analyze()
		"mine":
			_activate_mine()
		"swarm":
			_activate_swarm()
		"emergency":
			_activate_emergency()

func _activate_overload():
	var buff = {
		"name": "Overload",
		"type": "damage_mult",
		"value": 2.0,
		"duration": 3,  # 3 attacks
		"remaining": 3
	}
	active_buffs.append(buff)
	
	# Visual effect
	var tween = get_tree().create_tween()
	tween.tween_property(sprite, "modulate:v", 2.0, 0.2)
	tween.tween_property(sprite, "modulate:v", 1.0, 0.2)

func _activate_shield():
	# This would affect all agents - needs combat manager integration
	EventBus.emit_log_entry("SHIELD WALL ACTIVATED - All agents protected!", Color.GREEN)
	
	# Visual effect
	var shield_rect = ColorRect.new()
	shield_rect.size = Vector2(40, 40)
	shield_rect.position = Vector2(-20, -20)
	shield_rect.color = Color(0, 1, 0, 0.3)
	shield_rect.z_index = -1
	add_child(shield_rect)
	
	var tween = get_tree().create_tween()
	tween.tween_property(shield_rect, "modulate:a", 0.0, 2.0)
	tween.tween_callback(shield_rect.queue_free)

func _activate_analyze():
	var buff = {
		"name": "Analyze",
		"type": "crit_chance",
		"value": 0.5,
		"duration": 5.0,
		"remaining": 5.0
	}
	active_buffs.append(buff)
	EventBus.emit_log_entry("%s: Enemy patterns analyzed!" % agent_name, Color.CYAN)

func _activate_mine():
	var credits = randi_range(50, 100)
	EventBus.emit_log_entry("%s: Mined %d credits!" % [agent_name, credits], Color.YELLOW)
	# Would connect to currency system

func _activate_swarm():
	var original_speed = attack_timer.wait_time
	attack_timer.wait_time = original_speed / 3.0
	
	EventBus.emit_log_entry("%s: SWARM MODE!" % agent_name, Color.PURPLE)
	
	# Reset after 5 seconds
	await get_tree().create_timer(5.0).timeout
	if attack_timer:
		attack_timer.wait_time = original_speed

func _activate_emergency():
	var heal_amount = max_health * 0.5
	heal(heal_amount)
	EventBus.emit_log_entry("%s: Emergency repairs! +%.0f HP" % [agent_name, heal_amount], Color.GREEN)

func _process(delta):
	# Update ability cooldowns
	for ability_name in ability_cooldowns:
		if ability_cooldowns[ability_name] > 0:
			ability_cooldowns[ability_name] -= delta
			ability_cooldowns[ability_name] = max(0, ability_cooldowns[ability_name])
	
	# Update buff durations
	var expired_buffs = []
	for buff in active_buffs:
		if buff.has("duration") and typeof(buff.duration) == TYPE_FLOAT:
			buff.remaining -= delta
			if buff.remaining <= 0:
				expired_buffs.append(buff)
	
	for buff in expired_buffs:
		active_buffs.erase(buff)

func calculate_damage() -> float:
	# Base damage modified by hardware upgrades
	var final_damage = base_damage * damage_multiplier
	
	# Apply active buffs
	for buff in active_buffs:
		if buff.type == "damage_mult":
			final_damage *= buff.value
	
	# Add some variance
	final_damage *= randf_range(0.8, 1.2)
	
	# Check for crit
	var crit_chance = 0.1  # Base 10%
	for buff in active_buffs:
		if buff.type == "crit_chance":
			crit_chance += buff.value
	
	if randf() < crit_chance:
		final_damage *= 2.0
		EventBus.emit_agent_action(agent_name, "CRITICAL HIT!", "")
	
	# Special ability based on type
	match agent_type:
		"PacketSniffer":
			# Damage increases over time
			final_damage *= (1.0 + (attack_timer.wait_time * 0.1))
	
	# Decrease buff counters for per-attack buffs
	for buff in active_buffs:
		if buff.has("duration") and typeof(buff.duration) == TYPE_INT:
			buff.remaining -= 1
			if buff.remaining <= 0:
				active_buffs.erase(buff)
	
	return final_damage

extends Node2D
class_name EnemyServer

# Server types with different behaviors
enum ServerType { 
	BASIC,
	FIREWALL,
	HONEYPOT,
	ENCRYPTED,
	CORPORATE
}

# Server stats
@export_group("Server Configuration")
@export var server_type: ServerType = ServerType.BASIC
@export var server_name: String = "Server"
@export var max_health: float = 100.0
@export var base_damage: float = 5.0
@export var attack_speed: float = 0.5  # Slower than agents
@export var difficulty_tier: int = 1

# Loot configuration
@export_group("Rewards")
@export var base_money_reward: int = 10
@export var xp_reward: int = 5
@export var drop_chance: float = 0.1  # 10% chance for special drops

# Current state
var current_health: float
var is_defending: bool = false
var current_attackers: Array[Node2D] = []
var security_level: float = 1.0  # Multiplier for difficulty

# Components
@onready var sprite: ColorRect = $Sprite
@onready var health_bar: ProgressBar = $HealthBar
@onready var type_label: Label = $TypeLabel
@onready var attack_timer: Timer = $AttackTimer
@onready var special_timer: Timer = $SpecialTimer

signal server_defeated(server: EnemyServer, loot: Dictionary)
signal counter_attack(target: Node2D, damage: float)

func _ready():
	current_health = max_health
	setup_visuals()
	setup_health_bar()
	setup_timers()
	apply_server_type_stats()

func setup_visuals():
	# Create sprite if not exists
	if not sprite:
		sprite = ColorRect.new()
		sprite.name = "Sprite"
		add_child(sprite)
	
	sprite.size = Vector2(48, 48)
	sprite.position = Vector2(-24, -24)
	
	# Create type label if not exists
	if not type_label:
		type_label = Label.new()
		type_label.name = "TypeLabel"
		add_child(type_label)
	
	type_label.position = Vector2(-24, -8)
	type_label.add_theme_font_size_override("font_size", 10)

func setup_health_bar():
	if not health_bar:
		health_bar = ProgressBar.new()
		health_bar.name = "HealthBar"
		add_child(health_bar)
	
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.show_percentage = false
	health_bar.size = Vector2(48, 6)
	health_bar.position = Vector2(-24, -36)

func setup_timers():
	if not attack_timer:
		attack_timer = Timer.new()
		attack_timer.name = "AttackTimer"
		add_child(attack_timer)
	
	attack_timer.wait_time = 1.0 / attack_speed
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	if not special_timer:
		special_timer = Timer.new()
		special_timer.name = "SpecialTimer"
		add_child(special_timer)
	
	special_timer.wait_time = 5.0  # Special abilities every 5 seconds
	special_timer.timeout.connect(_on_special_timer_timeout)

func apply_server_type_stats():
	match server_type:
		ServerType.BASIC:
			sprite.color = Color.ORANGE
			type_label.text = "SRV"
			server_name = "Basic_Server"
			# Standard stats
			
		ServerType.FIREWALL:
			sprite.color = Color.RED
			type_label.text = "FW"
			server_name = "Firewall_Server"
			max_health *= 1.5
			base_damage *= 0.8
			
		ServerType.HONEYPOT:
			sprite.color = Color.YELLOW
			type_label.text = "HP"
			server_name = "Honeypot_Server"
			max_health *= 0.7
			base_damage *= 1.5  # Punishes attackers
			
		ServerType.ENCRYPTED:
			sprite.color = Color.PURPLE
			type_label.text = "ENC"
			server_name = "Encrypted_Server"
			max_health *= 1.2
			# Takes reduced damage initially
			
		ServerType.CORPORATE:
			sprite.color = Color.DARK_RED
			type_label.text = "CORP"
			server_name = "Corporate_Server"
			max_health *= 2.0
			base_damage *= 1.3
			base_money_reward *= 3
	
	# Apply difficulty scaling
	max_health *= (1.0 + (difficulty_tier - 1) * 0.5)
	base_damage *= (1.0 + (difficulty_tier - 1) * 0.3)
	base_money_reward = int(base_money_reward * (1.0 + (difficulty_tier - 1) * 0.5))
	
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func engage_attacker(attacker: Node2D):
	if not attacker in current_attackers:
		current_attackers.append(attacker)
		
		if not is_defending:
			start_defense()

func disengage_attacker(attacker: Node2D):
	current_attackers.erase(attacker)
	
	if current_attackers.is_empty():
		stop_defense()

func start_defense():
	is_defending = true
	attack_timer.start()
	special_timer.start()
	
	EventBus.server_response.emit(server_name, "INTRUSION DETECTED - ACTIVATING DEFENSES")

func stop_defense():
	is_defending = false
	attack_timer.stop()
	special_timer.stop()

func take_damage(amount: float):
	var actual_damage = amount
	
	# Type-specific damage reduction
	match server_type:
		ServerType.FIREWALL:
			actual_damage *= 0.7  # 30% damage reduction
		ServerType.ENCRYPTED:
			# Reduces damage based on remaining health percentage
			var health_percent = current_health / max_health
			actual_damage *= (1.0 - (health_percent * 0.3))
	
	current_health -= actual_damage
	health_bar.value = current_health
	
	# Visual feedback
	_play_damage_flash()
	
	EventBus.server_health_changed.emit(server_name, current_health, max_health)
	
	if current_health <= 0:
		die()

func perform_counter_attack():
	if current_attackers.is_empty():
		return
	
	# Pick random target
	var target = current_attackers.pick_random()
	if not is_instance_valid(target):
		current_attackers.erase(target)
		return
	
	var damage = calculate_counter_damage()
	counter_attack.emit(target, damage)
	
	# Log the counter attack
	EventBus.emit_damage(server_name, target.name, int(damage))
	EventBus.server_response.emit(server_name, "COUNTER-ATTACK INITIATED")
	
	# Deal damage
	if target.has_method("take_damage"):
		target.take_damage(damage)

func calculate_counter_damage() -> float:
	var damage = base_damage * security_level
	
	# Type-specific damage modifiers
	match server_type:
		ServerType.HONEYPOT:
			# Deals increasing damage over time
			damage *= (1.0 + (attack_timer.wait_time * 0.2))
		ServerType.CORPORATE:
			# Has a chance for devastating attacks
			if randf() < 0.15:
				damage *= 2.5
				EventBus.server_response.emit(server_name, "SECURITY PROTOCOL ALPHA ENGAGED!")
	
	return damage * randf_range(0.9, 1.1)

func use_special_ability():
	match server_type:
		ServerType.FIREWALL:
			# Damage reduction buff
			EventBus.server_response.emit(server_name, "FIREWALL REINFORCED")
			security_level = 1.5
			var tween = get_tree().create_tween()
			tween.tween_property(sprite, "modulate", Color.RED * 1.5, 0.2)
			tween.tween_interval(2.0)
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
			tween.tween_callback(func(): security_level = 1.0)
			
		ServerType.HONEYPOT:
			# Damage all attackers
			EventBus.server_response.emit(server_name, "HONEYPOT TRAP ACTIVATED!")
			for attacker in current_attackers:
				if is_instance_valid(attacker) and attacker.has_method("take_damage"):
					attacker.take_damage(base_damage * 0.5)
			
		ServerType.ENCRYPTED:
			# Heal
			var heal_amount = max_health * 0.2
			current_health = min(current_health + heal_amount, max_health)
			health_bar.value = current_health
			EventBus.server_response.emit(server_name, "SELF-REPAIR PROTOCOL")
			
		ServerType.CORPORATE:
			# Call for backup (would spawn adds in full game)
			EventBus.server_response.emit(server_name, "BACKUP REQUESTED - ALERTING SECURITY")

func die():
	stop_defense()
	
	# Calculate loot
	var loot = calculate_loot()
	server_defeated.emit(self, loot)
	
	EventBus.server_response.emit(server_name, "SYSTEM COMPROMISED")
	EventBus.server_defeated.emit(server_name, [loot])
	
	# Death animation
	var tween = get_tree().create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.2)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2(0, 0), 0.3)
	tween.tween_callback(queue_free)

func calculate_loot() -> Dictionary:
	var loot = {
		"money": base_money_reward * randi_range(8, 12) / 10,
		"xp": xp_reward,
		"items": []
	}
	
	# Chance for special drops
	if randf() < drop_chance:
		match server_type:
			ServerType.CORPORATE:
				loot.items.append({"name": "Corporate_Data", "rarity": "rare"})
			ServerType.ENCRYPTED:
				loot.items.append({"name": "Encryption_Key", "rarity": "uncommon"})
			_:
				loot.items.append({"name": "Server_Component", "rarity": "common"})
	
	return loot

func _play_damage_flash():
	var tween = get_tree().create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE * 2, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func _on_attack_timer_timeout():
	if is_defending:
		perform_counter_attack()

func _on_special_timer_timeout():
	if is_defending:
		use_special_ability()

func get_status_info() -> Dictionary:
	return {
		"name": server_name,
		"type": ServerType.keys()[server_type],
		"health": current_health,
		"max_health": max_health,
		"security_level": security_level,
		"tier": difficulty_tier
	}

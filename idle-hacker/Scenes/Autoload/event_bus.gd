extends Node

# Combat-related signals
signal combat_started(agents: Array, server: Node)
signal combat_ended(result: String)
signal damage_dealt(attacker: String, target: String, damage: int)
signal agent_health_changed(agent_name: String, health: float, max_health: float)
signal server_health_changed(server_name: String, health: float, max_health: float)

# Agent action signals
signal agent_action(agent_name: String, action: String, target: String)
signal agent_died(agent_name: String)

# Server/enemy signals
signal server_response(server_name: String, action: String)
signal server_defeated(server_name: String, loot: Array)

# Command prompt signals
signal command_prompt_shown(command_type: String, time_limit: float)
signal command_entered(command: String, success: bool)

# General game events
signal loot_gained(item_name: String, rarity: String)
signal upgrade_unlocked(upgrade_name: String)

# Command input signal
signal command_input(command: String)
signal ascii_art_display(art: String, color: Color, speed: float)

# Helper functions to emit common events
func emit_damage(attacker: String, target: String, damage: int):
	damage_dealt.emit(attacker, target, damage)

func emit_agent_action(agent: String, action: String, target: String = ""):
	agent_action.emit(agent, action, target)

func emit_command(command: String):
	command_input.emit(command)

func emit_ascii_art(art: String, color: Color = Color.WHITE, speed: float = 0.5):
	ascii_art_display.emit(art, color, speed)
	
	

#Note for signaling ascii art
#EventBus.emit_ascii_art("""
	#/\_/\  
   #( ^.^ ) 
	#> ^ <  
#""", Color.CYAN, 0.4)

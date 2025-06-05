extends Node

########################
# From any script in the game
# TerminalCommands.add_custom_command("hack", "Start hacking sequence", my_hack_function)
# To register a new command
########################

# Dictionary to store all available commands
var commands: Dictionary = {}

func _ready():
	register_all_commands()

func register_all_commands():
	# Basic system commands
	register_command("help", "Show available commands", _cmd_help)
	register_command("status", "Display system status", _cmd_status)
	register_command("clear", "Clear terminal log", _cmd_clear)
	
	# Agent commands
	register_command("boost", "Boost agent performance", _cmd_boost)
	register_command("heal", "Emergency agent healing", _cmd_heal)
	register_command("agents", "List active agents", _cmd_agents)
	
	# Visual commands
	register_command("logo", "Display system logo", _cmd_logo)
	register_command("banner", "Show warning banner", _cmd_banner)
	
	# Combat ability commands
	register_command("overload", "Activate BruteForce overload ability", _cmd_ability)
	register_command("shield", "Activate Firewall shield ability", _cmd_ability)
	register_command("analyze", "Activate PacketSniffer analyze ability", _cmd_ability)
	register_command("mine", "Activate Cryptominer mining ability", _cmd_ability)
	register_command("swarm", "Activate Botnet swarm ability", _cmd_ability)
	register_command("emergency", "Activate emergency healing (rare agents)", _cmd_ability)

func register_command(cmd_name: String, description: String, callback: Callable):
	commands[cmd_name] = {
		"description": description,
		"callback": callback
	}

func execute_command(command: String) -> bool:
	var cmd = command.to_lower().strip_edges()
	
	if cmd in commands:
		commands[cmd].callback.call(cmd)
		return true
	else:
		EventBus.emit_command_result(command, false, "Unknown command: %s" % command)
		return false

func get_command_list() -> Array[String]:
	var cmd_list: Array[String] = []
	for cmd_name in commands.keys():
		var desc = commands[cmd_name].description
		cmd_list.append("%s - %s" % [cmd_name, desc])
	return cmd_list

# Command implementations
func _cmd_help(cmd: String):
	var help_lines = ["Available commands:"]
	help_lines.append_array(get_command_list())
	EventBus.emit_multiline_log(help_lines, Globals.help_color,  2.0)

func _cmd_status(cmd: String):
	var status_lines = [
		"=== SYSTEM STATUS ===",
		"CPU: %d%% efficient" % randi_range(95, 99),
		"Memory: %.1fGB / 8GB" % randf_range(1.8, 3.2),
		"Network: SECURED",
		"Agents: 3 ACTIVE",
		"Uptime: %02d:%02d:%02d" % [
			randi_range(0, 23),
			randi_range(0, 59), 
			randi_range(0, 59)
		],
		"Status: OPERATIONAL"
	]
	EventBus.emit_multiline_log(status_lines, Color.GREEN, 1.5)

func _cmd_clear(cmd: String):
	EventBus.emit_clear_log()
	EventBus.emit_log_entry("Terminal cleared.", Globals.command_color, 3.0)

func _cmd_boost(cmd: String):
	EventBus.emit_log_entry("Boosting agent performance...", Globals.command_color, 1.0)
	EventBus.command_entered.emit("boost", true)

func _cmd_heal(cmd: String):
	EventBus.emit_log_entry("Initiating emergency protocols...", Globals.command_color, 1.0)
	EventBus.command_entered.emit("heal", true)

func _cmd_agents(cmd: String):
	var agent_lines = [
		"=== ACTIVE AGENTS ===",
		"[1] BruteForce_Agent - Status: ONLINE",
		"[2] Firewall_Agent - Status: ONLINE", 
		"[3] PacketSniffer_Agent - Status: ONLINE",
		"",
		"All agents operating within normal parameters."
	]
	EventBus.emit_multiline_log(agent_lines, Globals.command_color,  1.8)

func _cmd_logo(cmd: String):
	var logo_art = """
██╗  ██╗ █████╗  ██████╗██╗  ██╗
██║  ██║██╔══██╗██╔════╝██║ ██╔╝
███████║███████║██║     █████╔╝ 
██╔══██║██╔══██║██║     ██╔═██╗ 
██║  ██║██║  ██║╚██████╗██║  ██╗
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
	  NETWORK INFILTRATION SYSTEM
		 v2.1.7 - CLASSIFIED

"""
	EventBus.emit_ascii_art(logo_art, Globals.command_color,  5.0)

func _cmd_banner(cmd: String):
	var banner_art = """
╔══════════════════════════════════╗
║    UNAUTHORIZED ACCESS DETECTED  ║
║      DEPLOYING COUNTERMEASURES   ║
║         [ ! WARNING ! ]          ║
╚══════════════════════════════════╝"""
	EventBus.emit_ascii_art(banner_art, Globals.command_color,  5.0)

# Ability command handler
func _cmd_ability(cmd: String):
	# The ability commands are handled by the command input system
	# This just provides feedback that the command was recognized
	EventBus.emit_log_entry("Ability command recognized: %s" % cmd)
	EventBus.emit_log_entry("Usage: %s [agent_name or number]" % cmd)

# Helper function to add new commands at runtime
func add_custom_command(cmd_name: String, description: String, callback: Callable):
	register_command(cmd_name, description, callback)

# Helper function to remove commands
func remove_command(cmd_name: String):
	commands.erase(cmd_name)

extends Control

@onready var text_display = $ScrollContainer/RichTextLabel
@onready var scroll_container = $ScrollContainer

var max_lines: int = 100
var current_lines: int = 0
var line_buffer: Array[String] = []

# Animation variables
var is_animating: bool = false
var animation_queue: Array[Dictionary] = []
var glitch_chars: String = "!@#$%^&*()_+-=[]{}|;':\",./<>?~`"

# Exported animation settings
@export_group("Animation Settings")
@export var base_characters_per_minute: float = 600.0  # 600 = 10 chars per second
@export_range(0.0, 1.0) var glitch_chance: float = 0.7  # 70% chance per character
@export var max_glitch_iterations: int = 3
@export var cursor_character: String = "▮"
@export var cursor_blink_speed: float = 0.5  # Seconds between blink states
@export var glitch_speed_multiplier: float = 0.3  # How much to slow down during glitch
@export var line_by_line_delay: float = 0.1  # Delay between lines in line-by-line mode

# Exported colors
@export_group("Text Colors")
@export var damage_color: Color = Color.ORANGE
@export var agent_action_color: Color = Color.CYAN
@export var server_response_color: Color = Color.RED
@export var combat_event_color: Color = Color.YELLOW
@export var success_color: Color = Color.GREEN
@export var warning_color: Color = Color.MAGENTA
@export var command_color: Color = Color.YELLOW
@export var help_color: Color = Color.CYAN
@export var error_color: Color = Color.RED
@export var system_color: Color = Color.GREEN

func _ready():
	# Set up terminal styling
	text_display.bbcode_enabled = true
	text_display.fit_content = true
	
	# Connect to EventBus signals
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.agent_action.connect(_on_agent_action)
	EventBus.server_response.connect(_on_server_response)
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.combat_ended.connect(_on_combat_ended)
	EventBus.agent_health_changed.connect(_on_agent_health_changed)
	EventBus.command_entered.connect(_on_command_entered)
	EventBus.command_input.connect(_on_command_input)
	EventBus.ascii_art_display.connect(_on_ascii_art_display)
	
	# Add initial startup message
	process_command("logo")
	add_log_entry(">> NETWORK INFILTRATION SYSTEM ONLINE <<", system_color)
	add_log_entry("Initializing agent protocols...", system_color)

func add_log_entry(message: String, color: Color = Color.WHITE, speed_multiplier: float = 1.0):
	var timestamp = "[%02d:%02d:%02d] " % [
		Time.get_time_dict_from_system().hour,
		Time.get_time_dict_from_system().minute, 
		Time.get_time_dict_from_system().second
	]
	
	# Check if this is a multi-line message
	var lines = message.split("\n")
	
	if lines.size() > 1:
		# Multi-line message - animate each line separately
		for i in range(lines.size()):
			var line_text = lines[i]
			# Only add timestamp to first line
			if i == 0:
				line_text = timestamp + line_text
			else:
				# Indent continuation lines slightly
				line_text = "    " + line_text
			
			var animation_data = create_animation_data(line_text, color, speed_multiplier, false)
			animation_queue.append(animation_data)
	else:
		# Single line message - original behavior
		var full_message = timestamp + message
		var animation_data = create_animation_data(full_message, color, speed_multiplier, false)
		animation_queue.append(animation_data)
	
	# Start animation if not already running
	if not is_animating:
		process_animation_queue()

func add_multiline_log(lines: Array, color: Color = Color.WHITE, speed_multiplier: float = 1.0):
	# Helper function for explicitly multi-line content - uses char-by-char
	var message = "\n".join(lines)
	add_log_entry(message, color, speed_multiplier)

func add_ascii_art(art: String, color: Color = Color.WHITE, speed_multiplier: float = 0.5, line_by_line: bool = true):
	# Special function for ASCII art - can use line-by-line mode for better performance
	var timestamp = "[%02d:%02d:%02d] " % [
		Time.get_time_dict_from_system().hour,
		Time.get_time_dict_from_system().minute, 
		Time.get_time_dict_from_system().second
	]
	
	var lines = art.split("\n")
	for i in range(lines.size()):
		var line_text = lines[i]
		# Only add timestamp to first line
		if i == 0:
			line_text = timestamp + line_text
		else:
			# Indent continuation lines slightly
			line_text = "    " + line_text
		
		var animation_data = create_animation_data(line_text, color, speed_multiplier, line_by_line)
		animation_queue.append(animation_data)
	
	# Start animation if not already running
	if not is_animating:
		process_animation_queue()

func create_animation_data(full_message: String, color: Color, speed_multiplier: float, line_by_line: bool) -> Dictionary:
	# Calculate timing: chars per minute -> seconds per char
	var chars_per_second = (base_characters_per_minute * speed_multiplier) / 60.0
	var seconds_per_char = 1.0 / chars_per_second
	
	return {
		"message": full_message,
		"color": color,
		"char_delay": seconds_per_char,
		"line_by_line": line_by_line
	}

func process_animation_queue():
	if animation_queue.is_empty():
		is_animating = false
		return
	
	is_animating = true
	var current_anim = animation_queue.pop_front()
	
	if current_anim.line_by_line:
		await animate_line_instantly(current_anim)
	else:
		await animate_text_entry(current_anim)
	
	# Process next in queue
	process_animation_queue()

func animate_line_instantly(anim_data: Dictionary):
	# Add the full line instantly, then wait for line delay
	var formatted_line = "[color=%s]%s[/color]" % [anim_data.color.to_html(), anim_data.message]
	line_buffer.append(formatted_line)
	current_lines += 1
	
	update_display()
	
	# Auto-scroll
	await get_tree().process_frame
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value
	
	# Wait before next line
	await get_tree().create_timer(line_by_line_delay).timeout
	
	if current_lines > max_lines:
		trim_old_lines()

func animate_text_entry(anim_data: Dictionary):
	var message = anim_data.message
	var char_delay = anim_data.char_delay
	
	# Add placeholder to buffer
	var placeholder_line = "[color=%s]%s[/color]" % [anim_data.color.to_html(), cursor_character]
	line_buffer.append(placeholder_line)
	current_lines += 1
	
	var current_line_index = line_buffer.size() - 1
	var revealed_text = ""
	var cursor_visible = true
	
	# Start cursor blinking
	var cursor_timer = create_cursor_blink_timer(current_line_index, anim_data.color)
	
	# Animate character by character
	for i in range(message.length()):
		var target_char = message[i]
		
		# Skip spaces instantly
		if target_char == " ":
			revealed_text += target_char
			update_line_with_cursor(current_line_index, revealed_text, anim_data.color, cursor_visible)
			continue
		
		# Random glitch effect
		if randf() < glitch_chance:
			var glitch_iterations = randi_range(1, max_glitch_iterations)
			for glitch_step in range(glitch_iterations):
				var glitch_char = glitch_chars[randi() % glitch_chars.length()]
				var temp_text = revealed_text + glitch_char
				update_line_with_cursor(current_line_index, temp_text, anim_data.color, cursor_visible)
				
				# Slower glitch speed
				await get_tree().create_timer(char_delay / glitch_speed_multiplier).timeout
		
		# Show correct character
		revealed_text += target_char
		update_line_with_cursor(current_line_index, revealed_text, anim_data.color, cursor_visible)
		
		# Normal speed for correct characters
		var actual_delay = char_delay * randf_range(0.8, 1.2)
		await get_tree().create_timer(actual_delay).timeout
	
	# Stop cursor blinking and remove cursor
	cursor_timer.queue_free()
	line_buffer[current_line_index] = "[color=%s]%s[/color]" % [anim_data.color.to_html(), revealed_text]
	update_display()
	
	# Auto-scroll and trim if needed
	await get_tree().process_frame
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value
	
	if current_lines > max_lines:
		trim_old_lines()

func create_cursor_blink_timer(line_index: int, text_color: Color) -> Timer:
	var timer = Timer.new()
	timer.wait_time = cursor_blink_speed
	timer.autostart = true
	timer.timeout.connect(_on_cursor_blink.bind(line_index, text_color))
	add_child(timer)
	return timer

func _on_cursor_blink(line_index: int, text_color: Color):
	if line_index >= line_buffer.size():
		return
	
	# Toggle cursor visibility
	var current_text = line_buffer[line_index]
	var has_cursor = current_text.contains(cursor_character)
	
	# Extract the text without cursor
	var clean_text = current_text.replace("[color=%s]" % text_color.to_html(), "").replace("[/color]", "").replace(cursor_character, "")
	
	# Update with or without cursor
	if has_cursor:
		line_buffer[line_index] = "[color=%s]%s[/color]" % [text_color.to_html(), clean_text]
	else:
		line_buffer[line_index] = "[color=%s]%s%s[/color]" % [text_color.to_html(), clean_text, cursor_character]
	
	update_display()

func update_line_with_cursor(line_index: int, text: String, color: Color, cursor_visible: bool):
	var cursor = cursor_character if cursor_visible else ""
	line_buffer[line_index] = "[color=%s]%s%s[/color]" % [color.to_html(), text, cursor]
	update_display()

func update_display():
	text_display.text = "\n".join(line_buffer)

func trim_old_lines():
	var lines_to_remove = current_lines - max_lines
	for i in range(lines_to_remove):
		line_buffer.pop_front()
	current_lines = line_buffer.size()
	
	# Rebuild display
	text_display.text = "\n".join(line_buffer)

# Event handlers
func _on_damage_dealt(attacker: String, target: String, damage: int):
	add_log_entry("%s >> %s [%d DMG]" % [attacker, target, damage], damage_color, 2.0)

func _on_agent_action(agent_name: String, action: String, target: String):
	var msg = "%s: %s" % [agent_name, action]
	if target != "":
		msg += " -> %s" % target
	add_log_entry(msg, agent_action_color, 1.5)

func _on_server_response(server_name: String, action: String):
	add_log_entry("%s: %s" % [server_name, action], server_response_color, 1.0)

func _on_combat_started(agents: Array, server: Node):
	add_log_entry("=== ENGAGING TARGET SERVER ===", combat_event_color, 3.0)

func _on_combat_ended(result: String):
	var color = success_color if result == "SUCCESS" else error_color
	add_log_entry("=== %s ===" % result, color, 2.5)

func _on_agent_health_changed(agent_name: String, health: float, max_health: float):
	if health <= max_health * 0.2:  # Low health warning
		add_log_entry("WARNING: %s health critical! [%.0f/%.0f]" % [agent_name, health, max_health], warning_color, 4.0)

func _on_command_entered(command: String, success: bool):
	var result_color = success_color if success else error_color
	var result_text = "SUCCESS" if success else "FAILED"
	add_log_entry("CMD: %s [%s]" % [command, result_text], result_color, 3.0)

func _on_command_input(command: String):
	# Echo the command like a real terminal - fast typing
	add_log_entry(">> %s" % command, command_color, 5.0)
	
	# Process the command (you can expand this)
	process_command(command)

func _on_ascii_art_display(art: String, color: Color, speed: float):
	add_ascii_art(art, color, speed)

func process_command(command: String):
	var cmd = command.to_lower().strip_edges()
	
	match cmd:
		"help":
			add_log_entry("Available commands: help, status, boost, heal, logo, banner", help_color, 2.0)
		"status":
			var status_lines = [
				"=== SYSTEM STATUS ===",
				"CPU: 98.7% efficient",
				"Memory: 2.1GB / 8GB",
				"Network: SECURED",
				"Agents: 3 ACTIVE",
				"Status: OPERATIONAL"
			]
			add_multiline_log(status_lines, system_color, 1.5)
		"boost":
			add_log_entry("Boosting agent performance...", agent_action_color, 1.0)
			EventBus.command_entered.emit("boost", true)
		"heal":
			add_log_entry("Initiating emergency protocols...", warning_color, 1.0)
			EventBus.command_entered.emit("heal", true)
		"logo":
			var logo_art = """
██╗  ██╗ █████╗  ██████╗██╗  ██╗
██║  ██║██╔══██╗██╔════╝██║ ██╔╝
███████║███████║██║     █████╔╝ 
██╔══██║██╔══██║██║     ██╔═██╗ 
██║  ██║██║  ██║╚██████╗██║  ██╗
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
	  NETWORK INFILTRATION SYSTEM
	
	"""
			add_ascii_art(logo_art, agent_action_color, 0.3, true)  # Line-by-line
		"banner":
			var banner_art = """
╔══════════════════════════════════╗
║    UNAUTHORIZED ACCESS DETECTED  ║
║      DEPLOYING COUNTERMEASURES   ║
║         [ ! WARNING ! ]          ║
╚══════════════════════════════════╝

"""
			add_ascii_art(banner_art, warning_color, 0.8, true)  # Line-by-line
		_:
			add_log_entry("Unknown command: %s" % command, error_color, 2.0)
			EventBus.command_entered.emit(command, false)

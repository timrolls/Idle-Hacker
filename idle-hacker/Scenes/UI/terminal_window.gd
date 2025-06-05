extends Control

@onready var text_display = $ScrollContainer/RichTextLabel
@onready var scroll_container = $ScrollContainer

var max_lines: int = 20
var current_lines: int = 0
var line_buffer: Array[String] = []

# Animation variables
var is_animating: bool = false
var animation_queue: Array[Dictionary] = []
var current_tween: Tween

# Exported animation settings
@export_group("Animation Settings")
@export var default_animation_duration: float = 2.0  # Total time for a message
@export var cursor_character: String = "▮"
@export var cursor_blink_speed: float = 0.5  # Seconds between blink states
@export var line_by_line_delay: float = 0.1  # Delay between lines in line-by-line mode
@export var enable_glitch_effect: bool = true
@export var glitch_intensity: float = 0.3  # 0.0 to 1.0



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
	EventBus.multiline_log_display.connect(_on_multiline_log_display)
	EventBus.log_entry_display.connect(_on_log_entry_display)
	EventBus.clear_log_requested.connect(_on_clear_log_requested)
	
	# Add initial startup message
	TerminalCommands.execute_command("logo")
	add_log_entry(">> NETWORK INFILTRATION SYSTEM ONLINE <<", Globals.system_color)
	add_log_entry("Initializing agent protocols...", Globals.system_color)

func add_log_entry(message: String, color: Color = Color.WHITE, duration_override: float = -1.0, use_glitch: bool = false):
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
			
			var animation_data = create_animation_data(line_text, color, duration_override, use_glitch, false)
			animation_queue.append(animation_data)
	else:
		# Single line message
		var full_message = timestamp + message
		var animation_data = create_animation_data(full_message, color, duration_override, use_glitch, false)
		animation_queue.append(animation_data)
	
	# Start animation if not already running
	if not is_animating:
		process_animation_queue()

func add_multiline_log(lines: Array, color: Color = Color.WHITE, duration_override: float = -1.0, use_glitch: bool = false):
	var message = "\n".join(lines)
	add_log_entry(message, color, duration_override, use_glitch)

func add_ascii_art(art: String, color: Color = Color.WHITE, duration_override: float = -1.0, use_glitch: bool = false):
	var timestamp = "[%02d:%02d:%02d] " % [
		Time.get_time_dict_from_system().hour,
		Time.get_time_dict_from_system().minute, 
		Time.get_time_dict_from_system().second
	]
	
	# Treat the entire ASCII art as one message for timing
	var lines = art.split("\n")
	var full_message = ""
	
	for i in range(lines.size()):
		var line_text = lines[i]
		# Only add timestamp to first line
		if i == 0:
			line_text = timestamp + line_text
		else:
			# Indent continuation lines slightly
			line_text = "    " + line_text
		
		if i > 0:
			full_message += "\n"
		full_message += line_text
	
	# Create single animation for entire ASCII art
	var animation_data = create_animation_data(full_message, color, duration_override, use_glitch, false)
	animation_queue.append(animation_data)
	
	# Start animation if not already running
	if not is_animating:
		process_animation_queue()

func create_animation_data(full_message: String, color: Color, duration_override: float, use_glitch: bool, line_by_line: bool) -> Dictionary:
	var duration = duration_override if duration_override > 0 else default_animation_duration
	
	# Shorter messages should animate faster, longer messages slower
	var message_length = full_message.length()
	if duration_override < 0:  # Only auto-adjust if no override specified
		duration = max(0.5, min(4.0, message_length * 0.02))  # 20ms per character, clamped
	
	return {
		"message": full_message,
		"color": color,
		"duration": duration,
		"use_glitch": use_glitch and enable_glitch_effect
	}

func process_animation_queue():
	if animation_queue.is_empty():
		is_animating = false
		return
	
	is_animating = true
	var current_anim = animation_queue.pop_front()
	
	await animate_text_with_visible_characters(current_anim)
	
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

func animate_text_with_visible_characters(anim_data: Dictionary):
	var message = anim_data.message
	var duration = anim_data.duration
	var color = anim_data.color
	var use_glitch = anim_data.use_glitch
	
	# Add the formatted message to buffer
	var formatted_line = "[color=%s]%s[/color]" % [color.to_html(), message]
	line_buffer.append(formatted_line)
	current_lines += 1
	var current_line_index = line_buffer.size() - 1
	
	# Get starting character position for this line
	var chars_before_line = get_total_visible_chars_before_line(current_line_index)
	var total_chars_in_message = message.length()
	
	# Start with all characters hidden for this message
	text_display.visible_characters = chars_before_line
	update_display()
	
	# Animate visible characters using tween
	if current_tween:
		current_tween.kill()
	current_tween = create_tween()
	
	# Smoothly reveal characters over the duration
	current_tween.tween_method(
		_update_visible_chars.bind(chars_before_line, chars_before_line + total_chars_in_message),
		0.0,
		1.0,
		duration
	)
	
	await current_tween.finished
	
	# Ensure all characters are visible and start post-animation glitch if needed
	text_display.visible_characters = -1
	
	if use_glitch:
		start_post_animation_glitch(current_line_index, color, message)
	
	# Auto-scroll and trim if needed
	await get_tree().process_frame
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value
	
	if current_lines > max_lines:
		trim_old_lines()

func animate_with_cursor(line_index: int, total_chars: int, duration: float, color: Color):
	var start_chars = get_total_visible_chars_before_line(line_index)
	var cursor_blink_timer = 0.0
	var cursor_visible = true
	
	# Animation step size for smooth movement
	var steps = max(30, total_chars)  # At least 30 steps for smooth animation
	var step_duration = duration / steps
	
	for i in range(steps + 1):
		var progress = float(i) / float(steps)
		var chars_to_show = int(progress * total_chars)
		
		# Update visible characters
		text_display.visible_characters = start_chars + chars_to_show
		
		# Update cursor blinking
		cursor_blink_timer += step_duration
		if cursor_blink_timer >= cursor_blink_speed:
			cursor_visible = not cursor_visible
			cursor_blink_timer = 0.0
		
		# Add cursor at current position if we're not at the end
		if chars_to_show < total_chars:
			update_line_with_cursor_at_position(line_index, chars_to_show, color, cursor_visible)
		else:
			# Remove cursor when done
			remove_cursor_from_line(line_index, color)
		
		await get_tree().create_timer(step_duration).timeout
	
	# Ensure cursor is removed at the end
	remove_cursor_from_line(line_index, color)

func animate_with_glitch_effect(line_index: int, total_chars: int, duration: float, color: Color):
	var start_chars = get_total_visible_chars_before_line(line_index)
	var original_message = line_buffer[line_index]
	
	# Extract the actual message without color tags
	var clean_message = extract_clean_message(original_message)
	
	var steps = max(40, total_chars)  # More steps for glitch effect
	var step_duration = duration / steps
	
	for i in range(steps + 1):
		var progress = float(i) / float(steps)
		var chars_to_show = int(progress * total_chars)
		
		# Create glitched version of current text
		var current_text = clean_message.substr(0, chars_to_show)
		
		# Add random glitch characters at the end
		if chars_to_show < total_chars and randf() < glitch_intensity:
			var glitch_chars = "!@#$%^&*()_+-=[]{}|;':\",./<>?~`"
			var glitch_count = min(3, total_chars - chars_to_show)
			for j in range(glitch_count):
				current_text += glitch_chars[randi() % glitch_chars.length()]
		
		# Update the line with glitched text
		line_buffer[line_index] = "[color=%s]%s[/color]" % [color.to_html(), current_text]
		update_display()
		
		text_display.visible_characters = start_chars + current_text.length()
		
		await get_tree().create_timer(step_duration).timeout
	
	# Restore clean final text
	line_buffer[line_index] = "[color=%s]%s[/color]" % [color.to_html(), clean_message]
	update_display()

func get_total_visible_chars_before_line(line_index: int) -> int:
	var char_count = 0
	for i in range(line_index):
		if i < line_buffer.size():
			# Count actual characters, not including BBCode tags
			var clean_text = extract_clean_message(line_buffer[i])
			char_count += clean_text.length()
			if i > 0:  # Add newline character count except for first line
				char_count += 1
	return char_count

func extract_clean_message(formatted_line: String) -> String:
	# Remove BBCode color tags
	var regex = RegEx.new()
	regex.compile("\\[color=[^\\]]+\\]|\\[/color\\]")
	return regex.sub(formatted_line, "", true)

# Helper function to update visible characters during tween
func _update_visible_chars(start_chars: int, end_chars: int, progress: float):
	var current_chars = int(start_chars + (end_chars - start_chars) * progress)
	text_display.visible_characters = current_chars

# Post-animation glitch effect
func start_post_animation_glitch(line_index: int, color: Color, original_message: String):
	if not enable_glitch_effect:
		return
	
	var glitch_duration = randf_range(0.5, 2.0)  # Random glitch duration
	var glitch_interval = 0.1  # How often to change glitch
	var glitch_chars = "!@#$%^&*()_+-=[]{}|;':\",./<>?~`"
	
	var glitch_timer = 0.0
	var total_time = 0.0
	
	while total_time < glitch_duration:
		# Random chance to glitch this interval
		if randf() < glitch_intensity:
			# Create glitched version
			var glitched_message = ""
			for i in range(original_message.length()):
				if randf() < 0.1:  # 10% chance per character to glitch
					glitched_message += glitch_chars[randi() % glitch_chars.length()]
				else:
					glitched_message += original_message[i]
			
			# Update display with glitched text
			line_buffer[line_index] = "[color=%s]%s[/color]" % [color.to_html(), glitched_message]
			update_display()
			
			# Short glitch duration
			await get_tree().create_timer(randf_range(0.02, 0.08)).timeout
			
			# Restore original
			line_buffer[line_index] = "[color=%s]%s[/color]" % [color.to_html(), original_message]
			update_display()
		
		await get_tree().create_timer(glitch_interval).timeout
		total_time += glitch_interval

# These functions are kept for compatibility but not used in current cursor-less implementation
func update_line_with_cursor_at_position(line_index: int, char_position: int, color: Color, cursor_visible: bool):
	# Legacy function - not used in current implementation
	pass

func remove_cursor_from_line(line_index: int, color: Color):
	# Legacy function - not used in current implementation
	pass



func update_display():
	text_display.text = "\n".join(line_buffer)

func trim_old_lines():
	var lines_to_remove = current_lines - max_lines
	for i in range(lines_to_remove):
		line_buffer.pop_front()
	current_lines = line_buffer.size()
	
	# Rebuild display
	text_display.text = "\n".join(line_buffer)

# Event handlers (keeping all the existing ones)
func _on_damage_dealt(attacker: String, target: String, damage: int):
	add_log_entry("%s >> %s [%d DMG]" % [attacker, target, damage], Globals.damage_color, 1.5)

func _on_agent_action(agent_name: String, action: String, target: String):
	var msg = "%s: %s" % [agent_name, action]
	if target != "":
		msg += " -> %s" % target
	add_log_entry(msg, Globals.agent_action_color, 1.2)

func _on_server_response(server_name: String, action: String):
	add_log_entry("%s: %s" % [server_name, action], Globals.server_response_color, 1.0, true)  # Servers get glitch effect

func _on_combat_started(agents: Array, server: Node):
	add_log_entry("=== ENGAGING TARGET SERVER ===", Globals.combat_event_color, 2.0)

func _on_combat_ended(result: String):
	var color = Globals.success_color if result == "SUCCESS" else Globals.error_color
	add_log_entry("=== %s ===" % result, color, 1.5)

func _on_agent_health_changed(agent_name: String, health: float, max_health: float):
	if health <= max_health * 0.2:  # Low health warning
		add_log_entry("WARNING: %s health critical! [%.0f/%.0f]" % [agent_name, health, max_health], Globals.warning_color, 2.0)

func _on_command_entered(command: String, success: bool):
	var result_color = Globals.success_color if success else Globals.error_color
	var result_text = "SUCCESS" if success else "FAILED"
	add_log_entry("CMD: %s [%s]" % [command, result_text], result_color, 1.0)

func _on_command_input(command: String):
	# Echo the command like a real terminal - fast typing
	add_log_entry(">> %s" % command, Globals.command_color, 0.8)
	
	# Send to command processor
	TerminalCommands.execute_command(command)

func _on_ascii_art_display(art: String, color: Color, speed: float):
	# Convert speed to duration (inverted relationship)
	var duration = 2.0 / max(0.1, speed)
	add_ascii_art(art, color, duration)

func _on_multiline_log_display(lines: Array, color: Color, speed: float):
	var duration = 1.5 / max(0.1, speed)
	var message = "\n".join(lines)
	add_log_entry(message, color, duration)

func _on_log_entry_display(message: String, color: Color, speed: float):
	var duration = 1.0 / max(0.1, speed)
	add_log_entry(message, color, duration)

func _on_clear_log_requested():
	# Stop current animation
	if current_tween:
		current_tween.kill()
	is_animating = false
	animation_queue.clear()
	
	line_buffer.clear()
	current_lines = 0
	update_display()

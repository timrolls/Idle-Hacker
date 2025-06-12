# FunctionCombatPrototype.gd
extends Control

# Energy types
enum EnergyType {
	EMPTY,
	RED,
	BLUE,
	CYAN
}

# Function data structure
class CombatFunction:
	var name: String
	var description: String
	var energy_cost: Array = []  # Required energy to execute
	var energy_generated: Array = []  # Energy produced on execution
	var base_damage: int = 0
	var special_effects: Array = []
	var icon: String = "⚡"
	var color: Color = Color.WHITE
	
	func _init(n: String, desc: String = ""):
		name = n
		description = desc

# Agent class
class FunctionAgent:
	var agent_name: String = "Agent"
	var max_health: int = 100
	var current_health: int = 100
	var energy_queue: Array = []  # Max 5 slots
	var function_script: Array = []  # Array of CombatFunction - Max 3 slots
	var execution_speed: float = 2.0  # Seconds between attacks
	var attack_timer: float = 0.0
	var integrity: float = 1.0  # 0.0 to 1.0
	var xp: int = 1757
	var current_function_index: int = 0
	var max_function_slots: int = 3
	
	func _init():
		# Initialize with 5 empty energy slots
		for i in range(5):
			energy_queue.append(EnergyType.EMPTY)
	
	func add_energy(type: EnergyType):
		# Shift all energies left and add new one at the end
		for i in range(4):
			energy_queue[i] = energy_queue[i + 1]
		energy_queue[4] = type
	
	func consume_energy(required: Array) -> bool:
		# Check if we have the required energy
		var available = energy_queue.duplicate()
		var needed = required.duplicate()
		
		for req_energy in needed:
			var found = false
			for i in range(available.size()):
				if available[i] == req_energy:
					available[i] = EnergyType.EMPTY
					found = true
					break
			if not found:
				return false
		
		# If we get here, we can afford it - actually consume the energy
		for req_energy in required:
			for i in range(energy_queue.size()):
				if energy_queue[i] == req_energy:
					energy_queue[i] = EnergyType.EMPTY
					break
		
		return true
	
	func get_energy_count(type: EnergyType) -> int:
		var count = 0
		for energy in energy_queue:
			if energy == type:
				count += 1
		return count

# UI Nodes
@onready var agent_face = $VBox/TopPanel/AgentFace
@onready var stats_panel = $VBox/TopPanel/StatsPanel
@onready var energy_display = $VBox/TopPanel/EnergyDisplay
@onready var function_list = $VBox/BottomPanel/LeftPanel/LeftVBox/FunctionListContainer/FunctionList
@onready var available_functions = $VBox/BottomPanel/RightPanel/RightVBox/AvailableScroll/AvailableGrid
@onready var integrity_bar = $VBox/TopPanel/StatsPanel/StatsVBox/BarsGrid/IntegrityBar
@onready var xp_bar = $VBox/TopPanel/StatsPanel/StatsVBox/BarsGrid/XPBar
@onready var execution_bar = $VBox/TopPanel/StatsPanel/StatsVBox/BarsGrid/ExecutionBar
@onready var run_button = $VBox/BottomPanel/LeftPanel/LeftVBox/HeaderContainer/RunButton

# Test agent
var test_agent: FunctionAgent

# Drag and drop variables
var drag_preview: Control = null
var dragging_function: CombatFunction = null
var dragging_from_slot: int = -1  # Track which slot we're dragging from

# Execution control
var is_running: bool = false
var last_function_script_size: int = 0
var last_current_function_index: int = 0

func _ready():
	# Connect the run button
	run_button.pressed.connect(_on_run_button_pressed)
	
	create_test_agent()
	setup_available_functions()
	
	# Initial display - show everything including empty function slots
	update_energy_display()
	update_function_display()  # Force initial display of empty slots
	update_stats_display()
	
	# Set up tracking variables after initial display
	last_function_script_size = test_agent.function_script.size()
	last_current_function_index = test_agent.current_function_index
	
	# Start combat simulation
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.timeout.connect(_on_combat_timer_timeout)
	timer.autostart = true
	add_child(timer)

func _on_run_button_pressed():
	is_running = !is_running
	
	if is_running:
		# Start running
		run_button.text = "⏸ PAUSE"
		run_button.add_theme_color_override("font_color", Color.ORANGE)
		print("Script execution started")
	else:
		# Stop running
		run_button.text = "▶ RUN"
		run_button.add_theme_color_override("font_color", Color.GREEN)
		
		# Reset execution state
		test_agent.attack_timer = 0.0
		test_agent.current_function_index = 0
		
		print("Script execution paused - timer reset")
	
	# Force function display update since running state affects highlighting
	update_function_display()
	last_function_script_size = test_agent.function_script.size()
	last_current_function_index = test_agent.current_function_index

func create_test_agent():
	test_agent = FunctionAgent.new()
	test_agent.agent_name = "Test Agent"
	
	# Give some starting energy
	test_agent.add_energy(EnergyType.RED)
	test_agent.add_energy(EnergyType.BLUE)
	test_agent.add_energy(EnergyType.CYAN)

func setup_available_functions():
	var functions = create_function_library()
	
	for combat_function in functions:
		var button = create_function_button(combat_function)
		available_functions.add_child(button)

func create_function_library() -> Array:
	var functions = []
	
	# Basic attack (no requirements)
	var basic = CombatFunction.new("Basic Strike", "Simple attack with no energy cost")
	basic.base_damage = 10
	basic.energy_generated = [EnergyType.RED]
	basic.icon = "⚔"
	basic.color = Color.WHITE
	functions.append(basic)
	
	# Energy generators
	var red_gen = CombatFunction.new("Power Core", "Generate Red energy")
	red_gen.energy_generated = [EnergyType.RED, EnergyType.RED]
	red_gen.base_damage = 5
	red_gen.icon = "🔴"
	red_gen.color = Color.RED
	functions.append(red_gen)
	
	var blue_gen = CombatFunction.new("Data Mine", "Generate Blue energy")
	blue_gen.energy_generated = [EnergyType.BLUE, EnergyType.BLUE]
	blue_gen.base_damage = 5
	blue_gen.icon = "🔵"
	blue_gen.color = Color.BLUE
	functions.append(blue_gen)
	
	var cyan_gen = CombatFunction.new("Network Tap", "Generate Cyan energy")
	cyan_gen.energy_generated = [EnergyType.CYAN, EnergyType.CYAN]
	cyan_gen.base_damage = 5
	cyan_gen.icon = "🟢"
	cyan_gen.color = Color.CYAN
	functions.append(cyan_gen)
	
	# Energy spenders
	var red_spender = CombatFunction.new("Overload", "Powerful attack using Red energy")
	red_spender.energy_cost = [EnergyType.RED, EnergyType.RED]
	red_spender.base_damage = 35
	red_spender.icon = "💥"
	red_spender.color = Color.RED
	functions.append(red_spender)
	
	var blue_spender = CombatFunction.new("Data Spike", "High damage using Blue energy")
	blue_spender.energy_cost = [EnergyType.BLUE, EnergyType.BLUE]
	blue_spender.base_damage = 30
	blue_spender.special_effects = ["Ignore Defense"]
	blue_spender.icon = "📊"
	blue_spender.color = Color.BLUE
	functions.append(blue_spender)
	
	var cyan_spender = CombatFunction.new("Packet Storm", "Multi-hit using Cyan energy")
	cyan_spender.energy_cost = [EnergyType.CYAN, EnergyType.CYAN]
	cyan_spender.base_damage = 20
	cyan_spender.special_effects = ["Hits 3 times"]
	cyan_spender.icon = "🌊"
	cyan_spender.color = Color.CYAN
	functions.append(cyan_spender)
	
	# Converters
	var converter = CombatFunction.new("Energy Matrix", "Convert Red to Blue")
	converter.energy_cost = [EnergyType.RED]
	converter.energy_generated = [EnergyType.BLUE, EnergyType.BLUE]
	converter.base_damage = 8
	converter.icon = "🔄"
	converter.color = Color.PURPLE
	functions.append(converter)
	
	return functions

func create_function_button(combat_function: CombatFunction) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(120, 80)
	button.text = "%s\n%s\nDMG: %d" % [combat_function.icon, combat_function.name, combat_function.base_damage]
	button.add_theme_color_override("font_color", combat_function.color)
	
	# Store the function data on the button
	button.set_meta("combat_function", combat_function)
	
	# Connect signals
	button.mouse_entered.connect(_on_function_button_hover.bind(button))
	button.mouse_exited.connect(_on_function_button_unhover.bind(button))
	button.pressed.connect(_on_function_button_pressed.bind(button))
	
	# Add drag detection using button_down/button_up
	button.button_down.connect(_on_function_button_down.bind(button))
	button.button_up.connect(_on_function_button_up.bind(button))
	
	return button

func _on_function_button_hover(button: Button):
	button.modulate = Color(1.2, 1.2, 1.2)

func _on_function_button_unhover(button: Button):
	button.modulate = Color.WHITE

func _on_function_button_pressed(button: Button):
	# This handles single clicks - only add if not dragging
	if not dragging_function:
		var combat_function = button.get_meta("combat_function") as CombatFunction
		add_function_to_script(combat_function)

func _on_function_button_down(button: Button):
	print("Button down detected!")
	var combat_function = button.get_meta("combat_function") as CombatFunction
	
	# Start a timer to detect if this becomes a drag
	await get_tree().create_timer(0.1).timeout
	
	# If button is still pressed after 0.1 seconds, start drag
	if button.button_pressed:
		print("Starting drag for: ", combat_function.name)
		start_drag(combat_function, button)

func _on_function_button_up(button: Button):
	print("Button up detected!")
	# If we were dragging, this will be handled by _input
	pass

func _on_slot_button_down(button: Button):
	print("Slot button down detected!")
	var combat_function = button.get_meta("combat_function") as CombatFunction
	var slot_index = button.get_meta("slot_index") as int
	
	# Start a timer to detect if this becomes a drag
	await get_tree().create_timer(0.1).timeout
	
	# If button is still pressed after 0.1 seconds, start drag
	if button.button_pressed:
		print("Starting slot drag for: ", combat_function.name)
		start_slot_drag(combat_function, slot_index)

func start_slot_drag(combat_function: CombatFunction, from_index: int):
	# Clean up any existing drag state first
	cleanup_drag_state()
	
	dragging_function = combat_function
	dragging_from_slot = from_index
	
	# Create drag preview
	drag_preview = Control.new()
	drag_preview.custom_minimum_size = Vector2(200, 80)
	drag_preview.position = Vector2(0, 0)  # Start at origin to avoid sticking
	
	var preview_panel = Panel.new()
	preview_panel.custom_minimum_size = Vector2(200, 80)
	preview_panel.modulate = Color(1, 1, 1, 0.8)
	
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color.BLUE * 0.3
	preview_style.border_color = Color.BLUE
	preview_style.set_border_width_all(2)
	preview_style.set_corner_radius_all(5)
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	
	var preview_label = RichTextLabel.new()
	preview_label.anchors_preset = Control.PRESET_FULL_RECT
	preview_label.bbcode_enabled = true
	preview_label.fit_content = true
	preview_label.text = "[center][color=%s]%s[/color]\n[b]%s[/b][/center]" % [combat_function.color.to_html(), combat_function.icon, combat_function.name]
	preview_panel.add_child(preview_label)
	
	drag_preview.add_child(preview_panel)
	
	# Add to scene
	get_viewport().add_child(drag_preview)
	drag_preview.z_index = 100
	
	# Start following mouse
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	print("Started dragging function: ", combat_function.name, " from slot: ", from_index)

func start_drag(combat_function: CombatFunction, button: Button):
	if test_agent.function_script.size() >= test_agent.max_function_slots:
		# Flash the script area to show it's full
		var script_panel = $VBox/BottomPanel/LeftPanel
		var original_modulate = script_panel.modulate
		script_panel.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(script_panel, "modulate", original_modulate, 0.3)
		return
	
	dragging_function = combat_function
	dragging_from_slot = -1  # -1 indicates dragging from available functions
	
	# Create drag preview for available function
	drag_preview = Control.new()
	drag_preview.custom_minimum_size = Vector2(120, 80)
	var available_preview_button = Button.new()
	available_preview_button.custom_minimum_size = Vector2(120, 80)
	available_preview_button.text = button.text
	available_preview_button.add_theme_color_override("font_color", combat_function.color)
	available_preview_button.modulate = Color(1, 1, 1, 0.7)
	drag_preview.add_child(available_preview_button)
	
	# Add to scene
	get_viewport().add_child(drag_preview)
	drag_preview.z_index = 100
	
	# Start following mouse
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	dragging_function = combat_function
	#dragging_from_slot = from_index
	
	## Create drag preview
	#drag_preview = Control.new()
	#drag_preview.custom_minimum_size = Vector2(200, 80)
	
	var preview_panel = Panel.new()
	preview_panel.custom_minimum_size = Vector2(200, 80)
	preview_panel.modulate = Color(1, 1, 1, 0.8)
	
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color.BLUE * 0.3
	preview_style.border_color = Color.BLUE
	preview_style.set_border_width_all(2)
	preview_style.set_corner_radius_all(5)
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	
	var preview_label = RichTextLabel.new()
	preview_label.anchors_preset = Control.PRESET_FULL_RECT
	preview_label.bbcode_enabled = true
	preview_label.fit_content = true
	preview_label.text = "[center][color=%s]%s[/color]\n[b]%s[/b][/center]" % [combat_function.color.to_html(), combat_function.icon, combat_function.name]
	preview_panel.add_child(preview_label)
	
	drag_preview.add_child(preview_panel)
	
	# Add to scene
	get_viewport().add_child(drag_preview)
	drag_preview.z_index = 100
	
	# Start following mouse
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	#print("Started dragging function: ", combat_function.name, " from slot: ", from_index)
	if test_agent.function_script.size() >= test_agent.max_function_slots:
		# Flash the script area to show it's full
		var script_panel = $VBox/BottomPanel/LeftPanel
		var original_modulate = script_panel.modulate
		script_panel.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(script_panel, "modulate", original_modulate, 0.3)
		return
	
	dragging_function = combat_function
	
	# Create drag preview
	drag_preview = Control.new()
	drag_preview.custom_minimum_size = Vector2(120, 80)
	var preview_button = Button.new()
	preview_button.custom_minimum_size = Vector2(120, 80)
	preview_button.text = button.text
	preview_button.add_theme_color_override("font_color", combat_function.color)
	preview_button.modulate = Color(1, 1, 1, 0.7)
	drag_preview.add_child(preview_button)
	
	# Add to scene
	get_viewport().add_child(drag_preview)
	drag_preview.z_index = 100
	
	# Start following mouse
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)

func _input(event):
	if dragging_function and drag_preview:
		if event is InputEventMouseMotion:
			print("Dragging to: ", event.global_position)
			drag_preview.global_position = event.global_position - Vector2(60, 40)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			print("Mouse released during drag!")
			end_drag(event.global_position)
			# Force cleanup of drag state
			cleanup_drag_state()

func cleanup_drag_state():
	print("Cleaning up drag state")
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	
	if drag_preview and is_instance_valid(drag_preview):
		print("Removing drag preview")
		drag_preview.queue_free()
		
		# Force immediate removal by also removing from parent
		if drag_preview.get_parent():
			drag_preview.get_parent().remove_child(drag_preview)
	
	drag_preview = null
	dragging_function = null
	dragging_from_slot = -1

func end_drag(drop_position: Vector2):
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	
	# Check if dropped over script area
	var script_area = $VBox/BottomPanel/LeftPanel
	var script_rect = Rect2(script_area.global_position, script_area.size)
	
	print("Drop position: ", drop_position)
	print("Script area rect: ", script_rect)
	print("Has dragging function: ", dragging_function != null)
	print("Dragging from slot: ", dragging_from_slot)
	
	if script_rect.has_point(drop_position) and dragging_function:
		if dragging_from_slot >= 0:
			# Dragging from an existing slot - determine target slot
			var target_slot = get_target_slot_index(drop_position)
			print("Target slot: ", target_slot)
			if target_slot >= 0 and target_slot != dragging_from_slot:
				reorder_function(dragging_from_slot, target_slot)
			elif target_slot < 0:
				# Dropped in script area but not on a specific slot - keep in same position
				print("Dropped in script area but not on specific slot")
		else:
			# Dragging from available functions - add to script
			print("Adding function to script via drag!")
			add_function_to_script(dragging_function)
	elif dragging_function:
		print("Dropped outside script area")
	
	# Don't clean up here - let cleanup_drag_state handle it

func get_target_slot_index(drop_position: Vector2) -> int:
	# Calculate which slot the drop position corresponds to
	var function_list_global_pos = function_list.global_position
	var slot_height = 90  # Approximate height including spacing
	
	var relative_y = drop_position.y - function_list_global_pos.y
	var slot_index = int(relative_y / slot_height)
	
	# Clamp to valid range
	if slot_index >= 0 and slot_index < test_agent.max_function_slots:
		return slot_index
	return -1

func reorder_function(from_index: int, to_index: int):
	print("Reordering function from ", from_index, " to ", to_index)
	
	if from_index < 0 or from_index >= test_agent.function_script.size():
		print("Invalid from_index: ", from_index)
		return
	if to_index < 0 or to_index >= test_agent.max_function_slots:
		print("Invalid to_index: ", to_index)
		return
		
	var moving_function = test_agent.function_script[from_index]
	print("Moving function: ", moving_function.name)
	
	# Remove from old position
	test_agent.function_script.remove_at(from_index)
	print("Removed from position: ", from_index, " new size: ", test_agent.function_script.size())
	
	# Calculate insert position
	var insert_index = to_index
	
	# If dropping into an empty slot beyond current script size, append to end
	if to_index >= test_agent.function_script.size():
		insert_index = test_agent.function_script.size()
		print("Dropping to empty slot at end, insert_index: ", insert_index)
	else:
		# If moving to earlier position, adjust for removal
		if to_index > from_index:
			insert_index = to_index - 1
		print("Dropping to existing slot, insert_index: ", insert_index)
	
	# Clamp to valid range
	insert_index = max(0, min(insert_index, test_agent.function_script.size()))
	print("Final insert_index: ", insert_index)
	
	test_agent.function_script.insert(insert_index, moving_function)
	print("Inserted at position: ", insert_index, " new size: ", test_agent.function_script.size())
	
	# Update display
	update_function_display()
	last_function_script_size = test_agent.function_script.size()
	last_current_function_index = test_agent.current_function_index
	
	print("Function reordered successfully")

func add_function_to_script(combat_function: CombatFunction):
	print("Attempting to add function: ", combat_function.name)
	print("Current script size: ", test_agent.function_script.size())
	print("Max slots: ", test_agent.max_function_slots)
	
	if test_agent.function_script.size() < test_agent.max_function_slots:
		test_agent.function_script.append(combat_function)
		# Force function display update since we changed the script
		update_function_display()
		last_function_script_size = test_agent.function_script.size()
		last_current_function_index = test_agent.current_function_index
		print("Function added successfully!")
	else:
		print("Script is full!")

func update_display():
	update_energy_display()
	update_stats_display()
	
	# Only update function display if something actually changed
	if (test_agent.function_script.size() != last_function_script_size or 
		test_agent.current_function_index != last_current_function_index):
		update_function_display()
		last_function_script_size = test_agent.function_script.size()
		last_current_function_index = test_agent.current_function_index

func update_energy_display():
	# Clear existing energy display
	for child in energy_display.get_children():
		child.queue_free()
	
	# Create energy circles
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.anchors_preset = Control.PRESET_CENTER
	energy_display.add_child(grid)
	
	for i in range(5):
		var circle = Panel.new()
		circle.custom_minimum_size = Vector2(30, 30)
		
		var energy_type = test_agent.energy_queue[i]
		var energy_color = get_energy_color(energy_type)
		
		var style = StyleBoxFlat.new()
		style.bg_color = energy_color
		style.border_color = Color.WHITE
		style.set_border_width_all(2)
		style.set_corner_radius_all(15)
		circle.add_theme_stylebox_override("panel", style)
		
		grid.add_child(circle)

func update_function_display():
	# Clear existing function display
	for child in function_list.get_children():
		child.queue_free()
	
	# Create slots (empty or filled)
	for i in range(test_agent.max_function_slots):
		var slot_panel = Panel.new()
		slot_panel.custom_minimum_size.y = 80
		slot_panel.custom_minimum_size.x = 400
		
		# Style the slot with basic colors
		var slot_style = StyleBoxFlat.new()
		if i < test_agent.function_script.size():
			# Filled slot
			var current_function = test_agent.function_script[i]
			# Only highlight current function if running
			if i == test_agent.current_function_index and is_running:
				slot_style.bg_color = Color.BLUE * 0.3
			else:
				slot_style.bg_color = Color.DARK_GRAY * 0.3
			var function_slot = create_function_slot(current_function, i)
			slot_panel.add_child(function_slot)
		else:
			# Empty slot
			slot_style.bg_color = Color.DIM_GRAY * 0.2
			var empty_label = Label.new()
			empty_label.text = "Drop Function Here [Slot %d]" % (i + 1)
			empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty_label.anchors_preset = Control.PRESET_FULL_RECT
			empty_label.add_theme_color_override("font_color", Color.GRAY)
			slot_panel.add_child(empty_label)
		
		slot_panel.add_theme_stylebox_override("panel", slot_style)
		function_list.add_child(slot_panel)

func create_function_slot(combat_function: CombatFunction, index: int) -> Control:
	var slot = Control.new()
	slot.anchors_preset = Control.PRESET_FULL_RECT
	
	var hbox = HBoxContainer.new()
	hbox.anchors_preset = Control.PRESET_FULL_RECT
	hbox.add_theme_constant_override("separation", 10)
	slot.add_child(hbox)
	
	# Function icon/name - make this draggable with a button instead of RichTextLabel
	var drag_button = Button.new()
	drag_button.custom_minimum_size.x = 200
	drag_button.text = "%s %s" % [combat_function.icon, combat_function.name]
	drag_button.add_theme_color_override("font_color", combat_function.color)
	drag_button.flat = true
	drag_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Make the button draggable
	drag_button.set_meta("combat_function", combat_function)
	drag_button.set_meta("slot_index", index)
	drag_button.button_down.connect(_on_slot_button_down.bind(drag_button))
	
	hbox.add_child(drag_button)
	
	# Requirements
	var req_container = HBoxContainer.new()
	for energy in combat_function.energy_cost:
		var req_circle = Panel.new()
		req_circle.custom_minimum_size = Vector2(20, 20)
		var req_style = StyleBoxFlat.new()
		req_style.bg_color = get_energy_color(energy)
		req_style.set_corner_radius_all(10)
		req_circle.add_theme_stylebox_override("panel", req_style)
		req_container.add_child(req_circle)
	hbox.add_child(req_container)
	
	# Generated energy
	var gen_container = HBoxContainer.new()
	for energy in combat_function.energy_generated:
		var gen_circle = Panel.new()
		gen_circle.custom_minimum_size = Vector2(20, 20)
		var gen_style = StyleBoxFlat.new()
		gen_style.bg_color = get_energy_color(energy)
		gen_style.border_color = Color.YELLOW
		gen_style.set_border_width_all(2)
		gen_style.set_corner_radius_all(10)
		gen_circle.add_theme_stylebox_override("panel", gen_style)
		gen_container.add_child(gen_circle)
	hbox.add_child(gen_container)
	
	# Spacer to push remove button to the right
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	# Remove button
	var remove_btn = Button.new()
	remove_btn.text = "✕"
	remove_btn.custom_minimum_size = Vector2(40, 40)
	remove_btn.add_theme_color_override("font_color", Color.RED)
	remove_btn.add_theme_font_size_override("font_size", 16)
	remove_btn.flat = true
	
	# Use a different approach - no custom hover handlers, just styling
	remove_btn.pressed.connect(_on_remove_function.bind(index))
	
	# Set up hover colors using theme overrides instead of modulation
	remove_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	
	hbox.add_child(remove_btn)
	
	return slot

func _on_remove_function(index: int):
	test_agent.function_script.remove_at(index)
	# Force function display update since we changed the script
	update_function_display()
	last_function_script_size = test_agent.function_script.size()
	last_current_function_index = test_agent.current_function_index

func update_stats_display():
	integrity_bar.value = test_agent.integrity * 100
	execution_bar.value = (test_agent.attack_timer / test_agent.execution_speed) * 100

func get_energy_color(type: EnergyType) -> Color:
	match type:
		EnergyType.RED:
			return Color.RED
		EnergyType.BLUE:
			return Color.BLUE
		EnergyType.CYAN:
			return Color.CYAN
		EnergyType.EMPTY:
			return Color.DARK_GRAY
		_:
			return Color.WHITE

func _on_combat_timer_timeout():
	# Only process if we're running and have functions to execute
	if is_running and not test_agent.function_script.is_empty():
		# Update attack timer (0.1 seconds per tick)
		test_agent.attack_timer += 0.1
		
		# Check if ready to execute next function
		if test_agent.attack_timer >= test_agent.execution_speed:
			execute_next_function()
			test_agent.attack_timer = 0.0
	elif not is_running:
		# Keep timer at 0 when not running
		test_agent.attack_timer = 0.0
	
	update_display()

func execute_next_function():
	if test_agent.function_script.is_empty():
		return
	
	# Try each function in order starting from current index
	var functions_tried = 0
	var original_index = test_agent.current_function_index
	
	while functions_tried < test_agent.function_script.size():
		var current_function = test_agent.function_script[test_agent.current_function_index]
		
		# Check if we can afford this function
		if test_agent.consume_energy(current_function.energy_cost):
			# Execute the function
			print("Executing: %s for %d damage" % [current_function.name, current_function.base_damage])
			
			# Add generated energy
			for energy in current_function.energy_generated:
				test_agent.add_energy(energy)
			
			# Move to next function for next time
			test_agent.current_function_index = (test_agent.current_function_index + 1) % test_agent.function_script.size()
			return
		
		# Try next function
		test_agent.current_function_index = (test_agent.current_function_index + 1) % test_agent.function_script.size()
		functions_tried += 1
	
	# If we get here, no function could execute
	print("No functions can execute - insufficient energy")
	test_agent.current_function_index = original_index

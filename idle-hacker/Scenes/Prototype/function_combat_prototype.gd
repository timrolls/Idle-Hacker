# FunctionCombatPrototype.gd
extends Control

# UI Nodes - now all references to existing scene nodes
@onready var agent_face = $VBox/TopPanel/AgentFace
@onready var stats_panel = $VBox/TopPanel/StatsPanel
@onready var energy_display = $VBox/TopPanel/EnergyDisplay
@onready var energy_grid = $VBox/TopPanel/EnergyDisplay/EnergyGrid
@onready var function_slots_container = $VBox/BottomPanel/LeftPanel/LeftVBox/FunctionListContainer/FunctionSlots
@onready var available_functions = $VBox/BottomPanel/RightPanel/RightVBox/AvailableScroll/AvailableGrid

# Stats UI
@onready var level_label = $VBox/TopPanel/StatsPanel/StatsVBox/LevelLabel
@onready var integrity_bar = $VBox/TopPanel/StatsPanel/StatsVBox/BarsGrid/IntegrityBar
@onready var xp_bar = $VBox/TopPanel/StatsPanel/StatsVBox/BarsGrid/XPBar
@onready var execution_bar = $VBox/TopPanel/StatsPanel/StatsVBox/BarsGrid/ExecutionBar
@onready var level_up_button = $VBox/TopPanel/StatsPanel/StatsVBox/BarsGrid/LevelUpButton

# Controls
@onready var run_button = $VBox/BottomPanel/LeftPanel/LeftVBox/HeaderContainer/RunButton

# Test agent
var test_agent: FunctionAgent

# Drag and drop variables
var drag_preview: Control = null
var dragging_function: CombatFunction = null
var dragging_from_slot: int = -1
var is_dragging: bool = false

# Execution control
var is_running: bool = false
var last_function_script_size: int = 0
var last_current_function_index: int = 0

# UI references to slots
var function_slot_panels: Array[Panel] = []
var energy_slot_panels: Array[Panel] = []

func _ready():
	# Get references to all the slot panels
	setup_slot_references()
	
	# Connect buttons
	run_button.pressed.connect(_on_run_button_pressed)
	level_up_button.pressed.connect(_on_level_up_pressed)
	
	create_test_agent()
	setup_available_functions()
	
	# Initial display - update existing UI nodes
	update_energy_display()
	update_function_display()
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

func setup_slot_references():
	# Get references to all function slot panels
	function_slot_panels.clear()
	for i in range(5):
		var slot_name = "FunctionSlot%d" % (i + 1)
		var slot_panel = function_slots_container.get_node(slot_name) as Panel
		function_slot_panels.append(slot_panel)
	
	# Get references to all energy slot panels
	energy_slot_panels.clear()
	for i in range(5):
		var slot_name = "EnergySlot%d" % (i + 1)
		var slot_panel = energy_grid.get_node(slot_name) as Panel
		energy_slot_panels.append(slot_panel)

func _on_run_button_pressed():
	is_running = !is_running
	
	if is_running:
		run_button.text = "⏸ PAUSE"
		run_button.add_theme_color_override("font_color", Color.ORANGE)
		print("Script execution started")
	else:
		run_button.text = "▶ RUN"
		run_button.add_theme_color_override("font_color", Color.GREEN)
		
		test_agent.attack_timer = 0.0
		test_agent.current_function_index = 0
		
		print("Script execution paused - timer reset")
	
	update_function_display()
	last_function_script_size = test_agent.function_script.size()
	last_current_function_index = test_agent.current_function_index

func create_test_agent():
	test_agent = FunctionAgent.new()
	test_agent.agent_name = "Test Agent"
	test_agent.level = 1
	
	update_available_slots()
	
	# Give some starting energy
	test_agent.add_energy(CombatFunction.EnergyType.RED)
	test_agent.add_energy(CombatFunction.EnergyType.BLUE)
	test_agent.add_energy(CombatFunction.EnergyType.CYAN)

func get_required_level_for_slot(slot_index: int) -> int:
	match slot_index:
		0: return 1
		1: return 3
		2: return 6
		3: return 10
		4: return 15
		_: return 999

func update_available_slots():
	var new_available_slots = 1
	
	for i in range(1, test_agent.max_function_slots):
		if test_agent.level >= get_required_level_for_slot(i):
			new_available_slots = i + 1
		else:
			break
	
	if new_available_slots != test_agent.available_function_slots:
		test_agent.available_function_slots = new_available_slots
		print("Unlocked slot! Now have ", test_agent.available_function_slots, " available slots")
		update_function_display()

func level_up():
	test_agent.level += 1
	test_agent.xp = 0
	print("Level up! Now level ", test_agent.level)
	update_available_slots()
	update_stats_display()

func _on_level_up_pressed():
	level_up()

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
	basic.energy_generated.append(CombatFunction.EnergyType.RED)
	basic.icon = "⚔"
	basic.color = Color.WHITE
	functions.append(basic)
	
	# Energy generators
	var red_gen = CombatFunction.new("Power Core", "Generate Red energy")
	red_gen.energy_generated.append(CombatFunction.EnergyType.RED)
	red_gen.energy_generated.append(CombatFunction.EnergyType.RED)
	red_gen.base_damage = 5
	red_gen.icon = "🔴"
	red_gen.color = Color.RED
	functions.append(red_gen)
	
	var blue_gen = CombatFunction.new("Data Mine", "Generate Blue energy")
	blue_gen.energy_generated.append(CombatFunction.EnergyType.BLUE)
	blue_gen.energy_generated.append(CombatFunction.EnergyType.BLUE)
	blue_gen.base_damage = 5
	blue_gen.icon = "🔵"
	blue_gen.color = Color.BLUE
	functions.append(blue_gen)
	
	var cyan_gen = CombatFunction.new("Network Tap", "Generate Cyan energy")
	cyan_gen.energy_generated.append(CombatFunction.EnergyType.CYAN)
	cyan_gen.energy_generated.append(CombatFunction.EnergyType.CYAN)
	cyan_gen.base_damage = 5
	cyan_gen.icon = "🟢"
	cyan_gen.color = Color.CYAN
	functions.append(cyan_gen)
	
	# Energy spenders
	var red_spender = CombatFunction.new("Overload", "Powerful attack using Red energy")
	red_spender.energy_cost.append(CombatFunction.EnergyType.RED)
	red_spender.energy_cost.append(CombatFunction.EnergyType.RED)
	red_spender.base_damage = 35
	red_spender.icon = "💥"
	red_spender.color = Color.RED
	functions.append(red_spender)
	
	var blue_spender = CombatFunction.new("Data Spike", "High damage using Blue energy")
	blue_spender.energy_cost.append(CombatFunction.EnergyType.BLUE)
	blue_spender.energy_cost.append(CombatFunction.EnergyType.BLUE)
	blue_spender.base_damage = 30
	blue_spender.special_effects.append("Ignore Defense")
	blue_spender.icon = "📊"
	blue_spender.color = Color.BLUE
	functions.append(blue_spender)
	
	var cyan_spender = CombatFunction.new("Packet Storm", "Multi-hit using Cyan energy")
	cyan_spender.energy_cost.append(CombatFunction.EnergyType.CYAN)
	cyan_spender.energy_cost.append(CombatFunction.EnergyType.CYAN)
	cyan_spender.base_damage = 20
	cyan_spender.special_effects.append("Hits 3 times")
	cyan_spender.icon = "🌊"
	cyan_spender.color = Color.CYAN
	functions.append(cyan_spender)
	
	# Converters
	var converter = CombatFunction.new("Energy Matrix", "Convert Red to Blue")
	converter.energy_cost.append(CombatFunction.EnergyType.RED)
	converter.energy_generated.append(CombatFunction.EnergyType.BLUE)
	converter.energy_generated.append(CombatFunction.EnergyType.BLUE)
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
	
	button.set_meta("combat_function", combat_function)
	
	button.mouse_entered.connect(_on_function_button_hover.bind(button))
	button.mouse_exited.connect(_on_function_button_unhover.bind(button))
	button.pressed.connect(_on_function_button_pressed.bind(button))
	button.button_down.connect(_on_function_button_down.bind(button))
	
	return button

func _on_function_button_hover(button: Button):
	button.modulate = Color(1.2, 1.2, 1.2)

func _on_function_button_unhover(button: Button):
	button.modulate = Color.WHITE

func _on_function_button_pressed(button: Button):
	if not dragging_function:
		var combat_function = button.get_meta("combat_function") as CombatFunction
		add_function_to_script(combat_function)

func _on_function_button_down(button: Button):
	print("Button down detected!")
	var combat_function = button.get_meta("combat_function") as CombatFunction
	
	await get_tree().create_timer(0.1).timeout
	
	if button.button_pressed and not is_dragging:
		print("Starting drag for: ", combat_function.name)
		start_drag(combat_function, button)

func add_function_to_script(combat_function: CombatFunction):
	print("Attempting to add function: ", combat_function.name)
	
	if test_agent.function_script.size() < test_agent.available_function_slots:
		test_agent.function_script.append(combat_function)
		update_function_display()
		last_function_script_size = test_agent.function_script.size()
		last_current_function_index = test_agent.current_function_index
		print("Function added successfully!")
	else:
		print("Available slots are full!")
		flash_script_area_full()

func flash_script_area_full():
	var script_panel = $VBox/BottomPanel/LeftPanel
	var original_modulate = script_panel.modulate
	script_panel.modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(script_panel, "modulate", original_modulate, 0.3)

func start_drag(combat_function: CombatFunction, button: Button):
	if test_agent.function_script.size() >= test_agent.available_function_slots:
		flash_script_area_full()
		return
	
	if is_dragging:
		return
	
	is_dragging = true
	dragging_function = combat_function
	dragging_from_slot = -1
	
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	print("Started dragging function: ", combat_function.name)

func _input(event):
	if not is_dragging:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		print("Mouse released during drag")
		add_function_to_script(dragging_function)
		cleanup_drag_state()

func cleanup_drag_state():
	print("Cleaning up drag state")
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	dragging_function = null
	dragging_from_slot = -1
	is_dragging = false

func _exit_tree():
	cleanup_drag_state()

func update_display():
	update_energy_display()
	update_stats_display()
	
	if (test_agent.function_script.size() != last_function_script_size or 
		test_agent.current_function_index != last_current_function_index):
		update_function_display()
		last_function_script_size = test_agent.function_script.size()
		last_current_function_index = test_agent.current_function_index

func update_energy_display():
	# Update existing energy slot panels instead of creating new ones
	for i in range(5):
		var energy_type = test_agent.energy_queue[i]
		var energy_color = get_energy_color(energy_type)
		
		var style = StyleBoxFlat.new()
		style.bg_color = energy_color
		style.border_color = Color.WHITE
		style.set_border_width_all(2)
		style.set_corner_radius_all(15)
		
		energy_slot_panels[i].add_theme_stylebox_override("panel", style)

func update_function_display():
	# Update existing function slot panels instead of creating new ones
	for i in range(test_agent.max_function_slots):
		var slot_panel = function_slot_panels[i]
		
		# Clear existing children
		for child in slot_panel.get_children():
			child.queue_free()
		
		# Style the slot based on state
		var slot_style = StyleBoxFlat.new()
		
		if i >= test_agent.available_function_slots:
			# Locked slot
			slot_style.bg_color = Color.DIM_GRAY * 0.1
			slot_style.border_color = Color.GRAY * 0.5
			slot_style.set_border_width_all(2)
			
			var locked_label = Label.new()
			var required_level = get_required_level_for_slot(i)
			locked_label.text = "🔒 Unlocks at Level %d" % required_level
			locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			locked_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			locked_label.anchors_preset = Control.PRESET_FULL_RECT
			locked_label.add_theme_color_override("font_color", Color.GRAY)
			slot_panel.add_child(locked_label)
			
		elif i < test_agent.function_script.size():
			# Filled slot
			var current_function = test_agent.function_script[i]
			# Only highlight current function if running
			if i == test_agent.current_function_index and is_running:
				slot_style.bg_color = Color.BLUE * 0.3
			else:
				slot_style.bg_color = Color.DARK_GRAY * 0.3
			
			var function_content = create_function_slot_content(current_function, i)
			slot_panel.add_child(function_content)
		else:
			# Empty available slot
			slot_style.bg_color = Color.DIM_GRAY * 0.2
			slot_style.border_color = Color.GREEN * 0.3
			slot_style.set_border_width_all(1)
			
			var empty_label = Label.new()
			empty_label.text = "Drop Function Here [Slot %d]" % (i + 1)
			empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty_label.anchors_preset = Control.PRESET_FULL_RECT
			empty_label.add_theme_color_override("font_color", Color.GRAY)
			slot_panel.add_child(empty_label)
		
		slot_panel.add_theme_stylebox_override("panel", slot_style)

func create_function_slot_content(combat_function: CombatFunction, index: int) -> Control:
	var content = Control.new()
	content.anchors_preset = Control.PRESET_FULL_RECT
	
	var hbox = HBoxContainer.new()
	hbox.anchors_preset = Control.PRESET_FULL_RECT
	hbox.add_theme_constant_override("separation", 10)
	content.add_child(hbox)
	
	# Function name/icon
	var name_label = Label.new()
	name_label.text = "%s %s" % [combat_function.icon, combat_function.name]
	name_label.add_theme_color_override("font_color", combat_function.color)
	name_label.custom_minimum_size.x = 200
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_label)
	
	# Energy requirements
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
	
	# Energy generated
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
	
	# Spacer
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
	remove_btn.pressed.connect(_on_remove_function.bind(index))
	remove_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	hbox.add_child(remove_btn)
	
	return content

func _on_remove_function(index: int):
	test_agent.function_script.remove_at(index)
	update_function_display()
	last_function_script_size = test_agent.function_script.size()
	last_current_function_index = test_agent.current_function_index

func update_stats_display():
	level_label.text = str(test_agent.level)
	integrity_bar.value = test_agent.integrity * 100
	execution_bar.value = (test_agent.attack_timer / test_agent.execution_speed) * 100

func get_energy_color(type: CombatFunction.EnergyType) -> Color:
	match type:
		CombatFunction.EnergyType.RED:
			return Color.RED
		CombatFunction.EnergyType.BLUE:
			return Color.BLUE
		CombatFunction.EnergyType.CYAN:
			return Color.CYAN
		CombatFunction.EnergyType.EMPTY:
			return Color.DARK_GRAY
		_:
			return Color.WHITE

func _on_combat_timer_timeout():
	if is_running and not test_agent.function_script.is_empty():
		test_agent.attack_timer += 0.1
		
		if test_agent.attack_timer >= test_agent.execution_speed:
			execute_next_function()
			test_agent.attack_timer = 0.0
	elif not is_running:
		test_agent.attack_timer = 0.0
	
	update_display()

func execute_next_function():
	if test_agent.function_script.is_empty():
		return
	
	var functions_tried = 0
	var original_index = test_agent.current_function_index
	
	while functions_tried < test_agent.function_script.size():
		var current_function = test_agent.function_script[test_agent.current_function_index]
		
		if test_agent.consume_energy(current_function.energy_cost):
			print("Executing: %s for %d damage" % [current_function.name, current_function.base_damage])
			
			for energy in current_function.energy_generated:
				test_agent.add_energy(energy)
			
			test_agent.current_function_index = (test_agent.current_function_index + 1) % test_agent.function_script.size()
			return
		
		test_agent.current_function_index = (test_agent.current_function_index + 1) % test_agent.function_script.size()
		functions_tried += 1
	
	print("No functions can execute - insufficient energy")
	test_agent.current_function_index = original_index

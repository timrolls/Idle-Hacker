# function_combat_prototype_refactored.gd
extends Control

# Preload the discrete scenes
const FunctionSlotScene = preload("res://Scenes/Prototype/function_slot.tscn")
const AvailableFunctionButtonScene = preload("res://Scenes/Prototype/available_function_button.tscn")
const EnergySlotScene = preload("res://Scenes/Prototype/energy_slot.tscn")

# UI Nodes - references to existing scene nodes
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
var is_dragging: bool = false

# Execution control
var is_running: bool = false
var is_editing: bool = false
var was_running_before_edit: bool = false
var last_function_script_size: int = 0
var last_current_function_index: int = 0

# UI references to discrete scene instances
var function_slot_instances: Array[FunctionSlot] = []
var energy_slot_instances: Array[EnergySlot] = []
var available_function_buttons: Array[AvailableFunctionButton] = []

func _ready():
	# Connect buttons
	run_button.pressed.connect(_on_run_button_pressed)
	level_up_button.pressed.connect(_on_level_up_pressed)
	
	# Connect edit button
	var edit_button = $VBox/BottomPanel/LeftPanel/LeftVBox/HeaderContainer/EditButton
	edit_button.pressed.connect(_on_edit_button_pressed)
	
	# IMPORTANT: Setup discrete scenes FIRST before creating agent
	setup_discrete_scenes()
	create_test_agent()
	setup_available_functions()
	
	# Initial display
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

func setup_discrete_scenes():
	"""Create and setup all discrete scene instances"""
	# Clear existing containers first
	for child in function_slots_container.get_children():
		child.queue_free()
	for child in energy_grid.get_children():
		child.queue_free()
	
	# Create function slot instances
	function_slot_instances.clear()
	for i in range(5):
		var slot_instance = FunctionSlotScene.instantiate() as FunctionSlot
		slot_instance.name = "FunctionSlot%d" % (i + 1)
		slot_instance.function_removed.connect(_on_function_removed)
		function_slots_container.add_child(slot_instance)
		function_slot_instances.append(slot_instance)
	
	# Create energy slot instances
	energy_slot_instances.clear()
	for i in range(5):
		var energy_instance = EnergySlotScene.instantiate() as EnergySlot
		energy_instance.name = "EnergySlot%d" % (i + 1)
		energy_grid.add_child(energy_instance)
		energy_slot_instances.append(energy_instance)

func setup_available_functions():
	"""Create available function buttons using discrete scenes"""
	# Clear existing
	for child in available_functions.get_children():
		child.queue_free()
	
	available_function_buttons.clear()
	var functions = create_function_library()
	
	for combat_function in functions:
		var button_instance = AvailableFunctionButtonScene.instantiate() as AvailableFunctionButton
		# Add to scene tree FIRST so @onready variables are initialized
		available_functions.add_child(button_instance)
		# THEN setup the function data
		button_instance.setup_function(combat_function)
		available_function_buttons.append(button_instance)

func update_function_display():
	"""Update all function slots based on current agent state"""
	# Safety check: make sure slot instances exist
	if function_slot_instances.size() == 0:
		print("Warning: Function slot instances not created yet, skipping update")
		return
	
	for i in range(test_agent.max_function_slots):
		var slot_instance = function_slot_instances[i]
		
		if i >= test_agent.available_function_slots:
			# Locked slot
			var required_level = get_required_level_for_slot(i)
			slot_instance.setup_slot(i, FunctionSlot.SlotState.LOCKED, null, required_level)
		elif i < test_agent.function_script.size():
			# Filled slot
			var current_function = test_agent.function_script[i]
			var is_executing = (i == test_agent.current_function_index and is_running)
			
			if is_executing:
				slot_instance.setup_slot(i, FunctionSlot.SlotState.EXECUTING, current_function)
			else:
				slot_instance.setup_slot(i, FunctionSlot.SlotState.FILLED, current_function)
		else:
			# Empty available slot
			slot_instance.setup_slot(i, FunctionSlot.SlotState.EMPTY)

func update_energy_display():
	"""Update all energy slots based on current agent state"""
	# Safety check: make sure energy slot instances exist
	if energy_slot_instances.size() == 0:
		print("Warning: Energy slot instances not created yet, skipping update")
		return
	
	for i in range(5):
		var energy_type = test_agent.energy_queue[i]
		energy_slot_instances[i].set_energy_type(energy_type)



#func handle_function_drop(function: CombatFunction, from_slot: int, to_slot: int):
	#"""Handle when a function is dropped onto a slot"""
	#print("Function dropped: %s from slot %d to slot %d" % [function.name, from_slot, to_slot])
	#
	#if from_slot == -1:
		## Dropped from available functions
		#if test_agent.function_script.size() < test_agent.available_function_slots:
			## Insert at specific position if not at the end
			#if to_slot < test_agent.function_script.size():
				#test_agent.function_script.insert(to_slot, function)
			#else:
				#test_agent.function_script.append(function)
			#
			#update_function_display()
			#last_function_script_size = test_agent.function_script.size()
			#print("Function added to slot %d successfully!" % to_slot)
		#else:
			#print("No available slots!")
			#flash_script_area_full()
	#else:
		## Moved from one slot to another
		#if from_slot < test_agent.function_script.size() and to_slot != from_slot:
			#var moved_function = test_agent.function_script[from_slot]
			#test_agent.function_script.remove_at(from_slot)
			#
			## Adjust target index if needed
			#var insert_index = to_slot
			#if from_slot < to_slot:
				#insert_index -= 1
			#
			#if insert_index < test_agent.function_script.size():
				#test_agent.function_script.insert(insert_index, moved_function)
			#else:
				#test_agent.function_script.append(moved_function)
			#
			#update_function_display()
			#print("Function moved from slot %d to slot %d" % [from_slot, to_slot])
	#
	#cleanup_drag_state()



func _on_function_removed(slot_index: int):
	"""Handle when a function is removed from a slot"""
	if slot_index < test_agent.function_script.size():
		test_agent.function_script.remove_at(slot_index)
		update_function_display()
		last_function_script_size = test_agent.function_script.size()
		print("Function removed from slot ", slot_index)



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

func _exit_tree():
	pass

# Rest of the original functions remain mostly the same
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

func _on_level_up_pressed():
	level_up()

func _on_edit_button_pressed():
	is_editing = !is_editing
	var right_panel = $VBox/BottomPanel/RightPanel
	var edit_button = $VBox/BottomPanel/LeftPanel/LeftVBox/HeaderContainer/EditButton
	
	if is_editing:
		# Store current running state and pause execution
		was_running_before_edit = is_running
		if is_running:
			is_running = false
			run_button.text = "▶ RUN"
		
		# Reset attack timer to 0 when entering edit mode
		test_agent.attack_timer = 0.0
		
		# Show right panel and update edit button
		right_panel.visible = true
		edit_button.text = "✓ DONE"
		
		print("Edit mode enabled - execution paused")
	else:
		# Hide right panel and update edit button
		right_panel.visible = false
		edit_button.text = "✏ EDIT"
		
		# Resume execution if it was running before edit
		if was_running_before_edit:
			is_running = true
			run_button.text = "⏸ PAUSE"
			print("Edit mode disabled - execution resumed")
		else:
			print("Edit mode disabled - execution remains paused")
	
	update_function_display()

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
		1: return 1
		2: return 5
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
		# Only update display if slots are initialized
		if function_slot_instances.size() > 0:
			update_function_display()

func level_up():
	test_agent.level += 1
	test_agent.xp = 0
	print("Level up! Now level ", test_agent.level)
	update_available_slots()
	update_stats_display()

func update_display():
	update_energy_display()
	update_stats_display()
	
	if (test_agent.function_script.size() != last_function_script_size or 
		test_agent.current_function_index != last_current_function_index):
		update_function_display()
		last_function_script_size = test_agent.function_script.size()
		last_current_function_index = test_agent.current_function_index

func update_stats_display():
	level_label.text = "Level %d" % test_agent.level
	integrity_bar.value = test_agent.integrity * 100
	xp_bar.value = test_agent.xp
	
	var progress = float(test_agent.attack_timer) / test_agent.execution_speed
	execution_bar.value = progress * 100

func _on_combat_timer_timeout():
	if test_agent and is_running:
		test_agent.attack_timer += 0.1
		
		if test_agent.attack_timer >= test_agent.execution_speed:
			execute_current_function()
			test_agent.attack_timer = 0.0
	
	update_display()

func execute_current_function():
	if test_agent.function_script.size() == 0:
		return
	
	var current_function = test_agent.function_script[test_agent.current_function_index]
	
	# Check if we can afford the energy cost
	if test_agent.consume_energy(current_function.energy_cost):
		print("Executing: ", current_function.name)
		
		# Generate energy
		for energy_type in current_function.energy_generated:
			test_agent.add_energy(energy_type)
		
		# Add XP
		test_agent.xp += current_function.xp_reward
		if test_agent.xp >= 100:
			level_up()
	else:
		print("Not enough energy for: ", current_function.name)
	
	# Move to next function
	test_agent.current_function_index = (test_agent.current_function_index + 1) % test_agent.function_script.size()

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
	cyan_gen.icon = "🔷"
	cyan_gen.color = Color.CYAN
	functions.append(cyan_gen)
	
	# Powerful attacks requiring energy
	var fire_blast = CombatFunction.new("Fire Blast", "Powerful fire attack")
	fire_blast.energy_cost.append(CombatFunction.EnergyType.RED)
	fire_blast.energy_cost.append(CombatFunction.EnergyType.RED)
	fire_blast.base_damage = 25
	fire_blast.icon = "🔥"
	fire_blast.color = Color.ORANGE_RED
	functions.append(fire_blast)
	
	var ice_shard = CombatFunction.new("Ice Shard", "Freezing attack")
	ice_shard.energy_cost.append(CombatFunction.EnergyType.BLUE)
	ice_shard.energy_cost.append(CombatFunction.EnergyType.CYAN)
	ice_shard.base_damage = 20
	ice_shard.icon = "❄"
	ice_shard.color = Color.LIGHT_BLUE
	functions.append(ice_shard)
	
	return functions
	

# ===== DRAG AND DROP SYSTEM =====


func handle_function_drop(function: CombatFunction, from_slot: int, to_slot: int):
	"""Handle when a function is dropped onto a slot"""
	print("Function dropped: %s from slot %d to slot %d" % [function.name, from_slot, to_slot])
	
	if from_slot == -1:
		# Dropped from available functions
		if test_agent.function_script.size() < test_agent.available_function_slots:
			# Insert at specific position if not at the end
			if to_slot < test_agent.function_script.size():
				test_agent.function_script.insert(to_slot, function)
			else:
				test_agent.function_script.append(function)
			
			update_function_display()
			last_function_script_size = test_agent.function_script.size()
			print("Function added to slot %d successfully!" % to_slot)
		else:
			print("No available slots!")
			flash_script_area_full()
	else:
		# Moved from one slot to another
		if from_slot < test_agent.function_script.size() and to_slot != from_slot:
			var moved_function = test_agent.function_script[from_slot]
			test_agent.function_script.remove_at(from_slot)
			
			# Adjust target index if needed
			var insert_index = to_slot
			if from_slot < to_slot:
				insert_index -= 1
			
			if insert_index < test_agent.function_script.size():
				test_agent.function_script.insert(insert_index, moved_function)
			else:
				test_agent.function_script.append(moved_function)
			
			update_function_display()
			print("Function moved from slot %d to slot %d" % [from_slot, to_slot])

func handle_failed_drag(drag_data):
	"""Handle when a drag operation fails - restore the function to original slot"""
	if drag_data is Dictionary and drag_data.has("original_function") and drag_data.has("original_slot"):
		var original_function = drag_data["original_function"]
		var original_slot_index = drag_data["original_slot"]
		
		# Restore function to original slot
		if original_slot_index >= 0 and original_slot_index < function_slot_instances.size():
			var slot_instance = function_slot_instances[original_slot_index]
			slot_instance.accept_function(original_function)
			print("Restored function %s to original slot %d" % [original_function.name, original_slot_index])

# Override the _input method to handle failed drags
func _input(event):
	# Handle global drag failure cases
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		# Check if we have a drag in progress that wasn't handled by drop_data
		# This is a fallback for when drag data exists but no valid drop target was found
		var current_drag = get_viewport().gui_get_drag_data()
		if current_drag != null:
			# The drag failed (no valid drop target), handle cleanup
			handle_failed_drag(current_drag)

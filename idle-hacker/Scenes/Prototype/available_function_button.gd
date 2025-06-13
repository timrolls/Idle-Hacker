# available_function_button.gd
extends Control
class_name AvailableFunctionButton

@onready var button = $Button
@onready var icon_label = $Button/HBox/IconLabel
@onready var info_container = $Button/HBox/InfoContainer
@onready var name_label = $Button/HBox/InfoContainer/NameLabel
@onready var desc_label = $Button/HBox/InfoContainer/DescLabel
@onready var cost_container = $Button/HBox/InfoContainer/CostContainer

var combat_function: CombatFunction

# Style resources - editable in inspector
@export var normal_style: StyleBoxFlat
@export var hover_style: StyleBoxFlat
@export var pressed_style: StyleBoxFlat

signal function_drag_started(combat_function: CombatFunction, button_node: Button)

func _ready():
	# Set up default styles if not assigned
	if not normal_style:
		setup_default_styles()
	
	# Connect button signals
	button.button_down.connect(_on_button_down)
	button.mouse_entered.connect(_on_mouse_entered)
	button.mouse_exited.connect(_on_mouse_exited)

func setup_default_styles():
	# Normal style
	normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color.DIM_GRAY * 0.3
	normal_style.border_color = Color.GRAY * 0.5
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(5)
	
	# Hover style
	hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color.DIM_GRAY * 0.4
	hover_style.border_color = Color.GRAY * 0.7
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(5)
	
	# Pressed style
	pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color.DIM_GRAY * 0.5
	pressed_style.border_color = Color.WHITE
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(5)

func setup_function(function: CombatFunction):
	combat_function = function
	
	# Safety check: make sure @onready nodes are initialized
	if not icon_label:
		print("Warning: @onready nodes not ready yet, deferring setup")
		# Defer the setup until the next frame when @onready variables are ready
		call_deferred("_deferred_setup_function", function)
		return
	
	_do_setup_function(function)

func _deferred_setup_function(function: CombatFunction):
	"""Called on next frame when @onready variables are guaranteed to be ready"""
	_do_setup_function(function)

func _do_setup_function(function: CombatFunction):
	"""Actual setup implementation"""
	# Set icon and color
	icon_label.text = function.icon
	icon_label.modulate = function.color
	
	# Set name and description
	name_label.text = function.name
	desc_label.text = function.description
	
	# Clear and setup energy cost display
	for child in cost_container.get_children():
		child.queue_free()
	
	if function.energy_cost.size() > 0:
		var cost_label = Label.new()
		cost_label.text = "Cost: "
		cost_label.add_theme_color_override("font_color", Color.GRAY)
		cost_label.add_theme_font_size_override("font_size", 10)
		cost_container.add_child(cost_label)
		
		for energy_type in function.energy_cost:
			var energy_icon = Label.new()
			energy_icon.text = get_energy_icon(energy_type)
			energy_icon.add_theme_color_override("font_color", get_energy_color(energy_type))
			energy_icon.add_theme_font_size_override("font_size", 12)
			cost_container.add_child(energy_icon)
	else:
		var free_label = Label.new()
		free_label.text = "Free"
		free_label.add_theme_color_override("font_color", Color.GREEN)
		free_label.add_theme_font_size_override("font_size", 10)
		cost_container.add_child(free_label)
	
	# Apply normal style
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)

func get_energy_icon(energy_type: CombatFunction.EnergyType) -> String:
	match energy_type:
		CombatFunction.EnergyType.RED: return "🔴"
		CombatFunction.EnergyType.BLUE: return "🔵"
		CombatFunction.EnergyType.CYAN: return "🔷"
		_: return "⚪"

func get_energy_color(energy_type: CombatFunction.EnergyType) -> Color:
	match energy_type:
		CombatFunction.EnergyType.RED: return Color.RED
		CombatFunction.EnergyType.BLUE: return Color.BLUE
		CombatFunction.EnergyType.CYAN: return Color.CYAN
		_: return Color.WHITE

func _on_button_down():
	# Small delay to distinguish between click and drag
	await get_tree().create_timer(0.1).timeout
	
	if button.button_pressed:
		print("Starting drag for: ", combat_function.name)
		function_drag_started.emit(combat_function, button)
		
		# Start Godot's built-in drag and drop system
		var drag_data = {
			"type": "combat_function",
			"function": combat_function,
			"from_slot": -1  # -1 indicates from available functions
		}
		#set_drag_preview(create_drag_preview())
		button.set_drag_preview(create_drag_preview())

func create_drag_preview() -> Control:
	"""Create a visual preview for dragging"""
	var preview = Control.new()
	var preview_label = Label.new()
	preview_label.text = "%s %s" % [combat_function.icon, combat_function.name]
	preview_label.add_theme_color_override("font_color", combat_function.color)
	preview.add_child(preview_label)
	return preview

func get_drag_data(position: Vector2):
	"""Override to provide drag data for Godot's drag system"""
	if combat_function:
		var drag_data = {
			"type": "combat_function",
			"function": combat_function,
			"from_slot": -1
		}
		
		# Create visual feedback
		set_drag_preview(create_drag_preview())
		
		return drag_data
	
	return null

func _on_mouse_entered():
	# Optional: Add hover effects or tooltips here
	pass

func _on_mouse_exited():
	# Optional: Remove hover effects here
	pass

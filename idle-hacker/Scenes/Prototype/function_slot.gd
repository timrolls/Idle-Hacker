# function_slot.gd
extends Panel
class_name FunctionSlot

enum SlotState {
	LOCKED,
	EMPTY,
	FILLED,
	EXECUTING
}

@onready var content_container = $ContentContainer
@onready var locked_label = $ContentContainer/LockedLabel
@onready var empty_label = $ContentContainer/EmptyLabel
@onready var function_content = $ContentContainer/FunctionContent
@onready var function_icon = $ContentContainer/FunctionContent/HBox/FunctionIcon
@onready var function_info = $ContentContainer/FunctionContent/HBox/FunctionInfo
@onready var function_name_label = $ContentContainer/FunctionContent/HBox/FunctionInfo/FunctionName
@onready var function_desc_label = $ContentContainer/FunctionContent/HBox/FunctionInfo/FunctionDesc
@onready var energy_cost_container = $ContentContainer/FunctionContent/HBox/FunctionInfo/EnergyCostContainer

var slot_index: int = 0
var current_state: SlotState = SlotState.EMPTY
var combat_function: CombatFunction
var required_level: int = 1

# Style resources - these can be edited in the inspector
@export var locked_style: StyleBoxFlat
@export var empty_style: StyleBoxFlat
@export var filled_style: StyleBoxFlat
@export var executing_style: StyleBoxFlat

signal function_removed(slot_index: int)

func _ready():
	# Set up default styles if not assigned
	if not locked_style:
		setup_default_styles()

func setup_default_styles():
	# Locked slot style
	locked_style = StyleBoxFlat.new()
	locked_style.bg_color = Color.DIM_GRAY * 0.1
	locked_style.border_color = Color.GRAY * 0.5
	locked_style.set_border_width_all(2)
	
	# Empty slot style
	empty_style = StyleBoxFlat.new()
	empty_style.bg_color = Color.DIM_GRAY * 0.2
	empty_style.border_color = Color.GREEN * 0.3
	empty_style.set_border_width_all(1)
	
	# Filled slot style
	filled_style = StyleBoxFlat.new()
	filled_style.bg_color = Color.DARK_GRAY * 0.3
	
	# Executing slot style
	executing_style = StyleBoxFlat.new()
	executing_style.bg_color = Color.BLUE * 0.3

func setup_slot(index: int, state: SlotState, function: CombatFunction = null, req_level: int = 1):
	slot_index = index
	current_state = state
	combat_function = function
	required_level = req_level
	
	update_display()

func update_display():
	# Hide all content first
	locked_label.visible = false
	empty_label.visible = false
	function_content.visible = false
	
	match current_state:
		SlotState.LOCKED:
			show_locked_state()
		SlotState.EMPTY:
			show_empty_state()
		SlotState.FILLED:
			show_filled_state()
		SlotState.EXECUTING:
			show_executing_state()

func show_locked_state():
	locked_label.visible = true
	locked_label.text = "🔒 Unlocks at Level %d" % required_level
	add_theme_stylebox_override("panel", locked_style)

func show_empty_state():
	empty_label.visible = true
	empty_label.text = "Drop Function Here [Slot %d]" % (slot_index + 1)
	add_theme_stylebox_override("panel", empty_style)

func show_filled_state():
	if not combat_function:
		return
		
	function_content.visible = true
	
	# Update function info
	function_icon.text = combat_function.icon
	function_icon.modulate = combat_function.color
	function_name_label.text = combat_function.name
	function_desc_label.text = combat_function.description
	
	# Clear and update energy cost display
	for child in energy_cost_container.get_children():
		child.queue_free()
	
	if combat_function.energy_cost.size() > 0:
		var cost_label = Label.new()
		cost_label.text = "Cost: "
		cost_label.add_theme_color_override("font_color", Color.GRAY)
		energy_cost_container.add_child(cost_label)
		
		for energy_type in combat_function.energy_cost:
			var energy_icon = Label.new()
			energy_icon.text = get_energy_icon(energy_type)
			energy_icon.add_theme_color_override("font_color", get_energy_color(energy_type))
			energy_cost_container.add_child(energy_icon)
	
	add_theme_stylebox_override("panel", filled_style)

func show_executing_state():
	show_filled_state()  # Same as filled but different style
	add_theme_stylebox_override("panel", executing_style)

func set_executing(is_executing: bool):
	if current_state == SlotState.FILLED:
		current_state = SlotState.EXECUTING if is_executing else SlotState.FILLED
		update_display()

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

func _gui_input(event):
	# Handle right-click to remove function
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if current_state == SlotState.FILLED or current_state == SlotState.EXECUTING:
			remove_function()

func remove_function():
	function_removed.emit(slot_index)
	
func accept_function(function: CombatFunction):
	"""Call this to add a function to this slot"""
	if current_state == SlotState.EMPTY:
		combat_function = function
		current_state = SlotState.FILLED
		update_display()
		return true
	return false

func clear_function():
	"""Call this to remove the function from this slot"""
	if current_state == SlotState.FILLED or current_state == SlotState.EXECUTING:
		combat_function = null
		current_state = SlotState.EMPTY
		update_display()

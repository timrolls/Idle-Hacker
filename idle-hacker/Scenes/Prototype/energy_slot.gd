# energy_slot.gd
extends Panel
class_name EnergySlot

var energy_type: CombatFunction.EnergyType = CombatFunction.EnergyType.EMPTY

# Style resources - editable in inspector for easy customization
@export var empty_style: StyleBoxFlat
@export var red_style: StyleBoxFlat
@export var blue_style: StyleBoxFlat
@export var cyan_style: StyleBoxFlat

func _ready():
	# Set up default styles if not assigned
	if not empty_style:
		setup_default_styles()

func setup_default_styles():
	var corner_radius = 15
	
	# Empty style
	empty_style = StyleBoxFlat.new()
	empty_style.bg_color = Color.DIM_GRAY * 0.2
	empty_style.set_corner_radius_all(corner_radius)
	
	# Red energy style
	red_style = StyleBoxFlat.new()
	red_style.bg_color = Color.RED
	red_style.set_corner_radius_all(corner_radius)
	
	# Blue energy style
	blue_style = StyleBoxFlat.new()
	blue_style.bg_color = Color.BLUE
	blue_style.set_corner_radius_all(corner_radius)
	
	# Cyan energy style
	cyan_style = StyleBoxFlat.new()
	cyan_style.bg_color = Color.CYAN
	cyan_style.set_corner_radius_all(corner_radius)

func set_energy_type(new_energy_type: CombatFunction.EnergyType):
	energy_type = new_energy_type
	update_display()

func update_display():
	var style: StyleBoxFlat
	
	match energy_type:
		CombatFunction.EnergyType.EMPTY:
			style = empty_style
		CombatFunction.EnergyType.RED:
			style = red_style
		CombatFunction.EnergyType.BLUE:
			style = blue_style
		CombatFunction.EnergyType.CYAN:
			style = cyan_style
		_:
			style = empty_style
	
	add_theme_stylebox_override("panel", style)

func get_energy_color(energy_type_param: CombatFunction.EnergyType) -> Color:
	"""Helper function that can be used by other scripts"""
	match energy_type_param:
		CombatFunction.EnergyType.RED: return Color.RED
		CombatFunction.EnergyType.BLUE: return Color.BLUE
		CombatFunction.EnergyType.CYAN: return Color.CYAN
		_: return Color.DIM_GRAY * 0.2

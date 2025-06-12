# combat_function.gd
class_name CombatFunction
extends Resource

# Energy types enum - should be accessible from this class
enum EnergyType {
	EMPTY,
	RED,
	BLUE,
	CYAN
}

@export var name: String = ""
@export var description: String = ""
@export var energy_cost: Array[EnergyType] = []  # Required energy to execute
@export var energy_generated: Array[EnergyType] = []  # Energy produced on execution
@export var base_damage: int = 0
@export var special_effects: Array[String] = []
@export var icon: String = "⚡"
@export var color: Color = Color.WHITE

func _init(function_name: String = "", desc: String = ""):
	name = function_name
	description = desc

# Helper function to get energy color for UI
static func get_energy_color(type: EnergyType) -> Color:
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

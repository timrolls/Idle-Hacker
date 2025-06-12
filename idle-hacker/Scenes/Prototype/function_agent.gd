# function_agent.gd
class_name FunctionAgent
extends Resource

@export var agent_name: String = "Agent"
@export var max_health: int = 100
@export var current_health: int = 100
@export var energy_queue: Array[CombatFunction.EnergyType] = []  # Max 5 slots
@export var function_script: Array[CombatFunction] = []  # Array of CombatFunction - Max 5 slots
@export var execution_speed: float = 2.0  # Seconds between attacks
@export var attack_timer: float = 0.0
@export var integrity: float = 1.0  # 0.0 to 1.0
@export var xp: int = 1757
@export var level: int = 1
@export var current_function_index: int = 0
@export var max_function_slots: int = 5  # Total possible slots
@export var available_function_slots: int = 1  # Currently unlocked slots

func _init():
	# Initialize with 5 empty energy slots
	energy_queue = []
	function_script = []
	for i in range(5):
		energy_queue.append(CombatFunction.EnergyType.EMPTY)

func add_energy(type: CombatFunction.EnergyType):
	# Shift all energies left and add new one at the end
	for i in range(4):
		energy_queue[i] = energy_queue[i + 1]
	energy_queue[4] = type

func consume_energy(required: Array[CombatFunction.EnergyType]) -> bool:
	# Check if we have the required energy
	var available = energy_queue.duplicate()
	var needed = required.duplicate()
	
	for req_energy in needed:
		var found = false
		for i in range(available.size()):
			if available[i] == req_energy:
				available[i] = CombatFunction.EnergyType.EMPTY
				found = true
				break
		if not found:
			return false
	
	# If we get here, we can afford it - actually consume the energy
	for req_energy in required:
		for i in range(energy_queue.size()):
			if energy_queue[i] == req_energy:
				energy_queue[i] = CombatFunction.EnergyType.EMPTY
				break
	
	return true

func get_energy_count(type: CombatFunction.EnergyType) -> int:
	var count = 0
	for energy in energy_queue:
		if energy == type:
			count += 1
	return count

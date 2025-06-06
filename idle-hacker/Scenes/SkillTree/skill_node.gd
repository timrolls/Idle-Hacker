# SkillNode.gd - Individual skill node data
class_name SkillNode
extends Resource

@export var skill_name: String = "Skill Name"
@export var description: String = "Skill description here"
@export var grid_x: int = 0
@export var grid_y: int = 0
@export var cost: int = 1
@export var is_starting_node: bool = false
@export var is_allocated: bool = false
@export var icon: Texture2D
@export var skill_type: String = "Passive"  # Passive, Active, etc.

# Stats this skill provides
@export var stat_bonuses: Dictionary = {
	"damage": 0.0,
	"health": 0.0,
	"speed": 0.0,
	"critical_chance": 0.0
}

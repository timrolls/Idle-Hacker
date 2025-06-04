extends Control
class_name HardwareTreeUI

@export var node_scene: PackedScene  # Will create this next
@export var connection_color: Color = Color(0.3, 0.3, 0.3)
@export var unlocked_connection_color: Color = Color(0, 1, 0, 0.8)
@export var camera_smoothness: float = 0.1

@onready var tree_container: Control = $ScrollContainer/TreeContainer
@onready var connections_layer: Control = $ScrollContainer/TreeContainer/ConnectionsLayer
@onready var nodes_layer: Control = $ScrollContainer/TreeContainer/NodesLayer
@onready var camera: Camera2D = $Camera2D
@onready var points_label: Label = $UI/PointsLabel
@onready var stats_panel: Panel = $UI/StatsPanel
@onready var stats_text: RichTextLabel = $UI/StatsPanel/StatsText

var hardware_system: HardwareUpgradeSystem
var node_buttons: Dictionary = {}
var is_panning: bool = false
var pan_start_pos: Vector2

signal node_selected(node_id: String)

func _ready():
	# Get hardware system reference
	hardware_system = get_node("/root/HardwareUpgradeSystem")
	if not hardware_system:
		hardware_system = HardwareUpgradeSystem.new()
		add_child(hardware_system)
	
	# Connect signals
	hardware_system.node_unlocked.connect(_on_node_unlocked)
	hardware_system.stats_updated.connect(_on_stats_updated)
	
	# Build the tree
	build_tree_ui()
	update_connections()
	update_points_display()
	update_stats_display()

func build_tree_ui():
	# Clear existing
	for child in nodes_layer.get_children():
		child.queue_free()
	node_buttons.clear()
	
	# Create node buttons
	for node_id in hardware_system.upgrade_nodes:
		var node_data = hardware_system.upgrade_nodes[node_id]
		create_node_button(node_id, node_data)

func create_node_button(node_id: String, node_data: Dictionary):
	# Create container for the node
	var node_container = Control.new()
	node_container.position = node_data.position + Vector2(400, 400)  # Center offset
	node_container.size = Vector2(120, 80)
	
	# Create button
	var button = Button.new()
	button.size = Vector2(120, 80)
	button.anchor_left = 0.5
	button.anchor_top = 0.5
	button.position = Vector2(-60, -40)
	
	# Style based on type
	var color = get_node_type_color(node_data.type)
	button.modulate = color
	
	# Set text
	button.text = node_data.name + "\n" + node_data.description + "\nCost: " + str(node_data.cost)
	button.add_theme_font_size_override("font_size", 10)
	
	# Update visual state
	update_node_visual(button, node_data)
	
	# Connect signals
	button.pressed.connect(_on_node_button_pressed.bind(node_id))
	button.mouse_entered.connect(_on_node_hover.bind(node_id))
	button.mouse_exited.connect(_on_node_unhover.bind(node_id))
	
	node_container.add_child(button)
	nodes_layer.add_child(node_container)
	node_buttons[node_id] = button

func get_node_type_color(type: HardwareUpgradeSystem.NodeType) -> Color:
	match type:
		HardwareUpgradeSystem.NodeType.CPU:
			return Color.CYAN
		HardwareUpgradeSystem.NodeType.RAM:
			return Color.GREEN
		HardwareUpgradeSystem.NodeType.GPU:
			return Color.RED
		HardwareUpgradeSystem.NodeType.NETWORK:
			return Color.YELLOW
		HardwareUpgradeSystem.NodeType.STORAGE:
			return Color.PURPLE
		HardwareUpgradeSystem.NodeType.COOLING:
			return Color.BLUE
		_:
			return Color.WHITE

func update_node_visual(button: Button, node_data: Dictionary):
	if node_data.unlocked:
		button.disabled = false
		button.modulate.a = 1.0
	elif hardware_system.can_unlock_node(node_data.id):
		button.disabled = false
		button.modulate.a = 0.7
	else:
		button.disabled = true
		button.modulate.a = 0.3

func update_connections():
	# Clear existing connections
	for child in connections_layer.get_children():
		child.queue_free()
	
	# Draw new connections
	var connections = hardware_system.get_node_connections()
	for conn in connections:
		draw_connection(conn.from, conn.to, conn.unlocked)

func draw_connection(from_id: String, to_id: String, unlocked: bool):
	var from_node = hardware_system.upgrade_nodes[from_id]
	var to_node = hardware_system.upgrade_nodes[to_id]
	
	var from_pos = from_node.position + Vector2(400, 400)
	var to_pos = to_node.position + Vector2(400, 400)
	
	var line = Line2D.new()
	line.add_point(from_pos)
	line.add_point(to_pos)
	line.width = 3.0
	line.default_color = unlocked_connection_color if unlocked else connection_color
	line.z_index = -1
	
	connections_layer.add_child(line)

func update_points_display():
	points_label.text = "Upgrade Points: %d" % hardware_system.upgrade_points

func update_stats_display():
	var stats = hardware_system.current_stats
	var text = "[b]Current Hardware Stats:[/b]\n"
	text += "CPU Speed: x%.2f\n" % stats.cpu_speed
	text += "RAM Capacity: %d\n" % stats.ram_capacity
	text += "GPU Power: x%.2f\n" % stats.gpu_power
	text += "Network Speed: x%.2f\n" % stats.network_speed
	text += "Storage Bonus: +%.0f%%\n" % (stats.storage_bonus * 100)
	text += "Cooling: x%.2f" % stats.cooling_efficiency
	
	stats_text.bbcode_enabled = true
	stats_text.text = text

func _on_node_button_pressed(node_id: String):
	if hardware_system.can_unlock_node(node_id):
		if hardware_system.unlock_node(node_id):
			update_node_visual(node_buttons[node_id], hardware_system.upgrade_nodes[node_id])
			update_connections()
			update_points_display()
			
			# Update all nodes in case new ones became available
			for nid in node_buttons:
				update_node_visual(node_buttons[nid], hardware_system.upgrade_nodes[nid])
	
	node_selected.emit(node_id)

func _on_node_hover(node_id: String):
	# Show detailed tooltip
	var node_data = hardware_system.upgrade_nodes[node_id]
	# TODO: Implement tooltip

func _on_node_unhover(node_id: String):
	# Hide tooltip
	pass

func _on_node_unlocked(node_id: String):
	# Visual feedback for unlock
	var button = node_buttons[node_id]
	var tween = get_tree().create_tween()
	tween.tween_property(button, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.2)

func _on_stats_updated(stats: Dictionary):
	update_stats_display()

func _input(event):
	# Camera panning
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
			pan_start_pos = event.position
	
	elif event is InputEventMouseMotion and is_panning:
		var delta = event.position - pan_start_pos
		tree_container.position += delta
		pan_start_pos = event.position
	
	# Zoom
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			tree_container.scale *= 1.1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			tree_container.scale *= 0.9

func center_on_node(node_id: String):
	if not hardware_system.upgrade_nodes.has(node_id):
		return
	
	var node_data = hardware_system.upgrade_nodes[node_id]
	var target_pos = -(node_data.position + Vector2(400, 400)) + get_viewport_rect().size / 2
	
	var tween = get_tree().create_tween()
	tween.tween_property(tree_container, "position", target_pos, 0.5).set_ease(Tween.EASE_IN_OUT)

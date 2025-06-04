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
@onready var reset_button: Button = $UI/ResetButton

var hardware_system: HardwareUpgradeSystem
var node_buttons: Dictionary = {}
var is_panning: bool = false
var pan_start_pos: Vector2

signal node_selected(node_id: String)

func _ready():
	# Create the UI structure if nodes don't exist
	ensure_ui_structure()
	
	# Get hardware system reference - wait for it to be available
	await get_tree().process_frame
	
	hardware_system = get_node_or_null("/root/HardwareSystem")
	if not hardware_system:
		# Try alternate path
		hardware_system = get_node_or_null("/root/HardwareUpgradeSystem")
	
	if not hardware_system:
		push_warning("HardwareSystem not found, creating local instance")
		hardware_system = HardwareUpgradeSystem.new()
		hardware_system.name = "LocalHardwareSystem"
		add_child(hardware_system)
	
	# Connect signals
	hardware_system.node_unlocked.connect(_on_node_unlocked)
	hardware_system.stats_updated.connect(_on_stats_updated)
	
	# Connect reset button if it exists
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
	
	# Build the tree
	build_tree_ui()
	update_connections()
	update_points_display()
	update_stats_display()

func ensure_ui_structure():
	# Create Background if needed
	if not has_node("Background"):
		var bg = ColorRect.new()
		bg.name = "Background"
		bg.anchor_right = 1.0
		bg.anchor_bottom = 1.0
		bg.color = Color(0.05, 0.05, 0.05, 1)
		add_child(bg)
		move_child(bg, 0)
	
	# Create ScrollContainer if needed
	if not has_node("ScrollContainer"):
		var scroll = ScrollContainer.new()
		scroll.name = "ScrollContainer"
		scroll.anchor_right = 1.0
		scroll.anchor_bottom = 1.0
		scroll.anchor_top = 0.1
		add_child(scroll)
		
		# Create TreeContainer
		var tree_cont = Control.new()
		tree_cont.name = "TreeContainer"
		tree_cont.custom_minimum_size = Vector2(2000, 2000)
		scroll.add_child(tree_cont)
		
		# Create layers
		var conn_layer = Control.new()
		conn_layer.name = "ConnectionsLayer"
		conn_layer.anchor_right = 1.0
		conn_layer.anchor_bottom = 1.0
		conn_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tree_cont.add_child(conn_layer)
		
		var nodes_layer = Control.new()
		nodes_layer.name = "NodesLayer"
		nodes_layer.anchor_right = 1.0
		nodes_layer.anchor_bottom = 1.0
		nodes_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tree_cont.add_child(nodes_layer)
	
	# Create UI layer if needed
	if not has_node("UI"):
		var ui = Control.new()
		ui.name = "UI"
		ui.anchor_right = 1.0
		ui.anchor_bottom = 1.0
		ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ui)
		
		# Points label
		var points_lbl = Label.new()
		points_lbl.name = "PointsLabel"
		points_lbl.position = Vector2(20, 20)
		points_lbl.text = "Upgrade Points: 0"
		points_lbl.add_theme_font_size_override("font_size", 20)
		ui.add_child(points_lbl)
		
		# Stats panel
		var stats_pnl = Panel.new()
		stats_pnl.name = "StatsPanel"
		stats_pnl.anchor_left = 1.0
		stats_pnl.anchor_right = 1.0
		stats_pnl.position = Vector2(-250, 20)
		stats_pnl.size = Vector2(230, 180)
		stats_pnl.modulate = Color(1, 1, 1, 0.9)
		ui.add_child(stats_pnl)
		
		var stats_txt = RichTextLabel.new()
		stats_txt.name = "StatsText"
		stats_txt.anchor_right = 1.0
		stats_txt.anchor_bottom = 1.0
		stats_txt.position = Vector2(10, 10)
		stats_txt.size = Vector2(-20, -20)
		stats_txt.bbcode_enabled = true
		stats_txt.text = "[b]Hardware Stats[/b]"
		stats_pnl.add_child(stats_txt)
		
		# Reset button
		var reset_btn = Button.new()
		reset_btn.name = "ResetButton"
		reset_btn.position = Vector2(20, 60)
		reset_btn.size = Vector2(130, 30)
		reset_btn.text = "Reset Tree"
		ui.add_child(reset_btn)
	
	# Create Camera2D if needed
	if not has_node("Camera2D"):
		var cam = Camera2D.new()
		cam.name = "Camera2D"
		cam.position = Vector2(480, 270)
		add_child(cam)
	
	# Get references
	tree_container = get_node_or_null("ScrollContainer/TreeContainer")
	connections_layer = get_node_or_null("ScrollContainer/TreeContainer/ConnectionsLayer")
	nodes_layer = get_node_or_null("ScrollContainer/TreeContainer/NodesLayer")
	camera = get_node_or_null("Camera2D")
	points_label = get_node_or_null("UI/PointsLabel")
	stats_panel = get_node_or_null("UI/StatsPanel")
	stats_text = get_node_or_null("UI/StatsPanel/StatsText")
	reset_button = get_node_or_null("UI/ResetButton")

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

func _on_reset_pressed():
	# Confirm dialog would go here in full game
	hardware_system.reset_tree()
	build_tree_ui()
	update_connections()
	update_points_display()
	update_stats_display()

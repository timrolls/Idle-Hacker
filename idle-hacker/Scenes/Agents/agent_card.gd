extends Control
class_name AgentCard

# Card modes
enum CardMode {
	DISPLAY_ONLY,
	RECRUITMENT
}

# Exported properties
@export_group("Card Configuration")
@export var card_mode: CardMode = CardMode.DISPLAY_ONLY
@export var card_size: Vector2 = Vector2(200, 280)
@export var wireframe_color: Color = Color(0, 1, 0.8, 0.8)
@export var text_color: Color = Color.WHITE
@export var background_color: Color = Color(0.1, 0.1, 0.1, 0.9)

# Shape types for different agent types
enum ShapeType {
	ICOSAHEDRON,    # BruteForce - complex, aggressive
	CUBE,           # Firewall - solid, defensive
	OCTAHEDRON,     # PacketSniffer - sharp, fast
	DODECAHEDRON,   # Cryptominer - precious, valuable
	TETRAHEDRON     # Botnet - simple, numerous
}

# Node references
@onready var background_panel: Panel = $BackgroundPanel
@onready var shape_viewport: SubViewport = $ShapeContainer/SubViewport
@onready var shape_camera: Camera3D = $ShapeContainer/SubViewport/Camera3D
@onready var shape_mesh: MeshInstance3D = $ShapeContainer/SubViewport/ShapeNode
@onready var agent_type_label: Label = $InfoContainer/AgentTypeLabel
@onready var stats_container: GridContainer = $InfoContainer/StatsContainer
@onready var attack_timer_bar: ProgressBar = $InfoContainer/AttackTimerBar
@onready var special_attack_label: Label = $InfoContainer/SpecialAttackLabel
@onready var recruit_button: Button = $InfoContainer/RecruitButton

# Agent data
var current_agent: Agent = null
var agent_data: Dictionary = {}
var shape_rotation_speed: float = 1.0

signal agent_recruited(agent_card: AgentCard)

func _ready():
	setup_card_appearance()
	setup_shape_viewport()
	setup_recruitment_mode()
	
	# Debug print
	print("AgentCard _ready called")
	
	# Start shape rotation
	if shape_mesh:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_method(rotate_shape, 0.0, TAU, 4.0)
	else:
		print("Warning: shape_mesh not found in AgentCard")

func setup_card_appearance():
	# Set card size
	custom_minimum_size = card_size
	size = card_size
	
	# Style background panel
	if background_panel:
		var style = StyleBoxFlat.new()
		style.bg_color = background_color
		style.border_color = wireframe_color
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		background_panel.add_theme_stylebox_override("panel", style)
	
	# Style attack timer bar
	if attack_timer_bar:
		attack_timer_bar.modulate = wireframe_color
		var bar_style = StyleBoxFlat.new()
		bar_style.bg_color = Color.TRANSPARENT
		bar_style.border_color = wireframe_color
		bar_style.set_border_width_all(1)
		attack_timer_bar.add_theme_stylebox_override("background", bar_style)
		
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = wireframe_color
		attack_timer_bar.add_theme_stylebox_override("fill", fill_style)

func setup_shape_viewport():
	if not shape_viewport:
		return
		
	# Configure viewport for wireframe rendering
	shape_viewport.size = Vector2(160, 120)
	shape_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Position camera
	if shape_camera:
		shape_camera.position = Vector3(0, 0, 3)
		shape_camera.look_at(Vector3.ZERO, Vector3.UP)

func setup_recruitment_mode():
	if recruit_button:
		recruit_button.visible = (card_mode == CardMode.RECRUITMENT)
		if card_mode == CardMode.RECRUITMENT:
			recruit_button.pressed.connect(_on_recruit_button_pressed)

func load_agent_data(agent: Agent = null, data: Dictionary = {}):
	# Store references
	current_agent = agent
	agent_data = data
	
	print("Loading agent data into card")
	
	# Determine data source
	var display_data: Dictionary
	if agent:
		display_data = agent.get_status_info()
		display_data["type"] = agent.agent_type
		display_data["abilities"] = agent.abilities
		display_data["color"] = get_agent_type_color(agent.agent_type)
		print("Using live agent data: ", display_data.name)
	else:
		display_data = data
		print("Using dictionary data: ", data.get("name", "Unknown"))
	
	# Update UI elements
	update_agent_type(display_data.get("type", "Unknown"))
	update_stats(display_data)
	update_special_attack(display_data.get("abilities", []))
	update_wireframe_shape(display_data.get("type", "BruteForce"))
	
	# Set colors based on agent type/rarity
	var agent_color = display_data.get("color", wireframe_color)
	wireframe_color = agent_color
	setup_card_appearance()

func update_agent_type(agent_type: String):
	if agent_type_label:
		agent_type_label.text = agent_type.replace("_", " ")
		agent_type_label.add_theme_color_override("font_color", text_color)

func update_stats(data: Dictionary):
	if not stats_container:
		return
	
	# Clear existing stat labels
	for child in stats_container.get_children():
		child.queue_free()
	
	# Add stat pairs
	var stats_to_show = [
		{"label": "Health", "value": "%.0f/%.0f" % [data.get("health", 0), data.get("max_health", 100)]},
		{"label": "Damage", "value": "%.0f" % data.get("damage", 10)},
		{"label": "Speed", "value": "%.1f" % data.get("attack_speed", 1.0)},
		{"label": "RAM", "value": "%d" % data.get("ram_cost", 2)}
	]
	
	for stat in stats_to_show:
		# Stat label
		var stat_label = Label.new()
		stat_label.text = stat.label
		stat_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		stat_label.add_theme_font_size_override("font_size", 10)
		stats_container.add_child(stat_label)
		
		# Stat value
		var value_label = Label.new()
		value_label.text = stat.value
		value_label.add_theme_color_override("font_color", text_color)
		value_label.add_theme_font_size_override("font_size", 10)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stats_container.add_child(value_label)

func update_special_attack(abilities: Array):
	if not special_attack_label:
		return
	
	# Find first active ability with a command
	var special_command = "No Special"
	for ability in abilities:
		if ability.get("type") == "active" and ability.has("command"):
			special_command = ability.command
			break
	
	special_attack_label.text = special_command
	special_attack_label.add_theme_color_override("font_color", wireframe_color)

func update_wireframe_shape(agent_type: String):
	if not shape_mesh:
		print("Error: shape_mesh not found!")
		return
	
	print("Creating wireframe shape for: ", agent_type)
	
	var shape_type = get_shape_for_agent_type(agent_type)
	var wireframe_mesh = create_wireframe_mesh(shape_type)
	
	shape_mesh.mesh = wireframe_mesh
	shape_mesh.material_override = create_wireframe_material()
	
	print("Wireframe shape created successfully")

func get_shape_for_agent_type(agent_type: String) -> ShapeType:
	match agent_type:
		"BruteForce":
			return ShapeType.ICOSAHEDRON
		"Firewall":
			return ShapeType.CUBE
		"PacketSniffer":
			return ShapeType.OCTAHEDRON
		"Cryptominer":
			return ShapeType.DODECAHEDRON
		"Botnet":
			return ShapeType.TETRAHEDRON
		_:
			return ShapeType.CUBE

func get_agent_type_color(agent_type: String) -> Color:
	match agent_type:
		"BruteForce":
			return Color.CYAN
		"Firewall":
			return Color.GREEN
		"PacketSniffer":
			return Color.RED
		"Cryptominer":
			return Color.YELLOW
		"Botnet":
			return Color.PURPLE
		_:
			return Color.WHITE

func create_wireframe_mesh(shape_type: ShapeType) -> ArrayMesh:
	var vertices: PackedVector3Array = []
	var indices: PackedInt32Array = []
	
	match shape_type:
		ShapeType.CUBE:
			vertices = create_cube_vertices()
			indices = create_cube_indices()
		ShapeType.TETRAHEDRON:
			vertices = create_tetrahedron_vertices()
			indices = create_tetrahedron_indices()
		ShapeType.OCTAHEDRON:
			vertices = create_octahedron_vertices()
			indices = create_octahedron_indices()
		ShapeType.ICOSAHEDRON:
			vertices = create_icosahedron_vertices()
			indices = create_icosahedron_indices()
		ShapeType.DODECAHEDRON:
			vertices = create_dodecahedron_vertices()
			indices = create_dodecahedron_indices()
	
	var mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh

func create_wireframe_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.flags_unshaded = true
	material.vertex_color_use_as_albedo = true
	material.albedo_color = wireframe_color
	material.flags_transparent = true
	material.flags_do_not_use_vertex_colors = false
	return material

# Geometric shape vertex/index creation functions
func create_cube_vertices() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1),  # Back face
		Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)       # Front face
	])

func create_cube_indices() -> PackedInt32Array:
	return PackedInt32Array([
		# Back face edges
		0, 1, 1, 2, 2, 3, 3, 0,
		# Front face edges  
		4, 5, 5, 6, 6, 7, 7, 4,
		# Connecting edges
		0, 4, 1, 5, 2, 6, 3, 7
	])

func create_tetrahedron_vertices() -> PackedVector3Array:
	var a = 1.0
	return PackedVector3Array([
		Vector3(a, a, a),
		Vector3(a, -a, -a),
		Vector3(-a, a, -a),
		Vector3(-a, -a, a)
	])

func create_tetrahedron_indices() -> PackedInt32Array:
	return PackedInt32Array([
		0, 1, 0, 2, 0, 3,
		1, 2, 1, 3, 2, 3
	])

func create_octahedron_vertices() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(0, 1, 0),   # Top
		Vector3(0, -1, 0),  # Bottom
		Vector3(1, 0, 0),   # Right
		Vector3(-1, 0, 0),  # Left
		Vector3(0, 0, 1),   # Front
		Vector3(0, 0, -1)   # Back
	])

func create_octahedron_indices() -> PackedInt32Array:
	return PackedInt32Array([
		# Top pyramid
		0, 2, 0, 4, 0, 3, 0, 5,
		# Bottom pyramid
		1, 2, 1, 4, 1, 3, 1, 5,
		# Middle square
		2, 4, 4, 3, 3, 5, 5, 2
	])

func create_icosahedron_vertices() -> PackedVector3Array:
	var phi = (1.0 + sqrt(5.0)) / 2.0  # Golden ratio
	var vertices = PackedVector3Array()
	
	# 12 vertices of icosahedron
	vertices.append(Vector3(-1, phi, 0))
	vertices.append(Vector3(1, phi, 0))
	vertices.append(Vector3(-1, -phi, 0))
	vertices.append(Vector3(1, -phi, 0))
	vertices.append(Vector3(0, -1, phi))
	vertices.append(Vector3(0, 1, phi))
	vertices.append(Vector3(0, -1, -phi))
	vertices.append(Vector3(0, 1, -phi))
	vertices.append(Vector3(phi, 0, -1))
	vertices.append(Vector3(phi, 0, 1))
	vertices.append(Vector3(-phi, 0, -1))
	vertices.append(Vector3(-phi, 0, 1))
	
	return vertices

func create_icosahedron_indices() -> PackedInt32Array:
	# Simplified icosahedron edges for wireframe
	return PackedInt32Array([
		0, 1, 0, 5, 0, 7, 0, 10, 0, 11,
		1, 5, 1, 7, 1, 8, 1, 9,
		2, 3, 2, 4, 2, 6, 2, 10, 2, 11,
		3, 4, 3, 6, 3, 8, 3, 9,
		4, 5, 4, 9, 4, 11,
		5, 9, 5, 11,
		6, 7, 6, 8, 6, 10,
		7, 8, 7, 10,
		8, 9, 10, 11
	])

func create_dodecahedron_vertices() -> PackedVector3Array:
	var phi = (1.0 + sqrt(5.0)) / 2.0
	var inv_phi = 1.0 / phi
	
	# Simplified dodecahedron - using key vertices for wireframe effect
	return PackedVector3Array([
		Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(1, -1, 1), Vector3(1, -1, -1),
		Vector3(-1, 1, 1), Vector3(-1, 1, -1), Vector3(-1, -1, 1), Vector3(-1, -1, -1),
		Vector3(0, inv_phi, phi), Vector3(0, inv_phi, -phi), Vector3(0, -inv_phi, phi), Vector3(0, -inv_phi, -phi),
		Vector3(inv_phi, phi, 0), Vector3(inv_phi, -phi, 0), Vector3(-inv_phi, phi, 0), Vector3(-inv_phi, -phi, 0),
		Vector3(phi, 0, inv_phi), Vector3(phi, 0, -inv_phi), Vector3(-phi, 0, inv_phi), Vector3(-phi, 0, -inv_phi)
	])

func create_dodecahedron_indices() -> PackedInt32Array:
	# Simplified edge connections for dodecahedron wireframe
	return PackedInt32Array([
		0, 2, 0, 12, 0, 16, 1, 3, 1, 12, 1, 17,
		2, 10, 2, 13, 3, 11, 3, 13, 4, 6, 4, 14, 4, 18,
		5, 7, 5, 14, 5, 19, 6, 10, 6, 15, 7, 11, 7, 15,
		8, 10, 8, 12, 8, 16, 9, 11, 9, 12, 9, 17,
		14, 18, 15, 19, 16, 18, 17, 19
	])

func rotate_shape(angle: float):
	if shape_mesh:
		shape_mesh.rotation.y = angle
		shape_mesh.rotation.x = angle * 0.3

func update_attack_timer(current_time: float, max_time: float):
	if attack_timer_bar:
		attack_timer_bar.max_value = max_time
		attack_timer_bar.value = current_time

func _process(_delta):
	# Auto-update from connected agent
	if current_agent and is_instance_valid(current_agent):
		var updated_data = current_agent.get_status_info()
		update_stats(updated_data)
		
		# Update attack timer if agent has attack timer
		if current_agent.has_method("get_attack_timer_progress"):
			var timer_progress = current_agent.get_attack_timer_progress()
			update_attack_timer(timer_progress.current, timer_progress.max)

func _on_recruit_button_pressed():
	agent_recruited.emit(self)

# Public methods for external updates
func set_recruitment_cost(cost: int):
	if recruit_button and card_mode == CardMode.RECRUITMENT:
		recruit_button.text = "RECRUIT $%d" % cost

func set_card_mode(new_mode: CardMode):
	card_mode = new_mode
	setup_recruitment_mode()

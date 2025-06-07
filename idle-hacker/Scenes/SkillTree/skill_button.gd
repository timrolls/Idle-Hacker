
extends Control
class_name SkillButton

enum State {
	LOCKED,     # Dark/unavailable
	AVAILABLE,  # Lighter/can purchase
	ALLOCATED   # Bright/owned
}

var skill_node: SkillNode
var current_state: State = State.LOCKED

# Visual styling
var locked_color: Color = Color(0.2, 0.2, 0.2, 0.8)
var available_color: Color = Color(0.5, 0.5, 0.5, 1.0)
var allocated_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var highlight_color: Color = Color(0.8, 0.8, 1.0, 1.0)

# Edge dimming
var edge_dim_factor: float = 0.8  # 20% dimmer
var edge_hover_factor: float = 1.2  # 20% brighter on hover
var is_hovered: bool = false

# Purchase progress
var is_holding: bool = false
var hold_progress: float = 0.0
var hold_duration: float = 1.0  # 2 seconds to purchase
var hold_timer: float = 0.0

signal pressed
signal purchase_completed  # New signal for when purchase finishes

func _ready():
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered_feedback)
	mouse_exited.connect(_on_mouse_exited_feedback)

func _draw():
	var rect = get_rect()
	var center = rect.size / 2
	var diamond_size = min(rect.size.x, rect.size.y) * 0.4
	
	# Create diamond shape points
	var points = PackedVector2Array([
		center + Vector2(0, -diamond_size),      # Top
		center + Vector2(diamond_size, 0),       # Right  
		center + Vector2(0, diamond_size),       # Bottom
		center + Vector2(-diamond_size, 0)       # Left
	])
	
	# Draw filled diamond
	var color = get_current_color()
	draw_colored_polygon(points, color)
	
	# Draw purchase progress bar if holding and available
	if is_holding and current_state == State.AVAILABLE and hold_progress > 0.0:
		draw_progress_ring(center, diamond_size, hold_progress)
	
	# Draw diamond outline with hover effect
	var outline_color = Color.WHITE
	if is_hovered:
		outline_color = outline_color * edge_hover_factor  # Brighter on hover
	else:
		outline_color = outline_color * edge_dim_factor    # Dimmer normally
	
	var outline_points = PackedVector2Array(points)
	outline_points.append(points[0])  # Close the shape
	draw_polyline(outline_points, outline_color, 2.0)
	
	# Draw icon if available
	if skill_node and skill_node.icon:
		var icon_size = diamond_size * 1.2  # Make icon slightly larger than diamond
		var icon_rect = Rect2(center - Vector2(icon_size, icon_size) / 2, Vector2(icon_size, icon_size))
		
		# Apply state-based tinting to the icon
		var icon_modulate = Color.WHITE
		match current_state:
			State.LOCKED:
				icon_modulate = Color(0.4, 0.4, 0.4, 0.8)  # Dim for locked
			State.AVAILABLE:
				icon_modulate = Color(0.9, 0.9, 0.9, 1.0)  # Slightly dim for available
			State.ALLOCATED:
				icon_modulate = Color.WHITE  # Full brightness for owned
		
		# Additional brightness for hover
		if is_hovered:
			icon_modulate = icon_modulate * 1.1
		
		draw_texture_rect(skill_node.icon, icon_rect, false, icon_modulate)

func get_current_color() -> Color:
	match current_state:
		State.LOCKED:
			return locked_color
		State.AVAILABLE:
			return available_color
		State.ALLOCATED:
			return allocated_color
		_:
			return locked_color

func set_state(new_state: State):
	current_state = new_state
	queue_redraw()

func _on_mouse_entered_feedback():
	is_hovered = true
	queue_redraw()

func _on_mouse_exited_feedback():
	is_hovered = false
	queue_redraw()

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start holding
			if current_state == State.AVAILABLE:
				start_hold()
			else:
				# Just emit pressed for non-available nodes (for selection)
				pressed.emit()
		else:
			# Stop holding
			stop_hold()

func start_hold():
	is_holding = true
	hold_timer = 0.0
	hold_progress = 0.0

func stop_hold():
	is_holding = false
	hold_timer = 0.0
	hold_progress = 0.0
	queue_redraw()

func complete_purchase():
	is_holding = false
	hold_timer = 0.0
	hold_progress = 0.0
	purchase_completed.emit()
	queue_redraw()
	
func draw_progress_ring(center: Vector2, radius: float, progress: float):
	# Draw a circular progress ring around the diamond
	var ring_radius = radius + 8  # Slightly outside the diamond
	var ring_width = 4.0
	var segments = 64
	
	# Calculate how many segments to draw based on progress
	var segments_to_draw = int(segments * progress)
	
	# Draw the progress arc
	for i in range(segments_to_draw):
		var angle_start = (float(i) / segments) * TAU - PI/2  # Start from top
		var angle_end = (float(i + 1) / segments) * TAU - PI/2
		
		var start_pos = center + Vector2(cos(angle_start), sin(angle_start)) * ring_radius
		var end_pos = center + Vector2(cos(angle_end), sin(angle_end)) * ring_radius
		
		draw_line(start_pos, end_pos, Color.WHITE_SMOKE, ring_width)

func _process(delta):
	if is_holding and current_state == State.AVAILABLE:
		hold_timer += delta
		hold_progress = hold_timer / hold_duration
		
		if hold_progress >= 1.0:
			# Purchase completed!
			complete_purchase()
		
		queue_redraw()  # Redraw to update progress bar# SkillButton.gd - Custom button for skill nodes

extends Control
class_name OSTaskbar

# Views/Apps
enum AppMode {
	TERMINAL,  # Combined Terminal + Combat
	RECRUITMENT,
	HARDWARE
}

@export_group("Style")
@export var taskbar_color: Color = Color(0.1, 0.1, 0.1, 0.95)
@export var button_hover_color: Color = Color(0.2, 0.2, 0.2)
@export var button_active_color: Color = Color(0, 0.8, 0.6)
@export var icon_size: int = 32

@onready var taskbar_panel: Panel = $TaskbarPanel
@onready var app_buttons_container: HBoxContainer = $TaskbarPanel/HBoxContainer
@onready var clock_label: Label = $TaskbarPanel/ClockLabel
@onready var system_tray: HBoxContainer = $TaskbarPanel/SystemTray

var current_app: AppMode = AppMode.TERMINAL
var app_buttons: Dictionary = {}
var view_containers: Dictionary = {}

signal app_switched(app: AppMode)

func _ready():
	setup_taskbar()
	create_app_buttons()
	update_clock()
	
	# Start clock update timer
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(update_clock)
	timer.autostart = true
	add_child(timer)

func setup_taskbar():
	# Style the taskbar panel
	var style = StyleBoxFlat.new()
	style.bg_color = taskbar_color
	style.border_color = Color(0, 1, 0.8, 0.5)
	style.border_width_bottom = 2
	#taskbar_panel.add_theme_stylebox_override("panel", style)

func create_app_buttons():
	# Terminal (includes Combat)
	var terminal_btn = create_app_button(
		"Terminal",
		AppMode.TERMINAL,
		">_",  # Terminal prompt
		Color.WHITE
	)
	
	# Agent Recruitment
	var recruit_btn = create_app_button(
		"Recruit",
		AppMode.RECRUITMENT,
		"👤",  # Person icon
		Color.GREEN
	)
	
	# Hardware Manager
	var hardware_btn = create_app_button(
		"Hardware",
		AppMode.HARDWARE,
		"⚙",  # Gear icon
		Color.CYAN
	)
	
	# Set terminal as active by default
	set_active_app(AppMode.TERMINAL)

func create_app_button(app_name: String, app_mode: AppMode, icon: String, icon_color: Color) -> Button:
	var button = Button.new()
	button.text = " %s" % [app_name]
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(100, 40)
	
	# Style the button
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color.TRANSPARENT
	button.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = button_hover_color
	button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = button_active_color
	pressed_style.border_color = button_active_color
	pressed_style.border_width_bottom = 3
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	# Connect button
	button.pressed.connect(_on_app_button_pressed.bind(app_mode))
	
	# Add to container
	app_buttons_container.add_child(button)
	app_buttons[app_mode] = button
	
	# Create glitch effect on hover
	button.mouse_entered.connect(_on_button_hover.bind(button, app_name, icon))
	
	return button

func _on_app_button_pressed(app_mode: AppMode):
	if current_app == app_mode:
		return
	
	set_active_app(app_mode)
	app_switched.emit(app_mode)
	
	# Log app switch
	#var app_names = ["Terminal", "Recruit", "Hardware"]
	#EventBus.emit_log_entry("Launching %s..." % app_names[app_mode], Color.CYAN)
	
	# Glitch transition effect
	play_transition_effect()

func set_active_app(app_mode: AppMode):
	# Update button states
	for mode in app_buttons:
		var button = app_buttons[mode]
		if mode == app_mode:
			button.button_pressed = true
			button.modulate = Color.WHITE
		else:
			button.button_pressed = false
			button.modulate = Color(0.7, 0.7, 0.7)
	
	current_app = app_mode
	
	# Hide all views, show selected
	for mode in view_containers:
		if view_containers[mode]:
			view_containers[mode].visible = (mode == app_mode)

func register_view_container(app_mode: AppMode, container: Control):
	view_containers[app_mode] = container
	container.visible = (app_mode == current_app)

func update_clock():
	var time = Time.get_time_dict_from_system()
	clock_label.text = "%02d:%02d:%02d" % [time.hour, time.minute, time.second]

func _on_button_hover(button: Button, original_text: String, icon):
	# Glitch effect on hover
	var glitch_chars = "!@#$%^&*"
	var glitched = ""
	
	for i in range(original_text.length()):  
		if randf() < 0.3:
			glitched += glitch_chars[randi() % glitch_chars.length()]
		else:
			glitched += original_text[i]
	
	button.text = " " + glitched
	
	# Reset after a moment
	await get_tree().create_timer(0.1).timeout
	button.text = " " + original_text

func play_transition_effect():
	# Create a full-screen transition effect
	var transition = ColorRect.new()
	transition.color = Color(0, 1, 0.8, 0.1)
	transition.anchor_right = 1.0
	transition.anchor_bottom = 1.0
	transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(transition)
	
	# Flicker effect
	var tween = get_tree().create_tween()
	tween.tween_property(transition, "modulate:a", 0.3, 0.05)
	tween.tween_property(transition, "modulate:a", 0.0, 0.05)
	tween.tween_property(transition, "modulate:a", 0.2, 0.05)
	tween.tween_property(transition, "modulate:a", 0.0, 0.1)
	tween.tween_callback(transition.queue_free)

func add_system_tray_icon(icon: String, tooltip: String) -> Label:
	var icon_label = Label.new()
	icon_label.text = icon
	icon_label.tooltip_text = tooltip
	icon_label.add_theme_font_size_override("font_size", 16)
	system_tray.add_child(icon_label)
	return icon_label

func add_resource_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color(0.8, 0.8, 0.8)
	
	# Add some spacing
	if system_tray.get_child_count() > 0:
		var spacer = Control.new()
		spacer.custom_minimum_size.x = 20
		system_tray.add_child(spacer)
	
	system_tray.add_child(label)
	return label

func add_alert_box() -> LineEdit:
	var alert = LineEdit.new()
	alert.placeholder_text = "Alert"
	alert.editable = false
	alert.custom_minimum_size = Vector2(100, 30)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2)
	style.border_color = Color(0.4, 0.4, 0.4)
	style.set_border_width_all(1)
	alert.add_theme_stylebox_override("normal", style)
	
	system_tray.add_child(alert)
	return alert

extends LineEdit

@export var command_prompt: String = ">> "

func _ready():
	# Set up terminal styling
	placeholder_text = "Enter command..."
	
	# Connect the text submission signal
	text_submitted.connect(_on_text_submitted)
	
	# Optional: Connect focus events for better UX
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	
	# Set initial prompt
	update_prompt()

func _on_text_submitted(new_text: String):
	if new_text.strip_edges() == "":
		return
	
	# Send command to EventBus
	EventBus.emit_command(new_text.strip_edges())
	
	# Clear the input
	clear()
	update_prompt()

func update_prompt():
	# This makes it look more terminal-like
	placeholder_text = command_prompt + "Enter command..."

func _on_focus_entered():
	# Optional: Change appearance when focused
	modulate = Color.WHITE

func _on_focus_exited():
	# Optional: Dim when not focused
	modulate = Color(0.8, 0.8, 0.8)

# Optional: Handle special keys
func _input(event):
	if has_focus() and event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				# Could implement command history here
				pass
			KEY_DOWN:
				# Could implement command history here  
				pass

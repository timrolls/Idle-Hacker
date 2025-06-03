extends Node2D

enum GameState { TRAVELING, COMBAT }

@export var server_scene: PackedScene 
@export var party_speed: float = 50.0
@export var server_spacing: float = 500.0

var current_state: GameState = GameState.TRAVELING
var next_server_position: float = 500.0

@onready var party_group = $TravelLayer/PartyGroup
@onready var server_container = $TravelLayer/ServerContainer
@onready var agent_panel = $UI/AgentPanel



func _ready():
	setup_initial_server()
	setup_agent_ui()

func _process(delta):
	match current_state:
		GameState.TRAVELING:
			handle_traveling(delta)
		GameState.COMBAT:
			handle_combat(delta)

func handle_traveling(delta):
	# Move party forward
	party_group.position.x += party_speed * delta
	
	# Check if we've reached the next server
	if party_group.position.x >= next_server_position:
		start_combat()

func handle_combat(delta):
	# Combat logic will go here
	# For now, just simulate a 5-second combat
	await get_tree().create_timer(5.0).timeout
	end_combat()

func start_combat():
	current_state = GameState.COMBAT
	print("Combat started!")
	# Stop party movement, start hacking

func end_combat():
	current_state = GameState.TRAVELING
	print("Combat ended!")
	
	# Remove the defeated server
	if server_container.get_child_count() > 0:
		server_container.get_child(0).queue_free()
	
	# Spawn next server
	spawn_next_server()

func setup_initial_server():
	spawn_server(next_server_position)

func spawn_next_server():
	next_server_position += server_spacing
	spawn_server(next_server_position)

func spawn_server(pos_x: float):
	var server = server_scene.instantiate()
	server.position.x = pos_x
	server_container.add_child(server)

func setup_agent_ui():
	# Set up health bars for each agent
	var health_bars = get_tree().get_nodes_in_group("HealthBar")
	for i in range(health_bars.size()):
		health_bars[i].value = 100  # Start at full health

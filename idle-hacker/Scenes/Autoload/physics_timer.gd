
###############################################################
## Create, autostart, and auto-free after 0.1 seconds
#var timer = PhysicsTimer.new(0.1, true, true, true)
#add_child(timer)
#await timer.timeout
## Timer is automatically freed
#print("100ms timer completed and freed")
###############################################################


class_name PhysicsTimer
extends Node

signal timeout

var wait_time: float = 1.0
var time_left: float = 0.0
var is_running: bool = false
var one_shot: bool = false
var auto_free: bool = false  # Automatically free on timeout for one-shot timers

func _init(
	duration: float = 1.0, 
	single_shot: bool = false, 
	autostart: bool = false, 
	auto_free: bool = false
) -> void:
	wait_time = duration
	one_shot = single_shot
	self.auto_free = auto_free
	set_physics_process(false)
	
	# Store autostart state for _ready()
	if autostart:
		is_running = true
		time_left = wait_time

func _ready() -> void:
	if is_running:
		set_physics_process(true)

func start(duration: float = -1.0) -> void:
	if duration > 0:
		wait_time = duration
	time_left = wait_time
	is_running = true
	set_physics_process(true)

func stop() -> void:
	is_running = false
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	time_left -= delta
	
	if time_left <= 0:
		_handle_timeout()

func _handle_timeout() -> void:
	var overshoot = -time_left
	emit_signal("timeout")
	
	if one_shot:
		stop()
		if auto_free:
			queue_free()
	else:
		time_left = wait_time - overshoot
		# Handle cases where overshoot exceeds wait_time
		while time_left <= 0:
			emit_signal("timeout")
			time_left += wait_time

# Clean await interface
func wait_for_timeout() -> void:
	if is_running:
		await timeout
	# If auto_free is set, the node might be freed after this

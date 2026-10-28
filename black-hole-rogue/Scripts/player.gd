extends CharacterBody2D

signal state_changed(new_state: String)
enum State { IDLE, RUN, SPRINT, JUMP, FALL, DASH }

@export var run_speed := 240.0
@export var sprint_speed := 360.0
@export var acceleration := 2200.0
@export var deceleration := 2600.0
@export var air_acceleration := 1700.0
@export var jump_velocity := -420.0
@export var gravity := 1200.0
@export var coyote_time := 0.10
@export var jump_buffer_time := 0.12
@export var dash_speed := 650.0
@export var dash_duration := 0.16
@export var dash_cooldown := 0.45

var state: State = State.IDLE
var facing := 1.0
var coyote_left := 0.0
var jump_buffer_left := 0.0
var dash_left := 0.0
var cooldown_left := 0.0
var dash_direction := 1.0
var trail_left := 0.0
@onready var visual: Node2D = $Visual
@onready var camera: Camera2D = $Camera2D
var spawn_position: Vector2

func _ready() -> void:
	spawn_position = global_position
	floor_snap_length = 6.0
	floor_stop_on_slope = true

func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		facing = signf(direction)
	cooldown_left = maxf(0.0, cooldown_left - delta)
	coyote_left = coyote_time if is_on_floor() else maxf(0.0, coyote_left - delta)
	jump_buffer_left = maxf(0.0, jump_buffer_left - delta)
	if Input.is_action_just_pressed("jump"):
		jump_buffer_left = jump_buffer_time
	if Input.is_action_just_pressed("dash") and cooldown_left <= 0.0:
		dash_left = dash_duration
		cooldown_left = dash_cooldown
		dash_direction = facing
		trail_left = 0.0
	if dash_left > 0.0:
		dash_left = maxf(0.0, dash_left - delta)
		velocity = Vector2(dash_direction * dash_speed, 0)
		trail_left -= delta
		if trail_left <= 0.0:
			visual.afterimage()
			trail_left = 0.035
	else:
		velocity.y = minf(velocity.y + gravity * delta, 800.0)
		if jump_buffer_left > 0.0 and coyote_left > 0.0:
			velocity.y = jump_velocity
			jump_buffer_left = 0.0
			coyote_left = 0.0
			floor_snap_length = 0.0
		else:
			floor_snap_length = 6.0
		# Releasing Space early produces a shorter hop, including buffered jumps.
		if not Input.is_action_pressed("jump") and velocity.y < 0.0:
			velocity.y += gravity * 2.0 * delta
		var target := direction * (sprint_speed if Input.is_action_pressed("sprint") else run_speed)
		var rate := acceleration if is_on_floor() else air_acceleration
		if direction == 0.0:
			rate = deceleration if is_on_floor() else air_acceleration * 0.65
		velocity.x = move_toward(velocity.x, target, rate * delta)
	move_and_slide()
	if global_position.y > 720.0:
		respawn()
	_update_state()
	visual.facing = facing
	camera.offset.x = move_toward(camera.offset.x, facing * 36.0, delta * 120.0)

func _update_state() -> void:
	var next := State.IDLE
	if dash_left > 0.0:
		next = State.DASH
	elif not is_on_floor():
		next = State.JUMP if velocity.y < 0.0 else State.FALL
	elif absf(velocity.x) > 12.0:
		next = State.SPRINT if Input.is_action_pressed("sprint") else State.RUN
	if next != state:
		state = next
		visual.state = State.keys()[state]
		state_changed.emit(visual.state)

func respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	dash_left = 0.0
	cooldown_left = 0.0
	jump_buffer_left = 0.0
	coyote_left = 0.0
	camera.reset_smoothing()

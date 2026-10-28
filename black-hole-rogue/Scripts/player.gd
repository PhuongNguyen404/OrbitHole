extends CharacterBody2D

signal state_changed(new_state: String)
signal melee_hit(target: Node, stage: int)
enum State { IDLE, RUN, SPRINT, JUMP, FALL, DASH, ATTACK }

@export var run_speed := 240.0
@export var sprint_speed := 360.0
@export var acceleration := 2200.0
@export var deceleration := 2600.0
@export var air_acceleration := 1700.0
@export var jump_velocity := -580.0
@export var gravity := 1200.0
@export var coyote_time := 0.10
@export var jump_buffer_time := 0.12
@export var dash_speed := 650.0
@export var dash_duration := 0.16
@export var dash_cooldown := 0.45

const COMBO_DURATIONS := [0.40, 0.46, 0.62]
const ACTIVE_START := 0.30
const ACTIVE_END := 0.53
var attack_stage := -1
var attack_elapsed := 0.0
var attack_queued := false
var attack_lockout := 0.0
var attack_direction := 1.0
var struck_targets: Dictionary = {}
var air_attack_used := false
var landing_speed := 0.0
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
	if direction != 0.0 and attack_stage < 0:
		facing = signf(direction)
	attack_lockout = maxf(0.0, attack_lockout - delta)
	if is_on_floor():
		air_attack_used = false
	if Input.is_action_just_pressed("attack"):
		if attack_stage >= 0:
			if attack_elapsed / COMBO_DURATIONS[attack_stage] > 0.18:
				attack_queued = true
		elif dash_left <= 0.0 and attack_lockout <= 0.0 and (is_on_floor() or not air_attack_used):
			_begin_attack(0)
			if not is_on_floor():
				air_attack_used = true
	cooldown_left = maxf(0.0, cooldown_left - delta)
	coyote_left = coyote_time if is_on_floor() else maxf(0.0, coyote_left - delta)
	jump_buffer_left = maxf(0.0, jump_buffer_left - delta)
	if Input.is_action_just_pressed("jump"):
		jump_buffer_left = jump_buffer_time
	if Input.is_action_just_pressed("dash") and cooldown_left <= 0.0:
		_end_attack()
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
		var gravity_scale := 0.78 if absf(velocity.y) < 90.0 else 1.0
		velocity.y = minf(velocity.y + gravity * gravity_scale * delta, 800.0)
		if jump_buffer_left > 0.0 and coyote_left > 0.0:
			_end_attack()
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
		if attack_stage >= 0:
			target *= 0.28
		var rate := acceleration if is_on_floor() else air_acceleration
		if direction == 0.0:
			rate = deceleration if is_on_floor() else air_acceleration * 0.65
		velocity.x = move_toward(velocity.x, target, rate * delta)
	_tick_attack(delta)
	var was_grounded := is_on_floor()
	landing_speed = velocity.y
	move_and_slide()
	if is_on_floor() and not was_grounded and landing_speed > 120.0:
		visual.land(landing_speed)

	if global_position.y > 720.0:
		respawn()
	_update_state()
	visual.motion_velocity = velocity
	visual.facing = facing
	camera.offset.x = move_toward(camera.offset.x, facing * 36.0, delta * 120.0)

func _update_state() -> void:
	var next := State.IDLE
	if dash_left > 0.0:
		next = State.DASH
	elif attack_stage >= 0:
		next = State.ATTACK
	elif not is_on_floor():
		next = State.JUMP if velocity.y < 0.0 else State.FALL
	elif absf(velocity.x) > 12.0:
		next = State.SPRINT if Input.is_action_pressed("sprint") else State.RUN
	if next != state:
		state = next
		visual.state = State.keys()[state]
		state_changed.emit(visual.state)

func _begin_attack(stage: int) -> void:
	attack_stage = stage
	attack_elapsed = 0.0
	attack_queued = false
	struck_targets.clear()
	attack_direction = facing
	visual.attack_stage = stage
	visual.attack_progress = 0.0

func _end_attack() -> void:
	if attack_stage >= 0:
		attack_lockout = 0.12
	attack_stage = -1
	attack_queued = false
	visual.attack_progress = -1.0

func _tick_attack(delta: float) -> void:
	if attack_stage < 0:
		return
	attack_elapsed += delta
	var duration: float = COMBO_DURATIONS[attack_stage]
	var progress := attack_elapsed / duration
	visual.attack_stage = attack_stage
	visual.attack_progress = progress
	# Stones compress toward the singularity before being thrown outward.
	if progress < ACTIVE_START:
		var sphere := CircleShape2D.new()
		sphere.radius = 112.0
		var pull_query := PhysicsShapeQueryParameters2D.new()
		pull_query.shape = sphere
		pull_query.transform = Transform2D(0.0, global_position + Vector2(0,-42))
		pull_query.collision_mask = 4
		for result in get_world_2d().direct_space_state.intersect_shape(pull_query):
			var target: Object = result.collider
			if target.has_method("apply_gravity_pull"):
				target.apply_gravity_pull(global_position + Vector2(0,-42), delta * 650.0)
	if progress >= ACTIVE_START and progress <= ACTIVE_END:
		var hit_shape := RectangleShape2D.new()
		hit_shape.size = Vector2(44 if attack_stage == 2 else 34, 24)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = hit_shape
		query.transform = Transform2D(0.0,global_position + Vector2(attack_direction * (37 if attack_stage == 2 else 29),-32 if attack_stage == 2 else -47))
		query.collision_mask = 4
		for result in get_world_2d().direct_space_state.intersect_shape(query):
			var target: Node = result.collider
			if not struck_targets.has(target.get_instance_id()) and target.has_method("receive_melee_hit"):
				struck_targets[target.get_instance_id()] = true
				target.receive_melee_hit(Vector2(attack_direction * (360 if attack_stage == 2 else 180),-100), attack_stage)
				melee_hit.emit(target,attack_stage)
	if progress >= 1.0:
		if attack_queued and attack_stage < 2:
			_begin_attack(attack_stage + 1)
		else:
			_end_attack()

func respawn() -> void:
	_end_attack()
	air_attack_used = false
	global_position = spawn_position
	velocity = Vector2.ZERO
	dash_left = 0.0
	cooldown_left = 0.0
	jump_buffer_left = 0.0
	coyote_left = 0.0
	camera.reset_smoothing()

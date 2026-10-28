extends CharacterBody2D

## Void Construct — movement + animation polish.
## Tune exported values on the Player node in the Inspector.

const BASE_SPRITE_SCALE := 0.6

@export_group("Movement")
@export var move_speed: float = 210.0
@export var ground_acceleration: float = 2200.0
@export var ground_deceleration: float = 2400.0
@export var air_acceleration: float = 1600.0
@export var air_deceleration: float = 900.0
@export var turnaround_boost: float = 1.35

@export_group("Jump")
@export var jump_velocity: float = -440.0
@export var jump_cut_multiplier: float = 0.45
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.12
@export var fall_gravity_multiplier: float = 1.45
@export var max_fall_speed: float = 720.0

@export_group("Dash")
@export var dash_speed: float = 460.0
@export var dash_time: float = 0.13
@export var dash_cooldown: float = 0.22
@export var dash_end_speed_keep: float = 0.45

@export_group("Camera")
@export var camera_look_ahead: float = 48.0
@export var camera_look_ahead_speed: float = 140.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

var _facing: float = 1.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_dir: float = 1.0
var _can_air_dash: bool = true
var _was_on_floor: bool = true
var _land_timer: float = 0.0
var _squash := Vector2.ONE
var _afterimage_acc: float = 0.0
var _just_jumped: bool = false
var _just_dashed: bool = false


func _ready() -> void:
	motion_mode = MOTION_MODE_GROUNDED
	up_direction = Vector2.UP
	floor_stop_on_slope = true
	floor_constant_speed = true
	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(50.0)
	safe_margin = 0.08
	_was_on_floor = is_on_floor()
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	_just_jumped = false
	_just_dashed = false
	_update_timers(delta)

	_try_start_dash()

	if _is_dashing:
		_apply_dash(delta)
	else:
		_apply_gravity(delta)
		_apply_jump()
		_apply_horizontal(delta)

	_update_facing()
	move_and_slide()

	var on_floor := is_on_floor() and velocity.y >= 0.0
	if on_floor:
		_coyote_timer = coyote_time
		_can_air_dash = true
		if not _was_on_floor:
			_land_timer = 0.14 if absf(velocity.x) < 40.0 else 0.07
			_squash = Vector2(1.22, 0.74)
	_was_on_floor = on_floor

	_update_animations()
	_update_camera(delta)


func _process(delta: float) -> void:
	_update_visuals(delta)


func _update_timers(delta: float) -> void:
	if not is_on_floor():
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	if _land_timer > 0.0:
		_land_timer = maxf(_land_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time


func _apply_gravity(delta: float) -> void:
	var gravity_vec := get_gravity()
	var multiplier := fall_gravity_multiplier if velocity.y > 0.0 else 1.0
	velocity += gravity_vec * multiplier * delta
	if velocity.y > max_fall_speed:
		velocity.y = max_fall_speed


func _apply_jump() -> void:
	var can_jump := is_on_floor() or _coyote_timer > 0.0
	if can_jump and _jump_buffer_timer > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_land_timer = 0.0
		floor_snap_length = 0.0
		_squash = Vector2(0.84, 1.22)
		_just_jumped = true
	else:
		floor_snap_length = 8.0

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


func _apply_horizontal(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var on_floor := is_on_floor()
	var accel := ground_acceleration if on_floor else air_acceleration
	var decel := ground_deceleration if on_floor else air_deceleration
	var target_speed := direction * move_speed

	if direction == 0.0:
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
		return

	var reversing := velocity.x != 0.0 and signf(velocity.x) != signf(direction)
	var rate := (accel + decel) * turnaround_boost if reversing else accel
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)


func _try_start_dash() -> bool:
	if _is_dashing:
		return false
	if not Input.is_action_just_pressed("dash"):
		return false
	if _dash_cooldown_timer > 0.0:
		return false
	if not is_on_floor() and not _can_air_dash:
		return false

	var direction := Input.get_axis("move_left", "move_right")
	_dash_dir = direction if direction != 0.0 else _facing
	if _dash_dir == 0.0:
		_dash_dir = 1.0

	_is_dashing = true
	_dash_timer = dash_time
	_dash_cooldown_timer = dash_cooldown
	_land_timer = 0.0
	_afterimage_acc = 0.0
	_squash = Vector2(1.28, 0.78)
	_just_dashed = true
	if not is_on_floor():
		_can_air_dash = false
	_facing = _dash_dir
	_spawn_afterimage()
	return true


func _apply_dash(delta: float) -> void:
	_dash_timer -= delta
	velocity.x = _dash_dir * dash_speed
	velocity.y = 0.0
	_afterimage_acc += delta
	if _afterimage_acc >= 0.028:
		_afterimage_acc = 0.0
		_spawn_afterimage()
	if _dash_timer <= 0.0:
		_is_dashing = false
		velocity.x *= dash_end_speed_keep
		_squash = Vector2(1.08, 0.94)


func _update_facing() -> void:
	if _is_dashing:
		_facing = _dash_dir
	else:
		var direction := Input.get_axis("move_left", "move_right")
		if direction != 0.0:
			_facing = direction

	# HD sheet faces right. Flip only when moving left.
	sprite.flip_h = _facing < 0.0


func _update_animations() -> void:
	var anim := _choose_animation()
	var restart := (_just_jumped and anim == "jump") or (_just_dashed and anim == "dash")
	if sprite.animation != anim or restart:
		sprite.play(anim)

	if anim == "run":
		sprite.speed_scale = clampf(absf(velocity.x) / move_speed, 0.7, 1.4)
	elif anim == "idle":
		sprite.speed_scale = 0.9
	elif anim == "fall":
		sprite.speed_scale = 0.85
	else:
		sprite.speed_scale = 1.0


func _choose_animation() -> String:
	if _is_dashing:
		return "dash"
	if not is_on_floor():
		if velocity.y < -50.0:
			return "jump"
		return "fall"
	if _land_timer > 0.0 and absf(velocity.x) < 50.0:
		return "land"
	if absf(velocity.x) > 18.0:
		return "run"
	return "idle"


func _update_visuals(delta: float) -> void:
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-delta * 14.0))
	var breath := 1.0
	if sprite.animation == "idle":
		breath = 1.0 + sin(float(Time.get_ticks_msec()) * 0.0035) * 0.025
	sprite.scale = Vector2(
		BASE_SPRITE_SCALE * _squash.x,
		BASE_SPRITE_SCALE * _squash.y * breath
	)

	var lean_target := 0.0
	if _is_dashing:
		lean_target = deg_to_rad(8.0) * _facing
	elif not is_on_floor():
		lean_target = deg_to_rad(-4.0) * _facing if velocity.y < 0.0 else deg_to_rad(5.0) * _facing
	elif absf(velocity.x) > 20.0:
		lean_target = deg_to_rad(5.0) * signf(velocity.x)
	sprite.rotation = lerp_angle(sprite.rotation, lean_target, 1.0 - exp(-delta * 12.0))


func _spawn_afterimage() -> void:
	if sprite.sprite_frames == null:
		return
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = tex
	ghost.global_position = sprite.global_position
	ghost.global_rotation = sprite.global_rotation
	ghost.scale = sprite.scale
	ghost.flip_h = sprite.flip_h
	ghost.z_index = sprite.z_index - 1
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ghost.modulate = Color(0.72, 0.38, 1.0, 0.5)
	get_parent().add_child(ghost)
	var tw := ghost.create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tw.tween_callback(ghost.queue_free)


func _update_camera(delta: float) -> void:
	var target_x := _facing * camera_look_ahead
	camera.offset.x = move_toward(camera.offset.x, target_x, camera_look_ahead_speed * delta)

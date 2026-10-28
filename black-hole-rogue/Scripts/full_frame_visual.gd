extends AnimatedSprite2D
## One complete body drawing. Animation timing never deforms the sprite transform.
var state := "IDLE":
	set(value):
		if state != value:
			state = value
			state_elapsed = 0.0
			if state != "IDLE":
				landing_left = 0.0
			_select_locomotion()
var facing := 1.0:
	set(value):
		facing = -1.0 if value < 0.0 else 1.0
		flip_h = facing < 0.0
var motion_velocity := Vector2.ZERO
var attack_stage := -1
var attack_progress := -1.0
var attacking := false
var attack_animation: StringName
var state_elapsed := 0.0
var landing_left := 0.0
var _resume_after_hitstop := false
var attack_paused := false:
	set(value):
		if attack_paused == value:
			return
		attack_paused = value
		if attack_paused:
			_resume_after_hitstop = is_playing() and not attacking
			pause()
		elif not attacking and _resume_after_hitstop:
			play(animation)
			_resume_after_hitstop = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_select_locomotion()
	if not is_playing() and sprite_frames != null:
		play(animation)

func _process(delta: float) -> void:
	if not attack_paused:
		state_elapsed += delta
		if landing_left > 0.0:
			landing_left = maxf(0.0, landing_left - delta)
			if landing_left <= 0.0:
				_select_locomotion()
	var target_rate := 1.0
	if not attacking and state in ["RUN", "SPRINT"]:
		var nominal := 360.0 if state == "SPRINT" else 240.0
		target_rate = clampf(absf(motion_velocity.x) / nominal, 0.5, 1.15)
		speed_scale = lerpf(speed_scale, target_rate, 1.0 - exp(-delta * 12.0))
	else:
		speed_scale = 1.0
	if not attacking and not attack_paused and state == "JUMP" and animation == &"jump" and state_elapsed >= 0.025:
		var final_frame := sprite_frames.get_frame_count(&"jump") - 1
		if final_frame >= 1:
			# The rising drawing waits for the physical apex. No delayed jump input,
			# whole-body shift, or replay of the takeoff drawing is required.
			if motion_velocity.y >= -110.0:
				frame = final_frame
				pause()
			elif frame >= final_frame:
				frame = final_frame - 1
				pause()

func _select_locomotion() -> void:
	if attacking or sprite_frames == null:
		return
	var next := StringName(state.to_lower())
	if next == &"attack" or not sprite_frames.has_animation(next):
		next = &"idle"
	if landing_left > 0.0 and state == "IDLE" and sprite_frames.has_animation(&"landing"):
		next = &"landing"
	if animation != next:
		var preserve_stride := animation in [&"run", &"sprint"] and next in [&"run", &"sprint"]
		var previous_frame := frame
		var previous_progress := frame_progress
		var previous_count := sprite_frames.get_frame_count(animation) if sprite_frames.has_animation(animation) else 0
		play(next)
		# Both locomotion clips use corresponding contact/down/pass/flight keys.
		# Shift changes cadence without resetting the feet to contact A;
		# the separate VFX node supplies sprint afterimages.
		if preserve_stride and previous_count == sprite_frames.get_frame_count(next):
			frame = mini(previous_frame, previous_count - 1)
			frame_progress = previous_progress

func animation_duration(clip: StringName) -> float:
	if sprite_frames == null or not sprite_frames.has_animation(clip):
		return 0.0
	var rate := sprite_frames.get_animation_speed(clip)
	return _total_weight(clip) / rate if rate > 0.0 else 0.0

func _total_weight(clip: StringName) -> float:
	if sprite_frames == null or not sprite_frames.has_animation(clip):
		return 0.0
	var total := 0.0
	for index in range(sprite_frames.get_frame_count(clip)):
		total += maxf(0.001, sprite_frames.get_frame_duration(clip, index))
	return total

func frame_start_fraction(clip: StringName, index: int) -> float:
	var total := _total_weight(clip)
	if total <= 0.0:
		return 0.0
	var prefix := 0.0
	for prior in range(clampi(index, 0, sprite_frames.get_frame_count(clip))):
		prefix += maxf(0.001, sprite_frames.get_frame_duration(clip, prior))
	return prefix / total

func frame_end_fraction(clip: StringName, index: int) -> float:
	return frame_start_fraction(clip, index + 1)

func frame_middle_fraction(clip: StringName, index: int) -> float:
	return (frame_start_fraction(clip, index) + frame_end_fraction(clip, index)) * 0.5

func frame_at_progress(clip: StringName, value: float) -> int:
	var total := _total_weight(clip)
	if total <= 0.0:
		return 0
	var cursor := clampf(value, 0.0, 1.0) * total
	var count := sprite_frames.get_frame_count(clip)
	for index in range(count):
		var weight := maxf(0.001, sprite_frames.get_frame_duration(clip, index))
		if cursor < weight or index == count - 1:
			return index
		cursor -= weight
	return maxi(0, count - 1)

func begin_attack(index: int, clip: StringName) -> void:
	landing_left = 0.0
	attacking = true
	attack_stage = index
	attack_animation = clip
	attack_progress = 0.0
	speed_scale = 1.0
	if sprite_frames != null and sprite_frames.has_animation(clip):
		animation = clip
		pause()
		frame = 0

func set_attack_progress(value: float) -> void:
	attack_progress = value
	if not attacking or sprite_frames == null or not sprite_frames.has_animation(attack_animation):
		return
	var index := frame_at_progress(attack_animation, value)
	frame = index
	var start := frame_start_fraction(attack_animation, index)
	var finish := frame_end_fraction(attack_animation, index)
	frame_progress = clampf((value - start) / maxf(0.001, finish - start), 0.0, 1.0)

func end_attack() -> void:
	attacking = false
	attack_stage = -1
	attack_progress = -1.0
	attack_animation = &""
	_select_locomotion()

func land(speed: float) -> void:
	var vfx := get_node_or_null("../GravityVFX")
	if vfx != null and not (attacking and attack_stage == 5):
		vfx.land(speed)
	# Compression is a real drawing and is immediately canceled by movement,
	# jump, dash or attack. It never delays input or modifies the body collider.
	if not attacking and absf(motion_velocity.x) < 35.0 and sprite_frames.has_animation(&"landing"):
		landing_left = animation_duration(&"landing")
		animation = &"landing"
		play(&"landing")

func attack_release(index: int, point: Vector2, direction: float) -> void:
	var vfx := get_node_or_null("../GravityVFX")
	if vfx != null:
		vfx.attack_release(index, point, direction)

func smash_land(point: Vector2) -> void:
	var vfx := get_node_or_null("../GravityVFX")
	if vfx != null:
		vfx.smash_land(point)

func impact(point: Vector2, heavy: bool) -> void:
	var vfx := get_node_or_null("../GravityVFX")
	if vfx != null:
		vfx.impact(point, heavy)

func afterimage(opacity := 0.24, lifetime := 0.12) -> void:
	if sprite_frames == null or sprite_frames.get_frame_count(animation) == 0:
		return
	var ghost := Sprite2D.new()
	ghost.texture = sprite_frames.get_frame_texture(animation, frame)
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.flip_h = flip_h
	ghost.offset = offset
	get_tree().current_scene.add_child(ghost)
	ghost.global_transform = global_transform
	ghost.modulate = Color(0.66, 0.28, 1.0, clampf(opacity, 0.0, 0.3))
	ghost.z_index = 15
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, clampf(lifetime, 0.05, 0.2))
	tween.tween_callback(ghost.queue_free)

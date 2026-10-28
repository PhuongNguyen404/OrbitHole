extends Node2D
## Secondary effects only. Never draws or assembles the character's body.
var impacts: Array[Dictionary] = []
var attack_stage := -1
var attack_progress := -1.0
var direction := 1.0

func _process(delta: float) -> void:
	for effect in impacts:
		effect.life -= delta
	impacts = impacts.filter(func(effect: Dictionary) -> bool: return effect.life > 0.0)
	var combat := get_node_or_null("../Combat")
	if combat != null and combat.attacking:
		attack_stage = combat.stage
		attack_progress = combat.progress
		direction = combat.direction
	else:
		attack_stage = -1
		attack_progress = -1.0
	queue_redraw()

func impact(point: Vector2, heavy: bool) -> void:
	impacts.append({"point": to_local(point), "life": 0.16, "heavy": heavy, "ground": false})

func land(speed: float) -> void:
	if speed > 240.0:
		impacts.append({"point": Vector2.ZERO, "life": 0.12, "heavy": false, "ground": true})

func _draw() -> void:
	# Small gravity arcs reinforce complete drawn attack frames. They never
	# stand in for a head, limb, torso, or any other part of the character.
	if attack_stage in [1, 2, 3, 4, 5] and attack_progress > 0.25 and attack_progress < 0.62:
		var fade := 1.0 - smoothstep(0.43, 0.62, attack_progress)
		var center := Vector2(28.0 * direction, -45.0)
		if attack_stage == 5:
			center = Vector2(0.0, -9.0)
		draw_arc(center, 12.0, -1.2, 0.8, 12, Color(0.68, 0.32, 1.0, 0.35 * fade), 1.0)
	for effect in impacts:
		var duration := 0.12 if effect.ground else 0.16
		var fade: float = effect.life / duration
		if effect.ground:
			draw_arc(effect.point, (1.0 - fade) * 10.0 + 1.0, PI, TAU, 12, Color(0.6, 0.39, 0.8, fade * 0.35), 1.0)
		else:
			var radius := (1.0 - fade) * (17.0 if effect.heavy else 8.0) + 2.0
			draw_arc(effect.point, radius, 0.0, TAU, 20, Color(0.85, 0.46, 1.0, fade * 0.8), 1.0)
			draw_line(effect.point - Vector2(2, 0), effect.point + Vector2(2, 0), Color(1, 0.8, 1, fade), 1.5)
			if effect.heavy:
				for i in range(4):
					var offset := Vector2(cos(i * 2.4), sin(i * 2.4)) * (1.0 - fade) * 15.0
					draw_rect(Rect2(effect.point + offset, Vector2.ONE), Color(0.5, 0.35, 0.65, fade))

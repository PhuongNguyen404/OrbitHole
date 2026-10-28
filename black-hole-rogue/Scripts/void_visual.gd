extends Node2D
## Articulated cutout animation, using only the original generated master PNG.
## Texture polygons retain the same palette and anatomy in every pose.
const MASTER := preload("res://Assets/VoidConstruct/void_construct.png")
const PIXEL_SCALE := 80.0 / 1536.0
const FOOT_ORIGIN := Vector2(512, 1435)
const RATES := {"IDLE": 8.0, "RUN": 12.0, "SPRINT": 14.0, "JUMP": 8.0, "FALL": 8.0, "DASH": 14.0}

var state := "IDLE":
	set(value):
		if state != value:
			state = value
			animation_time = 0.0
var facing := 1.0
var animation_time := 0.0
var orbit_time := 0.0
var rig: Node2D
var bones: Dictionary = {}
var anchors: Dictionary = {}
var source_pivots: Dictionary = {}
var fragments: Array[Polygon2D] = []
var fragment_homes: Array[Vector2] = []
var sampled_rotations: Dictionary = {}
var head_ring: Line2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rig = Node2D.new()
	rig.name = "ArticulatedMaster"
	add_child(rig)
	_build_rig()
	_build_fragments()

func _piece(id: String, parent_id: String, pivot: Vector2, outline: PackedVector2Array, depth: int = 0) -> void:
	var joint := Node2D.new()
	joint.name = id
	var parent_joint: Node2D = rig if parent_id.is_empty() else bones[parent_id]
	var parent_pivot: Vector2 = FOOT_ORIGIN if parent_id.is_empty() else source_pivots[parent_id]
	joint.position = (pivot - parent_pivot) * PIXEL_SCALE
	parent_joint.add_child(joint)
	bones[id] = joint
	anchors[id] = joint.position
	source_pivots[id] = pivot
	var art := Polygon2D.new()
	art.texture = MASTER
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.antialiased = false
	art.z_index = depth
	var local_outline := PackedVector2Array()
	for point in outline:
		local_outline.append((point - pivot) * PIXEL_SCALE)
	art.polygon = local_outline
	art.uv = outline
	joint.add_child(art)

func _build_rig() -> void:
	# Coordinates trace the stone fragments in the 1024 x 1536 master.
	# Open joints are intentional: gravity holds the disconnected stones together.
	_piece("hips", "", Vector2(535,765), PackedVector2Array([
		Vector2(465,660),Vector2(555,645),Vector2(650,715),Vector2(635,800),Vector2(560,845),Vector2(475,790),Vector2(435,725)]))
	_piece("chest", "hips", Vector2(535,530), PackedVector2Array([
		Vector2(445,300),Vector2(560,285),Vector2(630,325),Vector2(653,370),Vector2(660,460),Vector2(614,525),Vector2(662,565),Vector2(650,641),Vector2(596,707),Vector2(526,670),Vector2(466,609),Vector2(450,540),Vector2(410,490),Vector2(439,425)]))
	_piece("head", "chest", Vector2(580,200), PackedVector2Array([
		Vector2(325,50),Vector2(790,50),Vector2(850,235),Vector2(810,325),Vector2(660,330),Vector2(515,280),Vector2(405,205)]), 2)
	_piece("arm_back", "chest", Vector2(650,405), PackedVector2Array([
		Vector2(630,345),Vector2(680,360),Vector2(712,428),Vector2(702,515),Vector2(660,530),Vector2(635,470)]), -2)
	_piece("forearm_back", "arm_back", Vector2(690,560), PackedVector2Array([
		Vector2(655,515),Vector2(714,510),Vector2(760,600),Vector2(774,680),Vector2(746,715),Vector2(692,668),Vector2(655,605)]), -2)
	_piece("hand_back", "forearm_back", Vector2(745,730), PackedVector2Array([
		Vector2(710,680),Vector2(771,682),Vector2(790,765),Vector2(821,847),Vector2(816,930),Vector2(774,958),Vector2(729,910),Vector2(712,815),Vector2(685,769)]), -2)
	_piece("arm_front", "chest", Vector2(425,365), PackedVector2Array([
		Vector2(411,307),Vector2(486,339),Vector2(467,404),Vector2(418,467),Vector2(350,464),Vector2(321,427),Vector2(340,355)]), 2)
	_piece("forearm_front", "arm_front", Vector2(332,505), PackedVector2Array([
		Vector2(300,448),Vector2(362,461),Vector2(385,512),Vector2(354,565),Vector2(333,636),Vector2(302,696),Vector2(263,697),Vector2(241,649),Vector2(270,558)]), 2)
	_piece("hand_front", "forearm_front", Vector2(287,727), PackedVector2Array([
		Vector2(258,673),Vector2(313,682),Vector2(349,754),Vector2(369,827),Vector2(376,895),Vector2(347,955),Vector2(300,951),Vector2(251,911),Vector2(245,830),Vector2(225,790)]), 2)
	_piece("thigh_back", "hips", Vector2(595,800), PackedVector2Array([
		Vector2(577,757),Vector2(637,781),Vector2(683,837),Vector2(681,926),Vector2(652,997),Vector2(601,1012),Vector2(565,951),Vector2(568,861)]), -1)
	_piece("shin_back", "thigh_back", Vector2(641,1020), PackedVector2Array([
		Vector2(617,976),Vector2(670,967),Vector2(715,1022),Vector2(695,1105),Vector2(710,1198),Vector2(680,1275),Vector2(626,1262),Vector2(610,1193),Vector2(620,1104),Vector2(590,1052)]), -1)
	_piece("foot_back", "shin_back", Vector2(665,1293), PackedVector2Array([
		Vector2(632,1245),Vector2(687,1251),Vector2(728,1314),Vector2(729,1362),Vector2(808,1384),Vector2(842,1434),Vector2(682,1442),Vector2(601,1417),Vector2(596,1374)]), -1)
	_piece("thigh_front", "hips", Vector2(482,800), PackedVector2Array([
		Vector2(472,744),Vector2(543,782),Vector2(565,854),Vector2(536,922),Vector2(489,975),Vector2(433,982),Vector2(403,922),Vector2(420,821)]), 1)
	_piece("shin_front", "thigh_front", Vector2(433,1020), PackedVector2Array([
		Vector2(406,950),Vector2(463,960),Vector2(497,1003),Vector2(471,1076),Vector2(424,1137),Vector2(410,1214),Vector2(379,1289),Vector2(326,1271),Vector2(317,1201),Vector2(338,1129),Vector2(358,1055)]), 1)
	_piece("foot_front", "shin_front", Vector2(366,1300), PackedVector2Array([
		Vector2(332,1254),Vector2(391,1264),Vector2(414,1304),Vector2(399,1354),Vector2(446,1384),Vector2(480,1438),Vector2(328,1445),Vector2(292,1417),Vector2(301,1360)]), 1)
	# A moving highlight orbits the original black-hole ring without rotating the face.
	head_ring = Line2D.new()
	head_ring.width = 1.0
	head_ring.default_color = Color("f2b6ff")
	head_ring.z_index = 3
	bones["head"].add_child(head_ring)

func _build_fragments() -> void:
	for i in range(7):
		var crystal := Polygon2D.new()
		crystal.polygon = PackedVector2Array([Vector2(0,-2),Vector2(1,0),Vector2(0,2),Vector2(-1,0)])
		crystal.color = Color("bf8ade") if i % 2 == 0 else Color("635078")
		fragment_homes.append(Vector2(-19 if i % 2 == 0 else 18, -65 + i * 8))
		fragments.append(crystal)
		rig.add_child(crystal)

func _process(delta: float) -> void:
	animation_time += delta
	orbit_time += delta
	var sampled: float = floorf(animation_time * RATES[state]) / RATES[state]
	var orbit_sample := floorf(orbit_time * 8.0) / 8.0
	var phase := sampled * TAU * (2.0 if state == "SPRINT" else 1.5)
	var gait := sin(phase)
	var running := state == "RUN" or state == "SPRINT"
	var pose := {"hips": 0.0,"chest": 0.0,"head": 0.0,
		"arm_front": 0.0,"forearm_front": 0.0,"hand_front": 0.0,
		"arm_back": 0.0,"forearm_back": 0.0,"hand_back": 0.0,
		"thigh_front": 0.0,"shin_front": 0.0,"foot_front": 0.0,
		"thigh_back": 0.0,"shin_back": 0.0,"foot_back": 0.0}
	var hip_offset := Vector2.ZERO
	var separation := 0.0
	if running:
		var stride := 0.62 if state == "RUN" else 0.9
		pose["hips"] = 0.06 if state == "RUN" else 0.16
		pose["chest"] = 0.05 if state == "RUN" else 0.12
		pose["head"] = -0.08
		pose["thigh_front"] = gait * stride
		pose["thigh_back"] = -gait * stride
		pose["shin_front"] = -maxf(0.0,gait) * 0.9
		pose["shin_back"] = -maxf(0.0,-gait) * 0.9
		pose["foot_front"] = -gait * 0.25
		pose["foot_back"] = gait * 0.25
		pose["arm_front"] = -gait * stride * 0.85
		pose["arm_back"] = gait * stride * 0.85
		pose["forearm_front"] = -0.3 - maxf(0.0,-gait) * 0.55
		pose["forearm_back"] = -0.3 - maxf(0.0,gait) * 0.55
		hip_offset.y = -absf(cos(phase)) * 1.5
	elif state == "JUMP":
		pose.merge({"hips": -0.08,"chest": -0.08,"head": 0.12,
			"thigh_front": -0.55,"shin_front": -0.45,"foot_front": 0.3,
			"thigh_back": 0.45,"shin_back": -1.0,"foot_back": 0.3,
			"arm_front": -0.6,"forearm_front": -0.7,
			"arm_back": 0.5,"forearm_back": -0.5},true)
		separation = 0.6
	elif state == "FALL":
		pose.merge({"hips": 0.05,"chest": -0.04,"head": 0.08,
			"thigh_front": -0.2,"shin_front": -0.25,"foot_front": 0.25,
			"thigh_back": 0.3,"shin_back": -0.4,
			"arm_front": 0.7,"forearm_front": -0.8,
			"arm_back": -0.65,"forearm_back": -0.5},true)
		separation = 0.9
	elif state == "DASH":
		pose.merge({"hips": -0.15,"chest": 0.65,"head": -0.3,
			"thigh_front": -0.45,"shin_front": -0.25,
			"thigh_back": 0.6,"shin_back": -0.7,
			"arm_front": 1.0,"forearm_front": -0.3,
			"arm_back": 0.9,"forearm_back": -0.4},true)
		separation = 1.0
	else:
		# Breathing and floating affect separate stones, never shake the root.
		pose["chest"] = sin(orbit_sample * 1.8) * 0.018
		pose["arm_front"] = sin(orbit_sample * 1.5) * 0.025
		pose["arm_back"] = -sin(orbit_sample * 1.5) * 0.025
		pose["head"] = -pose["chest"]
	sampled_rotations = pose
	# Blend state changes while the gait itself is sampled at its declared rate.
	var blend := 1.0 - exp(-delta * 24.0)
	for id in bones:
		var joint: Node2D = bones[id]
		joint.rotation = lerp_angle(joint.rotation, pose[id], blend)
		var target: Vector2 = anchors[id]
		if id == "hips":
			target += hip_offset
		elif id == "chest" or id == "head":
			target.y -= separation + sin(orbit_sample * 1.8) * (0.4 if id == "chest" else 0.8)
		elif id.begins_with("arm"):
			target.x -= 0.8 if state == "SPRINT" else 0.0
		joint.position = joint.position.lerp(target, blend)
	rig.scale.x = facing
	_plant_feet(blend)
	for i in range(fragments.size()):
		var phase_offset := orbit_sample * 1.6 + i * 1.4
		var drift := Vector2(sin(phase_offset) * 1.5,cos(phase_offset) * 2.0)
		if state == "FALL":
			drift.y -= 3.0
		elif state == "DASH" or state == "SPRINT":
			drift.x -= 5.0 if state == "DASH" else 2.0
		fragments[i].position = fragment_homes[i] + drift
		fragments[i].rotation = phase_offset * 0.3
	var ring_points := PackedVector2Array()
	for i in range(5):
		var angle := orbit_sample * 1.1 + i * 0.13
		ring_points.append(Vector2(cos(angle) * 10.0, sin(angle) * 3.5).rotated(0.43))
	head_ring.points = ring_points

func _plant_feet(blend: float) -> void:
	# Keep the lower foot at the body's baseline during grounded locomotion.
	# The collision shape lives on Player, outside this visual hierarchy.
	if state != "IDLE" and state != "RUN" and state != "SPRINT":
		rig.position.y = lerpf(rig.position.y, 0.0, blend)
		return
	var lowest := -INF
	for id in ["foot_front","foot_back"]:
		var foot: Node2D = bones[id]
		var art: Polygon2D = foot.get_child(0)
		for vertex in art.polygon:
			var relative := rig.to_local(art.to_global(vertex))
			lowest = maxf(lowest,relative.y)
	rig.position.y = -lowest

func afterimage() -> void:
	if rig == null:
		return
	# Snapshot all articulated parts, including the actual limb pose and facing.
	var ghost := rig.duplicate() as Node2D
	get_tree().current_scene.add_child(ghost)
	ghost.global_transform = rig.global_transform
	ghost.modulate = Color(0.65,0.25,1.0,0.40)
	ghost.z_index = -5
	var tween := ghost.create_tween()
	tween.tween_property(ghost,"modulate:a",0.0,0.20)
	tween.tween_callback(ghost.queue_free)

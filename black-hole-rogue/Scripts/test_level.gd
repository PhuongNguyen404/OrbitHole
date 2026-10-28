extends Node2D
## All platform edges and collision are on a 16-pixel grid.
const PLATFORMS := [Rect2i(0,448,896,128), Rect2i(1040,448,1264,128), Rect2i(336,352,144,16), Rect2i(576,272,128,16), Rect2i(1200,336,160,16)]

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("100c20"))
	_build_tiles()
	_build_hud()
	var core = preload("res://Scripts/practice_core.gd").new()
	core.position = Vector2(760,398)
	add_child(core)
	queue_redraw()

func _build_tiles() -> void:
	# Original simple tile graphics; no old character or terrain assets.
	var image := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color("292339"))
	for x in range(32):
		for y in range(16):
			var color := Color("292339") if x < 16 else Color("221d31")
			if y == 0 and x < 16:
				color = Color("b889db")
			elif y < 3 and x < 16:
				color = Color("645078")
			elif (x + y * 3) % 19 == 0:
				color = Color("393047")
			image.set_pixel(x,y,color)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(image)
	atlas.texture_region_size = Vector2i(16,16)
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(16,16)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0,1)
	tiles.add_source(atlas,0)
	for x in range(2):
		atlas.create_tile(Vector2i(x,0))
		var data := atlas.get_tile_data(Vector2i(x,0),0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-8,-8),Vector2(8,-8),Vector2(8,8),Vector2(-8,8)]))
	var layer := TileMapLayer.new()
	layer.name = "Platforms"
	layer.tile_set = tiles
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(layer)
	for platform in PLATFORMS:
		for x in range(platform.position.x / 16, platform.end.x / 16):
			for y in range(platform.position.y / 16, platform.end.y / 16):
				layer.set_cell(Vector2i(x,y),0,Vector2i(0 if y == platform.position.y / 16 else 1,0))

func _draw() -> void:
	# Quiet layered silhouettes, sparse stars, and readable platform markers.
	for i in range(80):
		var x := float((i * 137 + 39) % 2304)
		var y := float((i * 79 + 23) % 460 - 160)
		draw_rect(Rect2(x,y,1,1),Color("51415f"))
	for i in range(18):
		var x := float(i * 144)
		draw_rect(Rect2(x, 320 + (i % 3) * 24, 80, 320),Color("191329"))
	draw_line(Vector2(880,448),Vector2(880,400),Color("ce8aff"),2)
	draw_line(Vector2(1056,448),Vector2(1056,400),Color("ce8aff"),2)

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := ColorRect.new()
	panel.color = Color(0.045,0.03,0.08,0.91)
	panel.position = Vector2(20,18)
	panel.size = Vector2(700,118)
	canvas.add_child(panel)
	var label := Label.new()
	label.position = Vector2(36,26)
	label.text = "O R B I T B R E A K   /   VOID CONSTRUCT\nA / D  MOVE     SPACE  JUMP     SHIFT  SPRINT     J  DASH\nK / LEFT CLICK  PUNCH → PUNCH → KICK   •   tap to chain\nHold SPACE for higher jumps  /  falls reset automatically"
	label.add_theme_font_size_override("font_size",16)
	label.add_theme_color_override("font_color",Color("e5d4ff"))
	canvas.add_child(label)

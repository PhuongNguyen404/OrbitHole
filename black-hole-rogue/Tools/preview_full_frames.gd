extends SceneTree
## Developer contact-sheet capture; draws complete imported textures, never limbs.
## DISPLAY=:99 godot --path black-hole-rogue --script res://Tools/preview_full_frames.gd -- run /tmp/run.png
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var args := OS.get_cmdline_user_args()
	var name: StringName = args[0] if args.size()>0 else "run"
	var output := args[1] if args.size()>1 else "/tmp/void_frames_preview.png"
	var frames := load("res://Animations/void_frames.tres") as SpriteFrames
	if not frames.has_animation(name):
		push_error("No animation: "+str(name))
		quit(1)
		return
	root.size = Vector2i(1120,620)
	root.content_scale_size = Vector2i(1120,620)
	RenderingServer.set_default_clear_color(Color("100c20"))
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	for i in range(frames.get_frame_count(name)):
		var column := i%4
		var row := i/4
		var sprite := Sprite2D.new()
		sprite.texture = frames.get_frame_texture(name,i)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(140+280*column,174+310*row)
		sprite.scale = Vector2.ONE*2.2
		scene.add_child(sprite)
		var label := Label.new()
		label.position = Vector2(20+280*column,18+310*row)
		label.text = str(name)+" / "+str(i+1)
		scene.add_child(label)
		var guide := Line2D.new()
		guide.points = PackedVector2Array([Vector2(20+column*280,280+row*310),Vector2(260+column*280,280+row*310)])
		guide.width = 1
		guide.default_color = Color("594567")
		scene.add_child(guide)
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output)
	print("Saved complete-frame preview: ",output)
	quit(0 if result==OK else 1)

extends SceneTree
## Imports five complete generated enemy drawings, never extracts limbs.
func _initialize() -> void:
	var source := Image.load_from_file("res://Assets/Enemies/CrystalSentinel/source.png")
	if source==null:
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)
	var regions := [Rect2i(51,45,480,460),Rect2i(544,48,501,462),Rect2i(1052,45,464,465),Rect2i(54,541,550,430),Rect2i(555,686,551,291)]
	var body_bounds := [Rect2i(63,57,456,436),Rect2i(556,60,477,438),Rect2i(1064,57,440,441),Rect2i(66,553,526,406),Rect2i(567,698,527,267)]
	var scale := 50.0/441.0
	for i in range(regions.size()):
		var region: Rect2i = regions[i]
		var body: Rect2i = body_bounds[i]
		var frame := source.get_region(region)
		frame.resize(roundi(region.size.x*scale),roundi(region.size.y*scale),Image.INTERPOLATE_NEAREST)
		var image := Image.create(96,96,false,Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		var origin := Vector2i(roundi(48-(body.get_center().x-region.position.x)*scale),roundi(88-(body.end.y-region.position.y)*scale))
		image.blit_rect(frame,Rect2i(Vector2i.ZERO,frame.get_size()),origin)
		if image.save_png("res://Assets/Enemies/CrystalSentinel/enemy_%02d.png"%i)!=OK:
			quit(1)
			return
	var text := "[gd_resource type=\"SpriteFrames\" load_steps=6 format=3]\n"
	for i in range(5):
		text += "[ext_resource type=\"Texture2D\" path=\"res://Assets/Enemies/CrystalSentinel/enemy_%02d.png\" id=\"%d\"]\n"%[i,i+1]
	text += "[resource]\nanimations = [\n"
	var definitions := [["idle",[1],true,4],["walk",[2,3],true,6],["swipe",[3],false,8],["hurt",[4],false,8],["dead",[5],false,4]]
	for definition in definitions:
		text += "{\"name\": &\"%s\", \"loop\": %s, \"speed\": %s, \"frames\": ["%[definition[0],"true" if definition[2] else "false",definition[3]]
		for index in range(definition[1].size()):
			text += "{\"duration\":1.0,\"texture\":ExtResource(\"%d\")}"%definition[1][index]
			if index<definition[1].size()-1:text+=","
		text += "]},\n"
	text += "]\n"
	FileAccess.open("res://Assets/Enemies/CrystalSentinel/frames.tres",FileAccess.WRITE).store_string(text)
	print("Built five complete crystal enemy drawings")
	quit()

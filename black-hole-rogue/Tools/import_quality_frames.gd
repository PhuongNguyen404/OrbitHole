extends SceneTree
## Imports authored WHOLE-character key poses/inbetweens; never rigs or synthesizes limbs.
## Unlisted animations, especially approved idle, remain byte-for-byte referenced.
const OUT := "res://Assets/VoidConstruct/Frames"
const SOURCES := "res://Assets/VoidConstruct/QualitySources"
var failed := false
func _initialize() -> void:
	call_deferred("build")
func error(message: String) -> void:
	failed=true
	push_error(message)
func build() -> void:
	var args:=OS.get_cmdline_user_args()
	var manifest_path:=args[0] if not args.is_empty() else SOURCES+"/manifest.json"
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		error("Invalid quality manifest")
		quit(1)
		return
	var manifest: Dictionary=parsed
	var frames:=load("res://Animations/void_frames.tres") as SpriteFrames
	var report: Dictionary={}
	var retained: Dictionary={"animations":{}}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SOURCES))
	for name in manifest.animations:
		var entry: Dictionary=manifest.animations[name]
		if entry.has("existing_paths"):
			if not frames.has_animation(name):frames.add_animation(name)
			frames.clear(name)
			frames.set_animation_speed(name,entry.fps)
			frames.set_animation_loop(name,entry.get("loop",false))
			for i in range(entry.existing_paths.size()):
				var texture:=load(str(entry.existing_paths[i])) as Texture2D
				frames.add_frame(name,texture,float(entry.durations[i]))
			retained.animations[name]=entry.duplicate(true)
			report[name]={"preserved_textures":entry.existing_paths,"durations":entry.durations,"fps":entry.fps}
			continue
		var images: Array[Image]=[]
		var specs: Array[Dictionary]=[]
		var boxes: Array[Rect2i]=[]
		for raw_spec in entry.frames:
			var spec: Dictionary=raw_spec.duplicate(true)
			if spec.has("reuse"):
				images.append(null)
				boxes.append(Rect2i())
				specs.append(spec)
				continue
			var source:=str(spec.file)
			var target:=SOURCES+"/"+source.get_file()
			if ProjectSettings.globalize_path(source)!=ProjectSettings.globalize_path(target):
				if DirAccess.copy_absolute(ProjectSettings.globalize_path(source),ProjectSettings.globalize_path(target))!=OK:
					error("Cannot retain source "+source)
					break
			var image:=Image.load_from_file(ProjectSettings.globalize_path(target))
			if image==null:
				error("Cannot load "+target)
				break
			image.convert(Image.FORMAT_RGBA8)
			if spec.has("region"):
				var r: Array=spec.region
				image=image.get_region(Rect2i(r[0],r[1],r[2],r[3]))
			var box:=bounds(image)
			if box.size.y==0:
				error("Empty pose in "+str(name))
				break
			images.append(image)
			boxes.append(box)
			spec.file=target
			specs.append(spec)
		if failed:
			break
		var max_height:=0.0
		for box in boxes:
			max_height=maxf(max_height,box.size.y)
		var default_scale:=80.0/max_height
		var weights: Array=entry.get("durations",[])
		if weights.size()!=images.size():
			error("One authored duration is required per pose: "+str(name))
			break
		var paths: Array[String]=[]
		for i in range(images.size()):
			if specs[i].has("reuse"):
				paths.append(str(specs[i].reuse))
				continue
			var image:=images[i]
			var box:=boxes[i]
			var spec:=specs[i]
			var scale_factor: float=float(spec.get("scale",entry.get("scale",default_scale)))
			var crop:=box.grow(maxi(3,roundi(box.size.y*.025))).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
			var whole:=image.get_region(crop)
			whole.resize(maxi(1,roundi(whole.get_width()*scale_factor)),maxi(1,roundi(whole.get_height()*scale_factor)),Image.INTERPOLATE_NEAREST)
			var anchor: float=float(spec.get("anchor_x",body_anchor(image,box)))
			var baseline: float=float(spec.get("baseline_y",box.end.y))
			var offset:=Vector2i(roundi(80-(anchor-crop.position.x)*scale_factor),roundi(104-(baseline-crop.position.y)*scale_factor))
			if offset.x<0 or offset.y<0 or offset.x+whole.get_width()>160 or offset.y+whole.get_height()>112:
				error("Whole pose exceeds shared canvas: %s #%s"%[name,i])
				break
			var canvas:=Image.create(160,112,false,Image.FORMAT_RGBA8)
			canvas.fill(Color.TRANSPARENT)
			canvas.blit_rect(whole,Rect2i(Vector2i.ZERO,whole.get_size()),offset)
			var output:=OUT+"/%s_%02d.png"%[name,i]
			if canvas.save_png(output)!=OK:
				error("Cannot write pose "+output)
				break
			paths.append(output)
		if failed:
			break
		if not frames.has_animation(name):frames.add_animation(name)
		frames.clear(name)
		frames.set_animation_speed(name,entry.fps)
		frames.set_animation_loop(name,entry.get("loop",false))
		for i in range(paths.size()):
			# Loading raw images avoids stale imported texture caches during a rebuild.
			var texture:=ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(paths[i])))
			texture.take_over_path(paths[i])
			frames.add_frame(name,texture,float(weights[i]))
		retained.animations[name]=entry.duplicate(true)
		retained.animations[name].frames=specs
		report[name]={"frames":paths,"durations":weights,"fps":entry.fps,"source_height":max_height}
		print("Updated ",name," with ",paths.size()," complete authored poses")
	if not failed:
		# The PNGs are standalone external resources, not body-part atlases.
		var result:=save_external(frames,"res://Animations/void_frames.tres")
		if result!=OK:error("Cannot save SpriteFrames")
		var retained_file:=FileAccess.open(SOURCES+"/manifest.json",FileAccess.WRITE)
		# Keep full float precision: rounding a retained uniform scale can move a
		# half-pixel crop/baseline across roundi() on the next portable rebuild.
		retained_file.store_string(JSON.stringify(retained,"\t",true,true)+"\n")
		var report_file:=FileAccess.open(SOURCES+"/import_report.json",FileAccess.WRITE)
		report_file.store_string(JSON.stringify(report,"\t",true,true)+"\n")
	quit(1 if failed else 0)
func bounds(image: Image) -> Rect2i:
	var data:=image.get_data();var width:=image.get_width();var height:=image.get_height()
	var left:=width;var right:=-1;var top:=height;var bottom:=-1
	for y in range(height):
		for x in range(width):
			if data[(y*width+x)*4+3]>=170:
				left=mini(left,x);right=maxi(right,x);top=mini(top,y);bottom=maxi(bottom,y)
	return Rect2i(left,top,right-left+1,bottom-top+1) if right>=left else Rect2i()
func body_anchor(image: Image,box: Rect2i) -> float:
	var data:=image.get_data();var width:=image.get_width();var samples: Array[float]=[]
	for part in [.48,.52,.56]:
		var y:=clampi(roundi(box.position.y+box.size.y*part),0,image.get_height()-1)
		var start:=-1;var best:=0;var center: float=box.get_center().x
		for x in range(box.position.x,box.end.x+1):
			var solid:=x<box.end.x and data[(y*width+x)*4+3]>=210
			if solid and start<0:start=x
			elif not solid and start>=0:
				if x-start>best:best=x-start;center=(x+start)*.5
				start=-1
		samples.append(center)
	samples.sort()
	return samples[1]

func save_external(frames: SpriteFrames,path: String) -> Error:
	var names:=frames.get_animation_names()
	names.sort()
	var paths: Array[String]=[]
	for name in names:
		for i in range(frames.get_frame_count(name)):
			var texture:=frames.get_frame_texture(name,i)
			if texture==null or texture.resource_path.is_empty():
				error("Frame has no external PNG: "+str(name))
				return ERR_INVALID_DATA
			if not paths.has(texture.resource_path):paths.append(texture.resource_path)
	var uid:=ResourceLoader.get_resource_uid(path)
	var header:="[gd_resource type=\"SpriteFrames\" load_steps=%d format=3"%(paths.size()+1)
	if uid>0:header+=" uid=\""+ResourceUID.id_to_text(uid)+"\""
	var lines: Array[String]=[header+"]", ""]
	for i in range(paths.size()):
		lines.append("[ext_resource type=\"Texture2D\" path=\"%s\" id=\"frame_%03d\"]"%[paths[i],i])
	lines.append("\n[resource]\nanimations = [")
	for n in range(names.size()):
		var name:=names[n]
		lines.append("{\n\"frames\": [")
		for i in range(frames.get_frame_count(name)):
			var texture:=frames.get_frame_texture(name,i)
			var id:=paths.find(texture.resource_path)
			lines.append("{\"duration\": %s, \"texture\": ExtResource(\"frame_%03d\")}%s"%[str(frames.get_frame_duration(name,i)),id,"," if i<frames.get_frame_count(name)-1 else ""])
		lines.append("],\n\"loop\": %s,\n\"name\": &\"%s\",\n\"speed\": %s\n}%s"%["true" if frames.get_animation_loop(name) else "false",name,str(frames.get_animation_speed(name)),"," if n<names.size()-1 else ""])
	lines.append("]\n")
	var output:=FileAccess.open(path,FileAccess.WRITE)
	if output==null:return FileAccess.get_open_error()
	output.store_string("\n".join(lines))
	return OK

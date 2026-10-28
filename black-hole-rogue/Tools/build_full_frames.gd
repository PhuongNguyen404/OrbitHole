extends SceneTree
## Offline whole-frame import only: no limb extraction, pose synthesis or runtime rig.
## Usage: godot --headless --path black-hole-rogue --script res://Tools/build_full_frames.gd -- /workspace/orbithole-frame-art/manifest.json
const FRAME_SIZE := Vector2i(160,112)
const FOOT_BASELINE := 104
const BODY_HEIGHT := 80.0
const OUTPUT_ROOT := "res://Assets/VoidConstruct/Frames"
const SOURCE_ROOT := "res://Assets/VoidConstruct/FrameSources"
var errors: Array[String] = []
var records: Dictionary = {}
var retained_entries: Dictionary = {}

func _initialize() -> void:
	call_deferred("build")

func fail(message: String) -> void:
	push_error(message)
	errors.append(message)

func build() -> void:
	var args := OS.get_cmdline_user_args()
	var manifest_path := args[0] if not args.is_empty() else "res://Assets/VoidConstruct/FrameSources/manifest.json"
	if args.is_empty() and not FileAccess.file_exists(manifest_path):
		manifest_path = "/workspace/orbithole-frame-art/manifest.json"
	if not FileAccess.file_exists(manifest_path):
		fail("Frame manifest does not exist: "+manifest_path)
		quit(1)
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not raw is Dictionary:
		fail("Frame manifest must be a JSON object")
		quit(1)
		return
	var manifest: Dictionary = raw
	var animations: Dictionary = manifest.get("animations",{})
	if animations.is_empty():
		fail("Frame manifest has no animations")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SOURCE_ROOT))
	if manifest.has("approved_master"):
		_copy_source(str(manifest.approved_master),"approved_master.png")
	for key in animations:
		_import_animation(str(key),animations[key])
	if errors.is_empty():
		_write_sprite_frames(animations)
		var report := {"frame_canvas":[160,112],"foot_baseline":104,"body_height":BODY_HEIGHT,"animations":records}
		var report_file := FileAccess.open("res://Assets/VoidConstruct/Frames/import_report.json",FileAccess.WRITE)
		report_file.store_string(JSON.stringify(report,"\t")+"\n")
		var retained_manifest := {"approved_master":SOURCE_ROOT.path_join("approved_master.png"),"animations":retained_entries}
		var manifest_file := FileAccess.open(SOURCE_ROOT.path_join("manifest.json"),FileAccess.WRITE)
		manifest_file.store_string(JSON.stringify(retained_manifest,"\t")+"\n")
		print("Built ",records.size()," complete-character animations; source art retained. Run editor --import next.")
	quit(0 if errors.is_empty() else 1)

func _copy_source(path: String,destination: String) -> String:
	var target := SOURCE_ROOT.path_join(destination)
	if ProjectSettings.globalize_path(path)==ProjectSettings.globalize_path(target):
		return target
	var result := DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(target))
	if result!=OK:
		fail("Cannot retain source "+path+": "+error_string(result))
	return target

func _open_image(path: String) -> Image:
	var image := Image.new()
	var result := image.load(ProjectSettings.globalize_path(path))
	if result!=OK:
		fail("Cannot read source art "+path+": "+error_string(result))
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image

func _import_animation(name: String,entry: Dictionary) -> void:
	var cells: Array[Image] = []
	var original_sources: Array[String] = []
	if entry.has("files"):
		var paths: Array = entry.files
		for index in range(paths.size()):
			var source := str(paths[index])
			var retained := _copy_source(source,"%s_%02d_source.png"%[name,index])
			original_sources.append(retained)
			var image := _open_image(source)
			if image!=null:
				cells.append(image)
	elif entry.has("file"):
		var source := str(entry.file)
		original_sources.append(_copy_source(source,name+"_source.png"))
		var image := _open_image(source)
		if image==null:
			return
		if entry.has("regions"):
			for values in entry.regions:
				var region := Rect2i(int(values[0]),int(values[1]),int(values[2]),int(values[3]))
				if region.size.x<1 or region.size.y<1 or not Rect2i(Vector2i.ZERO,image.get_size()).encloses(region):
					fail("Explicit source region is outside image for "+name)
					return
				cells.append(image.get_region(region))
		else:
			var columns := int(entry.get("columns",1))
			var rows := int(entry.get("rows",1))
			var count := int(entry.get("count",columns*rows))
			if columns<1 or rows<1 or count<1 or count>columns*rows:
				fail("Invalid source grid for "+name)
				return
			for index in range(count):
				var column := index%columns
				var row := index/columns
				var x0 := roundi(float(column)*image.get_width()/columns)
				var x1 := roundi(float(column+1)*image.get_width()/columns)
				var y0 := roundi(float(row)*image.get_height()/rows)
				var y1 := roundi(float(row+1)*image.get_height()/rows)
				cells.append(image.get_region(Rect2i(x0,y0,x1-x0,y1-y0)))
	else:
		fail("Animation needs file or files: "+name)
		return
	if cells.is_empty():
		fail("No source frames: "+name)
		return
	if entry.has("count") and cells.size()!=int(entry.count):
		fail("Unexpected frame count for "+name)
		return
	var bounds: Array[Rect2i] = []
	var reference_height := 0.0
	for image in cells:
		var box := _alpha_bounds(image,int(entry.get("alpha_threshold",96)))
		if box.size.x==0 or box.size.y==0:
			fail("Empty complete-character frame in "+name)
			return
		if (box.position.x<=0 or box.position.y<=0 or box.end.x>=image.get_width() or box.end.y>=image.get_height()) and not bool(entry.get("allow_source_edge",false)):
			fail("Visible source artwork touches its frame boundary in "+name+"; inspect source for clipping before import")
			return
		bounds.append(box)
		reference_height = maxf(reference_height,box.size.y)
	# One uniform scale for the entire animation; never stretch or re-proportion a pose.
	reference_height = float(entry.get("reference_height",entry.get("source_height",reference_height)))
	var scale_factor := float(entry.get("scale",BODY_HEIGHT/reference_height))
	var maximum_width := 0.0
	for index in range(cells.size()):
		maximum_width = maxf(maximum_width,bounds[index].size.x)
	if maximum_width*scale_factor>FRAME_SIZE.x-6:
		fail("Complete strike silhouette exceeds the shared canvas for "+name+"; expand common canvas rather than shrinking character scale")
		return
	var outputs: Array[String] = []
	var imported_bounds: Array = []
	var hashes: Array[String] = []
	for index in range(cells.size()):
		var image := cells[index]
		var body := bounds[index]
		# Preserve restrained edge glow without allowing near-transparent sheet bloom
		# to define the character's size. This is a crop, not new artwork.
		var padding := maxi(2,ceili(reference_height*.025))
		var crop := body.grow(padding).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
		var trimmed := image.get_region(crop)
		var resized := Vector2i(maxi(1,roundi(trimmed.get_width()*scale_factor)),maxi(1,roundi(trimmed.get_height()*scale_factor)))
		trimmed.resize(resized.x,resized.y,Image.INTERPOLATE_NEAREST)
		var canvas := Image.create(FRAME_SIZE.x,FRAME_SIZE.y,false,Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		var center: float = float(entry.get("anchor_x",_body_anchor_x(image,body)))
		var baseline: float = float(entry.get("baseline_y",body.end.y))
		var origin := Vector2i(roundi(FRAME_SIZE.x*.5-(center-crop.position.x)*scale_factor),roundi(FOOT_BASELINE-(baseline-crop.position.y)*scale_factor))
		var requested := Rect2i(origin,resized)
		if requested.position.x<0 or requested.end.x>FRAME_SIZE.x or requested.position.y<0 or requested.end.y>FRAME_SIZE.y:
			fail("Normalized frame would clip for %s #%d; revise source scale/anchor rather than cutting the character"%[name,index])
			return
		canvas.blit_rect(trimmed,Rect2i(Vector2i.ZERO,resized),origin)
		var output := OUTPUT_ROOT.path_join("%s_%02d.png"%[name,index])
		var result := canvas.save_png(output)
		if result!=OK:
			fail("Cannot save normalized frame "+output)
			return
		outputs.append(output)
		hashes.append(FileAccess.get_sha256(output))
		imported_bounds.append([body.position.x,body.position.y,body.size.x,body.size.y])
	var retained: Dictionary = entry.duplicate(true)
	if entry.has("files"):
		retained["files"] = original_sources
	else:
		retained["file"] = original_sources[0]
	retained_entries[name] = retained
	records[name]={"count":cells.size(),"fps":float(entry.get("fps",12)),"loop":bool(entry.get("loop",true)),"uniform_scale":scale_factor,"reference_height":reference_height,"source_bounds":imported_bounds,"sources":original_sources,"frames":outputs,"frame_sha256":hashes}
	print(name,": ",cells.size()," full drawings, uniform scale ",scale_factor)

func _alpha_bounds(image: Image,threshold: int) -> Rect2i:
	var bytes := image.get_data()
	var width := image.get_width()
	var height := image.get_height()
	var left := width
	var right := -1
	var top := height
	var bottom := -1
	for y in range(height):
		var row_start := y*width*4
		for x in range(width):
			if bytes[row_start+x*4+3]>=threshold:
				left = mini(left,x)
				right = maxi(right,x)
				top = mini(top,y)
				bottom = maxi(bottom,y)
	if right<left:
		return Rect2i()
	return Rect2i(left,top,right-left+1,bottom-top+1)

func _body_anchor_x(image: Image,bounds: Rect2i) -> float:
	# Anchor the drawing near the waist, so a far-reaching fist does not drag the
	# entire character backward as it would with full-silhouette bbox centering.
	var bytes := image.get_data()
	var width := image.get_width()
	var samples: Array[float] = []
	var expected := bounds.position.x+bounds.size.x*.5
	for fraction in [.49,.52,.55,.58]:
		var row := clampi(roundi(bounds.position.y+bounds.size.y*fraction),0,image.get_height()-1)
		var best_score := -1.0
		var best_center := expected
		var start := -1
		for x in range(bounds.position.x,bounds.end.x+1):
			var opaque := x<bounds.end.x and bytes[(row*width+x)*4+3]>=128
			if opaque and start<0:
				start = x
			elif not opaque and start>=0:
				var center := (start+x-1)*.5
				var score := (x-start)*(1.0-minf(.3,absf(center-expected)/maxf(1,bounds.size.x)*.3))
				if score>best_score:
					best_score = score
					best_center = center
				start = -1
		samples.append(best_center)
	samples.sort()
	return (samples[1]+samples[2])*.5

func _write_sprite_frames(animations: Dictionary) -> void:
	var total := 0
	for name in records:
		total += records[name].count
	var lines: Array[String] = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]'%[total+1],""]
	var ids: Dictionary = {}
	var next := 1
	for name in animations:
		if not records.has(name):
			continue
		ids[name]=[]
		for path in records[name].frames:
			var id := "frame_%03d"%next
			lines.append('[ext_resource type="Texture2D" path="%s" id="%s"]'%[path,id])
			ids[name].append(id)
			next += 1
	lines.append("")
	lines.append("[resource]")
	lines.append("animations = [")
	var names: Array = ids.keys()
	for animation_index in range(names.size()):
		var name: String = names[animation_index]
		lines.append('{"frames": [')
		for index in range(ids[name].size()):
			lines.append('{"duration": 1.0, "texture": ExtResource("%s")}%s'%[ids[name][index],"," if index+1<ids[name].size() else ""])
		lines.append('], "loop": %s, "name": &"%s", "speed": %s}%s'%["true" if records[name].loop else "false",name,str(records[name].fps),"," if animation_index+1<names.size() else ""])
	lines.append("]")
	lines.append("")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Animations"))
	var file := FileAccess.open("res://Animations/void_frames.tres",FileAccess.WRITE)
	file.store_string("\n".join(lines))

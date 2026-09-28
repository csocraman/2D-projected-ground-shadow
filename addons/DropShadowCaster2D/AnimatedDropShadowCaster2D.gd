@tool
@icon("res://addons/DropShadowCaster2D/Icons/AnimatedDropShadowCaster2D.svg")
extends DropShadow2D
class_name AnimatedDropShadowCaster2D

## Draws an animated shadow.

## [SpriteFrames] resource containing the animations of the shadow.
@export var animation : SpriteFrames :
	set(new):
		animation = new
		notify_property_list_changed()

var _old_points := PackedVector2Array()

var _polygons : Array[PackedVector2Array]
var _uvs : Array[PackedVector2Array]

## Current frame number.
var current_frame : int = 0
var _time_acc : float = 0.0

## Current shadow animation.
## Automatically excludes the animations with no frames.
var current_animation : String = "default":
	set(new):
		current_animation = new
		current_frame = 0
		_time_acc = 0

## Updates the property list to refresh the [member current_animation] enum
var update_current_animation_list : Callable :
	# When the script content changes, it can sometimes break the tool button.
	# Making a get() with the callable instead of putting in as the value fixes this issue.
	# here is the issue on github if anyone is interested:
	# https://github.com/godotengine/godot/issues/97834#issuecomment-3834304286
	get():
		return notify_property_list_changed

## The speed scaling ratio.
## For example, if this value is [code]1[/code], then the animation plays at normal speed.
## If it's [code]0.5[/code], then it plays at half speed.
## If it's [code]2[/code], then it plays at double speed.
##[br][br]
## If set to a negative value, the animation is played in reverse.
## If set to [code]0[/code], the animation will not advance.
@export_range(-4.0,4.0,0.001,"or_less","or_greater") var speed_scale := 1.0
##True if an animation is playing.
var playing := false

## Returns the duration of the animation.
## If the speed is null, the duration will be INF
func get_animation_duration(animationname : String) -> float:
	var anim_speed : float = animation.get_animation_speed(animationname)
	if anim_speed == 0.0:
		return INF
	return animation.get_frame_duration(animationname,current_frame)/anim_speed

## Play the animation with the key animationname.
func play(animationname : String):
	current_animation = animationname
	current_frame = 0
	playing = true

## Stops the current animation. The animation position is reset to 0.
func stop():
	playing = false
	current_frame = 0
	_time_acc = 0.0

## Pauses the current animation.
func pause():
	playing = false

## Returns the current animation frame.
func get_current_frame() -> Texture2D:
	var frame : Texture2D = animation.get_frame_texture(current_animation,current_frame)
	return frame

func animation_has_frames(animation_name:StringName=current_animation) -> bool:
	return animation.get_frame_count(animation_name) > 0

func _process(delta: float) -> void:
	if animation != null:
		if playing and animation.has_animation(current_animation):
			_time_acc += delta * abs(speed_scale)
			current_frame += sign(speed_scale)*floor(_time_acc/(get_animation_duration(current_animation)))
			if animation.get_animation_loop(current_animation):
				current_frame = int(fposmod(float(current_frame),float(animation.get_frame_count(current_animation))))
			else:
				current_frame = clampi(current_frame,0,animation.get_frame_count(current_animation)-1)
			_time_acc = fmod(_time_acc,get_animation_duration(current_animation))
	_points.clear()
	if !is_visible_in_tree() or (Engine.is_editor_hint() and !show_in_editor):
		return
	_create_points()
	
	if animation != null:
		if animation.has_animation(current_animation):
			queue_redraw()



func _draw() -> void:
	if (Engine.is_editor_hint() and !show_in_editor):
		return
	if Engine.is_editor_hint() and show_preview_line:
		draw_line(Vector2(-shadow_size.x/2,0),Vector2(shadow_size.x/2,0),Color.CRIMSON,preview_line_tickness)
	if _points.size() < 2:
		return
	
	_old_points = _points.duplicate()
	
	var polygon_shadow := ShadowPolygon.new(global_position)
	polygon_shadow.shadow_max_distance = shadow_max_distance
	
	polygon_shadow.size_x = shadow_size.x
	polygon_shadow.create_polygon(_points,shadow_size.y/2,shadow_offset)

	_polygons.clear()
	_uvs.clear()
	_polygons.append(polygon_shadow.polygon)
	_uvs.append(polygon_shadow.uv)

	_resolve_remaining_points(polygon_shadow,_polygons,_uvs)
	
	if !_check_is_on_screen(_polygons) or not animation_has_frames():
		return

	var current_tex : Texture2D = get_current_frame()
	var atlas_size : Vector2
	var region : Rect2

	if current_tex is AtlasTexture:
		var atlas_tex : AtlasTexture = current_tex
		atlas_size = atlas_tex.atlas.get_size()
		region = atlas_tex.region
	else:
		atlas_size = current_tex.get_size()
		region = Rect2(Vector2.ZERO, atlas_size)

	if region.size.x == 0.0 or region.size.y == 0.0:
		return

	for polygon_index in _polygons.size():
		for p in _uvs[polygon_index].size():
			_uvs[polygon_index][p] -= Vector2.ONE/2
			_uvs[polygon_index][p] = _uvs[polygon_index][p].rotated(shadow_rotation)
			_uvs[polygon_index][p] += Vector2.ONE/2
			_uvs[polygon_index][p] /= atlas_size / region.size
			_uvs[polygon_index][p] += region.position / atlas_size

		if _polygons[polygon_index].size() < 3 or _uvs[polygon_index].size() != _polygons[polygon_index].size():
			continue
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),_triangulate_polygon(_polygons[polygon_index]),_polygons[polygon_index],[],_uvs[polygon_index],[],[],current_tex.get_rid())
		if show_polygon_points:
			for point_index : float in _polygons[polygon_index].size():
				draw_circle(_polygons[polygon_index][point_index],polygon_points_radius,Color(_uvs[polygon_index][point_index].x,_uvs[polygon_index][point_index].y,0))
	if show_sample_points:
		for p in _points:
			draw_circle(p,sample_points_radius,Color.WHITE)


func _get_property_list() -> Array[Dictionary]:
	var property_list : Array[Dictionary] = []
	
	if animation == null: return property_list
	
	if animation.get_animation_names().is_empty(): return property_list
	
	# here we expose the names directly from the SpriteFrames dynamically
	# and filter the animations with no frames
	var animation_names : PackedStringArray = animation.get_animation_names()
	var not_empty_animation_names := PackedStringArray()
	
	for anim_name in animation_names:
		if animation.get_frame_count(anim_name) > 0:
			not_empty_animation_names.append(anim_name)
	
	if not_empty_animation_names.is_empty() : return property_list
	
	# guard to prevent the current animation to point to a non existant animation
	if not not_empty_animation_names.has(current_animation):
		current_animation = not_empty_animation_names[0]
	
	property_list.append(
		{
			"name": "current_animation",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ",".join(not_empty_animation_names)
		}
	)
	
	# adding the button to refresh the list manually in case
	# the animation list changed and the enum did not update
	property_list.append(
		{
			"name": "update_current_animation_list",
			"type": TYPE_CALLABLE,
			"hint": PROPERTY_HINT_TOOL_BUTTON,
			"hint_string": "Refresh current animation list"
		}
	)
	
	return property_list

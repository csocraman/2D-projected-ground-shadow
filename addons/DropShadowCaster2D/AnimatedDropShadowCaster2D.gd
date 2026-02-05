@tool
@icon("res://addons/DropShadowCaster2D/Icons/AnimatedDropShadowCaster2D.svg")
extends DropShadow2D
class_name AnimatedDropShadowCaster2D

## Draws a animated shadow.

##SpriteFrame resource containing the animations of the shadow.
@export var animation : SpriteFrames
var _old_points := PackedVector2Array()

var _polygons : Array[PackedVector2Array]
var _uvs : Array[PackedVector2Array]

## Current frame number.
var current_frame := 0
var _time_acc := 0.0

##Current shadow animation.
@export var current_animation := "default"
##The speed scaling ratio. For example, if this value is 1, then the animation plays at normal speed. If it's 0.5, then it plays at half speed. If it's 2, then it plays at double speed.
##If set to a negative value, the animation is played in reverse. If set to 0, the animation will not advance.
@export var speed_scale := 1.0
##True if an animation is playing.
var playing := false

## Returns the duration of the animation.
func get_animation_duration(animationname : String) -> float:
	return animation.get_frame_duration(animationname,current_frame)/animation.get_animation_speed(animationname)

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

func _mod(a,b) -> int:
	return a - b*floor(a/b)

## Returns the current animation frame.
func get_current_frame() -> AtlasTexture:
	var frame = animation.get_frame_texture(current_animation,current_frame)
	return frame
func _process(delta: float) -> void:
	if animation != null:
		if playing and animation.has_animation(current_animation):
			_time_acc += delta * abs(speed_scale)
			current_frame += sign(speed_scale)*floor(_time_acc/(get_animation_duration(current_animation)))
			if animation.get_animation_loop(current_animation):
				current_frame = _mod(float(current_frame),float(animation.get_frame_count(current_animation)))
			else:
				current_frame = clamp(current_frame,0,animation.get_frame_count(current_animation)-1)
			_time_acc = fmod(_time_acc,get_animation_duration(current_animation))
	if !is_visible_in_tree():
		return
	_points = []
	_create_points()
	
	if animation != null:
		if animation.has_animation(current_animation):
			queue_redraw()
		
func _draw() -> void:
	if (Engine.is_editor_hint() and show_in_editor):
		return
	if Engine.is_editor_hint() and show_preview_line:
		draw_line(Vector2(-shadow_size.x/2,0),Vector2(shadow_size.x/2,0),Color.CRIMSON,preview_line_tickness)
	if _points.size() < 2:
		return

	_old_points = _points
	_old_points.reverse()

	var polygon_shadow := ShadowPolygon.new(global_position)
	polygon_shadow.shadow_max_distance = shadow_max_distance
	
	var bottom_points := _points
	bottom_points.reverse()

	polygon_shadow.size_x = shadow_size.x
	polygon_shadow.create_polygon(_points,bottom_points,shadow_size.y/2,true)

	_polygons.clear()
	_uvs.clear()
	_polygons.append(polygon_shadow.polygon)
	_uvs.append(polygon_shadow.uv)

	var leftover_shadowpolygon = ShadowPolygon.new(global_position)
	
	_create_leftovers(polygon_shadow,_polygons,_uvs)
	
	if ! _check_is_on_screen(_polygons):
		return
	
	for polygon_index in _polygons.size():
		for p in _uvs[polygon_index].size():
			_uvs[polygon_index][p] -= Vector2.ONE/2
			_uvs[polygon_index][p] = _uvs[polygon_index][p].rotated(shadow_rotation)
			_uvs[polygon_index][p] += Vector2.ONE/2
			_uvs[polygon_index][p] /= get_current_frame().atlas.get_size() / get_current_frame().region.size
			_uvs[polygon_index][p] += get_current_frame().region.position / get_current_frame().atlas.get_size()
			
		if _polygons[polygon_index].size() < 3 or _uvs[polygon_index].size() != _polygons[polygon_index].size():
			continue
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),_triangulate_polygon(_polygons[polygon_index]),_polygons[polygon_index],[],_uvs[polygon_index],[],[],get_current_frame().get_rid())
		if show_polygon_points:
			for point_index : float in _polygons[polygon_index].size():
				draw_circle(_polygons[polygon_index][point_index],2,Color(_uvs[polygon_index][point_index].x,_uvs[polygon_index][point_index].y,0))
	if show_sample_points:
		for p in _points:
			draw_circle(p,1,Color.WHITE)

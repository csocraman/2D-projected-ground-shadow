@tool
@icon("res://addons/DropShadowCaster2D/Icons/AnimatedDropShadowCaster2D.svg")
extends DropShadow2D
class_name AnimatedDropShadowCaster2D

##SpriteFrame resource containing the animations of the shadow
@export var animation : SpriteFrames
var old_points := PackedVector2Array()

var polygons : Array[PackedVector2Array]
var uvs : Array[PackedVector2Array]

var current_frame := 0
var time_acc := 0.0

##Current shadow animation
@export var current_animation := "default"
var playing := false

func get_animation_duration(animationname : String):
	return animation.get_frame_duration(animationname,current_frame)/animation.get_animation_speed(animationname)

func play(animationname : String):
	current_animation = animationname
	current_frame = 0
	playing = true

func stop():
	playing = false

func get_current_frame() -> AtlasTexture:
	var frame = animation.get_frame_texture(current_animation,current_frame)
	return frame
func _process(delta: float) -> void:
	if animation != null:
		if playing and animation.has_animation(current_animation):
			time_acc += delta
			
			current_frame += floor(time_acc/(get_animation_duration(current_animation)))
			time_acc = fmod(time_acc,get_animation_duration(current_animation))
			
			if animation.get_animation_loop(current_animation):
				current_frame %= animation.get_frame_count(current_animation)
			else:
				current_frame = min(current_frame,animation.get_frame_count(current_animation)-1)
		
	points = []
	create_points()
	
	if animation != null:
		if animation.has_animation(current_animation):
			queue_redraw()
		
func _draw() -> void:
	if Engine.is_editor_hint():
		draw_line(Vector2(-shadow_size.x/2,0),Vector2(shadow_size.x/2,0),Color.CRIMSON,10)
	if points.size() < 2:
		return

	old_points = points
	old_points.reverse()

	var polygon_shadow := ShadowPolygon.new(global_position)
	polygon_shadow.shadow_max_distance = shadow_max_distance
	
	var bottom_points := points
	bottom_points.reverse()

	polygon_shadow.size_x = shadow_size.x
	polygon_shadow.create_polygon(points,bottom_points,shadow_size.y/2,true)

	polygons.clear()
	uvs.clear()
	polygons.append(polygon_shadow.polygon)
	uvs.append(polygon_shadow.uv)

	var leftover_shadowpolygon = ShadowPolygon.new(global_position)
	
	if !polygon_shadow.leftovers.is_empty():
		leftover_shadowpolygon.size_x = polygon_shadow.size_x
		leftover_shadowpolygon.StartIndex = polygon_shadow.EndIndex + polygon_shadow.StartIndex
		leftover_shadowpolygon.shadow_max_distance = shadow_max_distance
		leftover_shadowpolygon.create_polygon(polygon_shadow.leftovers,polygon_shadow.leftoversbottom,shadow_size.y/2,shadow_rotation,false)
		
		polygons.append(leftover_shadowpolygon.polygon.duplicate())
		uvs.append(leftover_shadowpolygon.uv.duplicate())
		
		while !leftover_shadowpolygon.leftovers.is_empty():
			leftover_shadowpolygon.StartIndex = leftover_shadowpolygon.EndIndex + leftover_shadowpolygon.StartIndex
			leftover_shadowpolygon.shadow_max_distance = shadow_max_distance
			leftover_shadowpolygon.create_polygon(leftover_shadowpolygon.leftovers,leftover_shadowpolygon.leftoversbottom,shadow_size.y/2,shadow_rotation,false)
			
			polygons.append(leftover_shadowpolygon.polygon.duplicate())
			uvs.append(leftover_shadowpolygon.uv.duplicate())
	
	var is_on_screen := false
	var min_x
	var max_x
	if scale.x >= 0:
		min_x = polygons[0][0].x + global_position.x
		max_x = polygons[polygons.size()-1][polygons[polygons.size()-1].size()/2-1].x + global_position.x
	else:
		max_x = polygons[0][0].x + global_position.x
		min_x = polygons[polygons.size()-1][polygons[polygons.size()-1].size()/2-1].x + global_position.x
	var min_y = polygons[0][0].y + global_position.y
	var max_y = polygons[0][0].y + global_position.y
	for polygon_index in polygons.size():
		for point in polygons[polygon_index]:
			if point.y + global_position.y > max_y:
				max_y = point.y + global_position.y
			if point.y + global_position.y < min_y:
				min_y = point.y + global_position.y
	var rect = Rect2(Vector2(min_x,min_y) + (get_viewport_transform().get_origin()),Vector2(max_x-min_x,max_y-min_y))
	is_on_screen = rect.intersects(get_viewport_rect())
	if !is_on_screen and !Engine.is_editor_hint():
		return
	
	for polygon_index in polygons.size():
		for p in uvs[polygon_index].size():
			uvs[polygon_index][p] -= Vector2.ONE/2
			uvs[polygon_index][p] = uvs[polygon_index][p].rotated(shadow_rotation)
			uvs[polygon_index][p] += Vector2.ONE/2
			uvs[polygon_index][p] /= get_current_frame().atlas.get_size() / get_current_frame().region.size
			uvs[polygon_index][p] += get_current_frame().region.position / get_current_frame().atlas.get_size()
			
			
		if polygons[polygon_index].size() < 3 or uvs[polygon_index].size() != polygons[polygon_index].size():
			continue
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),triangulate_polygon(polygons[polygon_index]),polygons[polygon_index],[],uvs[polygon_index],[],[],get_current_frame().get_rid())
		if show_polygon_points:
			for point_index : float in polygons[polygon_index].size():
				draw_circle(polygons[polygon_index][point_index],2,Color(uvs[polygon_index][point_index].x,uvs[polygon_index][point_index].y,0))
	if show_sample_points:
		for p in points:
			draw_circle(p,1,Color.BLACK)

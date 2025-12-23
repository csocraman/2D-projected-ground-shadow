@tool
@icon("res://addons/DropShadowCaster2D/Icons/DropShadowCaster2D.svg")
extends DropShadow2D
class_name DropShadowCaster2D


## The texture of the shadow
@export var texture : Texture2D:
	set(new):
		texture = new
		queue_redraw()

var old_points := PackedVector2Array()


func _process(delta: float) -> void:
	if !is_visible_in_tree():
		return
	points = []
	create_points()
	if old_points != points:
		queue_redraw()
		
func _draw() -> void:
	if Engine.is_editor_hint():
		draw_line(Vector2(-shadow_size.x/2,0),Vector2(shadow_size.x/2,0),Color.CRIMSON,10)
	if points.size() < 2 or texture == null:
		return

	old_points = points
	old_points.reverse()

	var polygon_shadow := ShadowPolygon.new(global_position)
	polygon_shadow.shadow_max_distance = shadow_max_distance
	
	var bottom_points := points
	bottom_points.reverse()
	
	polygon_shadow.size_x = shadow_size.x
	polygon_shadow.create_polygon(points,bottom_points,shadow_size.y/2,true)

	var polygons : Array[PackedVector2Array]
	var uvs : Array[PackedVector2Array]
	polygons.append(polygon_shadow.polygon)
	uvs.append(polygon_shadow.uv)

	create_leftovers(polygon_shadow,polygons,uvs)
	
	if !check_is_on_screen(polygons):
		return
	for polygon_index in polygons.size():
		for p in uvs[polygon_index].size():
			uvs[polygon_index][p] -= Vector2.ONE/2
			uvs[polygon_index][p] = uvs[polygon_index][p].rotated(shadow_rotation)
			uvs[polygon_index][p] += Vector2.ONE/2
		if polygons[polygon_index].size() < 3 or uvs[polygon_index].size() != polygons[polygon_index].size():
			continue
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),triangulate_polygon(polygons[polygon_index]),polygons[polygon_index],[],uvs[polygon_index],[],[],texture.get_rid())
		if show_polygon_points:
			for point_index : float in polygons[polygon_index].size():
				draw_circle(polygons[polygon_index][point_index],2,Color(uvs[polygon_index][point_index].x,uvs[polygon_index][point_index].y,0))
	if show_sample_points:
		for p in points:
			draw_circle(p,1,Color.WHITE)

@tool
@icon("res://addons/DropShadowCaster2D/Icons/DropShadowCaster2D.svg")
extends DropShadow2D
## Draws shadows using a texture.
class_name DropShadowCaster2D

## The texture of the shadow.
@export var texture : Texture2D:
	set(new):
		texture = new
		queue_redraw()

var _old_points := PackedVector2Array()


func _process(delta: float) -> void:
	if !is_visible_in_tree():
		return
	_points = []
	_create_points()
	if _old_points != _points:
		queue_redraw()
		
func _draw() -> void:
	if (Engine.is_editor_hint() and show_in_editor):
		return
	if Engine.is_editor_hint() and show_preview_line:
		draw_line(Vector2(-shadow_size.x/2,0),Vector2(shadow_size.x/2,0),Color.CRIMSON,preview_line_tickness)
	if _points.size() < 2 or texture == null:
		return
	_old_points = _points
	_old_points.reverse()
	
	var polygon_shadow := ShadowPolygon.new(global_position)
	polygon_shadow.shadow_max_distance = shadow_max_distance
	
	var bottom_points := _points
	bottom_points.reverse()
	
	polygon_shadow.size_x = shadow_size.x
	polygon_shadow.create_polygon(_points,bottom_points,shadow_size.y/2,true)

	var polygons : Array[PackedVector2Array]
	var uvs : Array[PackedVector2Array]
	polygons.append(polygon_shadow.polygon)
	uvs.append(polygon_shadow.uv)

	_create_leftovers(polygon_shadow,polygons,uvs)
	
	if !_check_is_on_screen(polygons):
		return
	for polygon_index in polygons.size():
		var polygon = polygons[polygon_index]
		var uv = uvs[polygon_index]
		for p in uv.size():
			uv[p] -= Vector2.ONE/2
			uv[p] = uv[p].rotated(shadow_rotation)
			uv[p] += Vector2.ONE/2
		if polygon.size() < 3 or uv.size() != polygon.size():
			continue
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),_triangulate_polygon(polygon),polygon,[],uv,[],[],texture.get_rid())
		if show_polygon_points:
			for point_index : float in polygon.size():
				draw_circle(polygon[point_index],2,Color(uv[point_index].x,uv[point_index].y,0))
	if show_sample_points:
		for p in _points:
			draw_circle(p,1,Color.WHITE)

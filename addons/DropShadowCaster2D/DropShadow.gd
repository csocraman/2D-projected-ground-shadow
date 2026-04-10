@tool
@abstract
extends Node2D
##Generates a ground-projected shadow polygon based on collision _points detected by several rays.
class_name DropShadow2D

## Emitted when sample points are created.
signal points_created

## The size of the shadow.
@export var shadow_size := Vector2(64,64):
	set(new):
		shadow_size = new
		queue_redraw()
##Shadow rotation.[br][br][b]Note:[/b]shadow_rotation will not change the shape of the shadow polygon only the sprite.
@export_range(-180,180,0.1,"radians_as_degrees") var shadow_rotation := 0.0
##The offset of the shadow.[br][br][b]Note:[/b]shadow_offset will not affect the shape of the resulting shadow only its displacement.
@export var shadow_offset : Vector2
##The distance at which the shadow diminishes to zero. For example, if this value is 256, at the distance of 128 from the ground, the shadow will be half its size.
@export var shadow_max_distance := 1000
## Toggles the preview in editor.
@export var show_in_editor := true
@export_group('Sampling')
## Resolution of the shadow. The bigger the value more precise the shadow will be.
@export_range(2.0,100000) var resolution := 64
## The physics layer that the shadow uses.
@export_flags_2d_physics var collision_mask := 1
## The maximum lenght each ray.
@export var max_distance := 1000.0
@export_group('Optimization')
## Tries to remove unnecessary points in straight lines, keeping only the first and last_height_difference.
@export var points_simplification := true
## Tolerance threshold for detecting whether a point lies on a straight line. While changing this value usually results in minimal visual differences, it still affects the accuracy of the simplification process.
@export_range(0.001,1.0,0.001) var threshold := 0.002
@export_group('Debug')
## Draws a line previewing the shadow width.
@export var show_preview_line := false
## The ticknes of the line previewing the shadow width.
@export var preview_line_tickness := 20.0
## Toggles drawing of sample points from each shadow ray.
@export var show_sample_points : bool:
	set(new):
		show_sample_points = new
		queue_redraw()
@export var sample_points_radius := 1.0
## Shows the points of the shadow polygon colored with its UV coordinate.
@export var show_polygon_points : bool:
	set(new):
		show_polygon_points = new
		queue_redraw()
@export var polygon_points_radius := 1.0

var _points := PackedVector2Array()

class ShadowPolygon:
	var EndIndex : int
	var polygon := PackedVector2Array()
	var StartIndex : int
	var remaining_points := PackedVector2Array()
	var uv := PackedVector2Array()
	var position : Vector2
	var shadow_max_distance : int
	var size_x : float
	var height_map := []

	func _init(position : Vector2) -> void:
		self.position = position
	
	func create_polygon(Top : PackedVector2Array,Size_y : float,shadow_rotation : float = 0.0) -> void:
		var Top_polygon_points := Top.duplicate()
		var Bottom_polygon_points := Top.duplicate()
	
		uv.clear()
		height_map.clear()
		polygon.clear()
		remaining_points.clear()
		EndIndex = 0
		
		for point in Top_polygon_points:
			height_map.append(abs(point.y))
		for x in Top_polygon_points.size():
			Top_polygon_points[x] -= Vector2(0,Size_y)
		for x in Bottom_polygon_points.size():
			Bottom_polygon_points[x] += Vector2(0,Size_y)
		var polygon_bottom : PackedVector2Array
	
		var last_point : Vector2
		var split := false
		var StartremainingpointsIndex : int
		var all_points : PackedVector2Array
		all_points.append_array(Top_polygon_points)
	
		var Bottom_polygon_points_reversed = Bottom_polygon_points.duplicate()
		Bottom_polygon_points_reversed.reverse()
		all_points.append_array(Bottom_polygon_points_reversed)
		for index in Top_polygon_points.size():
			var top_point = Top_polygon_points[index]
			if index == 0:
				last_point = top_point
				polygon.append(top_point)
				EndIndex = index
				continue
		
			var dir = top_point.direction_to(last_point)
			var angle_to_last_point = absf(atan2(dir.y,absf(dir.x)))

			if angle_to_last_point > deg_to_rad(70):
				height_map.insert(index,height_map[index-1])
				split = true
				StartremainingpointsIndex = index
				last_point = top_point
				break
			last_point = top_point
			polygon.append(top_point)
			EndIndex = index
		if split:
			remaining_points.append_array(Top.slice(StartremainingpointsIndex,Top_polygon_points.size()))
		polygon_bottom.append_array(Bottom_polygon_points.slice(0,EndIndex+1))
		if remaining_points.size() > 0:
			remaining_points[0].x = (remaining_points[0].x + polygon[polygon.size()-1].x)/2
	
		polygon_bottom.reverse()
		polygon.append_array(polygon_bottom)

		create_uv(Top_polygon_points,size_x,shadow_rotation)

		if Top.size() > 0:
			for i in polygon.size():
				if i <= EndIndex:
					polygon[i].y += height_map[i]*(Size_y/shadow_max_distance)
				else:
					polygon[i].y -= height_map[clamp((2*(EndIndex) - i + 1),0,height_map.size() - 1)]*(Size_y/shadow_max_distance)
					
				
	func create_uv(Top,sizex,shadow_rotation) -> void:
		if polygon.is_empty():
			return

		for p : float in range(0,EndIndex + 1):
			var width = (shadow_max_distance - height_map[p])/shadow_max_distance*sizex
			uv.append(Vector2((polygon[p].x+width/2) / width,0.0))
		for p : float in range(EndIndex+1,polygon.size()):
			var width = (shadow_max_distance - height_map[(p-(EndIndex+1))])/shadow_max_distance*sizex
			uv.append(Vector2((polygon[p].x+width/2) / width,1.0))

func _mix(a,b,f):
	return a*f + (1.0 - f)*b

func _create_points() -> void:
	if collision_mask == null or collision_mask == 0:
		return
	
	var state = get_world_2d().direct_space_state
	var points_param = PhysicsPointQueryParameters2D.new()
	points_param.collision_mask = collision_mask
	var rayparams = PhysicsRayQueryParameters2D.new()

	if get_parent() is CollisionObject2D:
		rayparams = PhysicsRayQueryParameters2D.create(Vector2.ZERO,Vector2.ZERO,collision_mask,[get_parent().get_rid()])
	else:
		rayparams = PhysicsRayQueryParameters2D.create(Vector2.ZERO,Vector2.ZERO,collision_mask)
	if get_parent() is CollisionObject2D:
		points_param.exclude = [get_parent().get_rid()]
	var candidate
	rayparams.hit_from_inside = false
	var from : Vector2
	var to : Vector2
	var result : Dictionary
	var last_height_difference :float= 0.0
	var point := Vector2()
	var signscale : Vector2 = scale.sign()
	var height_difference : float
	var last_point : Vector2
	for x in resolution:
		var x_position := (shadow_size.x)/float(resolution - 1)*x-(shadow_size.x)/2.0
	
		from = Vector2(x_position + global_position.x,global_position.y)
		to = global_position + Vector2(x_position,max_distance)

		points_param.position = from
		
		var res = state.intersect_point(points_param)
		if !res.is_empty():
			if x_position < 0:
				_points.clear()
			else:
				break
		rayparams.from = from
		rayparams.to = to
		
		result = state.intersect_ray(rayparams)
		var x_pos_abs : float = absf(x_position)
		var height : float
		if !result.is_empty():
			height = result.position.y - global_position.y
		else:
			height = max_distance - global_position.y

		var distance_from_mask = (shadow_max_distance-height)/shadow_max_distance*(shadow_size.x)-x_pos_abs
		
		if distance_from_mask >= (x_pos_abs-shadow_size.x*2/resolution):
			if !result.is_empty():
				if _points.is_empty() or distance_from_mask < (x_pos_abs):
					if true:
						point = (result.position - global_position)*signscale-shadow_offset
				else:
					point = (result.position - global_position)*signscale-shadow_offset
			else:
				point = Vector2(x_position,max_distance)*signscale-shadow_offset
			
			if points_simplification:
				if _points.size() < 1:
					_points.append(point)
				elif candidate == null:
					candidate = point
					last_point = _points[-1]
				else:
					height_difference = (last_point.y - candidate.y) + (candidate.y - point.y)
					
					var th = threshold / resolution
					if absf(height_difference-last_height_difference) >= th:
						_points.append(candidate)
					last_point = candidate
					last_height_difference = height_difference
					candidate = point
			else:
				_points.append(point)
		if x >= resolution-1 and candidate != null:
			_points.append(candidate)
	if _points.size() > 1:
		var sides = [_points[0],_points[-1]]
		for i in range(-1,1):
			var p = _points[i]
			var height = p.y
			var abs_xpos = abs(p.x)
			var distance_from_mask = (shadow_max_distance-height)/shadow_max_distance*(shadow_size.x/2.0)-abs_xpos
			var point_before = _points[i+2*sign(i)+1]
			var f = clampf(absf(distance_from_mask)/absf(p.x-point_before.x),0.,1.)
			if distance_from_mask <= 0:
				sides[i] = _mix(point_before,p*signscale,f) - shadow_offset
		for i in range(-1,1):
			_points[i] = sides[i]
	points_created.emit()
	
func _triangulate_polygon(polygon : PackedVector2Array) -> PackedInt32Array:
	var size = polygon.size()/2
	var result = PackedInt32Array()
	for i in size-1:
		result.append(i)
		result.append(size*2-1-i)
		result.append(size*2-2-i)
		result.append(i)
		result.append(i+1)
		result.append(size*2-2-i)
	return result

## Returns the distance of every sample point.
func get_points_distance() -> PackedFloat32Array:
	var distance = PackedFloat32Array()
	for point in _points:
		distance.append(point.y + shadow_offset.y)
	return distance

func _resolve_remaining_points(shadow_polygon : ShadowPolygon, polygons : Array[PackedVector2Array],uvs : Array[PackedVector2Array]) -> void:
	var new_shadow_polygon = ShadowPolygon.new(global_position)
	
	if !shadow_polygon.remaining_points.is_empty():
		new_shadow_polygon.size_x = shadow_polygon.size_x
		new_shadow_polygon.StartIndex = shadow_polygon.EndIndex + shadow_polygon.StartIndex
		new_shadow_polygon.shadow_max_distance = shadow_max_distance
		new_shadow_polygon.create_polygon(shadow_polygon.remaining_points,shadow_size.y/2,shadow_rotation)
		
		polygons.append(new_shadow_polygon.polygon.duplicate())
		uvs.append(new_shadow_polygon.uv.duplicate())
		
		while !new_shadow_polygon.remaining_points.is_empty():
			new_shadow_polygon.StartIndex = new_shadow_polygon.EndIndex + new_shadow_polygon.StartIndex
			new_shadow_polygon.shadow_max_distance = shadow_max_distance
			new_shadow_polygon.create_polygon(new_shadow_polygon.remaining_points,shadow_size.y/2,shadow_rotation)
			
			polygons.append(new_shadow_polygon.polygon.duplicate())
			uvs.append(new_shadow_polygon.uv.duplicate())
	
func _check_is_on_screen(polygons : Array[PackedVector2Array]):
	var is_on_screen := false
	var viewport_rect = get_viewport_rect()
	viewport_rect.position -= get_viewport_transform().origin/get_viewport_transform().get_scale()
	viewport_rect.size /= get_viewport_transform().get_scale()
	for polygon_index in polygons.size():
		for point in polygons[polygon_index]:
			if viewport_rect.has_point(point + global_position):
				is_on_screen = true
				break
	if is_on_screen or Engine.is_editor_hint():
		return true
	return false

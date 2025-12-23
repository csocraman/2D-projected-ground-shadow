@tool
extends Node2D
##Generates a ground-projected shadow polygon based on collision points detected by several rays.
class_name DropShadow2D

signal points_created

## The size of the shadow
@export var shadow_size := Vector2(64,64):
	set(new):
		shadow_size = new
		queue_redraw()
##Shadow rotation
@export_range(-180,180,0.1,"radians_as_degrees") var shadow_rotation := 0.0
##Shadow shadow_offset
@export var shadow_offset : Vector2
##The distance at which the shadow diminishes to zero
@export var shadow_max_distance := 1000
@export_group('Sampling')
## The amount of rays used to calculate the points
@export_range(2.0,100000) var steps := 64
## The physics layer that the rays uses hists
@export_flags_2d_physics var collision_mask := 1
## The maximum lenght each ray
@export var max_distance := 1000.0
@export_group('Optimization')
## Tries to remove unnecessary points in straight lines, keeping only the first and last
@export var points_simplification := true
## Tolerance threshold for detecting whether a point lies on a straight line. While changing this value usually results in minimal visual differences, it still affects the accuracy of the simplification process
@export_range(0.001,1.0,0.001) var threshold := 0.002
@export_group('Debug')
## Toggles drawing of sample points from each shadow ray
@export var show_sample_points : bool:
	set(new):
		show_sample_points = new
		queue_redraw()
## Shows the points of the shadow polygon colored with its UV coordinate
@export var show_polygon_points : bool:
	set(new):
		show_polygon_points = new
		queue_redraw()

var points := PackedVector2Array()

class ShadowPolygon:
	var EndIndex : int
	var polygon := PackedVector2Array()
	var StartIndex : int
	var leftovers := PackedVector2Array()
	var leftoversbottom := PackedVector2Array()
	var uv := PackedVector2Array()
	var position : Vector2
	var shadow_max_distance : int
	var size_x : float
	var height_map := []

	func _init(position : Vector2) -> void:
		self.position = position
	
	func create_polygon(Top : PackedVector2Array, Bottom : PackedVector2Array,Size_y : float,shadow_rotation : float = 0.0,shift : bool = true):
		var Top_polygon_points := Top.duplicate()
		var Bottom_polygon_points := Bottom.duplicate()
	
		uv.clear()
		height_map.clear()
		leftoversbottom.clear()
		polygon.clear()
		leftovers.clear()
		leftoversbottom.clear()
		for point in Top_polygon_points:
			if shift:
				height_map.append(Vector2(position.x,point.y + position.y).distance_to(position))
			else:
				height_map.append(Vector2(position.x,point.y + Size_y + position.y).distance_to(position))
		if shift:
			for x in Top_polygon_points.size():
				Top_polygon_points[x] -= Vector2(0,Size_y)
			for x in Bottom_polygon_points.size():
				Bottom_polygon_points[x] += Vector2(0,Size_y)
		var polygon_bottom : PackedVector2Array
	
		var last_point : Vector2
		var leftover_creation_stage := false
		EndIndex = 0
		var EndLeftoverIndex : int
		var StartLeftoverIndex : int
		var all_points : PackedVector2Array
		all_points.clear()
		all_points.append_array(Top_polygon_points)
	
		var Bottom_polygon_points_reversed = Bottom_polygon_points.duplicate()
		Bottom_polygon_points_reversed.reverse()
		all_points.append_array(Bottom_polygon_points_reversed)
		for index in Top_polygon_points.size():
			var top_point = Top_polygon_points[index]
			if !leftover_creation_stage:
				if index == 0:
					last_point = top_point
					polygon.append(top_point)
					EndIndex = index
					continue
	
				

				var dir = top_point.direction_to(last_point)
				var angle_to_last_point = abs(atan2(dir.y,abs(dir.x)))
	
				if angle_to_last_point > deg_to_rad(70):
					height_map.insert(index,height_map[index-1])
					leftovers.append(top_point)
					#polygon.append(Vector2(top_point.x,last_point.y))
					leftover_creation_stage = true
					StartLeftoverIndex = index
					EndLeftoverIndex = index
					last_point = top_point
					continue

				last_point = top_point
					
				polygon.append(top_point)
				EndIndex = index
			else:
				EndLeftoverIndex = index
				leftovers.append(top_point)
		leftoversbottom.append_array(Bottom_polygon_points.slice(StartLeftoverIndex,EndLeftoverIndex+1))
		polygon_bottom.append_array(Bottom_polygon_points.slice(0,EndIndex+1))
		if leftovers.size() > 0:
			leftoversbottom[0].x = (polygon_bottom[polygon_bottom.size()-1].x + leftoversbottom[0].x)/2
			leftovers[0].x = (leftovers[0].x + polygon[polygon.size()-1].x)/2
	
		polygon_bottom.reverse()
		polygon.append_array(polygon_bottom)

		create_uv(Top_polygon_points,size_x,shadow_rotation)

		var shifted = Size_y * int(!shift)
		if Top.size() > 0:
			for i in polygon.size():
				if i <= EndIndex:
					polygon[i].y += height_map[i]*(Size_y/shadow_max_distance)
					#polygon[i].y = min(Top[min(min(i,EndIndex),Top.size()-1)].y + shifted,polygon[i].y)
				else:
					polygon[i].y -= height_map[clamp((2*(EndIndex) - i + 1),0,height_map.size() - 1)]*(Size_y/shadow_max_distance)
					#polygon[i].y = max(Top[min(clamp((2*(EndIndex) - i ),0,height_map.size() - 1),Top.size()-1)].y + shifted,
					#polygon[i].y)
					pass
					
				
	func create_uv(Top,sizex,shadow_rotation):
		if polygon.is_empty():
			return

		for p : float in range(0,EndIndex + 1,1):
			var estimated_width = (shadow_max_distance - height_map[p])/shadow_max_distance*sizex
			uv.append(Vector2((polygon[p].x+estimated_width/2)/ estimated_width,0.0))

		for p : float in range(EndIndex+1,polygon.size(),1):
			var estimated_width = (shadow_max_distance-height_map[(p-(EndIndex++1))])/shadow_max_distance*sizex
			uv.append(Vector2(((polygon[p].x)+estimated_width/2) / estimated_width,1.0))
		
func mix(a,b,v):
	return b * v + a * (1.-v)

func create_points():
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
	var dt = 0
	for x in steps:
		
		var x_position := (shadow_size.x)/float(steps - 1)*x-(shadow_size.x)/2.0
		
		var from = global_position + Vector2(x_position,0)
		var to = global_position + Vector2(x_position,max_distance)
		rayparams.hit_from_inside = false
			
		points_param.position = from
		
		rayparams.from = from
		
		
		var res = state.intersect_point(points_param)
		if !res.is_empty():
			if x_position < 0:
				points.clear()
			else:
				break	
		
		rayparams.to = to
		var t = Time.get_ticks_msec()
		var result = state.intersect_ray(rayparams)
		dt += -t + Time.get_ticks_msec()
			
		var height : float
		if !result.is_empty():
			height = Vector2(global_position.x,result.position.y).distance_to(global_position)
		else:
			height = Vector2(global_position.x,max_distance).distance_to(global_position)
		var distance_from_mask = (shadow_max_distance-height)/shadow_max_distance*(shadow_size.x)-abs(x_position)
		if distance_from_mask >= (abs(x_position)-shadow_size.x*2/steps):
			if !result.is_empty():
				if points.is_empty() or distance_from_mask < (abs(x_position)):
					if distance_from_mask-abs(x_position) > 0:
						points.append((result.position - global_position)*sign(scale)-shadow_offset)
					else:
						var pos = result.position - global_position;
						var last_pos = (abs(x_position)-shadow_size.x/steps)
						var f = clamp(abs(distance_from_mask-abs(x_position))/abs((abs(x_position)-shadow_size.x*2/steps)-abs(x_position)),0,1)
						points.append(mix(pos,Vector2(sign(x_position)*last_pos,pos.y),f)*sign(scale)-shadow_offset)
				else:
					points.append((result.position - global_position)*sign(scale)-shadow_offset)
			else:
				points.append(Vector2(x_position,max_distance)*sign(scale)-shadow_offset)
	#print(dt/1000.0)
	if points_simplification:
		var height_difference_map : PackedFloat32Array= []
		for point_index in points.size():
			var height_difference : float
			if point_index > 0 and point_index < points.size()-1:
				height_difference = (points[point_index].y - points[point_index-1].y) + (points[point_index].y - points[point_index+1].y)

			if point_index == 1:
				height_difference_map[0] = height_difference

			height_difference_map.append(height_difference)

			if point_index == points.size()-1:
				height_difference_map[point_index] = height_difference_map[point_index-1]
		
		var lines : Dictionary[int,PackedInt32Array] = {0: [0]}
		var v : int = 0
		for i in height_difference_map.size():
			if i > 0:
				if abs(height_difference_map[i] - height_difference_map[i-1]) < threshold / steps:
					if !lines.has(v):
						lines[v] = PackedInt32Array()
					
					if lines[v].size() > 1 and points.size() >= 1000:
						lines[v].remove_at(1)
					lines[v].append(i)
					
				else:
					v = i
					lines[v] = PackedInt32Array()
					lines[v].append(i)
		var offset = 0
		
		if points.size() < 1000:
			for line_index in lines:
				for point in lines[line_index]:
					if lines[line_index][0] != point and lines[line_index][lines[line_index].size()-1] != point:
						points.remove_at(point-offset)
						offset += 1
		else:
			var npoints := PackedVector2Array()
			for line_index in lines:
				for point in lines[line_index]:
					npoints.append( points[point])
			points = npoints
	points_created.emit()
	
func triangulate_polygon(polygon : PackedVector2Array):
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

func get_points_distance():
	var distance = PackedFloat32Array()
	for point in points:
		distance.append(position.distance_to(Vector2(position.x,point.y)) + shadow_offset.y)
	return distance

func create_leftovers(polygon_shadow : ShadowPolygon, polygons : Array[PackedVector2Array],uvs : Array[PackedVector2Array]):
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
	
func check_is_on_screen(polygons : Array[PackedVector2Array]):
	var is_on_screen := false
	var viewport_rect = get_viewport_rect()
	viewport_rect.position -= get_viewport_transform().origin/get_viewport_transform().get_scale()
	viewport_rect.size /= get_viewport_transform().get_scale()
	for polygon_index in polygons.size():
		for point in polygons[polygon_index]:
			if viewport_rect.has_point(point + global_position):
				is_on_screen = true
				break
	if !is_on_screen and !Engine.is_editor_hint():
		return false
	return true

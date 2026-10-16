class_name PolygonEdit
extends Node2D
# This is heavily modified code that was originally written by Roman Movchan.
# See LICENSE.txt in the same folder as this file.
# See the original code here:
# https://github.com/Bugwan91/vector2_array_resource_editor

## A vertex will be active only when
## the cursor is at least this close to it, in pixels.
const _CURSOR_THRESHOLD: float = 6.0

## The radius of drawn vertices.
const _VERTEX_RADIUS: float = 6.0

## The color of drawn vertices.
const _VERTEX_COLOR := Color(0.0, 0.5, 1.0, 0.7)

## The color of drawn active (hovered) vertex.
const _VERTEX_ACTIVE_COLOR := Color.WHITE

## The color of the preview vertex that appears
## when the cursor hovers over the sides of the polygon.
const _VERTEX_PREVIEW_COLOR := Color(0.0, 1.0, 1.0, 0.5)

## The color of drawn polygon.
const _POLYGON_COLOR := Color(0.0, 0.5, 1.0, 0.2)

var shape: ProvinceShape:
	set(value):
		if shape != null:
			shape.changed.disconnect(queue_redraw)
		shape = value
		shape.changed.connect(queue_redraw)

## If set to false, the polygon itself will not be drawn.
## The vertices will still be drawn.
var is_draw_polygon_enabled: bool = true

## If set to false, dragging the entire polygon is disabled.
var can_drag_entire_polygon: bool = true:
	set(value):
		can_drag_entire_polygon = value
		if (
				not can_drag_entire_polygon
				and _is_dragging and _is_dragging_entire_polygon
		):
			_create_action_drag_polygon()
			_is_dragging = false

## The [UndoRedoResource] system to undo/redo changes.
var undo_redo: UndoRedoResource

## The index of the active (hovered) vertex.
## It's -1 if the cursor is not hovering over any vertex.
var _active_index: int = -1

## If the cursor if hovering over one of the polygon's sides,
## this variable tells you which side the cursor is on.
## It's -1 if it's not hovering over any side.
var _can_add_at: int = -1

var _is_dragging: bool = false
var _is_dragging_entire_polygon: bool = false

## Information about a currently ongoing drag.
## Used to create a drag action for the undo/redo.
var _drag_from: Vector2
var _drag_to: Vector2

## Prevents setting mouse input as handled
## when ending a polygon drag without ever moving the cursor.
var _moved_cursor_during_polygon_drag: bool = false

var _cursor_position: Vector2


func _draw() -> void:
	if is_draw_polygon_enabled:
		draw_colored_polygon(shape.polygon_points, _POLYGON_COLOR)
	for i in shape.polygon_points.size():
		_draw_vertex(shape.polygon_points[i], i)
	if _can_add_at != -1:
		_draw_preview_vertex()


func _unhandled_input(event: InputEvent) -> void:
	if (
			_handle_left_click(event)
			or _handle_right_click(event)
			or _handle_mouse_move(event)
	):
		get_viewport().set_input_as_handled()


func _handle_left_click(event: InputEvent) -> bool:
	if event is not InputEventMouseButton:
		return false
	var event_mouse_button := event as InputEventMouseButton

	if event_mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return false

	var is_handled: bool = false

	if event_mouse_button.is_pressed():
		if _can_add_at != -1:
			_add_vertex()
			_active_index = _can_add_at
			_can_add_at = -1
			_drag_to = _cursor_position
			is_handled = true
		if _has_active_vertex():
			_drag_from = shape.polygon_points[_active_index]
			_is_dragging = true
			_is_dragging_entire_polygon = false
			is_handled = true
		elif can_drag_entire_polygon and Geometry2D.is_point_in_polygon(
				_cursor_position, shape.polygon_points
		):
			_drag_from = _cursor_position
			_drag_to = _drag_from
			_moved_cursor_during_polygon_drag = false
			_is_dragging = true
			_is_dragging_entire_polygon = true
			is_handled = true

	if event_mouse_button.is_released() and _is_dragging:
		if _is_dragging_entire_polygon:
			_create_action_drag_polygon()
			is_handled = _moved_cursor_during_polygon_drag
		else:
			_create_action_drag_vertex()
			is_handled = true
		_is_dragging = false

	return is_handled


func _handle_right_click(event: InputEvent) -> bool:
	if event is not InputEventMouseButton:
		return false
	var event_mouse_button := event as InputEventMouseButton

	if (
			event_mouse_button.button_index == MOUSE_BUTTON_RIGHT
			and event_mouse_button.is_pressed()
			and _has_active_vertex()
			and not _is_dragging
			and shape.polygon_points.size() > 3
	):
		_remove_vertex()
		_active_index = -1
		return true

	return false


func _handle_mouse_move(event: InputEvent) -> bool:
	if event is not InputEventMouseMotion:
		return false

	var previous_cursor_position: Vector2 = _cursor_position
	_cursor_position = get_global_mouse_position()

	if _is_dragging:
		if _is_dragging_entire_polygon:
			_moved_cursor_during_polygon_drag = true
			_drag_polygon(_cursor_position - previous_cursor_position)
		else:
			_drag_vertex()
		return true

	_update_active_vertex()
	_can_add_at = _active_side()
	queue_redraw()
	return false


func _has_active_vertex() -> bool:
	return _active_index != -1


func _update_active_vertex() -> void:
	for i in shape.polygon_points.size():
		if (
				(_cursor_position - shape.polygon_points[i]).length()
				< _CURSOR_THRESHOLD
		):
			_active_index = i
			return
	_active_index = -1


## If the cursor is hovering over one of the polygon's sides,
## returns the index of the first vertex on that side of the polygon.
## Otherwise, returns -1.
func _active_side() -> int:
	# Don't check for sides if the cursor is on a vertex.
	if _has_active_vertex():
		return -1

	for i in shape.polygon_points.size():
		# checking if cursor position is between polygon side vertices
		var a: Vector2 = shape.polygon_points[i]
		var b: Vector2 = shape.polygon_points[
			i + 1 if i < shape.polygon_points.size() - 1 else 0
		]
		var ab: float = (b - a).length()
		var ac: float = (_cursor_position - a).length()
		var bc: float = (_cursor_position - b).length()
		if (ac + bc) - ab < _CURSOR_THRESHOLD:
			# checking height of triangle on base of polygon side
			# the opposite vertex is a cursor position
			var s: float = (ab + ac + bc) * 0.5
			var A: float = sqrt(s * (s - ab) * (s - ac) * (s - bc))
			var h: float = 2.0 * A / ab
			if h < _CURSOR_THRESHOLD:
				return i + 1
	return -1


func _add_vertex() -> void:
	undo_redo.create_action("Add vertex to polygon")
	undo_redo.add_do_method(
			shape.insert_point.bind(_can_add_at, _cursor_position)
	)
	undo_redo.add_undo_method(shape.remove_point.bind(_can_add_at))
	undo_redo.commit_action()


func _remove_vertex() -> void:
	undo_redo.create_action("Remove vertex from polygon")
	undo_redo.add_do_method(shape.remove_point.bind(_active_index))
	undo_redo.add_undo_method(shape.insert_point.bind(
			_active_index, shape.polygon_points[_active_index]
	))
	undo_redo.commit_action()


func _create_action_drag_vertex() -> void:
	if _drag_from == _drag_to:
		return
	undo_redo.create_action("Move vertex in polygon")
	undo_redo.add_do_method(shape.move_point_to.bind(_active_index, _drag_to))
	undo_redo.add_undo_method(
			shape.move_point_to.bind(_active_index, _drag_from)
	)
	undo_redo.commit_action(false)


func _create_action_drag_polygon() -> void:
	if _drag_from == _drag_to:
		return
	undo_redo.create_action("Move polygon")
	undo_redo.add_do_method(shape.move_relative.bind(_drag_to - _drag_from))
	undo_redo.add_undo_method(shape.move_relative.bind(_drag_from - _drag_to))
	undo_redo.commit_action(false)


## Moves the entire polygon by given relative amount.
func _drag_polygon(world_relative: Vector2) -> void:
	_drag_to = _cursor_position
	shape.move_relative(world_relative)


## Moves the active (hovered) vertex to the cursor's position.
func _drag_vertex() -> void:
	_drag_to = _cursor_position
	shape.move_point_to(_active_index, _cursor_position)


## Draws a vertex at given position. Displays the index of the active vertex.
func _draw_vertex(vertex_position: Vector2, vertex_index: int) -> void:
	var is_active_index: bool = vertex_index == _active_index
	const POINT_OUTLINE_THICKNESS: float = 1.0
	const POINT_OUTLINE_RADIUS: float = (
			_VERTEX_RADIUS + POINT_OUTLINE_THICKNESS * 0.5
	)

	# Outline
	draw_circle(
			vertex_position,
			POINT_OUTLINE_RADIUS,
			Color.BLACK,
			false,
			POINT_OUTLINE_THICKNESS
	)
	# The actual circle
	draw_circle(
			vertex_position,
			_VERTEX_RADIUS,
			_VERTEX_ACTIVE_COLOR if is_active_index else _VERTEX_COLOR
	)
	if is_active_index:
		# Outline
		const TEXT_OUTLINE_THICKNESS: int = 12
		draw_string_outline(
				ThemeDB.get_default_theme().default_font,
				vertex_position + Vector2(-16.0, -16.0),
				str(vertex_index),
				HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER,
				32.0,
				16,
				TEXT_OUTLINE_THICKNESS,
				Color.BLACK
		)
		# The actual text
		draw_string(
				ThemeDB.get_default_theme().default_font,
				vertex_position + Vector2(-16.0, -16.0),
				str(vertex_index),
				HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER,
				32.0
		)


## Draws the vertex that appears when you're able to
## create a new vertex on the sides of the polygon.
func _draw_preview_vertex() -> void:
	draw_circle(_cursor_position, _VERTEX_RADIUS, _VERTEX_PREVIEW_COLOR)

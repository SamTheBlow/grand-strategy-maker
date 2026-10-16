class_name ProvinceOverlay
extends Node2D
## Displays an overlay for editing the currently selected province.

@export var _undo_redo: UndoRedoResource

var _province_selection: ProvinceSelection
var _edge_case: PolygonEditEdgeCase


func _refresh() -> void:
	if not is_node_ready():
		return

	# Remove existing overlay
	NodeUtils.delete_all_children(self)

	var selected_province: Province = _province_selection.selected_province
	if selected_province == null:
		return

	# Setup the polygon shape editing
	var polygon_edit := PolygonEdit.new()
	polygon_edit.shape = selected_province.shape
	polygon_edit.is_draw_polygon_enabled = false
	polygon_edit.undo_redo = _undo_redo
	_edge_case.polygon_edit = polygon_edit
	add_child(polygon_edit)

	# Setup the army position marker
	var army_position_edit := PositionEdit.new(
			"Army position", PositionEdit.PointShape.SQUARE
	)
	army_position_edit.position = selected_province.position_army_host
	add_child(army_position_edit)

	selected_province.position_army_host_changed.connect(
			army_position_edit.set_position
	)
	army_position_edit.position_changed.connect(
			_on_army_position_changed.bind(selected_province)
	)
	army_position_edit.drag_finished.connect(
			_on_army_drag_finished.bind(selected_province)
	)

	# Setup the fortress position marker
	var fortress_position_edit := PositionEdit.new(
			"Fortress position", PositionEdit.PointShape.SQUARE
	)
	fortress_position_edit.position = selected_province.position_fortress
	add_child(fortress_position_edit)

	selected_province.position_fortress_changed.connect(
			fortress_position_edit.set_position
	)
	fortress_position_edit.position_changed.connect(
			_on_fortress_position_changed.bind(selected_province)
	)
	fortress_position_edit.drag_finished.connect(
			_on_fortress_drag_finished.bind(selected_province)
	)


func _on_world_loaded(world_visuals: WorldVisuals2D) -> void:
	if _province_selection != null:
		_province_selection.selected_province_changed.disconnect(_refresh)

	_province_selection = world_visuals.province_selection
	_edge_case = PolygonEditEdgeCase.new(world_visuals.world)

	_province_selection.selected_province_changed.connect(_refresh.unbind(1))

	if is_node_ready():
		_refresh()
	else:
		ready.connect(_refresh, ConnectFlags.CONNECT_ONE_SHOT)


func _on_army_position_changed(
		new_position: Vector2, province: Province
) -> void:
	province.position_army_host = new_position


func _on_fortress_position_changed(
		new_position: Vector2, province: Province
) -> void:
	province.position_fortress = new_position


func _on_army_drag_finished(
		start_position: Vector2, end_position: Vector2, province: Province
) -> void:
	if start_position == end_position:
		return

	# Note: we don't execute it since the position was already changed.
	_undo_redo.create_action("Move army in province")
	_undo_redo.add_do_property(province, &"position_army_host", end_position)
	_undo_redo.add_undo_property(
			province, &"position_army_host", start_position
	)
	_undo_redo.commit_action(false)


func _on_fortress_drag_finished(
		start_position: Vector2, end_position: Vector2, province: Province
) -> void:
	if start_position == end_position:
		return

	# Note: we don't execute it since the position was already changed.
	_undo_redo.create_action("Move fortress in province")
	_undo_redo.add_do_property(province, &"position_fortress", end_position)
	_undo_redo.add_undo_property(province, &"position_fortress", start_position)
	_undo_redo.commit_action(false)

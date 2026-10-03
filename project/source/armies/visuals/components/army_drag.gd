class_name ArmyDrag
extends Node
## Implements dragging an army with the mouse.

const _ARMY_VISUALS_SCENE: PackedScene = preload("uid://eso260jnknd4")

## Used to get currently selected/hovered army.
@export var _army_selection: ArmySelection
## Used to get visuals of currently selected army.
@export var _army_visuals_list: ArmyVisualsSetup
## Used to get currently hovered province.
@export var _province_visuals_input: ProvinceVisualsInput
## Used to get visuals of currently hovered province.
@export var _province_visuals_list: ProvinceVisualsContainer2D
## Used to implement undo/redo for the army's movement.
@export var _undo_redo: UndoRedoResource

## Used to move the army.
var _project: GameProject

## Keeps track of the visuals being dragged. May be null.
var _dragged_visuals: ArmyVisuals2D = null
## Used to reset the dragged visuals to their initial state. May be null.
var _drag_initial_parent: Node = null
## Used to reset the dragged visuals to their initial state.
var _drag_initial_position := Vector2.ZERO

## The army that is a preview and not actually an army. May be null.
var _preview_army: ArmyVisuals2D = null
## Used to check if the hovered province changed. May be null.
var _hovered_province: Province = null
## Used to check if the preview army's position changed.
var _preview_index: int = -1


func set_project(value: GameProject) -> void:
	_project = value


func reset() -> void:
	if _dragged_visuals != null:
		_dragged_visuals.modulate.a = 1.0
		_dragged_visuals.highlight_selected()
		_dragged_visuals.reparent(_drag_initial_parent)
		_dragged_visuals.position = _drag_initial_position
		_drag_initial_parent.move_child(_dragged_visuals, _dragged_index())
		_dragged_visuals = null
	_drag_initial_parent = null
	_drag_initial_position = Vector2.ZERO

	_remove_preview()
	_hovered_province = null
	_preview_index = -1


func _dragged_index() -> int:
	return (
			_project.game.world.armies_in_each_province
			.dictionary[_dragged_visuals.army.province_id()]
			.mapped_list[_dragged_visuals.army]
	)


func _refresh_preview() -> void:
	var something_changed: bool = false

	# Check if hovered province changed
	var new_province: Province = _province_visuals_input.hovered_province()
	if _hovered_province != new_province:
		_remove_preview()
		_hovered_province = new_province
		something_changed = true

	# Only create a preview when there is a hovered province
	if _hovered_province == null:
		return
	var preview_province: ProvinceVisuals2D = (
			_province_visuals_list.visuals_of(_hovered_province.id)
	)
	if preview_province == null:
		return

	# Check if position index changed
	var new_index: int = _calculated_preview_index(preview_province._army_stack)
	if _preview_index != new_index:
		_remove_preview()
		_preview_index = new_index
		something_changed = true

	if not something_changed:
		return

	# Create new preview army
	_preview_army = _ARMY_VISUALS_SCENE.instantiate() as ArmyVisuals2D
	_preview_army.is_invisible = true
	preview_province.add_army(_preview_army)
	preview_province.move_army(_preview_army, _preview_index)
	_preview_army.highlight_selected()


func _remove_preview() -> void:
	if _preview_army != null:
		NodeUtils.delete_node(_preview_army)
		_preview_army = null


func _calculated_preview_index(army_stack: ArmyStack2D) -> int:
	# Get the maximum index
	var army_list: Dictionary[Army, int] = (
			_project.game.world.armies_in_each_province
			.dictionary[_hovered_province.id].mapped_list
	)
	var maximum_index: int = army_list.size()
	if army_list.has(_dragged_visuals.army):
		maximum_index -= 1

	# Prevent division by zero
	var direction: Vector2 = army_stack.distance_between_armies
	var length_squared: float = direction.length_squared()
	if length_squared == 0.0:
		return maximum_index

	# Project the position onto the stack axis
	var local_position: Vector2 = (
			army_stack.to_local(_dragged_visuals.global_position)
	)
	var along_axis: float = local_position.dot(direction) / length_squared
	return clampi(roundi(along_axis), 0, maximum_index)


func _on_drag_started() -> void:
	var selected_army: Army = _army_selection.selected_army()
	if selected_army == null:
		return

	var hovered_army: Army = _army_selection.hovered_army()
	if hovered_army == null or hovered_army != selected_army:
		return

	_dragged_visuals = _army_visuals_list.visuals_of(selected_army)
	if _dragged_visuals == null:
		return

	# You are now dragging an army
	_drag_initial_parent = _dragged_visuals.get_parent()
	_drag_initial_position = _dragged_visuals.position
	_dragged_visuals.reparent(_army_visuals_list)
	_dragged_visuals.modulate.a = 0.5
	_dragged_visuals.remove_highlight()
	_preview_index = _dragged_index()
	_refresh_preview()
	get_viewport().set_input_as_handled()


func _on_drag_moved(delta: Vector2) -> void:
	if _dragged_visuals == null:
		return

	_dragged_visuals.position += delta
	_refresh_preview()


func _on_drag_ended() -> void:
	if _dragged_visuals == null:
		return

	var army: Army = _dragged_visuals.army
	var hovered_province: Province = _province_visuals_input.hovered_province()
	var province_id: int = (
			hovered_province.id if hovered_province != null else
			army.province_id()
	)
	var index: int = (
			_preview_index if hovered_province != null else
			_dragged_index()
	)

	# Reset the visuals first
	reset()

	_project.game.world.armies.undo_redo_move(
			army,
			province_id,
			index,
			_undo_redo,
			_project.game.world.armies_in_each_province
	)

	get_viewport().set_input_as_handled()

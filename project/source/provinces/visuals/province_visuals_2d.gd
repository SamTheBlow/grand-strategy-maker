class_name ProvinceVisuals2D
extends Node2D
## Visual representation of a [Province].

## Emitted on the release of left click.
signal clicked()
## Emitted on the press of right click.
signal right_clicked(is_double_click: bool)

signal mouse_entered()
signal mouse_exited()

@export_group("Outline types")
## Outline used when no other outline is used.
@export var _outline_none: OutlineSettings
## Outline used to highlight the province (e.g. when hovering it).
@export var _outline_highlight: OutlineSettings
## Outline used when the province is selected.
@export var _outline_selected: OutlineSettings
## Outline used to show the province as a valid target.
@export var _outline_target: OutlineSettings

## Hides buildings when false. (Does not always show buildings when true.)
var is_buildings_visible: bool = true:
	set = set_is_buildings_visible

## May be null, in which case LOD culling is disabled.
var lod: WorldLOD = null

var province: Province

## When true, locks the position and scale
## such that the visuals fit inside given preview rect.
var is_preview: bool = false
var preview_rect: Rect2

var _mouse_is_inside_area: bool = false

@onready var _outlined_polygon := %Polygon as OutlinedPolygon2D
@onready var _collision_shape := %CollisionShape as CollisionPolygon2D
@onready var _buildings := %Buildings as BuildingVisualsContainer2D
@onready var _army_stack := %ArmyStack2D as ArmyStack2D


func _ready() -> void:
	# Give this node a unique meaningful name
	name = "Province" + str(province.id)

	var _input_area := %InputArea as CollisionObject2D
	_input_area.mouse_entered.connect(set.bind(&"_mouse_is_inside_area", true))
	_input_area.mouse_entered.connect(mouse_entered.emit)
	_input_area.mouse_exited.connect(set.bind(&"_mouse_is_inside_area", false))
	_input_area.mouse_exited.connect(mouse_exited.emit)

	_refresh_visibility()
	if lod != null:
		lod.changed.connect(_refresh_visibility)

	(%ProvinceColorUpdate as ProvinceColorUpdate).setup(province)

	_refresh_stack_position()
	province.position_army_host_changed.connect(_refresh_stack_position)
	_refresh_polygon()
	province.shape.changed.connect(_refresh_polygon)

	_buildings.province = province


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	var event_mouse_button := event as InputEventMouseButton

	if (
			event_mouse_button.button_index == MOUSE_BUTTON_LEFT
			and not event_mouse_button.pressed
			and _mouse_is_inside_area
	):
		get_viewport().set_input_as_handled()
		clicked.emit()
	elif (
			event_mouse_button.button_index == MOUSE_BUTTON_RIGHT
			and event_mouse_button.pressed
			and _mouse_is_inside_area
	):
		get_viewport().set_input_as_handled()
		right_clicked.emit(event_mouse_button.double_click)


## Returns the global army host position.
func global_position_army_host() -> Vector2:
	return to_global(province.position_army_host)


func add_army(army_visuals: ArmyVisuals2D) -> void:
	if not is_node_ready():
		push_error("Node is not ready yet.")
		return
	if army_visuals.get_parent() != null:
		push_error("Army visuals already have a parent node.")
		return
	_army_stack.add_child(army_visuals)


func move_army(army_visuals: ArmyVisuals2D, position_index: int) -> void:
	_army_stack.move_child(army_visuals, position_index)


func highlight() -> void:
	_outlined_polygon.outline_settings = _outline_highlight


func highlight_selected() -> void:
	_outlined_polygon.outline_settings = _outline_selected


func highlight_target() -> void:
	_outlined_polygon.outline_settings = _outline_target


## Hides the outline around this province.
func remove_highlight() -> void:
	_outlined_polygon.outline_settings = _outline_none


func set_is_buildings_visible(value: bool) -> void:
	is_buildings_visible = value
	if is_node_ready():
		_refresh_visibility()


## Debug function that clearly highlights this province on the world map.
## To remove the highlight, pass false as an argument.
func highlight_debug(
		outline_color := Color.BLUE, show_highlight: bool = true
) -> void:
	if has_node(^"DebugHighlight"):
		remove_child(get_node(^"DebugHighlight"))

	if not show_highlight:
		return

	var outline_settings := OutlineSettings.new()
	outline_settings.outline_color = outline_color
	outline_settings.outline_width = 8.0

	var debug_highlight := OutlinedPolygon2D.new()
	debug_highlight.name = &"DebugHighlight"
	debug_highlight.color = Color(0.0, 0.0, 0.0, 0.0)
	debug_highlight.polygon = province.shape.polygon_points
	debug_highlight.outline_settings = outline_settings
	add_child(debug_highlight)


func _refresh_stack_position(_position := Vector2.ZERO) -> void:
	_army_stack.position = province.position_army_host


func _refresh_polygon() -> void:
	if is_preview:
		_refresh_preview()

	_outlined_polygon.polygon = province.shape.polygon_points
	_collision_shape.polygon = province.shape.polygon_points


func _refresh_preview() -> void:
	var province_rect := Rect2(
			province.shape.x_min,
			province.shape.y_min,
			# Prevent division by zero
			maxf(1.0, province.shape.x_max - province.shape.x_min),
			maxf(1.0, province.shape.y_max - province.shape.y_min)
	)

	# Determine the scale ratio (e.g. if the province
	# is 3x bigger than it should be, then we need to scale by 1/3)
	# To preserve the aspect ratio,
	# we need to multiply by the smallest of the two ratios.
	var scale_ratio: float = minf(
			preview_rect.size.x / province_rect.size.x,
			preview_rect.size.y / province_rect.size.y
	)
	position = (
			preview_rect.position + 0.5 * preview_rect.size
			- scale_ratio * (province_rect.position + 0.5 * province_rect.size)
	)
	scale = Vector2(scale_ratio, scale_ratio)


## Shows or hides this province's polygon shape and buildings.
func _refresh_visibility() -> void:
	if is_preview:
		return
	elif lod == null:
		_outlined_polygon.visible = true
		_buildings.visible = is_buildings_visible
		return

	_outlined_polygon.visible = lod.detail_level > WorldLOD.DetailLevel.LOW
	_buildings.visible = (
			lod.detail_level > WorldLOD.DetailLevel.LOW
			and is_buildings_visible
	)

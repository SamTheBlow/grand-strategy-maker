class_name ProvinceBatchRender
extends Node2D
## Draws every province as a single batched canvas item.
##
## This node exists for performance reasons.
## It's meant to improve performance on very large maps.

@export var lod: WorldLOD

## May be null, in which case nothing is rendered.
var provinces: Provinces = null:
	set(value):
		if provinces != null:
			provinces.added.disconnect(_connect_province)
			provinces.added.disconnect(queue_redraw)
			provinces.removed.disconnect(_disconnect_province)
			provinces.removed.disconnect(queue_redraw)
			for province in provinces.list:
				_disconnect_province(province)

		provinces = value
		queue_redraw()

		if provinces != null:
			for province in provinces.list:
				_connect_province(province)
			provinces.added.connect(_connect_province)
			provinces.added.connect(queue_redraw.unbind(1))
			provinces.removed.connect(_disconnect_province)
			provinces.removed.connect(queue_redraw.unbind(1))


func _ready() -> void:
	_refresh_visibility()
	lod.changed.connect(_refresh_visibility)


func _draw() -> void:
	const DEFAULT_FILL_COLOR := Color.WHITE

	if provinces == null:
		return

	for province in provinces.list:
		var country: Country = province.owner_country
		var color: Color = (
				DEFAULT_FILL_COLOR if country == null else country.color
		)
		draw_colored_polygon(province.shape.polygon_points, color)


func _refresh_visibility() -> void:
	visible = lod.detail_level <= WorldLOD.DetailLevel.LOW


func _connect_province(province: Province) -> void:
	province.owner_changed.connect(queue_redraw.unbind(1))
	province.shape.changed.connect(queue_redraw)


func _disconnect_province(province: Province) -> void:
	province.owner_changed.disconnect(queue_redraw)
	province.shape.changed.disconnect(queue_redraw)

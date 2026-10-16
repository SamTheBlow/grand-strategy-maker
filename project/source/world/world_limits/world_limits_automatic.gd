class_name WorldLimitsAutomatic
extends WorldLimits.WorldLimitsBase
## Determines world limits based on given [Provinces].

## The amount of free space to add on each side, in pixels.
const _PADDING: int = 200

var _is_enabled: bool = true
var _current_limits: Vector4i = WorldLimits.DEFAULT_LIMITS
var _provinces: Provinces


func _init(provinces: Provinces) -> void:
	_provinces = provinces

	_refresh()

	for province in provinces.list:
		province.shape.changed.connect(_refresh)
	provinces.added.connect(_on_province_added)
	provinces.removed.connect(_on_province_removed)


## When false, does not recalculate limits when provinces are added or removed.
## Useful for performance reasons when adding/removing provinces in bulk.
func set_automatic_update_enabled(is_enabled: bool) -> void:
	if _is_enabled == is_enabled:
		return
	_is_enabled = is_enabled
	_refresh()


func value() -> Vector4i:
	return _current_limits


## If the province list is empty, applies the default world limits instead.
func _refresh() -> void:
	if not _is_enabled:
		return
	elif _provinces.list.is_empty():
		_current_limits = WorldLimits.DEFAULT_LIMITS
		return

	var x_min: float = INF
	var x_max: float = -INF
	var y_min: float = INF
	var y_max: float = -INF
	for province in _provinces.list:
		x_min = minf(x_min, province.shape.x_min)
		x_max = maxf(x_max, province.shape.x_max)
		y_min = minf(y_min, province.shape.y_min)
		y_max = maxf(y_max, province.shape.y_max)

	var old_value: Vector4i = _current_limits

	_current_limits = Vector4i(
			int(x_min) - _PADDING,
			int(y_min) - _PADDING,
			int(x_max) + _PADDING,
			int(y_max) + _PADDING
	)

	if _current_limits != old_value:
		changed.emit()


func _on_province_added(province: Province) -> void:
	_refresh()
	province.shape.changed.connect(_refresh)


func _on_province_removed(province: Province) -> void:
	province.shape.changed.disconnect(_refresh)
	_refresh()

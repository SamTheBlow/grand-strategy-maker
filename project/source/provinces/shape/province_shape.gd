class_name ProvinceShape
## Provides precomputed values that are exposed for performance reasons.

signal position_changed(offset: Vector2)
signal changed()

const _DEFAULT_POLYGON_POINT_0 := 300.0 * Vector2(-0.5, 0.288675135)
const _DEFAULT_POLYGON_POINT_1 := 300.0 * Vector2(0.5, 0.288675135)
const _DEFAULT_POLYGON_POINT_2 := 300.0 * Vector2(0.0, -0.577350269)
const _DEFAULT_SHAPE_CENTROID := Vector2(0.0, 3e-07)
const _DEFAULT_SHAPE_LEFTMOST: float = -0.5
const _DEFAULT_SHAPE_RIGHTMOST: float = 0.5
const _DEFAULT_SHAPE_TOPMOST: float = -0.577350269
const _DEFAULT_SHAPE_BOTTOMMOST: float = 0.288675135

## Do not edit this list directly!
var polygon_points: PackedVector2Array = _default_polygon()

## This shape's centroid (center of mass).
## Precomputed; do not edit this value!
var centroid: Vector2 = _DEFAULT_SHAPE_CENTROID

## This shape's leftmost point.
## Precomputed; do not edit this value!
var x_min: float = _DEFAULT_SHAPE_LEFTMOST
## This shape's rightmost point.
## Precomputed; do not edit this value!
var x_max: float = _DEFAULT_SHAPE_RIGHTMOST
## This shape's topmost point.
## Precomputed; do not edit this value!
var y_min: float = _DEFAULT_SHAPE_TOPMOST
## This shape's bottommost point.
## Precomputed; do not edit this value!
var y_max: float = _DEFAULT_SHAPE_BOTTOMMOST


func is_default_shape() -> bool:
	var default_points: PackedVector2Array = _default_polygon()
	if polygon_points.size() != default_points.size():
		return false
	for i in default_points.size():
		if polygon_points[i] != default_points[i]:
			return false
	return true


## If given polygon is invalid, sets the shape to the default polygon instead.
func set_polygon_points(value: PackedVector2Array) -> void:
	if value.size() >= 3:
		polygon_points = value
		_compute_values()
	else:
		polygon_points = _default_polygon()
		centroid = _DEFAULT_SHAPE_CENTROID
		x_min = _DEFAULT_SHAPE_LEFTMOST
		x_max = _DEFAULT_SHAPE_RIGHTMOST
		y_min = _DEFAULT_SHAPE_TOPMOST
		y_max = _DEFAULT_SHAPE_BOTTOMMOST

	changed.emit()


## Moves the entire shape by given amount.
func move_relative(offset: Vector2) -> void:
	if offset == Vector2.ZERO:
		return

	for i in polygon_points.size():
		polygon_points[i] += offset

	centroid += offset
	x_min += offset.x
	x_max += offset.x
	y_min += offset.y
	y_max += offset.y
	position_changed.emit(offset)
	changed.emit()


## Assumes given index is valid.
func insert_point(index: int, position: Vector2) -> void:
	polygon_points.insert(index, position)
	_compute_values()
	changed.emit()


## Assumes given index is valid.
## No effect if this action would invalidate the polygon.
func remove_point(index: int) -> void:
	if polygon_points.size() == 3:
		return
	polygon_points.remove_at(index)
	_compute_values()
	changed.emit()


## Assumes given index is valid.
func move_point_to(index: int, position: Vector2) -> void:
	polygon_points[index] = position
	_compute_values()
	changed.emit()


## Copies the state of given instance.
func copy_other(province_shape: ProvinceShape) -> void:
	polygon_points = province_shape.polygon_points
	centroid = province_shape.centroid
	x_min = province_shape.x_min
	x_max = province_shape.x_max
	y_min = province_shape.y_min
	y_max = province_shape.y_max
	changed.emit()


# This has to be a static function instead of a constant property.
# Arrays are passed by reference, so a constant array means
# it's the reference that can't change, not the contents.
# So confusingly, a constant array's contents actually are not constant.
## Returns a new array containing the default polygon shape.
static func _default_polygon() -> PackedVector2Array:
	return [
		_DEFAULT_POLYGON_POINT_0,
		_DEFAULT_POLYGON_POINT_1,
		_DEFAULT_POLYGON_POINT_2,
	]


func _compute_values() -> void:
	centroid = Vector2.ZERO
	x_min = INF
	x_max = -INF
	y_min = INF
	y_max = -INF
	for point in polygon_points:
		centroid += point
		x_min = minf(x_min, point.x)
		x_max = maxf(x_max, point.x)
		y_min = minf(y_min, point.y)
		y_max = maxf(y_max, point.y)
	centroid /= polygon_points.size()

class_name WorldLimitWiring
extends Node
## Provides position limits and zoom limits according to some [WorldLimits].
## Resets the camera components when a new world is loaded.
## Moves the camera to the center of the world map.

signal limits_changed(left: float, top: float, right: float, bottom: float)

const _MAXIMUM_ZOOM: float = 1.0

@export var _camera: CustomCamera2D
@export var _camera_zoom: CameraZoom
@export var _inertia: Inertia

var _world_limits: WorldLimits:
	set(value):
		if _world_limits != null:
			_world_limits.current_limits_changed.disconnect(_refresh)

		_world_limits = value

		_refresh()
		_world_limits.current_limits_changed.connect(_refresh)


func _ready() -> void:
	# The minimum zoom depends on the viewport size.
	get_viewport().size_changed.connect(_refresh_zoom_limits)


func _on_world_loaded(world_visuals: WorldVisuals2D) -> void:
	_camera_zoom.reset()
	_inertia.stop()
	_world_limits = world_visuals.project.game.world.limits()

	# Move camera to center of world map
	_camera.move_to(_world_limits.center())


func _refresh() -> void:
	_refresh_limits()
	_refresh_zoom_limits()


func _refresh_limits() -> void:
	limits_changed.emit(
			float(_world_limits.limit_left()),
			float(_world_limits.limit_top()),
			float(_world_limits.limit_right()),
			float(_world_limits.limit_bottom())
	)


func _refresh_zoom_limits() -> void:
	if not is_inside_tree():
		return
	var minimum_zoom: float = _minimum_zoom()
	var maximum_zoom: float = maxf(_MAXIMUM_ZOOM, minimum_zoom)
	_camera_zoom.set_zoom_limits(minimum_zoom, maximum_zoom)


## Currently, you can zoom out such that the world takes half the screen.
func _minimum_zoom() -> float:
	if (
			_world_limits == null
			or _world_limits.width() == 0
			or _world_limits.height() == 0
	):
		return -INF

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	return 0.5 * minf(
			viewport_size.x / _world_limits.width(),
			viewport_size.y / _world_limits.height()
	)

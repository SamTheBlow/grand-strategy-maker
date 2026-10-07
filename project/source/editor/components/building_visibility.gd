extends Node
## Applies building visibility to province visuals according to given setting.

@export var _setting: ItemBool


func apply_to(province_visuals: ProvinceVisuals2D) -> void:
	province_visuals.set_is_buildings_visible(_setting.value)
	_setting.value_changed.connect(province_visuals.set_is_buildings_visible)

class_name GameWorld
## A [Game]'s world.

signal background_color_changed(new_color: Color)

var army_data := ArmyData.new()

## Do not overwrite!
var armies := Armies.new()
## Do not overwrite!
var provinces := Provinces.new()

var background_color: Color = default_clear_color():
	set(value):
		if background_color == value:
			return
		background_color = value
		background_color_changed.emit(background_color)

var decorations := WorldDecorations.new()

var armies_in_each_province := ArmiesInEachProvince.new(provinces, armies)
var armies_of_each_country: ArmiesOfEachCountry
var provinces_of_each_country: ProvincesOfEachCountry

var _limits := WorldLimits.new(provinces)

## Multiple building types is already implemented for saving/loading,
## however multiple building types is still not fully implemented.
## The first element in the list is assumed to be the fortress type,
## and other building types will be ignored.
var _building_data_list: Array[BuildingData] = []


func _init(game: Game) -> void:
	armies_of_each_country = ArmiesOfEachCountry.new(game.countries, armies)
	provinces_of_each_country = (
			ProvincesOfEachCountry.new(game.countries, provinces)
	)


func limits() -> WorldLimits:
	return _limits


func fortress_data() -> BuildingData:
	if _building_data_list.is_empty():
		var new_fortress_data := BuildingData.new()
		new_fortress_data.building_name = "Fortress"
		new_fortress_data.defense_multiplier = 2.0
		new_fortress_data.money_cost = 1000
		_building_data_list.append(new_fortress_data)

	return _building_data_list[0]


static func default_clear_color() -> Color:
	return ProjectSettings.get_setting(
			"rendering/environment/defaults/default_clear_color",
			Color(0.3, 0.3, 0.3)
	)

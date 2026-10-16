class_name Province
## In a game, a province represents a certain area on the world map.
## It may be of any size or shape, and
## it may or may not be under the control of a [Country].

signal name_changed(new_name: String)
signal link_added(linked_province_id: int)
signal link_removed(linked_province_id: int)
signal links_reset()
signal owner_changed(this: Province)
signal position_army_host_changed(new_position: Vector2)
signal position_fortress_changed(new_position: Vector2)

## Unique identifier. Useful for saving/loading, networking, etc.
var id: int = -1

## This province's name.
var name: String = "":
	set(value):
		if name == value:
			return
		name = value
		name_changed.emit(name)

## The [Country] in control of this province.
## May be null, in which case this province is not controlled by any country.
var owner_country: Country = null:
	set(value):
		if value == owner_country:
			return
		owner_country = value
		owner_changed.emit(self)

## Do not set this to a different instance!
var shape := ProvinceShape.new()

## Where this province's [ArmyStack2D] will be positioned.
var position_army_host := Vector2.ZERO:
	set(value):
		if position_army_host == value:
			return
		position_army_host = value
		position_army_host_changed.emit(position_army_host)

## Where this province's [Building] will be positioned.
var position_fortress := Vector2(80.0, 56.0):
	set(value):
		if position_fortress == value:
			return
		position_fortress = value
		position_fortress_changed.emit(position_fortress)

var buildings := Buildings.new()

## A list of IDs for all the provinces that are
## neighboring this province, e.g. when moving armies.
var _linked_province_ids: Array[int] = []

var _population := IntWithSignals.new(0, true)
var _money_income := IntWithSignals.new()


func _init() -> void:
	shape.position_changed.connect(_on_shape_moved)


## The default name this province would have if it didn't have a name.
func default_name() -> String:
	return "Province " + str(id)


## This province's name, or its default name if the name is empty.
func name_or_default() -> String:
	if name != "":
		return name
	else:
		return default_name()


## Returns a list of all the provinces linked to this province.
## Feel free to edit the list.
func linked_province_ids() -> Array[int]:
	return _linked_province_ids


func is_linked_to(province_id: int) -> bool:
	return _linked_province_ids.has(province_id)


## No effect if given province is already linked.
## No effect if given province id is the same as this province's.
func add_link(province_id: int) -> void:
	if province_id == id or _linked_province_ids.has(province_id):
		return
	_linked_province_ids.append(province_id)
	link_added.emit(province_id)


## No effect if given province is already not linked.
func remove_link(province_id: int) -> void:
	if _linked_province_ids.has(province_id):
		_linked_province_ids.erase(province_id)
		link_removed.emit(province_id)


## Adds given province to the links if it's not a link, otherwise removes it.
func toggle_link(province_id: int) -> void:
	if _linked_province_ids.has(province_id):
		remove_link(province_id)
	else:
		add_link(province_id)


func reset_links() -> void:
	_linked_province_ids = []
	links_reset.emit()


func population() -> IntWithSignals:
	return _population


func money_income() -> IntWithSignals:
	return _money_income


## Returns true if all the following conditions are met:
## - Given [Country] has military access to this province.
## - This province is not unclaimed.
## - At least one of this province's links is either unclaimed or
##   under control of a country which given country cannot move into.
func is_frontline(country: Country, provinces: Provinces) -> bool:
	if not country.has_permission_to_move_into_country(owner_country):
		return false

	if owner_country == null:
		return false

	for linked_province in provinces.links_of(id):
		if (
				linked_province.owner_country == null
				or not country.has_permission_to_move_into_country(
						linked_province.owner_country
				)
		):
			return true

	return false


## Returns true if all the following conditions are met:
## - Given [Country] has military access to this province.
## - This province is not unclaimed.
## - At least one of this province's links is either unclaimed or
##   under control of a country which given country is currently fighting.
func is_war_frontline(country: Country, provinces: Provinces) -> bool:
	if not country.has_permission_to_move_into_country(owner_country):
		return false

	if owner_country == null:
		return false

	for linked_province in provinces.links_of(id):
		if (
				linked_province.owner_country == null
				or
				country.relationships
				.with_country(linked_province.owner_country).is_fighting()
		):
			return true

	return false


## Returns the nearest province(s).
## It may return more than one province if there's a tie.
## It may also return an empty array if there is no valid province.
## Optionally, you can provide a filter callable.
## The filter must take one input of type Province and must return a boolean.
## The filter lets you get the nearest province that fulfills
## specific conditions. (e.g. "the nearest province that you own")
func nearest_provinces(
		provinces: Provinces,
		province_filter: Callable = (
				func(_province: Province) -> bool: return true
		)
) -> Array[Province]:
	var calculation := NearestProvinces.new()
	calculation.calculate(id, provinces, province_filter)
	return calculation.furthest_links


func _on_shape_moved(offset: Vector2) -> void:
	position_army_host += offset
	position_fortress += offset

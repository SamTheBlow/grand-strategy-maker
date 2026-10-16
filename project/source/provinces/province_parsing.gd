class_name ProvinceParsing
## Parses raw data from/to [Province] instances.

const _ID_KEY: String = "id"
const _NAME_KEY: String = "name"
const _LINKS_KEY: String = "links"
const _POSITION_ARMY_HOST_X_KEY: String = "position_army_host_x"
const _POSITION_ARMY_HOST_Y_KEY: String = "position_army_host_y"
const _POSITION_FORTRESS_X_KEY: String = "position_fortress_x"
const _POSITION_FORTRESS_Y_KEY: String = "position_fortress_y"
const _SHAPE_KEY: String = "shape"
const _OWNER_ID_KEY: String = "owner_country_id"
const _POPULATION_KEY: String = "population"
const _BUILDINGS_KEY: String = "buildings"
const _INCOME_MONEY_KEY: String = "income_money"

# Specific to province shape data
const _SHAPE_X_KEY: String = "x"
const _SHAPE_Y_KEY: String = "y"

# Specific to [Population] data
const _POPULATION_SIZE_KEY: String = "size"

# Specific to [Building] data
const _BUILDING_TYPE_KEY: String = "type"


## NOTE: Given game's countries must already be loaded before using this.
##
## Clears already existing provinces in given game.
##
## Always succeeds. Ignores unrecognized data.
## When data is invalid, uses the default value instead.
## Discards provinces with an already-in-use id.
static func load_from_raw_data(raw_data: Variant, game: Game) -> void:
	game.world.provinces.clear()

	if raw_data is not Array:
		return
	var raw_array: Array = raw_data

	for province_data: Variant in raw_array:
		_load_province_from_raw(province_data, game)

	# Validate province links (needs to be done after all provinces are loaded)
	for province_id in game.world.provinces.map:
		var link_id_list: Array[int] = (
				game.world.provinces.map[province_id].linked_province_ids()
		)
		for i in link_id_list.size():
			if not game.world.provinces.map.has(link_id_list[i]):
				link_id_list.remove_at(i)
				i -= 1


static func to_raw_array(province_list: Array[Province]) -> Array:
	var output: Array = []

	for province in province_list:
		var province_data: Dictionary = { _ID_KEY: province.id }

		# Name
		if province.name != "":
			province_data.merge({ _NAME_KEY: province.name })

		# Owner country
		if province.owner_country != null:
			province_data.merge({ _OWNER_ID_KEY: province.owner_country.id })

		# Links
		if not province.linked_province_ids().is_empty():
			province_data.merge({
				_LINKS_KEY: Array(province.linked_province_ids().duplicate())
			})

		# Shape
		if not province.shape.is_default_shape():
			var shape_vertices_x: Array = []
			var shape_vertices_y: Array = []
			for point in province.shape.polygon_points:
				shape_vertices_x.append(point.x)
				shape_vertices_y.append(point.y)
			province_data.merge({
				_SHAPE_KEY: {
					_SHAPE_X_KEY: shape_vertices_x,
					_SHAPE_Y_KEY: shape_vertices_y,
				}
			})

		# Position army host
		if province.position_army_host.x != 0.0:
			province_data.merge({
				_POSITION_ARMY_HOST_X_KEY: province.position_army_host.x
			})
		if province.position_army_host.y != 0.0:
			province_data.merge({
				_POSITION_ARMY_HOST_Y_KEY: province.position_army_host.y
			})

		# Position fortress
		if province.position_fortress.x != 0.0:
			province_data.merge({
				_POSITION_FORTRESS_X_KEY: province.position_fortress.x
			})
		if province.position_fortress.y != 0.0:
			province_data.merge({
				_POSITION_FORTRESS_Y_KEY: province.position_fortress.y
			})

		# Population
		if province.population().value != 0:
			province_data.merge({
				_POPULATION_KEY:
					{ _POPULATION_SIZE_KEY: province.population().value }
			})

		# Money income
		if province.money_income().value != 0:
			province_data.merge(
					{ _INCOME_MONEY_KEY: province.money_income().value }
			)

		# Buildings
		var buildings_data: Array = []
		for building in province.buildings.list():
			buildings_data.append({ _BUILDING_TYPE_KEY: 0 })
		if not buildings_data.is_empty():
			province_data.merge({ _BUILDINGS_KEY: buildings_data })

		output.append(province_data)

	return output


## Applies given raw data to given province.
## Not all data is applied: id, links, shape, and positions are ignored.
static func apply_raw_data(
		province: Province, raw_data: Variant, game: Game
) -> void:
	if raw_data is not Dictionary:
		return
	var raw_dict: Dictionary = raw_data

	# Name
	if ParseUtils.dictionary_has_string(raw_dict, _NAME_KEY):
		province.name = raw_dict[_NAME_KEY]

	# Owner country
	if ParseUtils.dictionary_has_number(raw_dict, _OWNER_ID_KEY):
		var country_id: int = (
				ParseUtils.dictionary_int(raw_dict, _OWNER_ID_KEY)
		)
		province.owner_country = game.countries.map.get(country_id)

	# Population
	province.population().value = (
			_population_from_raw(raw_dict.get(_POPULATION_KEY))
	)

	# Money income
	if ParseUtils.dictionary_has_number(raw_dict, _INCOME_MONEY_KEY):
		province.money_income().value = (
				ParseUtils.dictionary_int(raw_dict, _INCOME_MONEY_KEY)
		)

	# Buildings
	_load_buildings_from_raw(province, raw_dict, game)


static func _load_province_from_raw(raw_data: Variant, game: Game) -> void:
	if raw_data is not Dictionary:
		return
	var raw_dict: Dictionary = raw_data

	# Province id (mandatory)
	if not ParseUtils.dictionary_has_number(raw_dict, _ID_KEY):
		return
	var id: int = ParseUtils.dictionary_int(raw_dict, _ID_KEY)

	# The id must be valid and available.
	if not game.world.provinces._unique_id_system.is_id_available(id):
		return

	var province := Province.new()
	province.id = id

	# Name
	if ParseUtils.dictionary_has_string(raw_dict, _NAME_KEY):
		province.name = raw_dict[_NAME_KEY]

	# Links
	if ParseUtils.dictionary_has_array(raw_dict, _LINKS_KEY):
		var links_array: Array = raw_dict[_LINKS_KEY]
		for link_data: Variant in links_array:
			if ParseUtils.is_number(link_data):
				province.linked_province_ids().append(
						ParseUtils.number_as_int(link_data)
				)

	# Shape
	province.shape.set_polygon_points(
			_polygon_shape_from_raw(raw_dict.get(_SHAPE_KEY))
	)

	# Position of the host army
	province.position_army_host = _position_army_host_from_raw(raw_dict)

	# Position of the fortress
	province.position_fortress = _position_fortress_from_raw(raw_dict)

	# Owner country
	if ParseUtils.dictionary_has_number(raw_dict, _OWNER_ID_KEY):
		var country_id: int = (
				ParseUtils.dictionary_int(raw_dict, _OWNER_ID_KEY)
		)
		province.owner_country = game.countries.map.get(country_id)

	# Population
	province.population().value = (
			_population_from_raw(raw_dict.get(_POPULATION_KEY))
	)

	# Money income
	if ParseUtils.dictionary_has_number(raw_dict, _INCOME_MONEY_KEY):
		province.money_income().value = (
				ParseUtils.dictionary_int(raw_dict, _INCOME_MONEY_KEY)
		)

	# Buildings
	_load_buildings_from_raw(province, raw_dict, game)

	game.world.provinces.add(province)


## Returns an empty array if data is invalid.
static func _polygon_shape_from_raw(raw_data: Variant) -> PackedVector2Array:
	if raw_data is not Dictionary:
		return PackedVector2Array()
	var raw_dict: Dictionary = raw_data

	var shape_x_array: Array = []
	if ParseUtils.dictionary_has_array(raw_dict, _SHAPE_X_KEY):
		shape_x_array = raw_dict[_SHAPE_X_KEY]

	var shape_y_array: Array = []
	if ParseUtils.dictionary_has_array(raw_dict, _SHAPE_Y_KEY):
		shape_y_array = raw_dict[_SHAPE_Y_KEY]

	# If one has more points than the other, ignore the extra points
	var number_of_points: int = (
			mini(shape_x_array.size(), shape_y_array.size())
	)

	if number_of_points < 3:
		return PackedVector2Array()

	var polygon_points: PackedVector2Array = []
	for i in number_of_points:
		# Avoid using [ParseUtils] here, for performance reasons
		# Yes this means number strings are not accepted here
		if not (
				(shape_x_array[i] is float or shape_x_array[i] is int)
				and (shape_y_array[i] is float or shape_y_array[i] is int)
		):
			return PackedVector2Array()

		polygon_points.append(Vector2(shape_x_array[i], shape_y_array[i]))

	return polygon_points


static func _position_army_host_from_raw(raw_dict: Dictionary) -> Vector2:
	var x_data: Variant = raw_dict.get(_POSITION_ARMY_HOST_X_KEY)
	var position_x: float = 0.0
	if ParseUtils.is_number(x_data):
		position_x = ParseUtils.number_as_float(x_data)

	var y_data: Variant = raw_dict.get(_POSITION_ARMY_HOST_Y_KEY)
	var position_y: float = 0.0
	if ParseUtils.is_number(y_data):
		position_y = ParseUtils.number_as_float(y_data)

	return Vector2(position_x, position_y)


static func _position_fortress_from_raw(raw_dict: Dictionary) -> Vector2:
	var x_data: Variant = raw_dict.get(_POSITION_FORTRESS_X_KEY)
	var position_x: float = 0.0
	if ParseUtils.is_number(x_data):
		position_x = ParseUtils.number_as_float(x_data)

	var y_data: Variant = raw_dict.get(_POSITION_FORTRESS_Y_KEY)
	var position_y: float = 0.0
	if ParseUtils.is_number(y_data):
		position_y = ParseUtils.number_as_float(y_data)

	return Vector2(position_x, position_y)


static func _population_from_raw(raw_data: Variant) -> int:
	if raw_data is not Dictionary:
		return 0
	var raw_dict: Dictionary = raw_data

	if ParseUtils.dictionary_has_number(raw_dict, _POPULATION_SIZE_KEY):
		return maxi(
				0, ParseUtils.dictionary_int(raw_dict, _POPULATION_SIZE_KEY)
		)

	return 0


static func _load_buildings_from_raw(
		province: Province, raw_dict: Dictionary, game: Game
) -> void:
	if not ParseUtils.dictionary_has_array(raw_dict, _BUILDINGS_KEY):
		return
	var raw_buildings_array := raw_dict[_BUILDINGS_KEY] as Array
	for building_data: Variant in raw_buildings_array:
		if building_data is not Dictionary:
			continue
		var building_dict: Dictionary = building_data
		if not ParseUtils.dictionary_has_number(
				building_dict, _BUILDING_TYPE_KEY
		):
			continue
		if ParseUtils.dictionary_int(building_dict, _BUILDING_TYPE_KEY) == 0:
			province.buildings.add(
					Building.new(game.world.fortress_data(), province.id)
			)

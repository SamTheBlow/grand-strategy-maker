class_name Countries
## An encapsulated list of [Country] objects.

signal added(country: Country)
signal removed(country: Country)
signal order_changed(country_id: int, old_index: int, new_index: int)

## The list, as an array.
## It's exposed for performance reasons. Do not edit this list!
var list: Array[Country] = []

## The list, as a dictionary. Maps a country id to its country.
## Use this list to quickly get a country by its id.
## It's exposed for performance reasons. Do not edit this list!
var map: Dictionary[int, Country] = {}

var _unique_id_system := UniqueIdSystem.new()


## If given country's id is invalid (i.e. a negative number),
## automatically gives it a new unique id.
##
## No effect if given country's id is already in use,
## or if given country is already in the list.
func add(country: Country) -> void:
	_add(country)


## No effect if given country is not on the list.
func remove(country_id: int) -> void:
	if not map.has(country_id):
		return
	var country: Country = map[country_id]

	map.erase(country_id)
	list.erase(country)

	# We have to unclaim the id because, if we want to bring this country
	# back in the list later with the same id, the id needs to not be in use.
	_unique_id_system.unclaim_id(country_id)

	removed.emit(country)


## Shuffles the list's order using given [GameRNG].
func shuffle_order(rng: GameRNG) -> void:
	for i in list.size() - 1:
		reorder(list[rng.randi_range(i, list.size() - 1)].id, i)


## Moves country with given id to be at given index position in the list.
## No effect if either input is invalid.
func reorder(country_id: int, new_index: int) -> void:
	# Validate new index
	if new_index < 0 or new_index >= list.size():
		return

	# Get old index
	var old_index: int = list.find(map.get(country_id))

	# Validate old index
	if old_index < 0 or old_index == new_index:
		return

	# Apply change
	list.insert(new_index, list.pop_at(old_index))
	order_changed.emit(country_id, old_index, new_index)


## Removes a country, using given [UndoRedoResource] system.
## Ensures that when we undo, everything is exactly as it was before.
func undo_redo_remove(
		country: Country, undo_redo: UndoRedoResource, game: Game
) -> void:
	# Save relationships state before removal
	var raw_relationships: Array = (
			DiplomacyRelationshipParsing.to_raw_array(country.relationships)
	)

	# Save which other countries referenced this country
	var referencing_country_ids: Array[int] = []
	for other_id in map:
		if map[other_id].relationships.list.has(country):
			referencing_country_ids.append(other_id)

	# Save all of this country's armies and their positions
	var armies_with_positions: Array[ArmyWithPositions] = (
			game.world.armies.list_with_positions(
					game.world.armies_of_each_country
					.dictionary[country].list.keys(),
					game.world.armies_in_each_province
			)
	)

	undo_redo.create_action("Delete country")
	undo_redo.add_do_method(remove.bind(country.id))

	# Ensure the country's position in the list is restored on undo
	undo_redo.add_undo_method(_add.bind(country, list.find(country)))

	# Ensure the country's relationships are restored on undo
	undo_redo.add_undo_method(_restore_relationships.bind(
			country, raw_relationships, referencing_country_ids
	))

	# Ensure province ownership is restored on undo
	var province_id_list: Array[int] = []
	for province in game.world.provinces.list:
		if province.owner_country == country:
			province_id_list.append(province.id)
	undo_redo.add_undo_method(_restore_province_ownership.bind(
			country, province_id_list, game.world.provinces
	))

	# Ensure the country's armies are restored on undo
	undo_redo.add_undo_method(game.world.armies.add_list_with_positions.bind(
			armies_with_positions, game.world.armies_in_each_province
	))

	# Ensure player control over this country is restored on undo
	var player_id_list: Array[int] = []
	for game_player in game.game_players.list:
		if game_player.playing_country == country:
			player_id_list.append(game_player.id)
	undo_redo.add_undo_method(_restore_player_control.bind(
			country, player_id_list, game.game_players
	))

	# Ensure the turn system's playing country is updated, when applicable
	if game.turn.playing_country() == country:
		undo_redo.add_do_method(game.turn.set_playing_country.bind(null))
		undo_redo.add_undo_method(game.turn.set_playing_country.bind(country))

	undo_redo.commit_action()


## Restores relationships after a country is un-done (re-added).
## Re-creates the country's own relationships from raw data
## and re-inserts this country into other countries' relationship lists.
func _restore_relationships(
		country: Country,
		raw_relationships: Array,
		referencing_country_ids: Array[int]
) -> void:
	# Restore own relationships
	DiplomacyRelationshipParsing.load_from_raw_data(
			country.relationships, raw_relationships
	)

	# Restore references from other countries
	for other_id: int in referencing_country_ids:
		var other: Country = map.get(other_id)
		if other != null and not other.relationships.list.has(country):
			# Re-create a basic relationship entry for this country
			other.relationships.add(country)


func _restore_province_ownership(
		country: Country, province_id_list: Array[int], provinces: Provinces
) -> void:
	for province_id in province_id_list:
		var province: Province = provinces.map.get(province_id)
		if province == null:
			push_warning("Province doesn't exist.")
			continue
		province.owner_country = country


func _restore_player_control(
		country: Country, player_id_list: Array[int], game_players: GamePlayers
) -> void:
	for player_id in player_id_list:
		var game_player: GamePlayer = game_players.map.get(player_id)
		if game_player == null:
			push_warning("Player doesn't exist.")
			continue
		game_player.playing_country = country


## Keeps the insertion index a private feature.
func _add(country: Country, insertion_index: int = -1) -> void:
	if map.has(country.id):
		push_warning("Country is already in the list.")
		return
	if not _unique_id_system.is_id_valid(country.id):
		country.id = _unique_id_system.new_unique_id()
	elif not _unique_id_system.is_id_available(country.id):
		push_warning(
				"Country id is already in use. (id: " + str(country.id) + ")"
		)
		return
	else:
		_unique_id_system.claim_id(country.id)

	map[country.id] = country

	if insertion_index < 0 or insertion_index >= list.size():
		list.append(country)
	else:
		list.insert(insertion_index, country)

	added.emit(country)

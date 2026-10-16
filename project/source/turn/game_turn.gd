class_name GameTurn
## Class responsible for a turn-based system.
## Each [Country] plays one at a time in order.
## After everyone is done playing, a new turn begins.
# TODO implement multiple players playing at the same time
# for now, assume the playing player is the first element in playing_players()

## During gameplay: emitted once all countries have played their turn.
## Outside gameplay: emitted when `set_current_turn` changes the value.
signal turn_changed(new_turn: int)

## During gameplay: emitted when it becomes a different country's turn to play.
## Outside gameplay: emitted when `set_playing_country` changes the value.
signal playing_country_changed(country: Country)

signal is_running_changed(is_running: bool)
## Emitted when the gameplay loop starts running.
signal started()
## Emitted when a country's turn ends, before the next country's turn begins.
signal country_turn_ended(country: Country)

var _game: Game

var _is_running: bool = false:
	set(value):
		if _is_running == value:
			return
		_is_running = value
		is_running_changed.emit(_is_running)
		if _is_running:
			started.emit()

var _turn: int = 1

## If the id is invalid, falls back to
## the first country in the list when the gameplay loop starts.
var _playing_country_id: int = -1
## Used to iterate through countries in the country list's order.
## Only relevant while gameplay loop is running.
var _playing_country_index: int = -1

var _ai_thread := AIThread.new()


func _init(
		game: Game, starting_turn: int = 1, playing_country_id: int = -1
) -> void:
	_game = game
	_turn = starting_turn
	_playing_country_id = playing_country_id
	_ai_thread.finished.connect(_on_ai_finished)


## Returns true if the gameplay loop is currently running.
func is_running() -> bool:
	return _is_running


func current_turn() -> int:
	return _turn


## Cannot be used while gameplay loop is running. Value must be at least 1.
func set_current_turn(new_value: int) -> void:
	if _is_running:
		push_error("Tried to set current turn while gameplay loop is running.")
		return
	elif _turn == new_value:
		return
	_turn = new_value
	turn_changed.emit(_turn)


## It's currently this country's turn to play.
## May return null if gameplay loop is not currently running.
func playing_country() -> Country:
	return _game.countries.map.get(_playing_country_id)


## Cannot be used while gameplay loop is running. Value may be null.
func set_playing_country(new_value: Country) -> void:
	if _is_running:
		push_error("Tried to set playing country while gameplay loop is running.")
		return
	elif new_value == null:
		if _playing_country_id == -1:
			return
		_playing_country_id = -1
	else:
		if _playing_country_id == new_value.id:
			return
		_playing_country_id = new_value.id

	playing_country_changed.emit(new_value)


## Returns a list of all players whose country is the current playing country.
func playing_players() -> Array[GamePlayer]:
	var country: Country = playing_country()
	if country == null:
		return []

	var output: Array[GamePlayer] = []
	for player in _game.game_players.list:
		if player.playing_country == country:
			output.append(player)
	return output


## Ends the player's turn. Has no effect if the player is an AI.
func end_turn() -> void:
	if not _is_running:
		return

	var player: GamePlayer = playing_players()[0]

	if not player.is_human():
		return

	_end_player_turn(player)


## Starts the gameplay loop, if possible.
## When it's an AI's turn, creates a new thread for the AI
## and waits for the thread to be finished.
func start() -> void:
	var old_playing_country_id: int = _playing_country_id

	# Cannot start with 0 countries.
	# Please verify this before calling this function.
	if _game.countries.list.is_empty():
		_playing_country_id = -1
		_playing_country_index = -1
		push_warning("Cannot start with 0 countries.")
		return

	# If playing country id is invalid, start at the first country in the list
	elif not _game.countries.map.has(_playing_country_id):
		_playing_country_id = _game.countries.list[0].id
		_playing_country_index = 0

	# Make sure country id and country index point at the same country
	else:
		_refresh_index()

	if not _is_running:
		_game.countries.added.connect(_refresh_index.unbind(1))
		_game.countries.removed.connect(_on_country_removed)
		_game.countries.order_changed.connect(_refresh_index.unbind(3))
		_is_running = true

	# Make sure the starting country has at least one player playing it
	_find_playing_country()
	if _is_running:
		if _playing_country_id != old_playing_country_id:
			playing_country_changed.emit(playing_country())
		_run_gameplay_loop()


# Stops the gameplay loop.
# Useful when it's an AI only game and you want the game loop to end.
func stop() -> void:
	if not _is_running:
		return

	_game.countries.added.disconnect(_refresh_index)
	_game.countries.removed.disconnect(_on_country_removed)
	_game.countries.order_changed.disconnect(_refresh_index)
	_is_running = false


func _end_player_turn(player: GamePlayer) -> void:
	if not _is_running:
		return

	# Make army movements according to [AutoArrow]s
	if player.is_human():
		player.human_status_changed.disconnect(_end_player_turn)
		AutoArrowBehavior.apply(_game)

	# Merge armies
	for armies_in_province: ArmiesInEachProvince.ArmiesInProvince in (
			_game.world.armies_in_each_province.dictionary.values()
	):
		_game.world.armies.merge_armies(armies_in_province.ordered_list, null)

	country_turn_ended.emit(player.playing_country)
	_playing_country_index += 1
	_refresh_playing_country()


func _refresh_playing_country() -> void:
	_find_playing_country()
	if _is_running:
		playing_country_changed.emit(playing_country())
	# Check again, just in case the signal causes the gameplay loop to end.
	if _is_running:
		_run_gameplay_loop()


## Ensures the playing country has at least one player playing it.
## Stops the gameplay loop if no valid country could be found.
func _find_playing_country() -> void:
	if _game.countries.list.is_empty():
		_playing_country_id = -1
		_playing_country_index = -1
		push_warning("There are 0 countries. Stopping gameplay loop.")
		stop()
		return

	var scanned: int = 0
	while scanned < _game.countries.list.size():
		if _playing_country_index >= _game.countries.list.size():
			_playing_country_index = 0
			_turn += 1
			turn_changed.emit(_turn)

		_playing_country_id = _game.countries.list[_playing_country_index].id

		if not playing_players().is_empty():
			return

		_playing_country_index += 1
		scanned += 1

	_playing_country_id = -1
	_playing_country_index = -1
	push_warning("There is no playing player. Stopping gameplay loop.")
	stop()


func _run_gameplay_loop() -> void:
	var player: GamePlayer = playing_players()[0]

	# If the player is an AI, play their actions in a separate thread
	if not player.is_human():
		_ai_thread.run(_game, player, player.player_ai)
	# Automatically end a human player's turn if they become an AI
	else:
		player.human_status_changed.connect(
				_end_player_turn, ConnectFlags.CONNECT_ONE_SHOT
		)


func _refresh_index() -> void:
	_playing_country_index = _game.countries.list.find(
			_game.countries.map[_playing_country_id]
	)


func _on_country_removed(country: Country) -> void:
	if country.id == _playing_country_id:
		_refresh_playing_country()
	else:
		_refresh_index()


func _on_ai_finished(actions: Array[Action]) -> void:
	if not _is_running:
		return

	var player: GamePlayer = playing_players()[0]

	for action in actions:
		action.apply_to(_game, player)

	_end_player_turn(player)

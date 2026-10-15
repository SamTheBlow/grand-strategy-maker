class_name NotificationAutoDismiss
## Automatically dismisses a [GameNotification]
## after it has been seen for a certain number of turns.


static func connect_game(game: Game) -> void:
	if game.turn.is_running():
		_refresh_connections(true, game)
	game.turn.is_running_changed.connect(_refresh_connections.bind(game))


## Ensures this system only operates while the game is running.
static func _refresh_connections(is_running: bool, game: Game) -> void:
	if is_running:
		_mark_as_seen(game.turn.playing_country())
		game.turn.playing_country_changed.connect(_mark_as_seen)
		game.turn.turn_changed.connect(_on_turn_changed.bind(game).unbind(1))
	else:
		game.turn.playing_country_changed.disconnect(_mark_as_seen)
		game.turn.turn_changed.disconnect(_on_turn_changed)


## Marks all of the given country's notifications as seen.
static func _mark_as_seen(country: Country) -> void:
	for game_notification in country.notifications.list():
		game_notification.was_seen_this_turn = true


## Reduces the number of turns before dismissal for every notification
## that has been seen this turn. Dismisses those whose time is up.
static func _on_turn_changed(game: Game) -> void:
	for country in game.countries.list:
		for game_notification in country.notifications.list():
			if game_notification.was_seen_this_turn:
				game_notification.turns_before_dismiss -= 1
				if game_notification.turns_before_dismiss < 1:
					game_notification.dismiss()
			game_notification.was_seen_this_turn = false

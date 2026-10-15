class_name GameNotificationParsing
## Parses raw data from/to [GameNotifications].

const _ID_KEY: String = "id"
const _CREATION_TURN_KEY: String = "creation_turn"
const _TURNS_BEFORE_DISMISS_KEY: String = "turns_before_dismiss"
const _WAS_SEEN_THIS_TURN_KEY: String = "was_seen_this_turn"

const _TYPE_KEY: String = "type"
const _TYPE_OFFER: String = "OFFER"
const _TYPE_OFFER_ACCEPTED: String = "OFFER ACCEPTED"
const _TYPE_PERFORMED_ACTION: String = "ACTION PERFORMED"

const _SENDER_COUNTRY_ID_KEY: String = "sender_country_id"
const _DIPLOMACY_ACTION_ID_KEY: String = "diplomacy_action_id"


## Loads given country's notifications using given raw data.
## Deletes all existing notifications.
##
## Always succeeds. Ignores unrecognized data.
## When data is invalid, uses the default value instead.
static func load_from_raw_data(
		raw_data: Variant, game: Game, country: Country
) -> void:
	country.notifications = GameNotifications.new()

	if raw_data is not Array:
		return
	var raw_array: Array = raw_data

	for notification_data: Variant in raw_array:
		_parse_game_notification(notification_data, game, country)


static func to_raw_array(game_notifications: GameNotifications) -> Array:
	var output: Array = []

	for game_notification in game_notifications._list:
		output.append(_game_notification_to_dict(game_notification))

	return output


## This operation may fail, in which case it has no effect.
static func _parse_game_notification(
		raw_data: Variant, game: Game, recipient_country: Country
) -> void:
	# Fails if the raw data isn't a dictionary
	if raw_data is not Dictionary:
		return
	var raw_dict: Dictionary = raw_data

	# Notification id (mandatory)
	if not ParseUtils.dictionary_has_number(raw_dict, _ID_KEY):
		return
	var id: int = ParseUtils.dictionary_int(raw_dict, _ID_KEY)

	# The id must be valid and available.
	if not recipient_country.notifications.id_system().is_id_available(id):
		return

	# Creation turn
	var creation_turn: int = game.turn.current_turn()
	if ParseUtils.dictionary_has_number(raw_dict, _CREATION_TURN_KEY):
		creation_turn = ParseUtils.dictionary_int(raw_dict, _CREATION_TURN_KEY)

	# Turns before dismiss
	var turns_before_dismiss: int = (
			GameNotification.DEFAULT_TURNS_BEFORE_DISMISS
	)
	if ParseUtils.dictionary_has_number(raw_dict, _TURNS_BEFORE_DISMISS_KEY):
		turns_before_dismiss = (
				ParseUtils.dictionary_int(raw_dict, _TURNS_BEFORE_DISMISS_KEY)
		)

	# Was seen this turn
	var was_seen_this_turn: bool = false
	if ParseUtils.dictionary_has_bool(raw_dict, _WAS_SEEN_THIS_TURN_KEY):
		was_seen_this_turn = raw_dict[_WAS_SEEN_THIS_TURN_KEY]

	var new_notification: GameNotification
	var type: Variant = (
			raw_dict[_TYPE_KEY] if raw_dict.has(_TYPE_KEY) else null
	)
	match type:
		_TYPE_OFFER:
			var action_definition: DiplomacyActionDefinition = (
					_action_definition(raw_dict, game)
			)
			if action_definition == null:
				return

			var sender_country: Country = _sender_country(raw_dict, game)
			if sender_country == null:
				return

			new_notification = GameNotificationOffer.new(
					game,
					recipient_country,
					sender_country,
					action_definition,
					creation_turn,
					turns_before_dismiss,
					was_seen_this_turn,
			)
		_TYPE_OFFER_ACCEPTED:
			var action_definition: DiplomacyActionDefinition = (
					_action_definition(raw_dict, game)
			)
			if action_definition == null:
				return

			var sender_country: Country = _sender_country(raw_dict, game)
			if sender_country == null:
				return

			new_notification = GameNotificationOfferAccepted.new(
					game,
					recipient_country,
					sender_country,
					action_definition,
					creation_turn,
					turns_before_dismiss,
					was_seen_this_turn,
			)
		_TYPE_PERFORMED_ACTION:
			var action_definition: DiplomacyActionDefinition = (
					_action_definition(raw_dict, game)
			)
			if action_definition == null:
				return

			var sender_country: Country = _sender_country(raw_dict, game)
			if sender_country == null:
				return

			new_notification = GameNotificationPerformedAction.new(
					game,
					recipient_country,
					sender_country,
					action_definition,
					creation_turn,
					turns_before_dismiss,
					was_seen_this_turn,
			)
		_:
			new_notification = GameNotification.new(
					game,
					recipient_country,
					creation_turn,
					turns_before_dismiss,
					was_seen_this_turn,
			)

	recipient_country.notifications.add(new_notification, id)


## May fail and return null.
static func _action_definition(
		raw_dict: Dictionary, game: Game
) -> DiplomacyActionDefinition:
	var output: DiplomacyActionDefinition

	if ParseUtils.dictionary_has_number(raw_dict, _DIPLOMACY_ACTION_ID_KEY):
		var action_id: int = (
				ParseUtils.dictionary_int(raw_dict, _DIPLOMACY_ACTION_ID_KEY)
		)
		output = game.diplomatic_actions.action_from_id(action_id)

	return output


## May fail and return null.
static func _sender_country(raw_dict: Dictionary, game: Game) -> Country:
	if not ParseUtils.dictionary_has_number(raw_dict, _SENDER_COUNTRY_ID_KEY):
		return null
	var sender_country_id: int = (
			ParseUtils.dictionary_int(raw_dict, _SENDER_COUNTRY_ID_KEY)
	)

	return game.countries.map.get(sender_country_id)


static func _game_notification_to_dict(
		game_notification: GameNotification
) -> Dictionary:
	var output: Dictionary = _super_to_dict(game_notification)

	var subclass_data: Dictionary = {}
	if game_notification is GameNotificationOffer:
		subclass_data = _offer_to_dict(
				game_notification as GameNotificationOffer
		)
	elif game_notification is GameNotificationOfferAccepted:
		subclass_data = _offer_accepted_to_dict(
				game_notification as GameNotificationOfferAccepted
		)
	elif game_notification is GameNotificationPerformedAction:
		subclass_data = _performed_action_to_dict(
				game_notification as GameNotificationPerformedAction
		)

	output.merge(subclass_data)
	return output


static func _super_to_dict(game_notification: GameNotification) -> Dictionary:
	var output: Dictionary = { _ID_KEY: game_notification.id }

	if (
			game_notification.creation_turn()
			!= game_notification._game.turn.current_turn()
	):
		output.merge({ _CREATION_TURN_KEY: game_notification.creation_turn() })

	if (
			game_notification.turns_before_dismiss
			!= GameNotification.DEFAULT_TURNS_BEFORE_DISMISS
	):
		output.merge({
			_TURNS_BEFORE_DISMISS_KEY: game_notification.turns_before_dismiss
		})

	if game_notification.was_seen_this_turn:
		output.merge({ _WAS_SEEN_THIS_TURN_KEY: true })

	return output


static func _offer_to_dict(
		game_notification: GameNotificationOffer
) -> Dictionary:
	return {
		_TYPE_KEY: _TYPE_OFFER,
		_SENDER_COUNTRY_ID_KEY: game_notification.sender_country().id,
		_DIPLOMACY_ACTION_ID_KEY: game_notification.action_id(),
	}


static func _offer_accepted_to_dict(
		game_notification: GameNotificationOfferAccepted
) -> Dictionary:
	return {
		_TYPE_KEY: _TYPE_OFFER_ACCEPTED,
		_SENDER_COUNTRY_ID_KEY: game_notification.sender_country().id,
		_DIPLOMACY_ACTION_ID_KEY: game_notification.action_id(),
	}


static func _performed_action_to_dict(
		game_notification: GameNotificationPerformedAction
) -> Dictionary:
	return {
		_TYPE_KEY: _TYPE_PERFORMED_ACTION,
		_SENDER_COUNTRY_ID_KEY: game_notification.sender_country().id,
		_DIPLOMACY_ACTION_ID_KEY: game_notification.action_id(),
	}

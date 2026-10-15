class_name GameNotificationOfferAccepted
extends GameNotification
## Informs of a diplomatic offer accepted by another country.

var _country_that_accepted: Country
var _diplomacy_action_definition: DiplomacyActionDefinition
var _icon := TextureInternal.new("%openmoji_1f44d")


func _init(
		game: Game,
		recipient_country: Country,
		country_that_accepted: Country,
		diplomacy_action_definition: DiplomacyActionDefinition,
		creation_turn_: int = game.turn.current_turn(),
		initial_turns_before_dismiss: int = DEFAULT_TURNS_BEFORE_DISMISS,
		initial_was_seen_this_turn: bool = false,
) -> void:
	super._init(
			game, recipient_country, creation_turn_,
			initial_turns_before_dismiss, initial_was_seen_this_turn
	)
	_country_that_accepted = country_that_accepted
	_diplomacy_action_definition = diplomacy_action_definition


func sender_country() -> Country:
	return _country_that_accepted


func action_id() -> int:
	return _diplomacy_action_definition.id


func icon() -> Texture2D:
	return _icon.texture(preload("uid://dlk4vjy5lgeuu"))


func description() -> String:
	return (
			_country_that_accepted.name_or_default()
			+ ' accepted your offer: "'
			+ _diplomacy_action_definition.name + '"'
	)


func _on_country_removed(country: Country) -> void:
	if country == _country_that_accepted or country == _recipient_country:
		dismiss()

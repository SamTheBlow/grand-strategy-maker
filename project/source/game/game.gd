class_name Game
## The internal state of a game.

signal error_triggered(error_message: String)
signal state_changed()
signal game_over(winning_country: Country)
signal action_applied(action: Action)

## Emitted when the game's setup phase is about to end.
## This is your chance to build the game's features
## (e.g. random generation) before the game starts.
signal setup_ending()

enum GameState {
	SETUP = 0,
	ONGOING = 1,
	GAMEOVER = 2,
}

## The game's current state.
## Setting this changes state directly without triggering state change logic.
var state: GameState = GameState.SETUP:
	set(value):
		if state == value:
			return
		state = value
		state_changed.emit()

## Do not overwrite!
var countries := Countries.new()

var game_players := GamePlayers.new(countries)

var turn := GameTurn.new(self)

## Do not overwrite!
var world := GameWorld.new(self)

## The game's RNG.
## It's important to always use this instead of built-in RNG methods
## so that RNG stays the same when you reload the game and when you play online.
var rng := GameRNG.new()

## Use this to obtain or provide modifiers across the entire game.
var modifier_request := ModifierRequest.new()

var _is_setup_for_play: bool = false

## A list of [GameComponent]s, mapped by their KEY constant for quick access.
var components: Dictionary[String, GameComponent] = {}

var diplomatic_presets := DiplomacyPresets.new([
	load("uid://coqnkgbae8r7r").duplicate_deep() as DiplomacyPreset,
	load("uid://c8mdgpc7c41f5").duplicate_deep() as DiplomacyPreset,
	load("uid://drsaelw08l4l5").duplicate_deep() as DiplomacyPreset,
])
var diplomatic_actions := DiplomacyActionDefinitions.new([
	load("uid://i0e1lhoyfteg").duplicate_deep() as DiplomacyActionDefinition,
	load("uid://c3kj2ppbkeuk6").duplicate_deep() as DiplomacyActionDefinition,
	load("uid://yw0vmi0myodt").duplicate_deep() as DiplomacyActionDefinition,
	load("uid://bke4orh12nfe5").duplicate_deep() as DiplomacyActionDefinition,
	load("uid://d1vcmgrvxolht").duplicate_deep() as DiplomacyActionDefinition,
	load("uid://bw7wow17qy2hc").duplicate_deep() as DiplomacyActionDefinition,
	load("uid://j3xl6wxmu3el").duplicate_deep() as DiplomacyActionDefinition,
	load("uid://cf45nbq3o1no7").duplicate_deep() as DiplomacyActionDefinition,
	load("uid://mqdrxwhb0kie").duplicate_deep() as DiplomacyActionDefinition,
	load("uid://cjxq7pod7pt0u").duplicate_deep() as DiplomacyActionDefinition,
	load("uid://1xq5bfaikpwu").duplicate_deep() as DiplomacyActionDefinition,
	load("uid://bp5csoje1ocde").duplicate_deep() as DiplomacyActionDefinition,
	load("uid://dvdfnj3lic55").duplicate_deep() as DiplomacyActionDefinition,
])


func _init() -> void:
	for province in world.provinces.list:
		for building in province.buildings.list():
			modifier_request.add_provider(building)
	world.provinces.building_added.connect(modifier_request.add_provider)
	world.provinces.building_removed.connect(modifier_request.remove_provider)

	AutoArrowProvinceCleanup.connect_game(self)
	ProvinceOwnershipUpdate.connect_game(self)
	AIRandomization.connect_game(self)
	NotificationAutoDismiss.connect_game(self)


## Sets up the game to be ready for playing.
## No effect if this was already called.
func setup_for_play() -> void:
	if _is_setup_for_play:
		return

	rng.lock()
	_register_components()

	_is_setup_for_play = true

	if state == GameState.SETUP:
		setup_ending.emit()
		state = GameState.ONGOING


## Starts/resumes the gameplay loop, if possible.
## No effect if setup_for_play() has not been called yet.
func start() -> void:
	if not _is_setup_for_play:
		return

	# You can continue playing if the game's over
	# but let's remind the user that the game is over.
	if state == GameState.GAMEOVER:
		game_over.emit(_winning_country())

	# Can't start a game with 0 players.
	if game_players.list.is_empty():
		error_triggered.emit("Cannot start a game with 0 players.")
		return

	turn.start()


## Marks game over. No effect if the game is already over.
func end_game() -> void:
	if state != GameState.ONGOING:
		return

	state = GameState.GAMEOVER
	game_over.emit(_winning_country())


func apply_action(action: Action) -> void:
	if not turn.is_running():
		return
	action.apply_to(self, turn.playing_players()[0])
	action_applied.emit(action)


func _register_components() -> void:
	var sorted_list: Array[GameComponent] = components.values()
	sorted_list.sort_custom(
			func(a: GameComponent, b: GameComponent) -> bool:
				return a.priority_index < b.priority_index
	)
	for component in sorted_list:
		component.register(self)


## Used to determine the winner when the game ends.
## Currently returns the country that controls the most provinces.
## Returns null if the game has no countries.
func _winning_country() -> Country:
	var province_count_per_country: Dictionary[Country, int] = (
			ProvinceCountPerCountry.result(world.provinces.list)
	)

	var winner_country: Country = null
	for country in province_count_per_country:
		if (
				winner_country == null
				or province_count_per_country[country]
				> province_count_per_country[winner_country]
		):
			winner_country = country

	return winner_country

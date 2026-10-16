class_name EditingInterface
extends Control
## Opens and closes interfaces for the user to use in the editor.

signal texture_popup_requested(
		item_texture: ItemTexture, project_textures: ProjectTextures
)
signal country_select_pressed(item_country: ItemCountry)
signal player_select_requested(callable: Callable)
signal country_interface_opened(country: Country)
signal country_interface_closed()
signal province_interface_opened(province: Province)
signal province_interface_closed()
signal army_interface_opened(army: Army)
signal army_interface_closed()
signal army_list_item_hovered(army: Army)
signal army_list_item_unhovered()
signal army_select_requested(army: Army)
signal province_list_item_hovered(province: Province)
signal province_list_item_unhovered()
signal province_select_requested(province: Province)
signal decoration_interface_opened(decoration: WorldDecoration)
signal decoration_interface_closed()
signal decoration_list_item_hovered(decoration: WorldDecoration)
signal decoration_list_item_unhovered()
signal decoration_select_requested(decoration: WorldDecoration)

## The root node of each scene is an [AppEditorInterface].
const _INTERFACE_SCENES: Dictionary[InterfaceNavigator.Type, PackedScene] = {
	InterfaceNavigator.Type.PROJECT_INFO:
		preload("uid://7k82f8lx1vpe"),
	InterfaceNavigator.Type.RNG:
		preload("uid://dp53fawdiydun"),
	InterfaceNavigator.Type.WIN_CONDITIONS:
		preload("uid://bi2e1mwxbqyvm"),
	InterfaceNavigator.Type.COUNTRY_LIST:
		preload("uid://pns3cw110b6w"),
	InterfaceNavigator.Type.COUNTRY_EDIT:
		preload("uid://ck6hme0uj2nuu"),
	InterfaceNavigator.Type.COUNTRY_RELATIONSHIPS:
		preload("uid://bxnnpjildojmj"),
	InterfaceNavigator.Type.COUNTRY_NOTIFICATIONS:
		preload("uid://bs0hbgxgmptdv"),
	InterfaceNavigator.Type.DIPLOMACY:
		preload("uid://cishrjvsb5hvl"),
	InterfaceNavigator.Type.PLAYER_LIST:
		preload("uid://dlpstn5iyda4k"),
	InterfaceNavigator.Type.PLAYER_EDIT:
		preload("uid://exhe7mpnu7w1"),
	InterfaceNavigator.Type.TURN_SYSTEM:
		preload("uid://bgcrykgs0vh3o"),
	InterfaceNavigator.Type.WORLD_LIMITS:
		preload("uid://cyspbdausxgwr"),
	InterfaceNavigator.Type.BACKGROUND_COLOR:
		preload("uid://bb53mhx3u8ho8"),
	InterfaceNavigator.Type.DECORATION_LIST:
		preload("uid://bql3bs1c3rgo3"),
	InterfaceNavigator.Type.DECORATION_EDIT:
		preload("uid://bfpg282qeb0rx"),
	InterfaceNavigator.Type.PROVINCE_LIST:
		preload("uid://bluif37tipwg7"),
	InterfaceNavigator.Type.PROVINCE_EDIT:
		preload("uid://bafpj3jqosje7"),
	InterfaceNavigator.Type.ARMY_LIST:
		preload("uid://l2nhdgg0p4oo"),
	InterfaceNavigator.Type.ARMY_EDIT:
		preload("uid://n04sb8kke04h"),
	InterfaceNavigator.Type.BUILDINGS:
		preload("uid://dn67kha2v6jam"),
}

@export var _undo_redo: UndoRedoResource

var _navigator := InterfaceNavigator.new(self)
var _project: GameProject

var _current_interface: AppEditorInterface:
	set(value):
		if _current_interface == value:
			return

		if _current_interface != null:
			# Use queue_free() instead of immediately deleting the node
			# so that input events still propagate through it on this frame.
			_current_interface.queue_free()
			_current_interface.closed_signal.emit()

		_current_interface = value

		visible = _current_interface != null
		if _current_interface != null:
			_forward_interface_signals(_current_interface)
			if is_node_ready():
				_add_contents()
			else:
				ready.connect(_add_contents, ConnectFlags.CONNECT_ONE_SHOT)

@onready var _contents_container: Node = %Contents


func _ready() -> void:
	# Just in case it was set to visible in the editor
	visible = _current_interface != null


func set_project(project: GameProject) -> void:
	_project = project


## Opens a new interface of given type.
func open_new_interface(type: InterfaceNavigator.Type) -> void:
	_open_interface(_INTERFACE_SCENES[type].instantiate() as AppEditorInterface)


## Has no effect if there is no interface open.
func close_interface() -> void:
	_current_interface = null


## Opens the interface for editing given province.
func open_province_edit_interface(province: Province) -> void:
	var new_interface := (
			_INTERFACE_SCENES[InterfaceNavigator.Type.PROVINCE_EDIT]
			.instantiate() as InterfaceProvinceEdit
	)
	new_interface.province = province
	new_interface.closed_signal = province_interface_closed
	_open_interface(new_interface)
	province_interface_opened.emit(province)


## Opens the interface for editing given army.
func open_army_edit_interface(army: Army) -> void:
	var new_interface := (
			_INTERFACE_SCENES[InterfaceNavigator.Type.ARMY_EDIT]
			.instantiate() as InterfaceArmyEdit
	)
	new_interface.army = army
	new_interface.closed_signal = army_interface_closed
	_open_interface(new_interface)
	army_interface_opened.emit(army)


## Opens the interface for editing given world decoration.
func open_decoration_edit_interface(world_decoration: WorldDecoration) -> void:
	var new_interface := (
			_INTERFACE_SCENES[InterfaceNavigator.Type.DECORATION_EDIT]
			.instantiate() as InterfaceWorldDecorationEdit
	)
	new_interface.world_decoration = world_decoration
	new_interface.closed_signal = decoration_interface_closed
	_open_interface(new_interface)
	decoration_interface_opened.emit(world_decoration)


## Opens the interface for editing given country.
func open_country_edit_interface(country: Country) -> void:
	var new_interface := (
			_INTERFACE_SCENES[InterfaceNavigator.Type.COUNTRY_EDIT]
			.instantiate() as InterfaceCountryEdit
	)
	new_interface.country = country
	new_interface.closed_signal = country_interface_closed
	_open_interface(new_interface)
	country_interface_opened.emit(country)


## Opens the interface for editing given player.
func open_player_edit_interface(game_player: GamePlayer) -> void:
	var new_interface := (
			_INTERFACE_SCENES[InterfaceNavigator.Type.PLAYER_EDIT]
			.instantiate() as InterfacePlayerEdit
	)
	new_interface.game_player = game_player
	_open_interface(new_interface)


## Opens the interface for editing given country's relationships.
func open_country_relationships_interface(country: Country) -> void:
	var new_interface := (
			_INTERFACE_SCENES[InterfaceNavigator.Type.COUNTRY_RELATIONSHIPS]
			.instantiate() as InterfaceCountryRelationships
	)
	new_interface.country = country
	_open_interface(new_interface)


## Opens the interface for editing given country's notifications.
func open_country_notifications_interface(country: Country) -> void:
	var new_interface := (
			_INTERFACE_SCENES[InterfaceNavigator.Type.COUNTRY_NOTIFICATIONS]
			.instantiate() as InterfaceCountryNotifications
	)
	new_interface.country = country
	_open_interface(new_interface)


func _add_contents() -> void:
	_contents_container.add_child(_current_interface)


## Prepares the interface and then opens it.
func _open_interface(new_interface: AppEditorInterface) -> void:
	new_interface.project = _project
	new_interface.navigator = _navigator
	new_interface.undo_redo = _undo_redo
	_current_interface = new_interface


## Propagates up the current interface's signals.
func _forward_interface_signals(interface: AppEditorInterface) -> void:
	interface.texture_popup_requested.connect(texture_popup_requested.emit)
	interface.country_select_pressed.connect(country_select_pressed.emit)
	interface.player_select_requested.connect(player_select_requested.emit)
	interface.army_list_item_hovered.connect(army_list_item_hovered.emit)
	interface.army_list_item_unhovered.connect(army_list_item_unhovered.emit)
	interface.army_select_requested.connect(army_select_requested.emit)
	interface.province_list_item_hovered.connect(province_list_item_hovered.emit)
	interface.province_list_item_unhovered.connect(province_list_item_unhovered.emit)
	interface.province_select_requested.connect(province_select_requested.emit)
	interface.decoration_list_item_hovered.connect(decoration_list_item_hovered.emit)
	interface.decoration_list_item_unhovered.connect(decoration_list_item_unhovered.emit)
	interface.decoration_select_requested.connect(decoration_select_requested.emit)

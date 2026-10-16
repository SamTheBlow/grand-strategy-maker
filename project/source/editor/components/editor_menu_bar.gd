class_name EditorMenuBar
extends MenuBar
## Translates raw menu button presses into useful signals.

signal quit_requested()
signal new_project_requested()
signal open_project_requested()
signal save_requested()
signal save_as_requested()
signal show_in_file_manager_requested()
signal playtest_requested()
signal interface_requested(type: InterfaceNavigator.Type)

const _ACTION_QUIT_EDITOR: StringName = &"quit_editor"
const _ACTION_NEW_PROJECT: StringName = &"new_project"
const _ACTION_OPEN_PROJECT: StringName = &"open_project"
const _ACTION_SAVE: StringName = &"save"
const _ACTION_SAVE_AS: StringName = &"save_as"
const _ACTION_PLAY_PROJECT: StringName = &"start_playtest"

const _EDITOR_TAB_SEPARATOR_IDS: Array[int] = []
const _EDITOR_TAB_QUIT_ID: int = 0

const _PROJECT_TAB_SEPARATOR_IDS: Array[int] = [2, 5, 7]
const _PROJECT_TAB_NEW_PROJECT_ID: int = 0
const _PROJECT_TAB_OPEN_ID: int = 1
const _PROJECT_TAB_SAVE_ID: int = 3
const _PROJECT_TAB_SAVE_AS_ID: int = 4
const _PROJECT_TAB_SHOW_IN_FILE_MANAGER_ID: int = 6
const _PROJECT_TAB_PLAY_ID: int = 8

const _EDIT_TAB_SEPARATOR_IDS: Array[int] = [3, 8]
const _EDIT_TAB_PROJECT_INFO_ID: int = 0
const _EDIT_TAB_RNG_ID: int = 1
const _EDIT_TAB_WIN_CONDITIONS_ID: int = 2
const _EDIT_TAB_COUNTRIES_ID: int = 4
const _EDIT_TAB_DIPLOMACY_ID: int = 5
const _EDIT_TAB_PLAYERS_ID: int = 6
const _EDIT_TAB_TURN_SYSTEM_ID: int = 7
const _EDIT_TAB_WORLD_LIMITS_ID: int = 9
const _EDIT_TAB_BACKGROUND_COLOR_ID: int = 10
const _EDIT_TAB_DECORATIONS_ID: int = 11
const _EDIT_TAB_PROVINCES_ID: int = 12
const _EDIT_TAB_ARMIES_ID: int = 13
const _EDIT_TAB_BUILDINGS_ID: int = 14

@export var _editor_tab: PopupMenu
@export var _project_tab: PopupMenu


func _ready() -> void:
	var shortcut_quit := Shortcut.new()
	shortcut_quit.events = InputMap.action_get_events(_ACTION_QUIT_EDITOR)
	_editor_tab.set_item_shortcut(_EDITOR_TAB_QUIT_ID, shortcut_quit)

	var shortcut_new := Shortcut.new()
	shortcut_new.events = InputMap.action_get_events(_ACTION_NEW_PROJECT)
	_project_tab.set_item_shortcut(_PROJECT_TAB_NEW_PROJECT_ID, shortcut_new)

	var shortcut_open := Shortcut.new()
	shortcut_open.events = InputMap.action_get_events(_ACTION_OPEN_PROJECT)
	_project_tab.set_item_shortcut(_PROJECT_TAB_OPEN_ID, shortcut_open)

	var shortcut_save := Shortcut.new()
	shortcut_save.events = InputMap.action_get_events(_ACTION_SAVE)
	_project_tab.set_item_shortcut(_PROJECT_TAB_SAVE_ID, shortcut_save)

	var shortcut_save_as := Shortcut.new()
	shortcut_save_as.events = InputMap.action_get_events(_ACTION_SAVE_AS)
	_project_tab.set_item_shortcut(_PROJECT_TAB_SAVE_AS_ID, shortcut_save_as)

	var shortcut_play := Shortcut.new()
	shortcut_play.events = InputMap.action_get_events(_ACTION_PLAY_PROJECT)
	_project_tab.set_item_shortcut(_PROJECT_TAB_PLAY_ID, shortcut_play)


func _on_project_path_validity_changed(has_valid_file_path: bool) -> void:
	# "Show in File Manager"
	_project_tab.set_item_disabled(
			_PROJECT_TAB_SHOW_IN_FILE_MANAGER_ID, not has_valid_file_path
	)


## Called when the user clicks on one of the options
## in the menu bar's "Editor" tab.
func _on_editor_tab_id_pressed(id: int) -> void:
	match id:
		_EDITOR_TAB_QUIT_ID:
			# "Quit"
			quit_requested.emit()
		_EDITOR_TAB_SEPARATOR_IDS:
			pass
		_:
			push_error("Unrecognized menu id.")


## Called when the user clicks on one of the options
## in the menu bar's "Project" tab.
func _on_project_tab_id_pressed(id: int) -> void:
	match id:
		_PROJECT_TAB_NEW_PROJECT_ID:
			# "New Project"
			new_project_requested.emit()
		_PROJECT_TAB_OPEN_ID:
			# "Open..."
			open_project_requested.emit()
		_PROJECT_TAB_SAVE_ID:
			# "Save"
			save_requested.emit()
		_PROJECT_TAB_SAVE_AS_ID:
			# "Save As..."
			save_as_requested.emit()
		_PROJECT_TAB_SHOW_IN_FILE_MANAGER_ID:
			# "Show in File Manager"
			show_in_file_manager_requested.emit()
		_PROJECT_TAB_PLAY_ID:
			# "Playtest"
			playtest_requested.emit()
		_PROJECT_TAB_SEPARATOR_IDS:
			# Separators & sub menus
			pass
		_:
			push_error("Unrecognized menu id.")


## Called when the user clicks on one of the options
## in the menu bar's "Edit" tab.
func _on_edit_tab_id_pressed(id: int) -> void:
	var interface_type: InterfaceNavigator.Type

	match id:
		_EDIT_TAB_PROJECT_INFO_ID:
			# "Project Info"
			interface_type = InterfaceNavigator.Type.PROJECT_INFO
		_EDIT_TAB_RNG_ID:
			# "RNG"
			interface_type = InterfaceNavigator.Type.RNG
		_EDIT_TAB_WIN_CONDITIONS_ID:
			# "Win Conditions"
			interface_type = InterfaceNavigator.Type.WIN_CONDITIONS
		_EDIT_TAB_COUNTRIES_ID:
			# "Countries"
			interface_type = InterfaceNavigator.Type.COUNTRY_LIST
		_EDIT_TAB_DIPLOMACY_ID:
			# "Diplomacy"
			interface_type = InterfaceNavigator.Type.DIPLOMACY
		_EDIT_TAB_PLAYERS_ID:
			# "Players"
			interface_type = InterfaceNavigator.Type.PLAYER_LIST
		_EDIT_TAB_TURN_SYSTEM_ID:
			# "Turn System"
			interface_type = InterfaceNavigator.Type.TURN_SYSTEM
		_EDIT_TAB_WORLD_LIMITS_ID:
			# "World Limits"
			interface_type = InterfaceNavigator.Type.WORLD_LIMITS
		_EDIT_TAB_BACKGROUND_COLOR_ID:
			# "Background Color"
			interface_type = InterfaceNavigator.Type.BACKGROUND_COLOR
		_EDIT_TAB_DECORATIONS_ID:
			# "Decorations"
			interface_type = InterfaceNavigator.Type.DECORATION_LIST
		_EDIT_TAB_PROVINCES_ID:
			# "Provinces"
			interface_type = InterfaceNavigator.Type.PROVINCE_LIST
		_EDIT_TAB_ARMIES_ID:
			# "Armies"
			interface_type = InterfaceNavigator.Type.ARMY_LIST
		_EDIT_TAB_BUILDINGS_ID:
			# "Buildings"
			interface_type = InterfaceNavigator.Type.BUILDINGS
		_EDIT_TAB_SEPARATOR_IDS:
			# Separators & sub menus
			return
		_:
			push_error("Unrecognized menu id.")
			return

	interface_requested.emit(interface_type)

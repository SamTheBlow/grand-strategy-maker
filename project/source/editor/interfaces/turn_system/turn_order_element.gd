class_name EditorTurnOrderElement
extends Control
## An element in the turn order list with up/down arrow buttons for reordering.

signal up_pressed()
signal down_pressed()

var country: Country

## The display label text.
var label_text: String = "":
	set(value):
		label_text = value
		_refresh_name()

@onready var _up_control := %UpControl as Control
@onready var _down_control := %DownControl as Control
@onready var _name_label := %NameLabel as Label
@onready var _country_button := %CountryButton as CountryButton


func _ready() -> void:
	_country_button.country = country
	_refresh_name()


func refresh_arrows() -> void:
	var parent: Node = get_parent()
	if parent == null:
		_up_control.visible = false
		_down_control.visible = false
		return

	var list_index: int = get_index()
	var list_size: int = parent.get_child_count()

	_up_control.visible = list_index > 0
	_down_control.visible = list_index < list_size - 1


func _refresh_name() -> void:
	if not is_node_ready():
		return

	_name_label.text = label_text


func _on_up_button_pressed() -> void:
	up_pressed.emit()


func _on_down_button_pressed() -> void:
	down_pressed.emit()

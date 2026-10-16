class_name InterfaceProvinceEdit
extends AppEditorInterface
## The interface in which the user can edit given [Province].

var province: Province

@onready var _add_army_button := %AddArmyButton as Button


func _ready() -> void:
	_refresh_army_button()

	(%ProvincePreview as ProvincePreviewNode).setup(province)

	_setup_settings(%Settings as ItemVoidNode)

	project.game.world.provinces.removed.connect(_on_province_removed)

	closed.connect(navigator.open_new_interface.bind(
			InterfaceNavigator.Type.PROVINCE_LIST
	))


func _load_settings(settings_item: PropertyTreeItem) -> void:
	# Name
	var item_name := settings_item.child_items[0] as ItemString
	item_name.value = province.name
	item_name.placeholder_text = province.default_name()
	item_name.value_changed.connect(_on_name_value_changed)
	province.name_changed.connect(
			_on_province_name_changed.bind(item_name).unbind(1)
	)

	# Owner country
	var item_country := settings_item.child_items[2] as ItemCountry
	item_country.value = province.owner_country
	item_country.value_changed.connect(_on_country_value_changed)
	item_country.change_requested.connect(country_select_pressed.emit)
	province.owner_changed.connect(
			_on_province_owner_changed.bind(item_country).unbind(1)
	)

	# Population
	var item_population := settings_item.child_items[3] as ItemInt
	item_population.value = province.population().value
	item_population.value_changed.connect(_on_population_value_changed)
	province.population().value_changed.connect(
			_on_province_population_changed.bind(item_population).unbind(1)
	)

	# Money income
	var item_income := settings_item.child_items[4] as ItemInt
	item_income.value = province.money_income().value
	item_income.value_changed.connect(_on_income_value_changed)
	province.money_income().value_changed.connect(
			_on_province_income_changed.bind(item_income).unbind(1)
	)

	# Has fortress
	var item_fortress := settings_item.child_items[5] as ItemBool
	item_fortress.value = not province.buildings.list().is_empty()
	item_fortress.value_changed.connect(_on_has_fortress_value_changed)
	province.buildings.changed.connect(
			_on_province_buildings_changed.bind(item_fortress)
	)


func _refresh_army_button() -> void:
	_add_army_button.disabled = province.owner_country == null


func _add_new_army() -> void:
	if province.owner_country == null:
		return

	var new_army: Army = Army.Factory.new(project.game).new_army(
			province.owner_country, province.id
	)

	# Create undo_redo action
	# (don't execute it since factory setup already added the army)
	undo_redo.create_action("Create new army")
	undo_redo.add_do_method(project.game.world.armies.add.bind(new_army))
	undo_redo.add_undo_method(project.game.world.armies.remove.bind(new_army))
	undo_redo.commit_action(false)


func _delete() -> void:
	project.game.world.provinces.undo_redo_remove(
			province,
			undo_redo,
			project.game.world.armies,
			project.game.world.armies_in_each_province
	)


func _duplicate() -> void:
	const _DUPLICATE_PROVINCE_OFFSET = Vector2(64.0, 64.0)

	# Create duplicate
	var new_province := Province.new()
	new_province.name = province.name
	new_province.shape.copy_other(province.shape)
	new_province.position_army_host = province.position_army_host
	new_province.position_fortress = province.position_fortress
	new_province.shape.move_relative(_DUPLICATE_PROVINCE_OFFSET)
	new_province.owner_country = province.owner_country
	new_province.population().value = province.population().value
	new_province.money_income().value = province.money_income().value

	# We need this new province to have a new unique id
	# assigned to it before we can create the undo_redo action
	project.game.world.provinces.add(new_province)

	# Buildings (needs the new province id)
	for building in province.buildings.list():
		new_province.buildings.add(Building.new(building.data, new_province.id))

	# Create undo_redo action
	# (don't execute it since we already added the province)
	undo_redo.create_action("Duplicate province")
	undo_redo.add_do_method(
			project.game.world.provinces.add.bind(new_province)
	)
	undo_redo.add_undo_method(
			project.game.world.provinces.remove.bind(new_province.id)
	)
	undo_redo.commit_action(false)

	# Select the new province for editing
	province_select_requested.emit(new_province)


func _on_province_removed(province_removed: Province) -> void:
	if province_removed == province:
		closed.emit()


func _on_name_value_changed(new_value: String) -> void:
	_apply_undo_redo_property(
			"Change province name",
			province,
			&"name",
			province.name,
			new_value
	)


func _on_country_value_changed(new_value: Country) -> void:
	_apply_undo_redo_property(
			"Change province owner",
			province,
			&"owner_country",
			province.owner_country,
			new_value
	)


func _on_population_value_changed(new_value: int) -> void:
	_apply_undo_redo_property(
			"Change province population",
			province.population(),
			&"value",
			province.population().value,
			new_value
	)


func _on_income_value_changed(new_value: int) -> void:
	_apply_undo_redo_property(
			"Change province money income",
			province.money_income(),
			&"value",
			province.money_income().value,
			new_value
	)


func _on_has_fortress_value_changed(new_value: bool) -> void:
	var description: String = "Toggle province having a fortress"

	var do_callable: Callable
	var undo_callable: Callable
	if new_value:
		# Add fortress
		var new_fortress := (
				Building.new(project.game.world.fortress_data(), province.id)
		)
		do_callable = province.buildings.add.bind(new_fortress)
		undo_callable = province.buildings.remove.bind(new_fortress)
	else:
		# Remove fortress
		var existing_fortress: Building = province.buildings._list[0]
		do_callable = province.buildings.remove.bind(existing_fortress)
		undo_callable = province.buildings.add.bind(existing_fortress)

	_apply_undo_redo_method(description, do_callable, undo_callable)


func _on_province_name_changed(item: ItemString) -> void:
	_set_setting_no_signal(item, _on_name_value_changed, province.name)


func _on_province_owner_changed(item: ItemCountry) -> void:
	_set_setting_no_signal(
			item, _on_country_value_changed, province.owner_country
	)
	_refresh_army_button()


func _on_province_population_changed(item: ItemInt) -> void:
	_set_setting_no_signal(
			item, _on_population_value_changed, province.population().value
	)


func _on_province_income_changed(item: ItemInt) -> void:
	_set_setting_no_signal(
			item, _on_income_value_changed, province.money_income().value
	)


func _on_province_buildings_changed(item: ItemBool) -> void:
	_set_setting_no_signal(
			item,
			_on_has_fortress_value_changed,
			not province.buildings.list().is_empty()
	)

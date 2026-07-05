## 保险柜管理屏幕
## 所有权: WS5 (客户端 UI 组)
## 显示和管理保险柜中的物品（现金/技能卡/道具）
extends Control
class_name SafeBoxScreen

signal safe_box_configured(items: Array[PlayerTypes.SafeBoxItem])

var _grid: GridContainer = null
var _available_list: VBoxContainer = null
var _confirm_btn: Button = null
var _slots: int = Constants.INITIAL_SAFE_BOX_SLOTS
var _items: Array[PlayerTypes.SafeBoxItem] = []
var _available_items: Array[PlayerTypes.SafeBoxItem] = []
var _slot_panels: Array[PanelContainer] = []


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 12)
	add_child(main_vbox)

	# 标题
	var title := Label.new()
	title.text = "保险柜管理"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	main_vbox.add_child(title)

	# 上半部分: 保险柜格子
	var safe_section := VBoxContainer.new()
	main_vbox.add_child(safe_section)
	var safe_label := Label.new()
	safe_label.text = "保险柜 (槽位: %d)" % _slots
	safe_label.add_theme_font_size_override("font_size", 16)
	safe_section.add_child(safe_label)

	_grid = GridContainer.new()
	_grid.columns = mini(_slots, 4)
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	safe_section.add_child(_grid)

	for i in range(_slots):
		var panel := _create_slot_panel(i)
		_grid.add_child(panel)
		_slot_panels.append(panel)

	# 下半部分: 可用物品列表
	var available_section := VBoxContainer.new()
	main_vbox.add_child(available_section)
	var avail_label := Label.new()
	avail_label.text = "可用物品（点击放入保险柜）"
	avail_label.add_theme_font_size_override("font_size", 16)
	available_section.add_child(avail_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	available_section.add_child(scroll)
	_available_list = VBoxContainer.new()
	_available_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_available_list)

	# 确认按钮
	_confirm_btn = Button.new()
	_confirm_btn.text = "确认配置"
	_confirm_btn.custom_minimum_size = Vector2(200, 50)
	_confirm_btn.pressed.connect(_on_confirm)
	main_vbox.add_child(_confirm_btn)


## 创建单个保险柜格子面板
func _create_slot_panel(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 100)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var icon_label := Label.new()
	icon_label.text = "[空]"
	icon_label.name = "IconLabel"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(icon_label)

	var name_label := Label.new()
	name_label.text = "槽位 %d" % (index + 1)
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(name_label)

	var btn := Button.new()
	btn.text = "移除"
	btn.name = "RemoveBtn"
	btn.custom_minimum_size = Vector2(60, 25)
	btn.visible = false
	btn.pressed.connect(func() -> void: _remove_item_from_slot(index))
	vbox.add_child(btn)

	return panel


## 加载可用物品列表
func load_available_items(items: Array[PlayerTypes.SafeBoxItem]) -> void:
	_available_items = items.duplicate()
	_refresh_available_list()


## 设置当前保险柜物品
func set_safe_box_items(items: Array[PlayerTypes.SafeBoxItem], slots: int) -> void:
	_slots = slots
	_items = items.duplicate()
	if _grid:
		_grid.columns = mini(_slots, 4)
		for child in _grid.get_children():
			child.queue_free()
		_slot_panels.clear()
		for i in range(_slots):
			var panel := _create_slot_panel(i)
			_grid.add_child(panel)
			_slot_panels.append(panel)
	_refresh_slots()


## 刷新所有格子显示
func _refresh_slots() -> void:
	for i in range(_slot_panels.size()):
		var panel: PanelContainer = _slot_panels[i]
		var icon_label: Label = panel.get_node("VBoxContainer/IconLabel")
		var name_label: Label = panel.get_node("VBoxContainer/NameLabel")
		var remove_btn: Button = panel.get_node("VBoxContainer/RemoveBtn")

		if i < _items.size():
			var item: PlayerTypes.SafeBoxItem = _items[i]
			icon_label.text = _get_item_icon(item)
			name_label.text = _get_item_display_name(item)
			remove_btn.visible = true
		else:
			icon_label.text = "[空]"
			name_label.text = "槽位 %d" % (i + 1)
			remove_btn.visible = false


## 刷新可用物品列表
func _refresh_available_list() -> void:
	for child in _available_list.get_children():
		child.queue_free()

	for i in range(_available_items.size()):
		var item: PlayerTypes.SafeBoxItem = _available_items[i]
		var already_placed := false
		for placed in _items:
			if placed.item_id == item.item_id and placed.item_type == item.item_type:
				already_placed = true
				break
		if already_placed:
			continue

		var btn := Button.new()
		btn.text = "%s %s" % [_get_item_icon(item), _get_item_display_name(item)]
		btn.custom_minimum_size = Vector2(0, 35)
		var item_ref := item
		btn.pressed.connect(func() -> void: _place_item_in_slot(item_ref))
		_available_list.add_child(btn)


## 将物品放入第一个空格子
func _place_item_in_slot(item: PlayerTypes.SafeBoxItem) -> void:
	if _items.size() >= _slots:
		return
	_items.append(item)
	_refresh_slots()
	_refresh_available_list()


## 从格子中移除物品
func _remove_item_from_slot(index: int) -> void:
	if index >= _items.size():
		return
	_items.remove_at(index)
	_refresh_slots()
	_refresh_available_list()


## 确认配置
func _on_confirm() -> void:
	safe_box_configured.emit(_items)


## 获取物品图标
func _get_item_icon(item: PlayerTypes.SafeBoxItem) -> String:
	match item.item_type:
		GameEnums.SafeBoxItemType.CASH:
			return "$"
		GameEnums.SafeBoxItemType.SKILL_CARD:
			return "★"
		_:
			return "?"


## 获取物品显示名称
func _get_item_display_name(item: PlayerTypes.SafeBoxItem) -> String:
	match item.item_type:
		GameEnums.SafeBoxItemType.CASH:
			return "现金 $%.0f" % item.amount
		GameEnums.SafeBoxItemType.SKILL_CARD:
			return "技能: %s Lv%d" % [str(item.item_id), item.level]
		_:
			return str(item.item_id)

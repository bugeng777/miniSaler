## 保险柜管理屏幕（像素风格）
## 所有权: WS5 (客户端 UI 组)
## 竖屏 720x1280, 2xN 网格, 每格 160x160, 间距 8px
## 数据源: WS3 SafeBoxManager (get_items / get_max_slots / get_total_cash)
extends Control
class_name SafeBoxScreen

## 物品移动（拖放换位）
signal item_moved(from_idx: int, to_idx: int)
## 物品取出到背包/手中
signal item_taken_out(item: PlayerTypes.SafeBoxItem, index: int)
## 物品丢弃（不可恢复）
signal item_discarded(item: PlayerTypes.SafeBoxItem, index: int)
signal back_requested()

# ─── 布局常量（整数, 像素单位） ──────────────────────────────────────────────
const COLS := 2                    ## 固定 2 列
const SLOT_SIZE := 160             ## 每格 160x160
const ICON_SIZE := 64              ## 物品图标 64x64
const GRID_GAP := 8                ## 格子间距 8px
const SCREEN_W := 720              ## 竖屏宽
const SCREEN_H := 1280             ## 竖屏高

# 网格区域起始 Y（标题栏下方）
const GRID_OFFSET_Y := 180
# 网格居中 X 偏移
const GRID_OFFSET_X := (SCREEN_W - (COLS * SLOT_SIZE + (COLS - 1) * GRID_GAP)) / 2

# 拖放状态
var _drag_from_idx: int = -1

# 运行时数据
var _safe_box_mgr: SafeBoxManager = null
var _player_id: int = 0
var _items: Array[PlayerTypes.SafeBoxItem] = []
var _max_slots: int = Constants.INITIAL_SAFE_BOX_SLOTS

# UI 引用
var _grid_container: Control = null
var _cash_label: Label = null
var _slots_label: Label = null
var _title_label: Label = null
var _detail_panel: PanelContainer = null
var _detail_name: Label = null
var _detail_desc: Label = null
var _btn_take_out: Button = null
var _btn_discard: Button = null
var _btn_close: Button = null
var _selected_idx: int = -1


func _ready() -> void:
	_build_ui()


# ═══════════════════════════════════════════════════════════════════════════════
#  UI 构建
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# 全屏背景
	var bg := ColorRect.new()
	bg.color = PixelTheme.BG_DARKEST
	bg.position = Vector2(0, 0)
	bg.size = Vector2(SCREEN_W, SCREEN_H)
	add_child(bg)

	# 标题
	_title_label = Label.new()
	_title_label.text = "═══ 保险柜 ═══"
	_title_label.position = Vector2(0, 16)
	_title_label.size = Vector2(SCREEN_W, 40)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", PixelTheme.ACCENT_GOLD)
	add_child(_title_label)

	# 现金总额
	_cash_label = Label.new()
	_cash_label.text = "保险柜现金: $0"
	_cash_label.position = Vector2(GRID_OFFSET_X, 60)
	_cash_label.add_theme_font_size_override("font_size", 16)
	_cash_label.add_theme_color_override("font_color", PixelTheme.TEXT_PRIMARY)
	add_child(_cash_label)

	# 格数信息
	_slots_label = Label.new()
	_slots_label.text = "格数: 0/0"
	_slots_label.position = Vector2(GRID_OFFSET_X, 84)
	_slots_label.add_theme_font_size_override("font_size", 14)
	_slots_label.add_theme_color_override("font_color", PixelTheme.TEXT_SECONDARY)
	add_child(_slots_label)

	# 网格容器
	_grid_container = Control.new()
	_grid_container.position = Vector2(GRID_OFFSET_X, GRID_OFFSET_Y)
	_grid_container.size = Vector2(COLS * SLOT_SIZE + (COLS - 1) * GRID_GAP, 0)
	add_child(_grid_container)

	# 详情面板（选中格子后显示）
	_build_detail_panel()

	# 返回按钮
	_btn_close = _create_pixel_button("返回", PixelTheme.TEXT_DIM)
	_btn_close.position = Vector2(SCREEN_W / 2 - 80, SCREEN_H - 100)
	_btn_close.pressed.connect(func() -> void: back_requested.emit())
	add_child(_btn_close)


func _build_detail_panel() -> void:
	_detail_panel = PanelContainer.new()
	var style := PixelTheme.create_rpg_panel(PixelTheme.ACCENT_BLUE)
	_detail_panel.add_theme_stylebox_override("panel", style)
	_detail_panel.position = Vector2(GRID_OFFSET_X, GRID_OFFSET_Y + 540)
	_detail_panel.size = Vector2(COLS * SLOT_SIZE + (COLS - 1) * GRID_GAP, 260)
	_detail_panel.visible = false
	add_child(_detail_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_detail_panel.add_child(vbox)

	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 20)
	_detail_name.add_theme_color_override("font_color", PixelTheme.ACCENT_GOLD)
	vbox.add_child(_detail_name)

	_detail_desc = Label.new()
	_detail_desc.add_theme_font_size_override("font_size", 14)
	_detail_desc.add_theme_color_override("font_color", PixelTheme.TEXT_SECONDARY)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_detail_desc)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	_btn_take_out = _create_pixel_button("取出", PixelTheme.COLOR_UP)
	_btn_take_out.pressed.connect(_on_take_out)
	btn_row.add_child(_btn_take_out)

	_btn_discard = _create_pixel_button("丢弃", PixelTheme.COLOR_DOWN)
	_btn_discard.pressed.connect(_on_discard)
	btn_row.add_child(_btn_discard)


# ═══════════════════════════════════════════════════════════════════════════════
#  公开方法
# ═══════════════════════════════════════════════════════════════════════════════

## 加载保险柜数据（由 TL/main.gd 调用）
func load_safe_box(safe_box_manager: SafeBoxManager, player_id: int) -> void:
	_safe_box_mgr = safe_box_manager
	_player_id = player_id
	_items = _safe_box_mgr.get_items(_player_id)
	_max_slots = _safe_box_mgr.get_max_slots(_player_id)
	refresh_grid()


## 刷新网格显示（物品变动后调用）
func refresh_grid() -> void:
	# 清除旧格子
	for child in _grid_container.get_children():
		child.queue_free()

	# 重新读取数据
	if _safe_box_mgr:
		_items = _safe_box_mgr.get_items(_player_id)
		_max_slots = _safe_box_mgr.get_max_slots(_player_id)

	# 更新现金和格数
	var total_cash := 0.0
	if _safe_box_mgr:
		total_cash = _safe_box_mgr.get_total_cash(_player_id)
	_cash_label.text = "保险柜现金: $%d" % int(total_cash)
	_slots_label.text = "格数: %d/%d" % [_items.size(), _max_slots]

	# 创建格子（2列 x N行）
	var rows := ceili(float(_max_slots) / float(COLS))
	_grid_container.size.y = rows * SLOT_SIZE + (rows - 1) * GRID_GAP

	for i in range(_max_slots):
		var col := i % COLS
		var row := i / COLS
		var x := col * (SLOT_SIZE + GRID_GAP)
		var y := row * (SLOT_SIZE + GRID_GAP)

		var slot := _create_slot_panel(i)
		slot.position = Vector2(x, y)
		_grid_container.add_child(slot)

	# 重置选中状态
	_selected_idx = -1
	_detail_panel.visible = false


# ═══════════════════════════════════════════════════════════════════════════════
#  格子创建
# ═══════════════════════════════════════════════════════════════════════════════

func _create_slot_panel(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	# 像素边框
	var style: StyleBoxFlat
	if index < _items.size():
		style = PixelTheme.create_rpg_panel(PixelTheme.ACCENT_BLUE)
	else:
		style = PixelTheme.create_simple_panel()
	panel.add_theme_stylebox_override("panel", style)

	# 内容布局
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	if index < _items.size():
		var item: PlayerTypes.SafeBoxItem = _items[index]
		# 图标区域
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.color = _get_item_color(item)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(icon)

		# 物品名称
		var name_label := Label.new()
		name_label.text = _get_item_name(item)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", PixelTheme.TEXT_PRIMARY)
		vbox.add_child(name_label)

		# 物品子信息
		var sub_label := Label.new()
		sub_label.text = _get_item_sub(item)
		sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_label.add_theme_font_size_override("font_size", 10)
		sub_label.add_theme_color_override("font_color", PixelTheme.TEXT_SECONDARY)
		vbox.add_child(sub_label)
	else:
		# 空格子
		var empty_label := Label.new()
		empty_label.text = "[空]"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
		vbox.add_child(empty_label)

	# 点击选中
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_on_slot_clicked(index)
	)

	return panel


# ═══════════════════════════════════════════════════════════════════════════════
#  交互处理
# ═══════════════════════════════════════════════════════════════════════════════

func _on_slot_clicked(index: int) -> void:
	_selected_idx = index
	if index < _items.size():
		var item: PlayerTypes.SafeBoxItem = _items[index]
		_detail_name.text = _get_item_name(item)
		_detail_desc.text = _get_item_description(item)
		_detail_panel.visible = true
		_btn_take_out.visible = true
		_btn_discard.visible = true
	else:
		_detail_panel.visible = false


func _on_take_out() -> void:
	if _selected_idx < 0 or _selected_idx >= _items.size():
		return
	var item: PlayerTypes.SafeBoxItem = _items[_selected_idx]
	item_taken_out.emit(item, _selected_idx)
	# 如果有 SafeBoxManager, 执行移除
	if _safe_box_mgr:
		_safe_box_mgr.remove_item(_player_id, _selected_idx)
	refresh_grid()


func _on_discard() -> void:
	if _selected_idx < 0 or _selected_idx >= _items.size():
		return
	var item: PlayerTypes.SafeBoxItem = _items[_selected_idx]
	item_discarded.emit(item, _selected_idx)
	# 如果有 SafeBoxManager, 执行移除（丢弃 = 移除但不返还）
	if _safe_box_mgr:
		_safe_box_mgr.remove_item(_player_id, _selected_idx)
	refresh_grid()


# ═══════════════════════════════════════════════════════════════════════════════
#  物品显示辅助
# ═══════════════════════════════════════════════════════════════════════════════

func _get_item_name(item: PlayerTypes.SafeBoxItem) -> String:
	match item.item_type:
		GameEnums.SafeBoxItemType.CASH:
			return "现金"
		GameEnums.SafeBoxItemType.SKILL_CARD:
			return "技能卡"
		GameEnums.SafeBoxItemType.INTEL:
			return "情报"
		GameEnums.SafeBoxItemType.LEGENDARY:
			return "传说道具"
		_:
			return "未知物品"


func _get_item_sub(item: PlayerTypes.SafeBoxItem) -> String:
	match item.item_type:
		GameEnums.SafeBoxItemType.CASH:
			return "$%d" % int(item.amount)
		GameEnums.SafeBoxItemType.SKILL_CARD:
			return "Lv%d" % item.level
		_:
			return str(item.item_id)


func _get_item_description(item: PlayerTypes.SafeBoxItem) -> String:
	match item.item_type:
		GameEnums.SafeBoxItemType.CASH:
			return "保险柜中的现金, 无论撤离成功或失败都会保留。\n金额: $%d" % int(item.amount)
		GameEnums.SafeBoxItemType.SKILL_CARD:
			return "技能: %s (Lv%d)\n放入保险柜可跨局保留。" % [str(item.item_id), item.level]
		GameEnums.SafeBoxItemType.INTEL:
			return "情报: %s\n可跨局使用的高价值信息。" % str(item.item_id)
		GameEnums.SafeBoxItemType.LEGENDARY:
			return "传说: %s\n特殊能力道具。" % str(item.item_id)
		_:
			return "未知物品"


func _get_item_color(item: PlayerTypes.SafeBoxItem) -> Color:
	match item.item_type:
		GameEnums.SafeBoxItemType.CASH:
			return PixelTheme.ACCENT_GOLD
		GameEnums.SafeBoxItemType.SKILL_CARD:
			return PixelTheme.ACCENT_BLUE
		GameEnums.SafeBoxItemType.INTEL:
			return PixelTheme.COLOR_UP
		GameEnums.SafeBoxItemType.LEGENDARY:
			return PixelTheme.COLOR_DOWN
		_:
			return PixelTheme.TEXT_DIM


# ═══════════════════════════════════════════════════════════════════════════════
#  像素按钮工厂
# ═══════════════════════════════════════════════════════════════════════════════

func _create_pixel_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 40)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_stylebox_override("normal", PixelTheme.create_button_normal())
	btn.add_theme_stylebox_override("hover", PixelTheme.create_button_hover())
	btn.add_theme_stylebox_override("pressed", PixelTheme.create_button_pressed())
	btn.add_theme_color_override("font_color", PixelTheme.TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", PixelTheme.ACCENT_GOLD)
	return btn

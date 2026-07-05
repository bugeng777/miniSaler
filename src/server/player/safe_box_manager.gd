## 保险柜管理器
## 所有权: WS3 (玩家经济组)
## 管理保险柜的跨局资产保护逻辑
extends Node
class_name SafeBoxManager

signal safe_box_updated(player_id: int, contents: Array)


## 玩家保险柜数据（从存档加载）
var _safe_boxes: Dictionary = {}  ## player_id -> Array[PlayerTypes.SafeBoxItem]
var _max_slots: Dictionary = {}   ## player_id -> int


## 初始化玩家保险柜
func initialize(player_id: int, items: Array[PlayerTypes.SafeBoxItem], slots: int) -> void:
	_safe_boxes[player_id] = items
	_max_slots[player_id] = slots


## 获取保险柜物品
func get_items(player_id: int) -> Array[PlayerTypes.SafeBoxItem]:
	return _safe_boxes.get(player_id, [])


## 获取最大格数
func get_max_slots(player_id: int) -> int:
	return _max_slots.get(player_id, Constants.INITIAL_SAFE_BOX_SLOTS)


## 添加物品到保险柜
func add_item(player_id: int, item: PlayerTypes.SafeBoxItem) -> bool:
	if not _safe_boxes.has(player_id):
		_safe_boxes[player_id] = []
	var items: Array = _safe_boxes[player_id]
	if items.size() >= get_max_slots(player_id):
		return false
	items.append(item)
	safe_box_updated.emit(player_id, items)
	return true


## 从保险柜移除物品
func remove_item(player_id: int, index: int) -> PlayerTypes.SafeBoxItem:
	if not _safe_boxes.has(player_id):
		return null
	var items: Array = _safe_boxes[player_id]
	if index < 0 or index >= items.size():
		return null
	var item: PlayerTypes.SafeBoxItem = items[index]
	items.remove_at(index)
	safe_box_updated.emit(player_id, items)
	return item


## 获取保险柜中现金总额
func get_total_cash(player_id: int) -> float:
	var total := 0.0
	for item in get_items(player_id):
		if item.item_type == GameEnums.SafeBoxItemType.CASH:
			total += item.amount
	return total


## 升级保险柜格数
func upgrade_slots(player_id: int, new_slots: int) -> void:
	if _max_slots.has(player_id):
		_max_slots[player_id] = maxi(_max_slots[player_id], new_slots)
	else:
		_max_slots[player_id] = new_slots

## UI 管理器
## 所有权: WS5 (客户端 UI 组)
## 管理 UI 屏幕栈、屏幕切换、全局 UI 状态
extends Control
class_name UIManager


## 屏幕引用
var _screens: Dictionary = {}  ## screen_name -> Control
var _current_screen: Control = null
var _screen_stack: Array[Control] = []


## 注册屏幕
func register_screen(name: String, screen: Control) -> void:
	_screens[name] = screen
	screen.visible = false
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## 显示屏幕（替换当前）
func show_screen(name: String) -> void:
	if not _screens.has(name):
		push_warning("UIManager: Screen '%s' not found" % name)
		return
	if _current_screen:
		_current_screen.visible = false
	_current_screen = _screens[name]
	_current_screen.visible = true


## 推入屏幕（保留前一个）
func push_screen(name: String) -> void:
	if _current_screen:
		_screen_stack.push_back(_current_screen)
		_current_screen.visible = false
	if _screens.has(name):
		_current_screen = _screens[name]
		_current_screen.visible = true


## 弹出屏幕（回到前一个）
func pop_screen() -> void:
	if _current_screen:
		_current_screen.visible = false
	if _screen_stack.size() > 0:
		_current_screen = _screen_stack.pop_back()
		_current_screen.visible = true


## 获取当前屏幕
func get_current_screen() -> Control:
	return _current_screen


## 按名称获取已注册屏幕
func get_screen(screen_name: String) -> Control:
	return _screens.get(screen_name, null)


## 获取所有已注册屏幕名称
func get_screen_names() -> Array[String]:
	var names: Array[String] = []
	for key in _screens:
		names.append(key)
	return names

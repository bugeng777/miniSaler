## 启动流程编排
## 所有权: TL (架构师)
## 管理游戏启动前的初始化流程（存档加载、配置验证等）
extends Node
class_name GameBootstrap


## 启动前检查与初始化
func bootstrap() -> Dictionary:
	var result := {
		"success": true,
		"profile": null,
		"errors": [],
	}

	# 1. 验证项目配置
	if not _validate_config():
		result.success = false
		result.errors.append("Config validation failed")

	# 2. 确保存档目录存在
	DirAccess.make_dir_recursive_absolute("user://saves/")

	# 3. 加载存档
	var save_mgr := SaveManager.new()
	var profile := save_mgr.load_profile()
	result.profile = profile

	return result


## 验证项目配置完整性
func _validate_config() -> bool:
	# 检查必要常量是否定义
	if Constants.MAX_PLAYERS <= 0:
		push_error("GameBootstrap: MAX_PLAYERS must be > 0")
		return false
	if Constants.TICK_INTERVAL <= 0.0:
		push_error("GameBootstrap: TICK_INTERVAL must be > 0")
		return false
	return true

## 真实渲染器 UI 调试入口。
## 用法: godot --path . --write-movie /tmp/screen.png --script res://tests/ui_screen_capture.gd -- tutorial
extends SceneTree

func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	var main := Main.new()
	root.add_child(main)
	await process_frame
	await process_frame
	var args := OS.get_cmdline_user_args()
	var screen_name := args[0] if not args.is_empty() else "main_menu"
	if main._ui_manager:
		main._ui_manager.show_screen(screen_name)

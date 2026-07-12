## 诊断测试：逐帧输出看哪里卡
extends SceneTree

var _timer: float = 0.0
var _main: Main = null
var _phase: int = 0
var _frame_count: int = 0
var _last_frame_print: int = 0


func _process(delta: float) -> bool:
	_frame_count += 1
	_timer += delta
	# 每10帧输出一次（比之前更密集）
	if _frame_count - _last_frame_print >= 10:
		var gs := _main._game_session if _main else null
		var tc := gs._tick_count if gs else -1
		var gp := gs._current_phase if gs else -1
		print("[T] f=%d t=%.2f p=%d tick=%d gp=%d" % [_frame_count, _timer, _phase, tc, gp])
		_last_frame_print = _frame_count

	if _phase == 0 and _timer > 0.5:
		_main = Main.new()
		root.add_child(_main)
		_phase = 1
		_timer = 0.0
	elif _phase == 1 and _timer > 0.5:
		_main._game_session.host_select_era(&"hk_1997")
		_phase = 2
		_timer = 0.0
	elif _phase == 2 and _timer > 0.5:
		print("[T] calling host_start_game")
		_main._game_session.host_start_game()
		print("[T] host_start_game returned")
		_phase = 3
		_timer = 0.0
	elif _phase == 3 and _timer > 6.0:
		print("[T] PASS")
		quit(0)
	return false

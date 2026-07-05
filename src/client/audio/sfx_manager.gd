## 音效管理器
## 所有权: WS5 (客户端 UI 组)
## 管理游戏音效的播放（买入/卖出/撤离/爆仓/新闻等）
extends Node
class_name SfxManager


## 音效类型枚举
enum SfxType {
	BUY,
	SELL,
	EXTRACTION_SUCCESS,
	BUST,
	NEWS_ALERT,
	BLACK_SWAN,
	BOSS_ENTER,
	WINDOW_OPEN,
	TICK,
}


## 音效播放器池
var _players: Array[AudioStreamPlayer] = []
const MAX_PLAYERS := 8


func _ready() -> void:
	for i in range(MAX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)


## 播放音效
func play_sfx(sfx_type: int) -> void:
	var player := _get_available_player()
	if not player:
		return
	# TODO: 加载实际音效文件后替换
	# player.stream = load("res://assets/audio/%s.ogg" % _get_sfx_path(sfx_type))
	# player.play()


## 播放盈利音效
func play_profit() -> void:
	play_sfx(SfxType.BUY)


## 播放亏损音效
func play_loss() -> void:
	play_sfx(SfxType.SELL)


## 播放撤离成功音效
func play_extraction_success() -> void:
	play_sfx(SfxType.EXTRACTION_SUCCESS)


## 播放爆仓音效
func play_bust() -> void:
	play_sfx(SfxType.BUST)


## 获取可用播放器
func _get_available_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	return null


## 获取音效资源路径
func _get_sfx_path(sfx_type: int) -> String:
	match sfx_type:
		SfxType.BUY: return "buy"
		SfxType.SELL: return "sell"
		SfxType.EXTRACTION_SUCCESS: return "extraction_success"
		SfxType.BUST: return "bust"
		SfxType.NEWS_ALERT: return "news_alert"
		SfxType.BLACK_SWAN: return "black_swan"
		SfxType.BOSS_ENTER: return "boss_enter"
		SfxType.WINDOW_OPEN: return "window_open"
		SfxType.TICK: return "tick"
	return "tick"

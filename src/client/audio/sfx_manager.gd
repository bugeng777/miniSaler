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


## 音效流缓存
var _streams: Dictionary = {}  ## SfxType -> AudioStream

## 音效播放器池
var _players: Array[AudioStreamPlayer] = []
const MAX_PLAYERS := 8


func _ready() -> void:
	for i in range(MAX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)
	# 预加载所有音效文件
	_preload_streams()


## 预加载音效流
func _preload_streams() -> void:
	var sfx_names := {
		SfxType.BUY: "buy",
		SfxType.SELL: "sell",
		SfxType.EXTRACTION_SUCCESS: "extraction_success",
		SfxType.BUST: "bust",
		SfxType.NEWS_ALERT: "news_alert",
		SfxType.BLACK_SWAN: "black_swan",
		SfxType.BOSS_ENTER: "boss_enter",
		SfxType.WINDOW_OPEN: "window_open",
		SfxType.TICK: "tick",
	}
	for sfx_type in sfx_names:
		var path := "res://assets/audio/%s.wav" % sfx_names[sfx_type]
		if ResourceLoader.exists(path):
			_streams[sfx_type] = load(path)


## 播放音效
func play_sfx(sfx_type: int) -> void:
	var player := _get_available_player()
	if not player:
		return
	if _streams.has(sfx_type):
		player.stream = _streams[sfx_type]
		player.play()


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


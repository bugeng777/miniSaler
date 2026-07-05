## 音效管理器
## 所有权: WS5 (客户端 UI 组)
## 管理游戏音效的播放，使用 AudioStreamWAV 生成占位音效
extends Node
class_name SfxManager

enum SfxType { BUY, SELL, EXTRACTION_SUCCESS, BUST, NEWS_ALERT, BLACK_SWAN, BOSS_ENTER, WINDOW_OPEN, TICK }

var _players: Array[AudioStreamPlayer] = []
const MAX_PLAYERS := 8
var _streams: Dictionary = {}
const SAMPLE_RATE := 22050.0

func _ready() -> void:
	for i in range(MAX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)
	_generate_all_sfx()

func _generate_all_sfx() -> void:
	_streams[SfxType.BUY] = _generate_sweep(440.0, 880.0, 0.1)
	_streams[SfxType.SELL] = _generate_sweep(880.0, 440.0, 0.1)
	_streams[SfxType.EXTRACTION_SUCCESS] = _generate_chord([261.6, 329.6, 392.0], 0.5)
	_streams[SfxType.BUST] = _generate_sweep(220.0, 55.0, 0.5)
	_streams[SfxType.NEWS_ALERT] = _generate_tone(660.0, 0.05)
	_streams[SfxType.BLACK_SWAN] = _generate_sweep(300.0, 50.0, 0.4)
	_streams[SfxType.BOSS_ENTER] = _generate_drum_pulses(3)
	_streams[SfxType.WINDOW_OPEN] = _generate_tone(523.2, 0.15)
	_streams[SfxType.TICK] = _generate_tone(1000.0, 0.02)

func _generate_sweep(freq_start: float, freq_end: float, duration: float) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	for i in range(sample_count):
		var t := float(i) / float(sample_count)
		var freq := freq_start + (freq_end - freq_start) * t
		phase += TAU * freq / SAMPLE_RATE
		var envelope := 1.0 - t * 0.5
		var sample_val := sin(phase) * envelope * 0.6
		var int_sample := int(clamp(sample_val * 32767.0, -32768.0, 32767.0))
		data[i * 2] = int_sample & 0xFF
		data[i * 2 + 1] = (int_sample >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(SAMPLE_RATE)
	wav.stereo = false
	wav.data = data
	return wav

func _generate_tone(freq: float, duration: float) -> AudioStreamWAV:
	return _generate_sweep(freq, freq, duration)

func _generate_chord(freqs: Array[float], duration: float) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var amplitude := 0.6 / freqs.size()
	for i in range(sample_count):
		var t := float(i) / float(sample_count)
		var sum := 0.0
		for freq in freqs:
			sum += sin(TAU * freq * float(i) / SAMPLE_RATE)
		var envelope := sin(t * PI)
		var sample_val := sum * amplitude * envelope
		var int_sample := int(clamp(sample_val * 32767.0, -32768.0, 32767.0))
		data[i * 2] = int_sample & 0xFF
		data[i * 2 + 1] = (int_sample >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(SAMPLE_RATE)
	wav.stereo = false
	wav.data = data
	return wav

func _generate_drum_pulses(count: int) -> AudioStreamWAV:
	var pulse_duration := 0.08
	var gap_duration := 0.05
	var total_duration := count * pulse_duration + (count - 1) * gap_duration
	var sample_count := int(total_duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var freq := 80.0
	for i in range(sample_count):
		var t := float(i) / SAMPLE_RATE
		var cycle := pulse_duration + gap_duration
		var pos_in_cycle := fmod(t, cycle)
		var in_pulse := pos_in_cycle < pulse_duration
		var sample_val := 0.0
		if in_pulse:
			var envelope := 1.0 - (pos_in_cycle / pulse_duration) * 0.7
			sample_val = (1.0 if sin(TAU * freq * t) > 0 else -1.0) * envelope * 0.7
		var int_sample := int(clamp(sample_val * 32767.0, -32768.0, 32767.0))
		data[i * 2] = int_sample & 0xFF
		data[i * 2 + 1] = (int_sample >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(SAMPLE_RATE)
	wav.stereo = false
	wav.data = data
	return wav

func play_sfx(sfx_type: int) -> void:
	var player := _get_available_player()
	if not player:
		return
	var stream = _streams.get(sfx_type)
	if stream:
		player.stream = stream
		player.play()

func play_profit() -> void:
	play_sfx(SfxType.BUY)

func play_loss() -> void:
	play_sfx(SfxType.SELL)

func play_extraction_success() -> void:
	play_sfx(SfxType.EXTRACTION_SUCCESS)

func play_bust() -> void:
	play_sfx(SfxType.BUST)

func _get_available_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	return null

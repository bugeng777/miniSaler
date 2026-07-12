## 顶栏（阶段/计时/现金/总资产/恐惧贪婪指数）
## 所有权: WS5 (客户端 UI 组)
extends HBoxContainer
class_name TopBar

var _phase_label: Label = null
var _timer_label: Label = null
var _cash_label: Label = null
var _assets_label: Label = null
var _fgi_label: Label = null
var _fgi_blocks: Array[ColorRect] = []


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	add_theme_constant_override("separation", 4)
	_phase_label = Label.new()
	_phase_label.text = "--"
	_phase_label.add_theme_color_override("font_color", PixelTheme.ACCENT_GOLD)
	add_child(_phase_label)
	add_child(_create_separator())

	_timer_label = Label.new()
	_timer_label.text = "00:00"
	add_child(_timer_label)
	add_child(_create_separator())

	_cash_label = Label.new()
	_cash_label.text = "$0"
	add_child(_cash_label)
	add_child(_create_separator())

	_assets_label = Label.new()
	_assets_label.text = "Σ$0"
	add_child(_assets_label)
	add_child(_create_separator())

	_fgi_label = Label.new()
	var fgi_box := VBoxContainer.new()
	fgi_box.add_theme_constant_override("separation", 1)
	add_child(fgi_box)
	_fgi_label.text = "FGI 50"
	_fgi_label.add_theme_font_size_override("font_size", 9)
	fgi_box.add_child(_fgi_label)
	var block_bar := HBoxContainer.new()
	block_bar.add_theme_constant_override("separation", 1)
	fgi_box.add_child(block_bar)
	for i in range(10):
		var block := ColorRect.new()
		block.custom_minimum_size = Vector2(5, 4)
		block.color = PixelTheme.TEXT_DIM
		block_bar.add_child(block)
		_fgi_blocks.append(block)


func update_phase(phase_name: String) -> void:
	_phase_label.text = phase_name


func update_timer(seconds: float) -> void:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	_timer_label.text = "%02d:%02d" % [mins, secs]


func update_cash(cash: float) -> void:
	_cash_label.text = "$%s" % _format_money(cash)


func update_assets(assets: float) -> void:
	_assets_label.text = "Σ$%s" % _format_money(assets)


func update_fear_greed(fgi: float) -> void:
	var label := "恐惧" if fgi < 40 else ("贪婪" if fgi > 60 else "中性")
	_fgi_label.text = "FGI %.0f %s" % [fgi, label]
	var filled := clampi(roundi(fgi / 10.0), 0, 10)
	var active_color := (PixelTheme.COLOR_DOWN if fgi < 40.0
		else PixelTheme.COLOR_UP if fgi > 60.0 else PixelTheme.ACCENT_GOLD)
	for i in range(_fgi_blocks.size()):
		_fgi_blocks[i].color = active_color if i < filled else PixelTheme.TEXT_DIM


func _create_separator() -> Label:
	var sep := Label.new()
	sep.text = "│"
	sep.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	return sep


func _format_money(value: float) -> String:
	if absf(value) >= 1_000_000.0:
		return "%.1fM" % (value / 1_000_000.0)
	if absf(value) >= 1_000.0:
		return "%.0fK" % (value / 1_000.0)
	return "%.0f" % value

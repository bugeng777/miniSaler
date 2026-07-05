## 顶栏（阶段/计时/现金/总资产/恐惧贪婪指数 + 撤离进度条）
## 所有权: WS5 (客户端 UI 组)
extends VBoxContainer
class_name TopBar

const PHASE_COLORS := {
	"ERA_SELECT": Color(0.3, 0.5, 1.0),
	"LOADOUT": Color(1.0, 0.85, 0.2),
	"TRADING": Color(0.2, 0.9, 0.3),
	"SETTLEMENT": Color(0.5, 0.5, 0.5),
}

var _phase_label: Label = null
var _timer_label: Label = null
var _cash_label: Label = null
var _assets_label: Label = null
var _fgi_label: Label = null
var _info_row: HBoxContainer = null
var _extraction_bar: ProgressBar = null

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	_info_row = HBoxContainer.new()
	add_child(_info_row)
	_phase_label = Label.new()
	_phase_label.text = "阶段: --"
	_info_row.add_child(_phase_label)
	_info_row.add_child(_create_separator())
	_timer_label = Label.new()
	_timer_label.text = "00:00"
	_info_row.add_child(_timer_label)
	_info_row.add_child(_create_separator())
	_cash_label = Label.new()
	_cash_label.text = "现金: $0"
	_info_row.add_child(_cash_label)
	_info_row.add_child(_create_separator())
	_assets_label = Label.new()
	_assets_label.text = "总资产: $0"
	_info_row.add_child(_assets_label)
	_info_row.add_child(_create_separator())
	_fgi_label = Label.new()
	_fgi_label.text = "恐贪: 50"
	_info_row.add_child(_fgi_label)
	_extraction_bar = ProgressBar.new()
	_extraction_bar.min_value = 0.0
	_extraction_bar.max_value = 100.0
	_extraction_bar.value = 0.0
	_extraction_bar.custom_minimum_size = Vector2(0, 6)
	_extraction_bar.show_percentage = false
	_extraction_bar.visible = false
	add_child(_extraction_bar)

func update_phase(phase_name: String, color: Color = Color.WHITE) -> void:
	_phase_label.text = "阶段: " + phase_name
	if color == Color.WHITE:
		color = PHASE_COLORS.get(phase_name, Color.WHITE)
	_phase_label.add_theme_color_override("font_color", color)

func update_extraction_status(is_window_open: bool, remaining: float) -> void:
	if is_window_open:
		_extraction_bar.visible = true
		var max_window: float = max(remaining, 30.0)
		_extraction_bar.value = (remaining / max_window) * 100.0
		var bar_style := StyleBoxFlat.new()
		bar_style.bg_color = Color(0.2, 0.9, 0.3)
		_extraction_bar.add_theme_stylebox_override("fill", bar_style)
	else:
		_extraction_bar.visible = false

func update_timer(seconds: float) -> void:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	_timer_label.text = "%02d:%02d" % [mins, secs]

func update_cash(cash: float) -> void:
	_cash_label.text = "现金: $%.0f" % cash

func update_assets(assets: float) -> void:
	_assets_label.text = "总资产: $%.0f" % assets

func update_fear_greed(fgi: float) -> void:
	var label := "恐惧" if fgi < 40 else ("贪婪" if fgi > 60 else "中性")
	_fgi_label.text = "恐贪: %.0f (%s)" % [fgi, label]

func _create_separator() -> Label:
	var sep := Label.new()
	sep.text = " | "
	return sep

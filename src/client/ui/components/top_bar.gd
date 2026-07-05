## 顶栏（阶段/计时/现金/总资产/恐惧贪婪指数）
## 所有权: WS5 (客户端 UI 组)
extends HBoxContainer
class_name TopBar

var _phase_label: Label = null
var _timer_label: Label = null
var _cash_label: Label = null
var _assets_label: Label = null
var _fgi_label: Label = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	_phase_label = Label.new()
	_phase_label.text = "阶段: --"
	add_child(_phase_label)
	add_child(_create_separator())

	_timer_label = Label.new()
	_timer_label.text = "00:00"
	add_child(_timer_label)
	add_child(_create_separator())

	_cash_label = Label.new()
	_cash_label.text = "现金: $0"
	add_child(_cash_label)
	add_child(_create_separator())

	_assets_label = Label.new()
	_assets_label.text = "总资产: $0"
	add_child(_assets_label)
	add_child(_create_separator())

	_fgi_label = Label.new()
	_fgi_label.text = "恐贪: 50"
	add_child(_fgi_label)


func update_phase(phase_name: String) -> void:
	_phase_label.text = "阶段: " + phase_name


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

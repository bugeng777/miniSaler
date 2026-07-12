## 可复用的代码像素图标。
## 每个图标由 12×12 字符网格绘制，缩放始终使用整数像素，避免 Emoji/矢量缩放发糊。
extends Control
class_name PixelIcon


enum Icon {
	TROPHY,
	LOCK,
	NEWS,
	LIGHTNING,
}

static var PATTERNS: Dictionary = {
	Icon.TROPHY: PackedStringArray([
		"............",
		".GGGGGGGGGG.",
		"GGYYYYYYYYGG",
		"G.YYYYYYYY.G",
		"..YYYYYYYY..",
		"...YYYYYY...",
		"....YYYY....",
		".....YY.....",
		"....YYYY....",
		"...YYYYYY...",
		"..GGGGGGGG..",
		"............",
	]),
	Icon.LOCK: PackedStringArray([
		"............",
		"....BBBB....",
		"...BB..BB...",
		"...BB..BB...",
		"..BBBBBBBB..",
		"..BYYYYYYB..",
		"..BYYBBYYB..",
		"..BYYBBYYB..",
		"..BYYYYYYB..",
		"..BBBBBBBB..",
		"............",
		"............",
	]),
	Icon.NEWS: PackedStringArray([
		"............",
		".BBBBBBBBBB.",
		".BWWWWWWWWB.",
		".BWBBBBBBWB.",
		".BWWWWWWWWB.",
		".BWBBBBWWWB.",
		".BWWWWWWWWB.",
		".BWBBBBBBWB.",
		".BWWWWWWWWB.",
		".BBBBBBBBBB.",
		"............",
		"............",
	]),
	Icon.LIGHTNING: PackedStringArray([
		".......YY...",
		"......YYY...",
		".....YYYY...",
		"....YYYY....",
		"...YYYYYY...",
		"..YYYYYY....",
		".....YYY....",
		"....YYY.....",
		"...YYY......",
		"..YYY.......",
		"..YY........",
		"............",
	]),
}

static var COLORS: Dictionary = {
	"Y": Color("#f7b801"),
	"G": Color("#d07d11"),
	"B": Color("#333c57"),
	"W": Color("#f4f4f4"),
}

@export var icon_type: Icon = Icon.TROPHY:
	set(value):
		icon_type = value
		queue_redraw()

@export_range(1, 8, 1) var pixel_size: int = 2:
	set(value):
		pixel_size = maxi(value, 1)
		custom_minimum_size = Vector2(12, 12) * pixel_size
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(12, 12) * pixel_size
	queue_redraw()


func _draw() -> void:
	var pattern: PackedStringArray = PATTERNS.get(icon_type, PackedStringArray())
	if pattern.is_empty():
		pattern = PATTERNS.get(Icon.TROPHY, PackedStringArray())
	var icon_size := Vector2(12, 12) * pixel_size
	var origin := ((size - icon_size) * 0.5).floor()
	for y in range(pattern.size()):
		var row: String = pattern[y]
		for x in range(row.length()):
			var key := row.substr(x, 1)
			if key == ".":
				continue
			draw_rect(
				Rect2(origin + Vector2(x, y) * pixel_size, Vector2.ONE * pixel_size),
				COLORS.get(key, PixelTheme.TEXT_PRIMARY))

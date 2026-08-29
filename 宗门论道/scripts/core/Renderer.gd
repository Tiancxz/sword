## ============================================================
## Renderer.gd - 渲染工具（绘制辅助层）
## ============================================================
## 作用: 提供统一的绘制辅助方法，供各场景在_draw()中调用。
## 设计: autoload单例，持有颜色常量和封装的绘制函数。
##       各CanvasItem在自己的_draw()中调用Renderer的方法。
## 注意: draw_rect/draw_string是CanvasItem实例方法，
##       必须在_draw()上下文中调用。Renderer作为Node2D autoload，
##       自身也可绘制全局UI/调试信息。
## ============================================================

extends Node2D

# ===== 颜色常量（修仙主题配色）=====
const COLOR_BG: Color = Color(0.08, 0.06, 0.12, 1)          # 深紫黑背景
const COLOR_GOLD: Color = Color(0.9, 0.8, 0.5, 1)           # 金色（标题/高亮）
const COLOR_WHITE: Color = Color(1, 1, 1, 1)                # 白色
const COLOR_RED: Color = Color(0.8, 0.2, 0.2, 1)            # 红色（血条背景/伤害）
const COLOR_GREEN: Color = Color(0.2, 0.8, 0.3, 1)          # 绿色（血条前景/治疗）
const COLOR_BLUE: Color = Color(0.3, 0.5, 0.9, 1)           # 蓝色（灵力）
const COLOR_GRAY: Color = Color(0.5, 0.5, 0.5, 1)           # 灰色（调试）
const COLOR_DARK: Color = Color(0.15, 0.12, 0.18, 1)        # 暗色（面板背景）
const COLOR_PANEL: Color = Color(0.2, 0.16, 0.26, 0.9)      # 半透明面板

## 默认字体（矢量字体，避免位图字体放大后模糊）
var _font: Font = null

## 是否显示调试信息
var show_debug: bool = true

## 字体资源路径（Noto Sans SC，SIL开源协议）
const FONT_PATH: String = "res://assets/fonts/NotoSansSC-Regular.otf"


## ============================================================
## 初始化
## ============================================================

func _ready() -> void:
	# 优先加载项目内置的矢量字体（解决fallback_font位图字体放大模糊问题）
	var loaded_font = load(FONT_PATH)
	if loaded_font is FontFile:
		# 启用抗锯齿和hinting提升小字号清晰度
		loaded_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		loaded_font.hinting = TextServer.HINTING_LIGHT
		loaded_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_ONE_HALF
		_font = loaded_font
		print("[Renderer] 已加载矢量字体: ", FONT_PATH)
	else:
		_font = ThemeDB.fallback_font
		push_warning("[Renderer] 矢量字体加载失败，回退到fallback_font")
	z_index = 100  # 渲染在最上层


## 获取全局字体（供其他场景的_draw调用）
## [return] 当前使用的Font实例
func get_font() -> Font:
	return _font


## ============================================================
## 绘制方法（在_draw中调用）
## ============================================================

## 绘制填充矩形
## [param rect] 矩形区域
## [param color] 填充颜色
## [param filled] 是否填充（false则只画边框）
func draw_filled_rect(rect: Rect2, color: Color, filled: bool = true) -> void:
	draw_rect(rect, color, filled)


## 绘制文字
## [param pos] 文字位置（左上角基准）
## [param text] 文字内容
## [param size] 字号
## [param color] 颜色
func draw_text(pos: Vector2, text: String, size: int = 16, color: Color = COLOR_WHITE) -> void:
	if _font:
		draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## 绘制居中文字
## [param center_pos] 中心位置
## [param text] 文字内容
## [param size] 字号
## [param color] 颜色
func draw_text_centered(center_pos: Vector2, text: String, size: int = 16, color: Color = COLOR_WHITE) -> void:
	if _font:
		draw_string(_font, center_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, size, color)


## 绘制血条
## [param pos] 血条左上角位置
## [param w] 血条总宽度
## [param h] 血条高度
## [param ratio] 血量比例（0.0~1.0）
func draw_health_bar(pos: Vector2, w: float, h: float, ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	# 背景（红色底）
	draw_rect(Rect2(pos.x, pos.y, w, h), COLOR_RED, true)
	# 前景（绿色，宽度按比例）
	var fg_w = w * ratio
	if fg_w > 0:
		draw_rect(Rect2(pos.x, pos.y, fg_w, h), COLOR_GREEN, true)
	# 边框
	draw_rect(Rect2(pos.x, pos.y, w, h), COLOR_WHITE, false, 1.0)


## 绘制灵力条（蓝色）
## [param pos] 灵力条左上角位置
## [param w] 总宽度
## [param h] 高度
## [param ratio] 灵力比例（0.0~1.0）
func draw_energy_bar(pos: Vector2, w: float, h: float, ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	# 背景
	draw_rect(Rect2(pos.x, pos.y, w, h), COLOR_DARK, true)
	# 前景
	var fg_w = w * ratio
	if fg_w > 0:
		draw_rect(Rect2(pos.x, pos.y, fg_w, h), COLOR_BLUE, true)
	# 边框
	draw_rect(Rect2(pos.x, pos.y, w, h), COLOR_WHITE, false, 1.0)


## 绘制圆（用多边形近似）
## [param center] 圆心
## [param radius] 半径
## [param color] 颜色
## [param filled] 是否填充
func draw_circle_filled(center: Vector2, radius: float, color: Color, filled: bool = true) -> void:
	draw_circle(center, radius, color)
	if not filled:
		# 空心圆：用线段画外圈
		var pts: PackedVector2Array = []
		var segments = 32
		for i in range(segments):
			var angle = TAU * i / segments
			pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
		for i in range(segments):
			draw_line(pts[i], pts[(i + 1) % segments], color, 1.0)


## 绘制面板背景（半透明圆角矩形效果）
## [param rect] 面板区域
## [param bg_color] 背景色
func draw_panel(rect: Rect2, bg_color: Color = COLOR_PANEL) -> void:
	draw_rect(rect, bg_color, true)
	draw_rect(rect, COLOR_GOLD, false, 1.5)


## ============================================================
## 调试绘制
## ============================================================

func _draw() -> void:
	if not show_debug:
		return
	if _font:
		draw_string(_font, Vector2(10, 20), "Renderer OK", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_GRAY)


## 请求重绘
func request_redraw() -> void:
	queue_redraw()

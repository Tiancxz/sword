## ============================================================
## Main.gd - 主场景脚本（游戏入口）
## ============================================================
## 作用: 游戏启动入口，显示标题界面，点击屏幕进入战斗场景。
## 设计: Main只负责标题展示与场景切换，不包含战斗业务逻辑。
## 流程: _ready初始化 → 点击屏幕 → SceneManager切换到battle场景。
## ============================================================

extends Node2D

## 累计运行时间（调试用）
var _elapsed: float = 0.0


## ============================================================
## 生命周期
## ============================================================

## 场点就绪时调用（项目启动入口）
func _ready() -> void:
	print("========================================")
	print("  《宗门论道》启动")
	print("  Godot版 v1.0")
	print("========================================")
	print("[Main] 点击屏幕开始游戏")


## 每帧更新（仅用于调试计时与闪烁提示）
func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


## 点击/触摸屏幕 → 进入战斗场景
func _input(event: InputEvent) -> void:
	var is_press: bool = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_press = event.pressed
	elif event is InputEventScreenTouch:
		is_press = event.pressed
	if is_press:
		print("[Main] 开始游戏，切换到战斗场景")
		SceneManager.switch("battle")


## ============================================================
## 画面渲染
## ============================================================

func _draw() -> void:
	var font = ThemeDB.fallback_font
	if font:
		# 调试信息
		draw_string(font, Vector2(10, 20), "FPS: %.0f" % Engine.get_frames_per_second(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.5, 0.5, 0.8))

		# 闪烁的"点击开始"提示（每秒闪一次）
		var blink: float = sin(_elapsed * 3.0) * 0.5 + 0.5
		var hint_alpha: float = 0.4 + blink * 0.6
		draw_string(font, Vector2(360, 1150), "点击屏幕开始",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 24,
			Color(0.9, 0.8, 0.5, hint_alpha))


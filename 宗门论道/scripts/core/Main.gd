## ============================================================
## Main.gd - 主场景脚本（游戏入口）
## ============================================================
## 作用: 游戏启动入口，驱动主循环。
## 设计: Main只负责驱动，不包含业务逻辑。具体逻辑在各场景中实现。
## 流程: _ready初始化 → _process每帧更新 → 场景切换时自动清理。
## ============================================================

extends Node2D

## 游戏是否运行中（用于暂停/恢复）
var _running: bool = true

## 累计运行时间（调试用）
var _elapsed: float = 0.0

## 是否需要重绘
var _need_redraw: bool = true


## ============================================================
## 生命周期
## ============================================================

## 场点就绪时调用（项目启动入口）
func _ready() -> void:
	print("========================================")
	print("  《宗门论道》启动")
	print("  Godot版 v1.0")
	print("========================================")

	# 初始化场景管理器（SceneManager是autoload，已自动实例化）
	# SceneManager._ready()会自动注册场景，无需手动调用

	# 后续可在此添加: 加载存档、初始化平台适配等
	print("[Main] 初始化完成")


## 每帧更新（Godot自动调用，delta为距上一帧的秒数）
## [param delta] 帧间隔（秒），通常约0.016（60fps）
func _process(delta: float) -> void:
	# 暂停时不更新
	if not _running:
		return

	_elapsed += delta

	# 分发逻辑更新到当前场景
	on_update(delta)

	# 触发重绘
	if _need_redraw:
		queue_redraw()


## 逻辑更新（虚方法，子类/场景重写以实现具体逻辑）
## [param delta] 帧间隔（秒）
func on_update(delta: float) -> void:
	pass


## ============================================================
## 画面渲染
## ============================================================

## 自定义绘制（Godot自动调用，需先queue_redraw触发）
func _draw() -> void:
	# 绘制调试信息：左上角显示运行时间
	var font = ThemeDB.fallback_font
	if font:
		draw_string(font, Vector2(10, 20), "FPS: %.0f" % Engine.get_frames_per_second(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.5, 0.5, 0.8))
		draw_string(font, Vector2(10, 40), "Time: %.1fs" % _elapsed, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 0.5, 0.5, 0.8))

	# 标记已绘制，下帧按需再触发
	_need_redraw = false


## 请求重绘（外部调用以触发下次_draw）
func request_redraw() -> void:
	_need_redraw = true


## ============================================================
## 暂停 / 恢复
## ============================================================

## 暂停游戏
func pause_game() -> void:
	_running = false
	print("[Main] 游戏暂停")

## 恢复游戏
func resume_game() -> void:
	_running = true
	print("[Main] 游戏恢复")

## ============================================================
## InputManager.gd - 输入管理器
## ============================================================
## 作用: 统一处理触摸/鼠标输入，分发到注册的回调。
## 设计: 注册-回调模式。场景注册点击区域，命中时触发回调。
## 扩展: 可添加拖拽、长按等输入类型，只需新增register方法。
## 跨平台: Godot的InputEvent自动适配PC鼠标和手机触屏。
## ============================================================

extends Node

## 点击区域定义
## id: 唯一标识，用于注销
## rect: 点击区域(Rect2)
## callback: 命中时调用的Callable，参数为点击位置Vector2
var _regions: Array[Dictionary] = []


## ============================================================
## 注册 / 注销
## ============================================================

## 注册一个点击区域
## [param id] 唯一标识，用于后续注销
## [param rect] 点击区域（全局坐标）
## [param callback] 命中时回调，签名: func(pos: Vector2) -> void
func register(id: String, rect: Rect2, callback: Callable) -> void:
	# 如果id已存在，先移除旧的（避免重复注册）
	unregister(id)
	_regions.append({
		"id": id,
		"rect": rect,
		"callback": callback
	})


## 注销某个点击区域
## [param id] 要注销的区域标识
func unregister(id: String) -> void:
	for i in range(_regions.size() - 1, -1, -1):
		if _regions[i]["id"] == id:
			_regions.remove_at(i)
			return


## 清空所有点击区域（场景切换时必须调用，防止旧回调残留）
func clear() -> void:
	_regions.clear()


## ============================================================
## 输入处理（Godot自动调用）
## ============================================================

## 处理输入事件
## Godot会在每次输入时自动调用此方法
## 支持鼠标点击(InputEventMouseButton)和触屏(InputEventScreenTouch)
func _input(event: InputEvent) -> void:
	var pos: Vector2 = Vector2.ZERO
	var is_press: bool = false
	
	# 鼠标点击（PC端）
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			pos = event.position
			is_press = event.pressed
	# 触屏点击（手机/微信小游戏端）
	elif event is InputEventScreenTouch:
		pos = event.position
		is_press = event.pressed
	
	# 只处理按下事件（松开不触发回调）
	if not is_press:
		return
	
	# 命中检测：遍历所有区域，触发第一个命中的回调
	for region in _regions:
		if region["rect"].has_point(pos):
			region["callback"].call(pos)
			# 消费该输入，阻止继续传播
			get_viewport().set_input_as_handled()
			return

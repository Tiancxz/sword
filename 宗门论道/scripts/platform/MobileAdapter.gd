## ============================================================
## MobileAdapter.gd - 移动端适配
## ============================================================
## 作用: 处理安卓/iOS平台特有的适配（安全区域、触屏优化、振动反馈）。
## 设计: Node（_ready时检测安全区域），由PlatformAdapter按需实例化。
## 依赖: Godot的DisplayServer和OS API
## 对应: I4.02 触屏适配
## 注意:
##   - InputEventScreenTouch已在InputManager中处理，无需重复
##   - 本类聚焦安全区域适配和触屏体验优化
## ============================================================

extends Node

## 安全区边距（像素）
var safe_area: Rect2 = Rect2(0, 0, 0, 0)

## 设备是否为平板（屏幕较短边>=6寸判定）
var is_tablet: bool = false


func _ready() -> void:
	_update_safe_area()
	_detect_device_type()
	print("[MobileAdapter] 安全区: ", safe_area)
	print("[MobileAdapter] 设备类型: ", "平板" if is_tablet else "手机")


## ============================================================
## 安全区域适配
## ============================================================

## 更新安全区域（刘海屏/圆角屏幕需避让）
func _update_safe_area() -> void:
	# DisplayServer.get_display_safe_area()返回物理安全区
	safe_area = DisplayServer.get_display_safe_area()
	# 如果安全区与屏幕尺寸相同，说明无刘海屏，无需避让
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	if safe_area.size == screen_size:
		safe_area = Rect2(0, 0, 0, 0)  ## 置零表示无需避让


## 获取顶部避让高度（刘海屏状态栏）
## [return] 像素数，无刘海返回0
func get_top_inset() -> int:
	if safe_area.size == Vector2.ZERO:
		return 0
	return safe_area.position.y


## 获取底部避让高度（手势条/虚拟导航键）
## [return] 像素数
func get_bottom_inset() -> int:
	if safe_area.size == Vector2.ZERO:
		return 0
	var screen_h: int = DisplayServer.screen_get_size().y
	return screen_h - safe_area.size.y - safe_area.position.y


## ============================================================
## 设备类型检测
## ============================================================

## 检测设备类型（手机/平板）
func _detect_device_type() -> void:
	var screen: Vector2i = DisplayServer.screen_get_size()
	var shorter_side: int = min(screen.x, screen.y)
	# 短边>=1600像素（约6寸以上）判定为平板
	is_tablet = shorter_side >= 1600


## ============================================================
## 触屏优化
## ============================================================

## 触摸反馈：振动
## [param duration_ms] 振动时长（毫秒），安卓用
func vibrate(duration_ms: int = 30) -> void:
	# 安卓振动反馈（增强触感）
	if OS.get_name() == "Android":
		# AndroidEnviron插件提供vibrate方法
		# 或通过Java原生调用
		var android = Engine.get_singleton("AndroidVibrate")
		if android != null:
			android.vibrate(duration_ms)


## 获取UI缩放系数（平板放大，手机标准）
## [return] 缩放系数
func get_ui_scale() -> float:
	# 平板屏幕大，UI放大1.2倍更舒适
	return 1.2 if is_tablet else 1.0


## ============================================================
## 生命周期处理
## ============================================================

## 应用进入后台（来电/Home键）时调用
func _on_application_paused() -> void:
	# 安卓: 暂停游戏逻辑，释放部分资源
	print("[MobileAdapter] 应用进入后台")


## 应用恢复前台时调用
func _on_application_resumed() -> void:
	# 安卓: 恢复游戏，重新检查网络/支付状态
	print("[MobileAdapter] 应用恢复前台")
	_update_safe_area()  ## 旋转屏幕后安全区可能变化

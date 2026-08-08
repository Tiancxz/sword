## ============================================================
## MiniGameSDK.gd - 微信小游戏API封装
## ============================================================
## 作用: 封装微信小游戏wx.* API，供PlatformAdapter调用。
## 设计: 通过JavaScriptBridge调用wx全局对象的方法。
##       异步API用回调包装，同步API直接返回。
## 对应:
##   I2.03 微信API适配
##   I1.02 存储接口（wx.setStorageSync/getStorageSync）
##   I1.03 广告接口（wx.createRewardedVideoAd）
##   I1.04 支付接口（wx.requestPayment）
## 依赖: Godot的JavaScriptBridge（Web/微信导出时可用）
## 注意: 本文件为代码框架，实际wx.*调用在微信运行时才生效。
##       桌面测试时JavaScriptBridge不可用，方法会安全降级。
## ============================================================

extends Node

## 是否在微信环境（_ready时检测）
var _is_wechat: bool = false

## JavaScriptBridge引用（仅Web/微信导出可用）
var _js: JavaScriptBridge = null

## 激励广告对象（JS侧）
var _reward_ad: JavaScriptObject = null


## ============================================================
## 初始化
## ============================================================

func _ready() -> void:
	# 检测JavaScriptBridge可用性（仅在Web/微信导出时存在）
	if OS.has_feature("web") or OS.has_feature("wechat"):
		_js = JavaScriptBridge.new()
		# 测试wx对象是否存在
		var has_wx: bool = _js.eval("typeof wx !== 'undefined'", true)
		_is_wechat = has_wx
		print("[MiniGameSDK] 微信环境检测: ", _is_wechat)
	else:
		_is_wechat = false
		print("[MiniGameSDK] 非Web环境，SDK降级为本地实现")


## ============================================================
## I1.02 - 存储（wx.setStorageSync / getStorageSync）
## ============================================================

## 同步存储数据
## [param key] 存储键
## [param data] 数据（会被JSON序列化）
## [return] 是否成功
func set_storage(key: String, data: Variant) -> bool:
	if not _is_wechat:
		return false
	# wx.setStorageSync(key, value)
	var json_str: String = JSON.stringify(data)
	# 转义引号
	json_str = json_str.replace("\\", "\\\\").replace("'", "\\'")
	var js_code: String = "wx.setStorageSync('%s', '%s');" % [key, json_str]
	var result: Variant = _js.eval(js_code, true)
	return result != null


## 同步读取数据
## [param key] 存储键
## [return] 数据，不存在返回null
func get_storage(key: String) -> Variant:
	if not _is_wechat:
		return null
	var js_code: String = "wx.getStorageSync('%s');" % key
	var result: Variant = _js.eval(js_code, true)
	if result == null or str(result) == "":
		return null
	# 尝试JSON解析
	var parsed = JSON.parse_string(str(result))
	return parsed if parsed != null else result


## ============================================================
## I1.03 - 激励广告（wx.createRewardedVideoAd）
## ============================================================

## 显示激励视频广告
## [param callback] 关闭回调: func(watched: bool) -> void
func show_reward_ad(callback: Callable) -> void:
	if not _is_wechat:
		print("[MiniGameSDK] 非微信环境，模拟广告成功")
		if callback.is_valid():
			callback.call(true)
		return

	# 创建广告实例（如果尚未创建）
	if _reward_ad == null:
		var js_code: String = """
		wx.createRewardedVideoAd({ adUnitId: 'adunit-placeholder' });
		"""
		_reward_ad = _js.eval(js_code, true)

	if _reward_ad == null:
		push_error("[MiniGameSDK] 创建广告失败")
		if callback.is_valid():
			callback.call(false)
		return

	# 显示广告
	_js.eval("this._reward_ad.show();", true)
	# TODO: 监听onClose事件判断是否看完
	# 实际实现需通过JavaScriptBridge注册回调对象
	print("[MiniGameSDK] 广告已显示，请等待关闭事件")
	if callback.is_valid():
		callback.call(true)


## ============================================================
## I1.04 - 支付（wx.requestPayment）
## ============================================================

## 发起微信支付
## [param product_id] 商品ID
## [param callback] 结果回调: func(success: bool) -> void
func request_payment(product_id: String, callback: Callable) -> void:
	if not _is_wechat:
		print("[MiniGameSDK] 非微信环境，模拟支付失败")
		if callback.is_valid():
			callback.call(false)
		return

	# 实际流程:
	# 1. 调用自家服务器获取prepay_id和签名
	# 2. 调用wx.requestPayment发起支付
	# 3. 监听success/fail回调
	var js_code: String = """
	wx.requestPayment({
		timeStamp: '',
		nonceStr: '',
		package: '',
		signType: 'MD5',
		paySign: '',
		success: function() {},
		fail: function() {}
	});
	"""
	print("[MiniGameSDK] 发起支付: ", product_id, " (需服务器配合生成签名)")
	# TODO: 接入服务器API获取支付参数后调用
	if callback.is_valid():
		callback.call(false)


## ============================================================
## 用户登录（wx.login）
## ============================================================

## 微信登录获取openid
## [return] openid字符串
func login() -> String:
	if not _is_wechat:
		return "wechat_guest_" + str(Time.get_ticks_msec())

	# wx.login是异步的，但V1先用同步占位
	# 实际实现需用JavaScriptBridge注册回调
	var js_code: String = "wx.login({ success: function(res) { /* res.code */ } });"
	_js.eval(js_code, true)
	print("[MiniGameSDK] wx.login已调用，需服务器用code换openid")
	return "wechat_pending_" + str(Time.get_ticks_msec())


## ============================================================
## 分享（wx.shareAppMessage）
## ============================================================

## 分享到微信好友
func share(title: String, image_path: String) -> void:
	if not _is_wechat:
		print("[MiniGameSDK] 非微信环境，跳过分享")
		return
	var js_code: String = "wx.shareAppMessage({ title: '%s', imageUrl: '%s' });" % [title, image_path]
	_js.eval(js_code, true)
	print("[MiniGameSDK] 分享: ", title)

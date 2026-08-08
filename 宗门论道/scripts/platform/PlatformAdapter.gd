## ============================================================
## PlatformAdapter.gd - 平台抽象层（跨平台核心）
## ============================================================
## 作用: 统一各平台(微信/Steam/安卓/Web)的API差异。
## 设计: 策略模式。业务层只调PlatformAdapter.xxx()，不关心当前平台。
##       各平台的具体实现委托给对应的SDK封装类:
##         - 微信 → MiniGameSDK (JavaScriptBridge调用wx.*)
##         - Steam → SteamCloud/SteamAchievements (GodotSteam插件)
##         - 安卓 → GoogleBilling/MobileAdapter (GodotGooglePlayBilling)
## 扩展: 新增平台功能时:
##   1. 在对应SDK封装类中实现具体调用
##   2. 在本类的match分支中调用SDK方法
## 对应: I1.01平台检测 / I1.02存储接口 / I1.03广告接口 / I1.04支付接口
## ============================================================

extends Node

## 平台枚举
enum Platform {
	WECHAT,    ## 微信小游戏
	STEAM,     ## Steam桌面端
	ANDROID,   ## 安卓(Google Play)
	WEB,       ## Web浏览器
	DESKTOP,   ## 桌面(开发/测试)
}

## 当前运行平台（_ready时自动检测）
var current: Platform = Platform.DESKTOP

## 各平台SDK封装实例（按需加载，未加载时为null）
var _mini_game_sdk: Node = null     ## 微信小游戏SDK
var _steam_cloud: Node = null       ## Steam云存档
var _steam_ach: Node = null         ## Steam成就
var _google_billing: Node = null    ## 谷歌支付


## ============================================================
## I1.01 - 平台检测与初始化
## ============================================================

func _ready() -> void:
	current = detect_platform()
	print("[PlatformAdapter] 当前平台: ", _platform_name(current))
	# 按需加载平台SDK
	_init_platform_sdks()


## 检测当前运行平台
## 通过Godot的OS API判断运行环境
## [return] 当前平台枚举值
func detect_platform() -> Platform:
	# 微信小游戏: 导出插件会设置 OS.has_feature("wechat")
	if OS.has_feature("wechat"):
		return Platform.WECHAT

	# 检查操作系统
	var os_name = OS.get_name()
	match os_name:
		"Android":
			return Platform.ANDROID
		"Web":
			return Platform.WEB
		"Windows", "macOS", "Linux":
			# 桌面端：检查是否通过Steam启动
			# GodotSteam插件会在启动时设置steam feature
			if OS.has_feature("steam"):
				return Platform.STEAM
			return Platform.DESKTOP

	return Platform.DESKTOP


## 按当前平台加载对应SDK封装
## SDK封装类通过preload加载，避免插件未安装时启动报错
func _init_platform_sdks() -> void:
	match current:
		Platform.WECHAT:
			# 微信SDK通过addons/godot_mini_game提供，运行时检查
			_mini_game_sdk = _try_load("res://addons/godot_mini_game/MiniGameSDK.gd")
		Platform.STEAM:
			_steam_cloud = _try_load("res://scripts/platform/SteamCloud.gd")
			_steam_ach = _try_load("res://scripts/platform/SteamAchievements.gd")
		Platform.ANDROID:
			_google_billing = _try_load("res://scripts/platform/GoogleBilling.gd")


## 尝试加载脚本（插件未安装时返回null，不报错）
## [param path] 脚本路径
## [return] 实例化的Node，或null
func _try_load(path: String) -> Node:
	if not ResourceLoader.exists(path):
		print("[PlatformAdapter] SDK未安装，跳过: ", path)
		return null
	var script = load(path)
	if script == null:
		return null
	var inst = script.new()
	if inst is Node:
		add_child(inst)
	return inst


## 获取平台名称（调试/显示用）
func _platform_name(platform: Platform) -> String:
	match platform:
		Platform.WECHAT: return "微信小游戏"
		Platform.STEAM: return "Steam"
		Platform.ANDROID: return "安卓"
		Platform.WEB: return "Web"
		Platform.DESKTOP: return "桌面"
		_: return "未知"


## ============================================================
## I1.02 - 存储接口（跨平台统一）
## ============================================================

## 保存数据到本地/云
## [param key] 存储键名
## [param data] 要存储的数据（任意类型）
## [return] 是否保存成功
func save_data(key: String, data: Variant) -> bool:
	match current:
		Platform.WECHAT:
			# 微信: 优先用wx.setStorageSync（同步，简单数据）
			if _mini_game_sdk != null:
				return _mini_game_sdk.set_storage(key, data)
			return _save_local(key, data)  ## 插件未装时回退本地
		Platform.STEAM:
			# Steam: 本地+云双写
			var ok: bool = _save_local(key, data)
			if _steam_cloud != null:
				_steam_cloud.write_file(key, data)  ## 异步同步到云
			return ok
		Platform.ANDROID:
			return _save_local(key, data)
		_:
			return _save_local(key, data)


## 从本地/云读取数据
## [param key] 存储键名
## [return] 读取到的数据，不存在返回null
func load_data(key: String) -> Variant:
	match current:
		Platform.WECHAT:
			if _mini_game_sdk != null:
				return _mini_game_sdk.get_storage(key)
			return _load_local(key)
		Platform.STEAM:
			# Steam: 云优先，云无则读本地
			if _steam_cloud != null and _steam_cloud.has_file(key):
				return _steam_cloud.read_file(key)
			return _load_local(key)
		_:
			return _load_local(key)


## 本地存储实现（内部方法，使用Godot的FileAccess读写user目录）
func _save_local(key: String, data: Variant) -> bool:
	var path = "user://" + key + ".save"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[PlatformAdapter] 无法写入文件: " + path)
		return false
	file.store_var(data)
	file.close()
	return true


## 本地读取实现（内部方法）
func _load_local(key: String) -> Variant:
	var path = "user://" + key + ".save"
	if not FileAccess.file_exists(path):
		return null
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var data = file.get_var()
	file.close()
	return data


## ============================================================
## I1.03 - 广告接口（跨平台统一）
## ============================================================

## 显示激励广告（看完给奖励）
## [param callback] 广告关闭回调，签名: func(watched: bool) -> void
func show_reward_ad(callback: Callable = Callable()) -> void:
	match current:
		Platform.WECHAT:
			if _mini_game_sdk != null:
				_mini_game_sdk.show_reward_ad(callback)
			else:
				print("[PlatformAdapter] 微信SDK未加载，无法显示广告")
				if callback.is_valid():
					callback.call(false)
		Platform.ANDROID:
			# 安卓: 调用GoogleAdMob（需AdMob插件）
			# MobileAdapter负责具体调用
			print("[PlatformAdapter] 安卓激励广告(需AdMob插件)")
			if callback.is_valid():
				callback.call(false)
		_:
			# Steam/Web无广告
			print("[PlatformAdapter] 当前平台无广告，直接发奖励(测试用)")
			if callback.is_valid():
				callback.call(true)


## ============================================================
## I1.04 - 支付接口（跨平台统一）
## ============================================================

## 发起内购
## [param product_id] 商品ID（各平台后台配置）
## [param callback] 购买结果回调，签名: func(success: bool) -> void
func purchase(product_id: String, callback: Callable = Callable()) -> void:
	match current:
		Platform.WECHAT:
			if _mini_game_sdk != null:
				_mini_game_sdk.request_payment(product_id, callback)
			else:
				print("[PlatformAdapter] 微信SDK未加载，无法支付: ", product_id)
				if callback.is_valid():
					callback.call(false)
		Platform.STEAM:
			# Steam: 通过Steamworks启动购买流程
			print("[PlatformAdapter] Steam购买(需GodotSteam): ", product_id)
			if callback.is_valid():
				callback.call(false)
		Platform.ANDROID:
			if _google_billing != null:
				_google_billing.purchase(product_id, callback)
			else:
				print("[PlatformAdapter] GoogleBilling未加载，无法支付: ", product_id)
				if callback.is_valid():
					callback.call(false)
		_:
			print("[PlatformAdapter] 当前平台不支持内购: ", product_id)
			if callback.is_valid():
				callback.call(false)


## ============================================================
## 用户登录（跨平台统一，V1.5实现）
## ============================================================

## 登录获取用户唯一标识
## [return] openid/steam_id/谷歌id（异步，实际实现用await）
func login() -> String:
	match current:
		Platform.WECHAT:
			if _mini_game_sdk != null:
				return await _mini_game_sdk.login()
			return "wechat_guest_" + str(Time.get_ticks_msec())
		Platform.STEAM:
			# TODO F1.01: SteamAPI.GetSteamID()
			return "steam_guest_" + str(Time.get_ticks_msec())
		Platform.ANDROID:
			# TODO F1.01: GoogleSignIn
			return "android_guest_" + str(Time.get_ticks_msec())
		_:
			return "desktop_guest_" + str(Time.get_ticks_msec())


## ============================================================
## 分享（跨平台统一，V1.5实现）
## ============================================================

## 分享内容
## [param title] 分享标题
## [param image_path] 分享图片路径
func share(title: String, image_path: String) -> void:
	match current:
		Platform.WECHAT:
			if _mini_game_sdk != null:
				_mini_game_sdk.share(title, image_path)
			else:
				print("[PlatformAdapter] 微信分享(待SDK): ", title)
		Platform.ANDROID:
			print("[PlatformAdapter] 安卓分享(待实现): ", title)
		_:
			print("[PlatformAdapter] 当前平台不支持分享: ", title)

## ============================================================
## PlatformAdapter.gd - 平台抽象层（跨平台核心）
## ============================================================
## 作用: 统一各平台(微信/Steam/安卓/Web)的API差异。
## 设计: 策略模式。业务层只调PlatformAdapter.xxx()，不关心当前平台。
##       各平台的具体实现通过_match平台分支，新增平台只需加一个分支。
## 扩展: 新增平台功能时:
##   1. 添加平台检测到 detect_platform()
##   2. 在各方法中添加对应平台的实现分支
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


## ============================================================
## 初始化
## ============================================================

func _ready() -> void:
	current = detect_platform()
	print("[PlatformAdapter] 当前平台: ", _platform_name(current))


## 检测当前运行平台
## 通过Godot的OS和Engine API判断运行环境
## [return] 当前平台枚举值
func detect_platform() -> Platform:
	# 检查是否在微信小游戏中（通过JavaScript桥接或插件标记）
	# 微信导出插件会设置 OS.has_feature("wechat")
	if OS.has_feature("wechat"):
		return Platform.WECHAT
	
	# 检查操作系统
	var os_name = OS.get_name()
	match os_name:
		"Android":
			return Platform.ANDROID
		"Web":
			# Web端需进一步判断是否在微信内
			# V1先当作普通Web处理
			return Platform.WEB
		"Windows", "macOS", "Linux":
			# 桌面端可能通过Steam运行
			# V1先当作普通桌面，后续Steam SDK接入后判断
			return Platform.DESKTOP
	
	return Platform.DESKTOP


## 获取平台名称（调试/显示用）
## [param platform] 平台枚举
## [return] 平台中文名称
func _platform_name(platform: Platform) -> String:
	match platform:
		Platform.WECHAT: return "微信小游戏"
		Platform.STEAM: return "Steam"
		Platform.ANDROID: return "安卓"
		Platform.WEB: return "Web"
		Platform.DESKTOP: return "桌面"
		_: return "未知"


## ============================================================
## 数据存储（跨平台统一接口）
## ============================================================

## 保存数据到本地/云
## [param key] 存储键名
## [param data] 要存储的数据（任意类型）
## [return] 是否保存成功
func save_data(key: String, data: Variant) -> bool:
	match current:
		Platform.WECHAT:
			# 微信: 使用wx.setStorageSync（通过JavaScript桥接）
			# TODO: V1.5接入微信云开发后切换
			return _save_local(key, data)
		Platform.STEAM:
			# Steam: 先存本地，再同步到Steam云
			# TODO: I3.03接入SteamCloud
			return _save_local(key, data)
		Platform.ANDROID:
			# 安卓: 存到应用私有目录
			return _save_local(key, data)
		_:
			# 桌面/Web: 存到user目录
			return _save_local(key, data)


## 从本地/云读取数据
## [param key] 存储键名
## [return] 读取到的数据，不存在返回null
func load_data(key: String) -> Variant:
	return _load_local(key)


## 本地存储实现（内部方法）
## 使用Godot的FileAccess读写user目录
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
## 用户登录（跨平台统一接口，V1.5实现）
## ============================================================

## 登录获取用户唯一标识
## [return] openid/steam_id/谷歌id（异步，实际实现用await）
func login() -> String:
	match current:
		Platform.WECHAT:
			# TODO F1.01: wx.login → 获取openid
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
## 广告（跨平台统一接口，V1.5实现）
## ============================================================

## 显示激励广告
## [return] 用户是否看完广告
func show_reward_ad() -> bool:
	match current:
		Platform.WECHAT:
			# TODO G2.01: wx.createRewardedVideoAd
			print("[PlatformAdapter] 微信激励广告(待实现)")
			return false
		Platform.ANDROID:
			# TODO G2.01: GoogleAdMob
			print("[PlatformAdapter] 安卓激励广告(待实现)")
			return false
		_:
			# Steam/Web无广告，直接返回false
			print("[PlatformAdapter] 当前平台无广告")
			return false


## ============================================================
## 内购（跨平台统一接口，V1.5实现）
## ============================================================

## 发起内购
## [param product_id] 商品ID
## [return] 是否购买成功
func purchase(product_id: String) -> bool:
	match current:
		Platform.WECHAT:
			# TODO G2.02: wx.requestPayment
			print("[PlatformAdapter] 微信支付(待实现): ", product_id)
			return false
		Platform.STEAM:
			# TODO G2.02: Steamworks.startPurchase
			print("[PlatformAdapter] Steam支付(待实现): ", product_id)
			return false
		Platform.ANDROID:
			# TODO G2.02: GooglePlayBilling
			print("[PlatformAdapter] 谷歌支付(待实现): ", product_id)
			return false
		_:
			print("[PlatformAdapter] 当前平台不支持内购")
			return false


## ============================================================
## 分享（跨平台统一接口，V1.5实现）
## ============================================================

## 分享内容
## [param title] 分享标题
## [param image_path] 分享图片路径
func share(title: String, image_path: String) -> void:
	match current:
		Platform.WECHAT:
			# TODO F3.02: wx.shareAppMessage
			print("[PlatformAdapter] 微信分享(待实现): ", title)
		Platform.ANDROID:
			# TODO F3.02: Intent分享
			print("[PlatformAdapter] 安卓分享(待实现): ", title)
		_:
			print("[PlatformAdapter] 当前平台不支持分享: ", title)

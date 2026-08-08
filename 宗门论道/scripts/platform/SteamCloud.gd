## ============================================================
## SteamCloud.gd - Steam云存档封装
## ============================================================
## 作用: 封装Steam云存储API，实现跨设备存档同步。
## 设计: RefCounted（无节点开销），由PlatformAdapter按需实例化。
## 依赖: GodotSteam插件 (addons/godotsteam/)
## 对应: I3.03 Steam云存档
## 注意: 需要先安装GodotSteam插件并配置steam_appid.txt。
##       插件未安装时方法安全降级（返回false/null）。
## ============================================================

class_name SteamCloud
extends RefCounted

## Steam云是否可用（_init时检测）
var _available: bool = false


func _init() -> void:
	# 检测Steamworks是否已初始化
	# GodotSteam插件提供Steam单例
	var steam_script = Engine.get_singleton("Steam")
	if steam_script != null:
		# 检查Steam是否已初始化且云同步开启
		_available = steam_script.isSteamRunning() and steam_script.isCloudEnabled()
		print("[SteamCloud] 云存档可用: ", _available)
	else:
		print("[SteamCloud] GodotSteam未安装，云存档降级")


## ============================================================
## 文件写入
## ============================================================

## 写入数据到Steam云
## [param filename] 文件名（不含路径）
## [param data] 数据（Variant，会被序列化为字节）
## [return] 是否成功
func write_file(filename: String, data: Variant) -> bool:
	if not _available:
		return false
	var steam = Engine.get_singleton("Steam")
	if steam == null:
		return false
	# 序列化数据为字节
	var bytes: PackedByteArray = var_to_bytes(data)
	# Steam: fileWrite(文件名, 数据)
	# 返回写入的字节数，-1表示失败
	var written: int = steam.fileWrite(filename, bytes)
	return written >= 0


## ============================================================
## 文件读取
## ============================================================

## 从Steam云读取数据
## [param filename] 文件名
## [return] 反序列化后的数据，失败返回null
func read_file(filename: String) -> Variant:
	if not _available:
		return null
	var steam = Engine.get_singleton("Steam")
	if steam == null:
		return null
	# Steam: fileRead(文件名) 返回PackedByteArray
	var bytes: PackedByteArray = steam.fileRead(filename)
	if bytes.is_empty():
		return null
	# 反序列化
	return bytes_to_var(bytes)


## 检查云文件是否存在
## [param filename] 文件名
## [return] 是否存在
func has_file(filename: String) -> bool:
	if not _available:
		return false
	var steam = Engine.get_singleton("Steam")
	if steam == null:
		return false
	# Steam: fileExists(文件名)
	return steam.fileExists(filename)


## 删除云文件
## [param filename] 文件名
## [return] 是否成功
func delete_file(filename: String) -> bool:
	if not _available:
		return false
	var steam = Engine.get_singleton("Steam")
	if steam == null:
		return false
	return steam.fileDelete(filename)

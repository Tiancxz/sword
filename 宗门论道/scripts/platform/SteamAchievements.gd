## ============================================================
## SteamAchievements.gd - Steam成就系统
## ============================================================
## 作用: 封装Steam成就API，解锁游戏成就并同步到Steam社区。
## 设计: RefCounted，由PlatformAdapter按需实例化。
## 依赖: GodotSteam插件 (addons/godotsteam/)
## 对应: I3.02 Steam成就系统
## 成就清单(需在Steamworks后台配置对应API ID):
##   - first_win: 首次胜利
##   - streak_3: 三连胜
##   - formation_master: 单局布阵5次
##   - spell_master: 单局施法10次
##   - flawless: 满血通关
## ============================================================

class_name SteamAchievements
extends RefCounted

## 所有成就定义（key=成就ID, value=显示名）
const ACHIEVEMENTS: Dictionary = {
	"first_win": "初次得道",
	"streak_3": "三连大捷",
	"formation_master": "阵法宗师",
	"spell_master": "万法归宗",
	"flawless": "毫发无伤",
}

## Steam是否可用
var _available: bool = false


func _init() -> void:
	var steam = Engine.get_singleton("Steam")
	if steam != null:
		_available = steam.isSteamRunning()
		print("[SteamAchievements] 成就系统可用: ", _available)
	else:
		print("[SteamAchievements] GodotSteam未安装，成就系统降级")


## ============================================================
## 解锁成就
## ============================================================

## 解锁指定成就
## [param achievement_id] 成就ID（见ACHIEVEMENTS常量）
## [return] 是否成功
func unlock(achievement_id: String) -> bool:
	if not _available:
		print("[SteamAchievements] (模拟)解锁成就: ", achievement_id)
		return false
	if not ACHIEVEMENTS.has(achievement_id):
		push_error("[SteamAchievements] 未知成就ID: " + achievement_id)
		return false
	var steam = Engine.get_singleton("Steam")
	# Steam: setAchievement(成就ID) → storeStats() 持久化
	steam.setAchievement(achievement_id)
	steam.storeStats()
	print("[SteamAchievements] 成就解锁: ", achievement_id, " - ", ACHIEVEMENTS[achievement_id])
	return true


## ============================================================
## 查询成就状态
## ============================================================

## 检查成就是否已解锁
## [param achievement_id] 成就ID
## [return] 是否已解锁
func is_unlocked(achievement_id: String) -> bool:
	if not _available:
		return false
	var steam = Engine.get_singleton("Steam")
	# Steam: getAchievement(成就ID) → bool
	return steam.getAchievement(achievement_id)


## ============================================================
## 统计数据
## ============================================================

## 设置统计数据（整数）
## [param stat_name] 统计项名（如"win_count", "total_play_time"）
## [param value] 数值
## [return] 是否成功
func set_stat(stat_name: String, value: int) -> bool:
	if not _available:
		return false
	var steam = Engine.get_singleton("Steam")
	steam.setStatInt(stat_name, value)
	return steam.storeStats()


## 获取统计数据
## [param stat_name] 统计项名
## [return] 数值，失败返回0
func get_stat(stat_name: String) -> int:
	if not _available:
		return 0
	var steam = Engine.get_singleton("Steam")
	return steam.getStatInt(stat_name)

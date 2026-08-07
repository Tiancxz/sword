## ============================================================
## SceneManager.gd - 场景管理器
## ============================================================
## 作用: 统一管理场景注册和切换，避免硬编码场景路径。
## 设计: 注册-切换模式。先register注册场景名→路径，再switch切换。
## 扩展: 可添加场景过渡动画、预加载、场景栈(返回上一场景)等。
## ============================================================

extends Node

## 已注册的场景: { 场景名: 资源路径 }
var _scenes: Dictionary = {}

## 当前场景名（用于调试和状态查询）
var current_scene_name: String = ""


## ============================================================
## 注册 / 查询
## ============================================================

## 注册场景
## [param name] 场景名（如"battle", "result"）
## [param path] 场景资源路径（如"res://scripts/scenes/BattleScene.tscn"）
func register(name: String, path: String) -> void:
	_scenes[name] = path


## 批量注册场景
## [param scenes] 字典: { 场景名: 路径 }
func register_all(scenes: Dictionary) -> void:
	for name in scenes:
		_scenes[name] = scenes[name]


## 获取场景路径
## [param name] 场景名
## [return] 资源路径，不存在返回空字符串
func get_scene_path(name: String) -> String:
	return _scenes.get(name, "")


## ============================================================
## 场景切换
## ============================================================

## 切换到指定场景
## [param name] 已注册的场景名
## [return] 是否切换成功
func switch(name: String) -> bool:
	# 检查场景是否已注册
	if not _scenes.has(name):
		push_error("[SceneManager] 场景未注册: " + name)
		return false
	
	# 清理输入区域（防止旧场景的点击回调残留）
	InputManager.clear()
	
	# Godot原生场景切换
	# change_scene_to_file会自动调用旧场景的_exit_tree和新场景的_enter_tree
	var path = _scenes[name]
	var err = get_tree().change_scene_to_file(path)
	
	if err != OK:
		push_error("[SceneManager] 场景切换失败: " + name + " (" + path + ")")
		return false
	
	current_scene_name = name
	print("[SceneManager] 切换到场景: ", name)
	return true


## ============================================================
## 初始化（项目启动时注册所有场景）
## ============================================================

func _ready() -> void:
	# 注册所有游戏场景
	# 新增场景时在此添加一行即可
	register_all({
		"main": "res://scripts/scenes/Main.tscn",
		# 以下场景在后续开发中逐步添加:
		# "battle": "res://scripts/scenes/BattleScene.tscn",
		# "result": "res://scripts/scenes/ResultScene.gd",
	})
	current_scene_name = "main"

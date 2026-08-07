## ============================================================
## MovementSystem.gd - 移动系统
## ============================================================
## 作用: 处理单位的移动、目标选择、碰撞检测、到达大殿检测。
## 设计: 纯静态方法，不持有状态，由 BattleLogic 每帧调用。
## 依赖: Unit, Const, Formation
## ============================================================

class_name MovementSystem


## ============================================================
## C3.02 - ★目标选择★
## ============================================================

## 寻找当前单位的攻击目标
## 优先同列最近敌人（单位或阵法），无目标返回null
static func find_target(unit: Unit, model: Dictionary) -> Variant:
	var enemies: Array = []
	var formations: Array = []

	# 收集敌方单位
	for u in model.get("units", []):
		if u is Unit and not u.is_dead() and u.owner != unit.owner:
			enemies.append(u)

	# 收集敌方阵法
	for f in model.get("formations", []):
		if f != null and f.get("owner", -1) != unit.owner and f.get("hp", 0) > 0:
			formations.append(f)

	# 合并候选目标
	var candidates: Array = enemies + formations

	# 筛选同列目标
	var same_col: Array = []
	for c in candidates:
		var c_x: int = -1
		if c is Unit:
			c_x = c.grid_x
		elif c is Dictionary:
			c_x = int(c.get("grid_x", -1))
		if c_x == unit.grid_x:
			same_col.append(c)

	# 无同列目标
	if same_col.is_empty():
		return null

	# 按距离排序，找最近的
	same_col.sort_custom(func(a, b):
		var dist_a: float = _get_distance(unit, a)
		var dist_b: float = _get_distance(unit, b)
		return dist_a < dist_b
	)

	return same_col[0]


## 获取单位到目标的距离
static func _get_distance(unit: Unit, target: Variant) -> float:
	var target_y: float = 0.0
	if target is Unit:
		target_y = target.position_y
	elif target is Dictionary:
		target_y = float(target.get("position_y", 0.0))
	return absf(target_y - unit.position_y)


## ============================================================
## C3.03 - 碰撞检测
## ============================================================

## 检测单位是否进入攻击范围
## 距离<=attack_range命中，跨列不命中
static func check_collision(unit: Unit, target: Variant) -> bool:
	if target == null:
		return false

	# 跨列不命中
	var target_x: int = -1
	if target is Unit:
		target_x = target.grid_x
	elif target is Dictionary:
		target_x = int(target.get("grid_x", -1))
	if target_x != unit.grid_x:
		return false

	# 检查距离
	var dist: float = _get_distance(unit, target)
	return dist <= float(unit.attack_range + 1)  ## +1容差，近战range=0时距离1格可攻击


## ============================================================
## C3.04 - 到达大殿检测
## ============================================================

## 检查单位是否到达敌方大殿
## 攻方到顶（y>=BOARD_LENGTH-1），守方到底（y<=0）
static func check_hall_reach(unit: Unit) -> bool:
	if unit.owner == 0:
		# 攻方向上移动，到达顶部大殿
		return unit.position_y >= float(Const.BOARD_LENGTH - 1)
	else:
		# 守方向下移动，到达底部大殿
		return unit.position_y <= 0.0


## ============================================================
## C3.01 - ★单位移动★
## ============================================================

## 主移动逻辑
## walking时移动 → 遇敌变fighting → 到殿变dead+伤害大殿
static func move_unit(unit: Unit, delta: float, model: Dictionary) -> void:
	if unit.state != "walking":
		return

	# 检查是否到达大殿
	if check_hall_reach(unit):
		unit.state = "dead"
		# 对敌方大殿造成伤害
		var enemy_owner: int = 1 - unit.owner
		var players: Array = model.get("players", [])
		if enemy_owner < players.size():
			CombatSystem.damage_hall(players[enemy_owner], unit.atk, model)
		return

	# 寻找目标
	var target: Variant = find_target(unit, model)
	unit.target = target

	# 检查碰撞 → 进入战斗
	if target != null and check_collision(unit, target):
		unit.state = "fighting"
		return

	# 正常移动
	var speed: float = unit.get_effective_speed()
	if speed > 0.0:
		unit.position_y += speed * delta * float(unit.facing)

## ============================================================
## ElderSkillSystem.gd - 长老技能系统
## ============================================================
## 作用: 精英单位（长老）每5秒随机触发一个技能分支。
## 设计: 纯静态方法，由 BattleLogic 在 _update_units 中对每个精英调用。
##       4个随机分支：飞剑(AOE) / 丹药(治疗) / 符箓(天雷) / 御兽(召唤)。
## 扩展: 新增分支只需在 _BRANCHES 加名称 + 实现 _branch_xxx。
## 依赖: Const, Unit, CombatSystem
## 对应:
##   C7.01 技能计时 - update
##   C7.02 随机分支 - _trigger_random
##   C7.03 飞剑分支 - _branch_flying_sword (范围3格AOE伤害3)
##   C7.04 丹药分支 - _branch_pill (自身+3血，周围2格友军+2血)
##   C7.05 符箓分支 - _branch_talisman (前方3格敌人受天雷4伤)
##   C7.06 御兽分支 - _branch_beast (召唤守门灵兽)
## ============================================================

class_name ElderSkillSystem

## 4个随机技能分支名称（与 _branch_xxx 方法名对应）
const _BRANCHES: Array[String] = ["flying_sword", "pill", "talisman", "beast"]


## ============================================================
## C7.01 - 技能计时
## ============================================================

## 每帧更新长老技能计时
## [param elder] 精英单位
## [param delta] 帧间隔（秒）
## [param model] 战斗模型
static func update(elder: Unit, delta: float, model: Dictionary) -> void:
	# 仅精英单位触发
	if elder.unit_type != "elite":
		return
	if elder.is_dead():
		return

	elder.elder_timer += delta
	if elder.elder_timer >= Const.ELDER_SKILL_INTERVAL:
		elder.elder_timer = 0.0
		_trigger_random(elder, model)


## ============================================================
## C7.02 - 随机分支
## ============================================================

## 随机触发一个技能分支
## [param elder] 精英单位
## [param model] 战斗模型
static func _trigger_random(elder: Unit, model: Dictionary) -> void:
	var idx: int = randi() % _BRANCHES.size()
	var branch_name: String = _BRANCHES[idx]
	# 通过match分发到对应分支（静态方法无法用call()实例方法）
	match branch_name:
		"flying_sword":
			branch_flying_sword(elder, model)
		"pill":
			branch_pill(elder, model)
		"talisman":
			branch_talisman(elder, model)
		"beast":
			branch_beast(elder, model)
	print("[ElderSkill] %s 触发技能: %s" % [elder.unit_name, branch_name])


## ============================================================
## C7.03 - 飞剑分支（AOE伤害）
## ============================================================

## 飞剑诀：对范围3格内的敌方单位造成3点AOE伤害
## [param elder] 精英单位
## [param model] 战斗模型
static func branch_flying_sword(elder: Unit, model: Dictionary) -> void:
	var enemies: Array = _get_enemy_units(elder.owner, model)
	# 筛选距离3格内的敌人
	var nearby: Array = enemies.filter(func(e: Unit) -> bool:
		return absf(e.position_y - elder.position_y) <= 3.0
	)
	# AOE伤害3
	for e in nearby:
		e.take_damage(3, elder)
	print("  └ 飞剑诀命中%d个敌人" % nearby.size())


## ============================================================
## C7.04 - 丹药分支（治疗）
## ============================================================

## 丹药：自身+3血，周围2格内友军+2血
## [param elder] 精英单位
## [param model] 战斗模型
static func branch_pill(elder: Unit, model: Dictionary) -> void:
	# 自身回血
	elder.hp = min(elder.max_hp, elder.hp + 3)

	# 周围2格友军回血
	var allies: Array = _get_ally_units(elder.owner, model)
	var healed: int = 0
	for a in allies:
		if a == elder:
			continue
		if absf(a.position_y - elder.position_y) <= 2.0:
			a.hp = min(a.max_hp, a.hp + 2)
			healed += 1
	print("  └ 丹药：自身+3血，治疗%d个友军" % healed)


## ============================================================
## C7.05 - 符箓分支（天雷）
## ============================================================

## 符箓：对前方3格内的敌人造成4点伤害（复用天雷效果）
## [param elder] 精英单位
## [param model] 战斗模型
static func branch_talisman(elder: Unit, model: Dictionary) -> void:
	var enemies: Array = _get_enemy_units(elder.owner, model)
	# 筛选前方3格内的敌人（前方=朝向方向，diff与facing同号）
	var facing: float = float(elder.facing)
	var front: Array = enemies.filter(func(e: Unit) -> bool:
		# 前方：目标y - 长老y 与 facing同号（攻方facing=+1向下，目标y应>长老y）
		var diff: float = e.position_y - elder.position_y
		return absf(diff) <= 3.0 and diff * facing >= 0.0
	)
	for e in front:
		e.take_damage(4, elder)
	print("  └ 符箓·天雷命中%d个敌人" % front.size())


## ============================================================
## C7.06 - 御兽分支（召唤）
## ============================================================

## 御兽：在长老所在列召唤一只守门灵兽
## [param elder] 精英单位
## [param model] 战斗模型
static func branch_beast(elder: Unit, model: Dictionary) -> void:
	var beast: Unit = Unit.new()
	# 在长老当前位置召唤守门灵兽
	beast.init_from_card("guardian_beast", elder.owner, elder.grid_x, int(elder.position_y))
	# init_from_card按owner重置了position_y到出生点，这里覆盖回长老当前位置
	beast.position_y = elder.position_y
	model["units"].append(beast)
	print("  └ 御兽：召唤守门灵兽于列%d y=%.1f" % [elder.grid_x, elder.position_y])


## ============================================================
## 辅助：获取单位列表
## ============================================================

## 获取敌方所有存活单位
static func _get_enemy_units(owner: int, model: Dictionary) -> Array:
	var result: Array = []
	for u in model.get("units", []):
		if u is Unit and not u.is_dead() and u.owner != owner:
			result.append(u)
	return result


## 获取己方所有存活单位
static func _get_ally_units(owner: int, model: Dictionary) -> Array:
	var result: Array = []
	for u in model.get("units", []):
		if u is Unit and not u.is_dead() and u.owner == owner:
			result.append(u)
	return result

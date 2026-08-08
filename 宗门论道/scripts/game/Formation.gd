## ============================================================
## Formation.gd - 阵法（守方建筑）
## ============================================================
## 作用: 表示棋盘上的一个阵法（截脉阵/寒霜阵/万刃阵/反震阵/天罗阵）。
## 设计: 继承RefCounted，纯逻辑数据+方法。
##       阵法为静态建筑，不移动，攻击进入范围的敌人。
##       渲染层(P5)可用Area2D节点包装本类数据。
## 依赖: Const, Cards, Unit, CombatSystem
## 对应:
##   C5.01 布阵 - init_from_card
##   C5.02 阵法攻击 - attack_target / update_attacks
##   C5.04 阵法被禁 - set_silence / update
## ============================================================

class_name Formation
extends RefCounted

# ===== 身份 =====
var card_id: String = ""           ## 卡牌ID
var formation_name: String = ""    ## 显示名称
var owner: int = 0                 ## 0=攻方, 1=守方
var formation_trait: String = ""       ## 特性（基础拦截/命中减速/反伤等）

# ===== 位置 =====
var grid_x: int = 0                ## 所在列
var position_y: float = 0.0        ## Y坐标（格）

# ===== 属性 =====
var hp: int = 0                    ## 当前血量
var max_hp: int = 0                ## 最大血量
var atk: int = 0                   ## 攻击力
var attack_range: int = 1          ## 攻击范围（格）

# ===== 攻击计时 =====
var last_attack_time: int = 0      ## 上次攻击时间（毫秒）

# ===== 沉默状态（C5.04）=====
var is_active: bool = true         ## 是否激活（false=被禁用）
var silence_timer: float = 0.0     ## 沉默剩余时间（秒）


## ============================================================
## C5.01 - 布阵（从卡牌创建阵法）
## ============================================================

## 从卡牌数据初始化阵法
## [param p_card_id] 卡牌ID
## [param p_owner] 所属玩家
## [param p_grid_x] 放置列
## [param p_position_y] 放置行坐标
func init_from_card(p_card_id: String, p_owner: int, p_grid_x: int, p_position_y: float) -> void:
	card_id = p_card_id
	owner = p_owner
	grid_x = p_grid_x
	position_y = p_position_y

	var card: Dictionary = Cards.get_card(card_id)
	if card.is_empty():
		push_error("Formation: 无法创建阵法，卡牌不存在: " + card_id)
		return

	formation_name = card.get("name", "")
	hp = int(card.get("hp", 1))
	max_hp = hp
	atk = int(card.get("atk", 0))
	attack_range = int(card.get("range", 1))
	formation_trait = card.get("trait", "")

	is_active = true
	silence_timer = 0.0
	last_attack_time = 0


## ============================================================
## C5.04 - 阵法被禁（沉默）
## ============================================================

## 设置沉默（禁用阵法一段时间）
## [param duration] 持续时间（秒）
func set_silence(duration: float) -> void:
	silence_timer = duration
	if duration > 0.0:
		is_active = false


## 每帧更新（处理沉默计时）
## [param delta] 帧间隔（秒）
func update(delta: float) -> void:
	if silence_timer > 0.0:
		silence_timer -= delta
		if silence_timer <= 0.0:
			silence_timer = 0.0
			is_active = true


## ============================================================
## C5.02 - 阵法攻击
## ============================================================

## 攻击目标单位
## [param target] 目标Unit
## [param model] 战斗模型（用于反伤等副作用）
func attack_target(target: Unit, model: Dictionary) -> void:
	if not is_active:
		return
	if atk <= 0:
		# 反震阵等atk=0的阵法不主动攻击，靠被动触发
		return

	# 攻击间隔检查
	var now: int = Time.get_ticks_msec()
	if last_attack_time != 0 and (now - last_attack_time) < int(Const.ATTACK_INTERVAL * 1000):
		return
	last_attack_time = now

	# 对目标造成伤害
	target.take_damage(atk, self)

	# 特性效果：寒霜阵-命中减速
	if formation_trait.find("减速") >= 0:
		target.add_buff("slow", Const.SLOW_AMOUNT, 1.0)


## 每帧检查范围内敌人并攻击（由BattleLogic调用）
## [param delta] 帧间隔
## [param model] 战斗模型
func update_attacks(delta: float, model: Dictionary) -> void:
	if not is_active:
		return
	if atk <= 0:
		return  # 被动阵法不在此处理

	# 寻找同列在攻击范围内的敌方单位
	for u in model.get("units", []):
		if u is Unit and not u.is_dead() and u.owner != owner:
			if u.grid_x != grid_x:
				continue
			var dist: float = absf(u.position_y - position_y)
			if dist <= float(attack_range + 1):  ## +1容差
				attack_target(u, model)


## ============================================================
## 受到伤害（含反伤特性）
## ============================================================

## 受到伤害
## [param amount] 伤害值
## [param attacker] 攻击者（用于反伤）
## [param model] 战斗模型
## [return] 实际造成的伤害
func take_damage(amount: int, attacker: Variant, model: Dictionary) -> int:
	if hp <= 0:
		return 0

	hp = max(0, hp - amount)

	# 特性效果：反震阵-反伤50%
	if formation_trait.find("反伤") >= 0 and attacker is Unit:
		var reflect: int = max(1, int(float(amount) * 0.5))
		attacker.take_damage(reflect, self)

	return amount


## 是否已损毁
func is_dead() -> bool:
	return hp <= 0


## 获取血量百分比（供UI使用）
func get_hp_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return float(hp) / float(max_hp)

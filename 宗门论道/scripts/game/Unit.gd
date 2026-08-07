## ============================================================
## Unit.gd - 战斗单位
## ============================================================
## 作用: 表示棋盘上的一个战斗单位（弟子/精英/守方单位）。
## 依赖: Const（常量）、Cards（卡牌数据）
## ============================================================

class_name Unit
extends Node2D

# ===== 身份 =====
var card_id: String = ""       ## 卡牌ID
var owner: int = 0             ## 0=攻方, 1=守方
var unit_name: String = ""     ## 显示名称

# ===== 属性 =====
var hp: int = 0
var max_hp: int = 0
var atk: int = 0
var base_speed: float = 0.0    ## 基础移速（格/秒）
var attack_range: int = 0      ## 攻击范围（格）
var unit_type: String = ""     ## unit/elite

# ===== 位置 =====
var grid_x: int = 0            ## 所在列
var position_y: float = 0.0    ## Y坐标（格，浮点表示移动中）

# ===== 状态 =====
var state: String = "walking"  ## walking/fighting/dead
var target: Variant = null     ## 当前目标（Unit/Formation/null）
var last_attack_time: int = 0  ## 上次攻击时间（毫秒）

# ===== Buff系统 =====
var buffs: Array[Dictionary] = []  ## {type, value, duration}

# ===== 阵营朝向：攻方向上(y递减)，守方向下(y递增) =====
var facing: int = 1  ## 1=向下(守方), -1=向上(攻方)


## ============================================================
## C2.01 - 从卡牌创建单位
## ============================================================

## 从卡牌数据初始化单位
func init_from_card(p_card_id: String, p_owner: int, x: int, y: int) -> void:
	card_id = p_card_id
	owner = p_owner
	grid_x = x
	position_y = float(y)

	var card: Dictionary = Cards.get_card(card_id)
	if card.is_empty():
		push_error("Unit: 无法创建单位，卡牌不存在: " + card_id)
		return

	unit_name = card.get("name", "")
	hp = int(card.get("hp", 1))
	max_hp = hp
	atk = int(card.get("atk", 0))
	base_speed = float(card.get("move_speed", 0))
	attack_range = int(card.get("range", 0))
	unit_type = card.get("type", "unit")

	# 攻方面朝上（y递减），守方面朝下（y递增）
	facing = -1 if owner == 0 else 1

	# 初始位置
	if owner == 0:
		position_y = 0.0  ## 攻方从底部出发
	else:
		position_y = float(Const.BOARD_LENGTH - 1)  ## 守方从顶部出发

	state = "walking"
	target = null


## ============================================================
## C2.02 - Buff系统
## ============================================================

## 添加buff
## [param type] slow/speed/stun/shield/atk_boost
## [param value] 数值
## [param duration] 持续时间（秒）
func add_buff(type: String, value: float, duration: float) -> void:
	# 同类型buff刷新（不叠加）
	for i in range(buffs.size()):
		if buffs[i]["type"] == type:
			buffs[i]["value"] = value
			buffs[i]["duration"] = duration
			return
	buffs.append({
		"type": type,
		"value": value,
		"duration": duration,
	})


## 更新buff计时（每帧调用）
func update_buffs(delta: float) -> void:
	for i in range(buffs.size() - 1, -1, -1):
		buffs[i]["duration"] -= delta
		if buffs[i]["duration"] <= 0.0:
			buffs.remove_at(i)


## ============================================================
## C2.03 - 实际移速计算
## ============================================================

## 计算实际移速（考虑buff）
## stun返回0，slow减速，最低为0
func get_effective_speed() -> float:
	# 检查眩晕
	for b in buffs:
		if b["type"] == "stun":
			return 0.0

	var spd: float = base_speed

	for b in buffs:
		match b["type"]:
			"slow":
				spd -= b["value"]
			"speed":
				spd += b["value"]

	return maxf(0.0, spd)


## ============================================================
## C2.04 - 受到伤害
## ============================================================

## 受到伤害
## [param amount] 伤害值
## [param attacker] 攻击者（用于击杀判定）
## [return] 实际造成的伤害值
func take_damage(amount: int, attacker: Variant) -> int:
	if hp <= 0:
		return 0

	# 检查护盾buff
	var shield: int = 0
	for b in buffs:
		if b["type"] == "shield":
			shield += int(b["value"])

	if shield > 0:
		# 护盾吸收伤害
		var absorbed: int = min(shield, amount)
		amount -= absorbed
		# 减少护盾值
		for b in buffs:
			if b["type"] == "shield":
				b["value"] = float(shield - absorbed)
				if b["value"] <= 0:
					pass  # 会被update_buffs移除
		if amount <= 0:
			return 0

	hp -= amount
	if hp <= 0:
		hp = 0
		state = "dead"
	return amount


## 获取当前攻击力（含atk_boost buff）
func get_effective_atk() -> int:
	var result: int = atk
	for b in buffs:
		if b["type"] == "atk_boost":
			result += int(b["value"])
	return result


## 是否已死亡
func is_dead() -> bool:
	return state == "dead" or hp <= 0

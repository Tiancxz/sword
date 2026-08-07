## ============================================================
## CombatSystem.gd - 战斗系统
## ============================================================
## 作用: 处理攻击逻辑（近战/远程）、击杀处理、大殿受伤。
## 设计: 纯静态方法，由 BattleLogic 每帧调用。
## 依赖: Unit, Const
## ============================================================

class_name CombatSystem


## ============================================================
## C4.02 - 近战互扣
## ============================================================

## 近战攻击：双方同时掉血
static func melee_attack(attacker: Unit, target: Unit) -> void:
	var attacker_atk: int = attacker.get_effective_atk()
	var target_atk: int = target.get_effective_atk()
	target.take_damage(attacker_atk, attacker)
	attacker.take_damage(target_atk, target)


## ============================================================
## C4.03 - 远程单方
## ============================================================

## 远程攻击：只有目标掉血，攻击者无损
static func ranged_attack(attacker: Unit, target: Variant) -> void:
	var atk_val: int = attacker.get_effective_atk()
	if target is Unit:
		target.take_damage(atk_val, attacker)
	elif target is Dictionary:
		# 阵法受到伤害
		var current_hp: int = int(target.get("hp", 0))
		target["hp"] = max(0, current_hp - atk_val)


## ============================================================
## C4.05 - ★击杀后继续推进★
## ============================================================

## 击杀后处理：击杀者继续前进，不消失
static func handle_kill(killer: Unit, victim: Variant) -> void:
	killer.state = "walking"
	killer.target = null
	# 核心修复：击杀者不消失，继续前进！


## ============================================================
## C4.01 - 攻击主逻辑
## ============================================================

## 攻击主逻辑
## fighting时按攻击间隔攻击目标，击杀后继续推进
static func attack(unit: Unit, delta: float, model: Dictionary) -> void:
	if unit.state != "fighting":
		return

	var target: Variant = unit.target
	if target == null:
		# 目标丢失，恢复行走
		unit.state = "walking"
		return

	# 检查目标是否已死亡
	var target_dead: bool = false
	if target is Unit:
		target_dead = target.is_dead()
	elif target is Dictionary:
		target_dead = int(target.get("hp", 0)) <= 0

	if target_dead:
		handle_kill(unit, target)
		return

	# 攻击间隔检查（Const.ATTACK_INTERVAL秒）
	var now: int = Time.get_ticks_msec()
	if unit.last_attack_time == 0 or (now - unit.last_attack_time) >= int(Const.ATTACK_INTERVAL * 1000):
		unit.last_attack_time = now

		# 根据攻击范围选择近战或远程
		if unit.attack_range <= 0:
			# 近战：双方互扣
			if target is Unit:
				melee_attack(unit, target)
		else:
			# 远程：单方攻击
			ranged_attack(unit, target)

		# 攻击后检查目标是否死亡
		if target is Unit:
			if target.is_dead():
				handle_kill(unit, target)
		elif target is Dictionary:
			if int(target.get("hp", 0)) <= 0:
				handle_kill(unit, target)


## ============================================================
## C4.06 - 大殿受伤
## ============================================================

## 大殿受伤逻辑
## 护盾优先吸收，hp到0触发游戏结束
static func damage_hall(player: Dictionary, amount: int, model: Dictionary) -> void:
	# 护盾优先
	var shield: int = int(player.get("hall_shield", 0))
	if shield > 0:
		var absorbed: int = min(shield, amount)
		amount -= absorbed
		player["hall_shield"] = shield - absorbed
		if amount <= 0:
			return

	# 扣减血量
	var current_hp: int = int(player.get("hall_hp", Const.HALL_HP))
	current_hp -= amount
	player["hall_hp"] = max(0, current_hp)

	# 大殿血量归零，游戏结束
	if current_hp <= 0:
		model["state"] = "ended"
		model["winner"] = 1 - int(player.get("id", 0))
		print("[CombatSystem] 大殿被摧毁！玩家%d获胜" % model["winner"])

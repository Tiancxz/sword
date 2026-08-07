## ============================================================
## BattleLogic.gd - 战斗逻辑总入口
## ============================================================
## 作用: 每帧驱动所有战斗子系统的更新，处理出牌与结束判定。
## 设计: 纯逻辑层，不包含渲染。由场景层每帧调用 on_update(delta)。
## 依赖: MovementSystem, CombatSystem, SpellSystem, ElderSkillSystem,
##       BattleChecker, Formation, Player, Unit, Const, Deck
## 对应:
##   C1.01 每帧总入口 - on_update
##   C9.01 出兵 - _spawn_unit
##   C9.02 施法 - _cast_spell
##   C11.01 清理死亡单位 - _remove_dead_units
##   C11.02 清理被毁阵法 - _remove_dead_formations
## ============================================================

class_name BattleLogic

## 战斗模型（游戏状态）
## {
##   units: Array[Unit],          棋盘上所有单位
##   formations: Array[Formation], 所有阵法
##   players: Array[Player],      玩家数据 [Player, Player]
##   time: float,                 当前阶段剩余时间
##   elapsed_time: float,         对局总时长（不减，用于灵力上限）
##   state: String,               "playing"/"overtime"/"ended"
##   winner: int,                 获胜方（-1=未结束）
## }
var model: Dictionary = {}


## ============================================================
## 初始化战斗
## ============================================================

## 初始化战斗模型
## [param deck_p0] 攻方卡组卡牌ID列表
## [param deck_p1] 守方卡组卡牌ID列表
func init_battle(deck_p0: Array[String], deck_p1: Array[String]) -> void:
	var p0: Player = Player.new()
	p0.init(0, deck_p0)
	var p1: Player = Player.new()
	p1.init(1, deck_p1)

	model = {
		"units": [],
		"formations": [],
		"players": [p0, p1],
		"time": Const.BATTLE_TIME,
		"elapsed_time": 0.0,
		"state": "playing",
		"winner": -1,
	}


## ============================================================
## C1.01 - 每帧总入口
## ============================================================

## 每帧更新：驱动所有子系统
func on_update(delta: float) -> void:
	if model.get("state", "") == "ended":
		return

	# 0. 累计总时长（灵力上限增长依据）
	model["elapsed_time"] = float(model.get("elapsed_time", 0.0)) + delta

	# 1. 灵力系统（含上限增长）
	_update_energy(delta)

	# 2. 卡组补牌
	for player in model["players"]:
		player.deck.update(delta)

	# 3. 单位移动 + 攻击 + 长老技能
	_update_units(delta)

	# 4. 阵法更新（沉默计时 + 主动攻击）
	_update_formations(delta)

	# 5. 清理死亡单位 / 被毁阵法
	_remove_dead_units()
	_remove_dead_formations()

	# 6. 检查结束条件
	_check_end(delta)


## ============================================================
## 灵力系统更新（委托给Player）
## ============================================================

func _update_energy(delta: float) -> void:
	var is_overtime: bool = model.get("state", "") == "overtime"
	var elapsed: float = float(model.get("elapsed_time", 0.0))
	for player in model["players"]:
		# C8.01 灵力实时回复
		player.update_energy(delta, is_overtime)
		# C8.02 灵力上限增长
		player.update_energy_cap(elapsed)


## ============================================================
## 单位更新（移动+攻击+长老技能）
## ============================================================

func _update_units(delta: float) -> void:
	for unit in model["units"]:
		if unit is Unit and not unit.is_dead():
			# 更新buff
			unit.update_buffs(delta)

			# C7.01 长老技能计时（仅精英）
			ElderSkillSystem.update(unit, delta, model)

			# 移动或攻击
			match unit.state:
				"walking":
					MovementSystem.move_unit(unit, delta, model)
				"fighting":
					CombatSystem.attack(unit, delta, model)


## ============================================================
## 阵法更新（沉默计时 + 主动攻击）
## ============================================================

func _update_formations(delta: float) -> void:
	for f in model["formations"]:
		if f is Formation:
			# C5.04 沉默计时恢复
			f.update(delta)
			# C5.02 阵法主动攻击范围内敌人
			f.update_attacks(delta, model)


## ============================================================
## C11.01 - 清理死亡单位
## ============================================================

func _remove_dead_units() -> void:
	for i in range(model["units"].size() - 1, -1, -1):
		var unit = model["units"][i]
		if unit is Unit and unit.is_dead():
			model["units"].remove_at(i)


## ============================================================
## C11.02 - 清理被毁阵法
## ============================================================

func _remove_dead_formations() -> void:
	for i in range(model["formations"].size() - 1, -1, -1):
		var f = model["formations"][i]
		if f is Formation and f.is_dead():
			# C5.03 记录阵法冷却（同格8秒内不能再布阵）
			var owner_player: Player = model["players"][f.owner]
			owner_player.record_formation_cooldown(f.grid_x, f.position_y)
			model["formations"].remove_at(i)
			print("[BattleLogic] 阵法被毁: %s (列%d)" % [f.formation_name, f.grid_x])


## ============================================================
## 检查结束条件（委托给BattleChecker）
## ============================================================

func _check_end(delta: float) -> void:
	if model.get("state", "") == "ended":
		return

	# 倒计时（playing 和 overtime 都要倒计）
	model["time"] = max(0.0, float(model.get("time", 0.0)) - delta)

	# C10.01-C10.03 综合检查
	var winner: int = BattleChecker.check_all(model)
	if winner >= 0:
		model["state"] = "ended"
		model["winner"] = winner
		print("[BattleLogic] 战斗结束！玩家%d获胜" % winner)


## ============================================================
## 出牌（外部调用）
## ============================================================

## 玩家出牌
## [param player_id] 玩家ID (0/1)
## [param hand_idx] 手牌索引
## [param grid_x] 放置列
## [param target] 法术目标（可选，Unit/Formation/null）
## [return] 是否成功
func play_card(player_id: int, hand_idx: int, grid_x: int, target: Variant = null) -> bool:
	if model.get("state", "") == "ended":
		return false

	var player: Player = model["players"][player_id]
	var deck: Deck = player.deck

	# 检查灵力是否足够
	if not deck.can_play(hand_idx, player.energy):
		return false

	# 预读卡牌类型
	var card_id: String = deck.hand[hand_idx]
	var card: Dictionary = Cards.get_card(card_id)
	var cost: int = int(card.get("cost", 0))
	var card_type: String = card.get("type", "")

	# 扣灵力
	player.spend_energy(cost)

	# 打出卡牌（从手牌移除 + 设置补牌计时器）
	deck.play_card(hand_idx)

	# 根据卡牌类型分发
	match card_type:
		"unit", "elite":
			return _spawn_unit(card_id, player_id, grid_x)
		"formation":
			return _spawn_formation(card_id, player_id, grid_x, card)
		"spell":
			return _cast_spell(card_id, player_id, target)
		_:
			push_error("[BattleLogic] 未知卡牌类型: " + card_type)
			return false


## ============================================================
## C9.01 - 出兵
## ============================================================

## 创建单位并加入棋盘
## [return] 始终true（已扣费）
func _spawn_unit(card_id: String, player_id: int, grid_x: int) -> bool:
	var unit: Unit = Unit.new()
	unit.init_from_card(card_id, player_id, grid_x, 0)
	model["units"].append(unit)
	print("[BattleLogic] 玩家%d在列%d放置单位: %s" % [player_id, grid_x, unit.unit_name])
	return true


## ============================================================
## C5.01 - 布阵
## ============================================================

## 创建阵法并加入棋盘（含冷却检查）
## [return] false=冷却中无法布阵（但已扣费，未来可优化为扣费前检查）
func _spawn_formation(card_id: String, player_id: int, grid_x: int, card: Dictionary) -> bool:
	var player: Player = model["players"][player_id]
	# 阵法放在己方半场边缘：攻方在顶部(y=0)，守方在底部(y=BOARD_LENGTH-1)
	var spawn_y: float = 0.0 if player_id == 0 else float(Const.BOARD_LENGTH - 1)

	# C5.03 冷却检查
	if not player.can_place_formation(grid_x, spawn_y):
		print("[BattleLogic] 列%d阵法冷却中，无法布阵" % grid_x)
		# 退还灵力（冷却失败不应扣费）
		player.energy += int(card.get("cost", 0))
		return false

	var formation: Formation = Formation.new()
	formation.init_from_card(card_id, player_id, grid_x, spawn_y)
	model["formations"].append(formation)
	print("[BattleLogic] 玩家%d在列%d放置阵法: %s" % [player_id, grid_x, formation.formation_name])
	return true


## ============================================================
## C9.02 - 施法
## ============================================================

## 施放法术
## [return] 是否施放成功
func _cast_spell(card_id: String, caster_id: int, target: Variant) -> bool:
	var ok: bool = SpellSystem.cast(card_id, caster_id, model, target)
	if not ok:
		# 施放失败，退还灵力
		var card: Dictionary = Cards.get_card(card_id)
		model["players"][caster_id].energy += int(card.get("cost", 0))
	return ok


## ============================================================
## 查询接口（供UI/渲染层使用）
## ============================================================

## 获取玩家手牌
func get_hand(player_id: int) -> Array[String]:
	if player_id < 0 or player_id >= model["players"].size():
		return []
	return model["players"][player_id].deck.hand

## 获取玩家灵力
func get_energy(player_id: int) -> int:
	if player_id < 0 or player_id >= model["players"].size():
		return 0
	return model["players"][player_id].energy

## 获取灵力上限
func get_energy_max(player_id: int) -> int:
	if player_id < 0 or player_id >= model["players"].size():
		return 0
	return model["players"][player_id].energy_max

## 获取大殿血量
func get_hall_hp(player_id: int) -> int:
	if player_id < 0 or player_id >= model["players"].size():
		return 0
	return model["players"][player_id].hall_hp

## 获取大殿护盾
func get_hall_shield(player_id: int) -> int:
	if player_id < 0 or player_id >= model["players"].size():
		return 0
	return model["players"][player_id].hall_shield

## 获取剩余时间
func get_time() -> float:
	return float(model.get("time", 0.0))

## 获取当前状态
func get_state() -> String:
	return model.get("state", "")

## 获取获胜方
func get_winner() -> int:
	return int(model.get("winner", -1))

## 获取所有单位（供渲染层遍历）
func get_units() -> Array:
	return model.get("units", [])

## 获取所有阵法（供渲染层遍历）
func get_formations() -> Array:
	return model.get("formations", [])

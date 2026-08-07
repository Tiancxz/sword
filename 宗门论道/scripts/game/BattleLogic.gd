## ============================================================
## BattleLogic.gd - 战斗逻辑总入口
## ============================================================
## 作用: 每帧驱动所有战斗子系统的更新。
## 设计: 纯逻辑层，不包含渲染。由场景层每帧调用 on_update(delta)。
## 依赖: MovementSystem, CombatSystem, Const, Deck
## ============================================================

class_name BattleLogic

## 战斗模型（游戏状态）
## {
##   units: Array[Unit],          棋盘上所有单位
##   formations: Array[Dictionary], 所有阵法
##   players: Array[Dictionary],   玩家数据 [{id:0, hall_hp:30, hall_shield:0, energy:5, deck:Deck}, ...]
##   time: float,                  剩余时间
##   state: String,                "playing"/"ended"
##   winner: int,                  获胜方（-1=未结束）
##   energy_max: int,              当前灵力上限
##   energy_cap_timer: float,      灵力上限增长计时器
## }
var model: Dictionary = {}


## ============================================================
## 初始化战斗
## ============================================================

## 初始化战斗模型
func init_battle(deck_p0: Array[String], deck_p1: Array[String]) -> void:
	model = {
		"units": [],
		"formations": [],
		"players": [
			{
				"id": 0,
				"hall_hp": Const.HALL_HP,
				"hall_shield": 0,
				"energy": Const.ENERGY_START,
				"energy_timer": 0.0,
				"deck": _create_deck(deck_p0),
			},
			{
				"id": 1,
				"hall_hp": Const.HALL_HP,
				"hall_shield": 0,
				"energy": Const.ENERGY_START,
				"energy_timer": 0.0,
				"deck": _create_deck(deck_p1),
			},
		],
		"time": Const.BATTLE_TIME,
		"state": "playing",
		"winner": -1,
		"energy_max": Const.ENERGY_START,
		"energy_cap_timer": 0.0,
	}


## 创建卡组实例
func _create_deck(card_ids: Array[String]) -> Deck:
	var deck: Deck = Deck.new()
	deck.init(card_ids)
	return deck


## ============================================================
## C1.01 - 每帧总入口
## ============================================================

## 每帧更新：驱动所有子系统
func on_update(delta: float) -> void:
	if model.get("state", "") != "playing":
		return

	# 1. 灵力系统
	_update_energy(delta)

	# 2. 卡组补牌
	for player in model["players"]:
		player["deck"].update(delta)

	# 3. 单位移动 + 攻击
	_update_units(delta)

	# 4. 阵法更新（阵法无移动，只检查被摧毁）
	_update_formations(delta)

	# 5. 清理死亡单位
	_remove_dead()

	# 6. 检查结束条件
	_check_end(delta)


## ============================================================
## 灵力系统更新
## ============================================================

func _update_energy(delta: float) -> void:
	# 灵力回复
	for player in model["players"]:
		player["energy_timer"] += delta
		if player["energy_timer"] >= Const.ENERGY_REGEN:
			player["energy_timer"] -= Const.ENERGY_REGEN
			var current_max: int = model["energy_max"]
			if player["energy"] < current_max:
				player["energy"] += 1

	# 灵力上限增长（每30秒+1，最大10）
	model["energy_cap_timer"] += delta
	if model["energy_cap_timer"] >= Const.ENERGY_CAP_GROWTH_INTERVAL:
		model["energy_cap_timer"] -= Const.ENERGY_CAP_GROWTH_INTERVAL
		if model["energy_max"] < Const.ENERGY_MAX_CAP:
			model["energy_max"] += 1


## ============================================================
## 单位更新（移动+攻击）
## ============================================================

func _update_units(delta: float) -> void:
	for unit in model["units"]:
		if unit is Unit and not unit.is_dead():
			# 更新buff
			unit.update_buffs(delta)

			# 移动或攻击
			match unit.state:
				"walking":
					MovementSystem.move_unit(unit, delta, model)
				"fighting":
					CombatSystem.attack(unit, delta, model)


## ============================================================
## 阵法更新
## ============================================================

func _update_formations(delta: float) -> void:
	# 阵法是静态的，只检查HP
	for i in range(model["formations"].size() - 1, -1, -1):
		var f: Dictionary = model["formations"][i]
		if int(f.get("hp", 0)) <= 0:
			model["formations"].remove_at(i)


## ============================================================
## 清理死亡单位
## ============================================================

func _remove_dead() -> void:
	for i in range(model["units"].size() - 1, -1, -1):
		var unit = model["units"][i]
		if unit is Unit and unit.is_dead():
			# 只清理state=dead且不是刚到殿的单位
			# 到殿的单位已经在move_unit中处理了大殿伤害
			model["units"].remove_at(i)


## ============================================================
## 检查结束条件
## ============================================================

func _check_end(delta: float) -> void:
	# 大殿血量检查（已在CombatSystem.damage_hall中处理）

	# 时间到
	if model.get("state", "") == "playing":
		model["time"] -= delta
		if model["time"] <= 0:
			model["time"] = 0
			model["state"] = "ended"
			# 比血量决定胜负
			var hp0: int = int(model["players"][0]["hall_hp"])
			var hp1: int = int(model["players"][1]["hall_hp"])
			if hp0 > hp1:
				model["winner"] = 0
			elif hp1 > hp0:
				model["winner"] = 1
			else:
				model["winner"] = -1  ## 平局
			print("[BattleLogic] 时间到！玩家%d获胜" % model["winner"])


## ============================================================
## 出牌（外部调用）
## ============================================================

## 玩家出牌
## [param player_id] 玩家ID (0/1)
## [param hand_idx] 手牌索引
## [param grid_x] 放置列
## [return] 是否成功
func play_card(player_id: int, hand_idx: int, grid_x: int) -> bool:
	if model.get("state", "") != "playing":
		return false

	var player: Dictionary = model["players"][player_id]
	var deck: Deck = player["deck"]

	# 检查灵力
	if not deck.can_play(hand_idx, player["energy"]):
		return false

	# 打出卡牌
	var card_id: String = deck.play_card(hand_idx)
	if card_id.is_empty():
		return false

	# 扣灵力
	var card: Dictionary = Cards.get_card(card_id)
	player["energy"] -= int(card.get("cost", 0))

	# 根据卡牌类型处理
	var card_type: String = card.get("type", "")

	match card_type:
		"unit", "elite":
			# 创建单位
			var unit: Unit = Unit.new()
			unit.init_from_card(card_id, player_id, grid_x, 0)
			model["units"].append(unit)
			print("[BattleLogic] 玩家%d在列%d放置单位: %s" % [player_id, grid_x, card.get("name", "")])

		"formation":
			# 创建阵法
			var spawn_y: float = float(Const.BOARD_LENGTH - 1) if player_id == 0 else 0.0
			model["formations"].append({
				"card_id": card_id,
				"name": card.get("name", ""),
				"owner": player_id,
				"grid_x": grid_x,
				"position_y": spawn_y,
				"hp": int(card.get("hp", 1)),
				"atk": int(card.get("atk", 0)),
				"range": int(card.get("range", 1)),
			})
			print("[BattleLogic] 玩家%d在列%d放置阵法: %s" % [player_id, grid_x, card.get("name", "")])

		"spell":
			# 法术效果（P4扩展战斗阶段实现具体效果）
			print("[BattleLogic] 玩家%d施放法术: %s (待实现)" % [player_id, card.get("name", "")])

	return true


## 获取玩家手牌
func get_hand(player_id: int) -> Array[String]:
	if player_id < 0 or player_id >= model["players"].size():
		return []
	return model["players"][player_id]["deck"].hand


## 获取玩家灵力
func get_energy(player_id: int) -> int:
	if player_id < 0 or player_id >= model["players"].size():
		return 0
	return model["players"][player_id]["energy"]


## 获取大殿血量
func get_hall_hp(player_id: int) -> int:
	if player_id < 0 or player_id >= model["players"].size():
		return 0
	return model["players"][player_id]["hall_hp"]

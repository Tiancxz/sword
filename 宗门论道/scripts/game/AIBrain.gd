## ============================================================
## AI.gd - 正式AI决策系统
## ============================================================
## 作用: 守方AI自动决策出牌，替代BattleScene中的简易自动出牌。
## 设计: 继承Node（可挂载为子节点），持有think_timer累计时间。
##       每次思考调用think()：计算攻守比→选牌→按卡牌类型分发执行。
##       三档难度影响布阵位置策略。
## 依赖: BattleLogic, Const, Cards, Player, Unit, Formation
## 对应:
##   D1.01 AI主循环 - update
##   D1.02 决策核心 - think
##   D1.03 攻守比计算 - decide_attack_ratio
##   D1.04 选牌逻辑 - pick_card
##   D1.05 布阵位置 - pick_formation_column
## ============================================================

class_name AIBrain
extends Node

## AI难度枚举
enum Difficulty {
	EASY,     ## 简单：随机位置布阵
	NORMAL,   ## 普通：在己方大殿附近布阵
	HARD,     ## 困难：在最快敌方单位前方布阵
}

# ===== 配置 =====
var player_id: int = 1            ## AI控制的玩家ID（守方=1）
var difficulty: int = Difficulty.NORMAL  ## 当前难度
var think_interval: float = Const.AI_THINK_INTERVAL  ## 思考间隔（秒）

# ===== 内部状态 =====
var _think_timer: float = 0.0     ## 思考累计计时器
var _logic: BattleLogic = null    ## 战斗逻辑引用（由外部注入）


## ============================================================
## 初始化
## ============================================================

## 初始化AI
## [param p_logic] 战斗逻辑实例
## [param p_player_id] AI控制的玩家ID
## [param p_difficulty] 难度
func setup(p_logic: BattleLogic, p_player_id: int, p_difficulty: int = Difficulty.NORMAL) -> void:
	_logic = p_logic
	player_id = p_player_id
	difficulty = p_difficulty
	_think_timer = 0.0
	print("[AI] 初始化完成 玩家=%d 难度=%s 间隔=%.1fs" % [player_id, _difficulty_name(difficulty), think_interval])


## ============================================================
## D1.01 - AI主循环
## ============================================================

## 每帧更新：累计计时，达到间隔后思考一次
## [param delta] 帧间隔（秒）
func update(delta: float) -> void:
	if _logic == null:
		return
	if _logic.get_state() == "ended":
		return

	_think_timer += delta
	if _think_timer >= think_interval:
		_think_timer = 0.0
		think()


## ============================================================
## D1.02 - 决策核心
## ============================================================

## 思考一次：计算攻守比→选牌→执行出牌
func think() -> void:
	if _logic == null:
		return

	# 获取AI玩家
	var players: Array = _logic.model.get("players", [])
	if player_id >= players.size():
		return
	var player: Player = players[player_id]
	if not player is Player:
		return

	# D1.03 计算攻守比（基于己方大殿血量）
	var ratio: float = decide_attack_ratio(player)

	# D1.04 选牌
	var card_idx: int = pick_card(player.energy, ratio, player.deck.hand)
	if card_idx < 0:
		return  # 无可出之牌，本次跳过

	# 读取卡牌类型，按类型分发
	var card_id: String = player.deck.hand[card_idx]
	var card: Dictionary = Cards.get_card(card_id)
	var card_type: String = card.get("type", "")

	match card_type:
		"unit", "elite":
			# 单位/精英：固定在己方出生列附近出兵
			var spawn_col: int = _pick_unit_column()
			_logic.play_card(player_id, card_idx, spawn_col, null)
			print("[AI] 出兵 列%d %s" % [spawn_col, card.get("name", "")])
		"formation":
			# 阵法：D1.05 布阵位置策略
			var formation_col: int = pick_formation_column()
			if formation_col >= 0:
				_logic.play_card(player_id, card_idx, formation_col, null)
				print("[AI] 布阵 列%d %s" % [formation_col, card.get("name", "")])
		"spell":
			# 法术：直接施放（SpellSystem自动选目标）
			_logic.play_card(player_id, card_idx, 0, null)
			print("[AI] 施法 %s" % card.get("name", ""))
		_:
			push_error("[AI] 未知卡牌类型: " + card_type)


## ============================================================
## D1.03 - 攻守比计算
## ============================================================

## 根据己方大殿血量计算攻守比
## 血量高→偏进攻(0.7)，血量低→偏防守(0.2)，中间→均衡(0.4)
## [param player] AI玩家
## [return] 攻守比 0.0~1.0（越高越偏进攻）
func decide_attack_ratio(player: Player) -> float:
	var pct: float = float(player.hall_hp) / float(Const.HALL_HP)
	if pct > 0.6:
		return 0.7   ## 血量充足，主动出击
	if pct < 0.3:
		return 0.2   ## 血量危急，全力防守
	return 0.4       ## 均衡


## ============================================================
## D1.04 - 选牌逻辑
## ============================================================

## 从手牌中选一张可负担且符合当前策略的牌
## [param energy] 当前灵力
## [param ratio] 攻守比（越高越偏进攻）
## [param hand] 手牌数组
## [return] 选中的手牌索引，-1=无可出之牌
func pick_card(energy: int, ratio: float, hand: Array[String]) -> int:
	# 过滤出所有可负担的牌
	var playable: Array = []
	for i in range(hand.size()):
		var card: Dictionary = Cards.get_card(hand[i])
		if card.is_empty():
			continue
		if energy >= int(card.get("cost", 0)):
			playable.append(i)

	if playable.is_empty():
		return -1  # 无可出之牌

	# 按攻守比排序：ratio>0.5 优先单位(进攻)，否则优先阵法(防守)
	if ratio > 0.5:
		# 进攻偏好：单位 > 精英 > 法术 > 阵法
		playable.sort_custom(func(a: int, b: int) -> bool:
			return _attack_priority(hand[a]) > _attack_priority(hand[b])
		)
	else:
		# 防守偏好：阵法 > 法术 > 单位 > 精英
		playable.sort_custom(func(a: int, b: int) -> bool:
			return _defense_priority(hand[a]) > _defense_priority(hand[b])
		)

	return playable[0]


## 进攻优先级评分（数值越大越优先）
func _attack_priority(card_id: String) -> int:
	var card: Dictionary = Cards.get_card(card_id)
	match card.get("type", ""):
		"unit": return 4
		"elite": return 3
		"spell": return 2
		"formation": return 1
		_: return 0


## 防守优先级评分（数值越大越优先）
func _defense_priority(card_id: String) -> int:
	var card: Dictionary = Cards.get_card(card_id)
	match card.get("type", ""):
		"formation": return 4
		"spell": return 3
		"unit": return 2
		"elite": return 1
		_: return 0


## ============================================================
## D1.05 - 布阵位置（单路设计）
## ============================================================

## 选择布阵列
## 单路设计下只有1列(列0)，始终返回0
## 难度差异体现在D1.02决策核心的选牌策略上（是否偏防守）
## [return] 列号（单路恒为0）
func pick_formation_column() -> int:
	return 0


## ============================================================
## 辅助：单位出兵列选择（单路设计）
## ============================================================

## 选择单位出兵列
## 单路设计下只有1列(列0)，始终返回0
func _pick_unit_column() -> int:
	return 0


## ============================================================
## 辅助
## ============================================================

## 难度名称（调试用）
func _difficulty_name(d: int) -> String:
	match d:
		Difficulty.EASY: return "简单"
		Difficulty.NORMAL: return "普通"
		Difficulty.HARD: return "困难"
		_: return "未知"


## 重置AI状态（重新开始战斗时调用）
func reset() -> void:
	_think_timer = 0.0

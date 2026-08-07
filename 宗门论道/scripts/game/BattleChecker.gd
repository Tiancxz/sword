## ============================================================
## BattleChecker.gd - 胜负判定
## ============================================================
## 作用: 检查游戏结束条件（大殿摧毁/时间到/加时赛结算）。
## 设计: 纯静态方法，由 BattleLogic._check_end 每帧调用。
## 流程:
##   1. 先检查大殿血量（任一方大殿HP<=0即结束）
##   2. 检查对局时间（到时比血量，平局进加时）
##   3. 加时赛结束比灵力决定胜负
## 依赖: Const, Player
## 对应:
##   C10.01 大殿摧毁 - check_hall
##   C10.02 时限检测 - check_time
##   C10.03 加时结算 - check_overtime
## ============================================================

class_name BattleChecker


## ============================================================
## C10.01 - 大殿摧毁检测
## ============================================================

## 检查大殿血量是否归零
## [param model] 战斗模型
## [return] 获胜方ID（0/1），-1=未结束
static func check_hall(model: Dictionary) -> int:
	var players: Array = model.get("players", [])
	if players.size() < 2:
		return -1

	var p0: Player = players[0]
	var p1: Player = players[1]

	# 攻方大殿被摧毁 → 守方胜
	if p0.hall_hp <= 0:
		return 1
	# 守方大殿被摧毁 → 攻方胜
	if p1.hall_hp <= 0:
		return 0
	return -1


## ============================================================
## C10.02 - 时限检测
## ============================================================

## 检查对局时间是否结束
## 到时比血量，血量相同则进入加时赛
## [param model] 战斗模型
## [return] 获胜方ID（0/1），-1=未结束（可能进入加时）
static func check_time(model: Dictionary) -> int:
	# 时间未到，继续
	if float(model.get("time", 0.0)) > 0.0:
		return -1

	var players: Array = model.get("players", [])
	if players.size() < 2:
		return -1

	var p0: Player = players[0]
	var p1: Player = players[1]

	# 血量不同 → 血量高者胜
	if p0.hall_hp != p1.hall_hp:
		return 0 if p0.hall_hp > p1.hall_hp else 1

	# 血量相同 → 进入加时赛（仅一次）
	var state: String = model.get("state", "")
	if state == "playing":
		# 转入加时赛
		model["state"] = "overtime"
		model["time"] = Const.OVERTIME_TIME
		print("[BattleChecker] 平局！进入加时赛（%d秒），比灵力决胜" % int(Const.OVERTIME_TIME))
		return -1

	# 已在加时赛中，交给 check_overtime 处理
	return -1


## ============================================================
## C10.03 - 加时赛结算
## ============================================================

## 加时赛结束比灵力决胜
## [param model] 战斗模型
## [return] 获胜方ID（0/1），-1=未结束
static func check_overtime(model: Dictionary) -> int:
	# 仅在加时赛阶段处理
	if model.get("state", "") != "overtime":
		return -1

	# 加时赛时间未到
	if float(model.get("time", 0.0)) > 0.0:
		return -1

	var players: Array = model.get("players", [])
	if players.size() < 2:
		return -1

	var p0: Player = players[0]
	var p1: Player = players[1]

	# 比灵力，灵力高者胜（灵力相同则攻方胜，因攻方需主动进攻）
	if p0.energy >= p1.energy:
		return 0
	else:
		return 1


## ============================================================
## 综合检查（一次调用检查所有条件）
## ============================================================

## 综合检查游戏结束条件
## [param model] 战斗模型
## [return] 获胜方ID（0/1），-1=未结束
## 注：若返回非-1，调用方应将 model["state"] 置为 "ended"，model["winner"] 置为返回值
static func check_all(model: Dictionary) -> int:
	# 1. 大殿摧毁（最高优先级）
	var winner: int = check_hall(model)
	if winner >= 0:
		return winner

	# 2. 根据当前状态选择检查
	var state: String = model.get("state", "")
	if state == "overtime":
		# 加时赛：检查加时结算
		winner = check_overtime(model)
	else:
		# 正常对局：检查时限
		winner = check_time(model)

	return winner

## ============================================================
## Player.gd - 玩家类
## ============================================================
## 作用: 封装单个玩家的全部战斗数据与灵力/阵法冷却逻辑。
## 设计: 继承RefCounted（引用计数自动回收），纯数据+方法，无渲染。
##       由 BattleLogic 在 init_battle 中实例化，存入 model["players"]。
## 依赖: Const, Deck
## 对应: C8.01 灵力实时回复 / C8.02 灵力上限增长 / C5.03 阵法冷却
## ============================================================

class_name Player
extends RefCounted

# ===== 身份 =====
var id: int = 0                    ## 玩家ID (0=攻方, 1=守方)

# ===== 大殿 =====
var hall_hp: int = 0               ## 大殿血量
var hall_shield: int = 0           ## 大殿护盾层数

# ===== 灵力系统 =====
var energy: int = 0                ## 当前灵力
var energy_max: int = 0            ## 灵力上限（随时间增长）
var energy_timer: float = 0.0      ## 灵力回复计时器

# ===== 卡组 =====
var deck: Deck = null              ## 卡组实例

# ===== 阵法冷却 =====
## key = "grid_x,position_y" 字符串，value = 冷却到期时间戳（毫秒）
## 同一格子在冷却期内不能再次布阵
var formation_cooldowns: Dictionary = {}


## ============================================================
## 初始化
## ============================================================

## 初始化玩家数据
## [param p_id] 玩家ID
## [param card_ids] 卡组卡牌ID列表
func init(p_id: int, card_ids: Array[String]) -> void:
	id = p_id
	hall_hp = Const.HALL_HP
	hall_shield = 0
	energy = Const.ENERGY_START
	energy_max = Const.ENERGY_START
	energy_timer = 0.0
	formation_cooldowns.clear()

	deck = Deck.new()
	deck.init(card_ids)


## ============================================================
## C8.01 - 灵力实时回复
## ============================================================

## 每帧更新灵力回复
## [param delta] 帧间隔（秒）
## [param is_overtime] 是否加时赛（加时赛回复速率提升1.5倍）
func update_energy(delta: float, is_overtime: bool = false) -> void:
	# 加时赛回复速率 = 2.8 / 1.5 ≈ 1.87秒/点
	var regen_rate: float = Const.ENERGY_REGEN
	if is_overtime:
		regen_rate = Const.ENERGY_REGEN / 1.5

	energy_timer += delta
	if energy_timer >= regen_rate:
		energy_timer -= regen_rate
		# 灵力不超过当前上限
		if energy < energy_max:
			energy += 1


## ============================================================
## C8.02 - 灵力上限增长
## ============================================================

## 根据对局已用时间更新灵力上限
## [param elapsed_time] 对局已用时间（秒）
func update_energy_cap(elapsed_time: float) -> void:
	# 公式: 初始5 + 每30秒+1，上限10
	var new_max: int = min(
		Const.ENERGY_MAX_CAP,
		Const.ENERGY_START + int(elapsed_time / Const.ENERGY_CAP_GROWTH_INTERVAL)
	)
	energy_max = new_max


## ============================================================
## 灵力消耗
## ============================================================

## 消耗灵力
## [param amount] 消耗量
## [return] 是否足够并成功扣除
func spend_energy(amount: int) -> bool:
	if energy < amount:
		return false
	energy -= amount
	return true


## ============================================================
## C5.03 - 阵法冷却
## ============================================================

## 检查指定格子是否可布阵（未在冷却中）
## [param grid_x] 列
## [param position_y] 行坐标
## [return] true=可布阵
func can_place_formation(grid_x: int, position_y: float) -> bool:
	var key: String = "%d,%.1f" % [grid_x, position_y]
	if not formation_cooldowns.has(key):
		return true
	# 冷却已到期则移除记录并放行
	var expire_time: int = int(formation_cooldowns[key])
	if Time.get_ticks_msec() >= expire_time:
		formation_cooldowns.erase(key)
		return true
	return false


## 记录某格布阵冷却
## [param grid_x] 列
## [param position_y] 行坐标
func record_formation_cooldown(grid_x: int, position_y: float) -> void:
	var key: String = "%d,%.1f" % [grid_x, position_y]
	formation_cooldowns[key] = Time.get_ticks_msec() + int(Const.FORMATION_COOLDOWN * 1000)


## ============================================================
## 大殿护盾
## ============================================================

## 添加大殿护盾（不超过上限）
## [param amount] 护盾层数
func add_shield(amount: int) -> void:
	hall_shield = min(Const.MAX_SHIELD, hall_shield + amount)


## 获取大殿血量百分比（供UI使用）
func get_hall_hp_ratio() -> float:
	if Const.HALL_HP <= 0:
		return 0.0
	return float(hall_hp) / float(Const.HALL_HP)


## 获取灵力百分比（供UI使用）
func get_energy_ratio() -> float:
	if energy_max <= 0:
		return 0.0
	return float(energy) / float(energy_max)

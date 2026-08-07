## ============================================================
## EventBus.gd - 全局事件总线
## ============================================================
## 作用: 跨模块通信的中枢。各模块通过信号解耦，不直接互相引用。
## 设计: 所有跨模块事件在此定义signal，发送方emit，接收方connect。
## 扩展: 新增功能时，在此文件添加对应的signal即可。
## ============================================================

extends Node

# ===== 卡牌相关信号 =====
## 出牌信号: card_id=卡牌ID, target=目标位置, player_id=出牌玩家
signal card_played(card_id: String, target: Vector2, player_id: int)
## 单位被创建信号: unit=单位实例
signal unit_spawned(unit)
## 单位死亡信号: unit=死亡单位, killer=击杀者(可为null)
signal unit_died(unit, killer)

# ===== 战斗相关信号 =====
## 大殿受伤信号: player_id=受伤玩家, damage=伤害值
signal hall_damaged(player_id: int, damage: int)
## 阵法被放置信号: formation=阵法实例, grid_x/grid_y=位置
signal formation_placed(formation, grid_x: int, grid_y: int)
## 法术施放信号: spell_id=法术ID, caster_id=施法者, target=目标
signal spell_cast(spell_id: String, caster_id: int, target)

# ===== 游戏流程信号 =====
## 游戏开始
signal battle_started()
## 游戏结束: winner=胜者ID(0或1)
signal battle_ended(winner: int)
## 灵力变化: player_id=玩家, energy=当前灵力, max_energy=上限
signal energy_changed(player_id: int, energy: int, max_energy: int)

# ===== UI相关信号 =====
## 手牌更新: player_id=玩家, hand=手牌数组
signal hand_updated(player_id: int, hand: Array)
## 选中卡牌: card_idx=手牌索引, -1表示取消选中
signal card_selected(card_idx: int)


## ============================================================
## 以下是便捷方法（可选，直接用emit也行）
## ============================================================

## 广播出牌事件
func emit_card_played(card_id: String, target: Vector2, player_id: int) -> void:
	card_played.emit(card_id, target, player_id)

## 广播单位死亡
func emit_unit_died(unit, killer = null) -> void:
	unit_died.emit(unit, killer)

## 广播游戏结束
func emit_battle_ended(winner: int) -> void:
	battle_ended.emit(winner)

## ============================================================
## Cards.gd - 卡牌配置表
## ============================================================
## 作用: 存储所有卡牌的静态数据，供全局查表使用。
## 设计: static var DATA 字典，key=cardId, value=卡牌属性字典。
## 来源: 数据与《4.卡牌数据》表一致，共20张卡牌。
## ============================================================

class_name Cards

## 卡牌数据表 key=cardId, value=Dictionary
static var DATA: Dictionary = {}


static func _static_init() -> void:
	# ===== 攻方 - 单位 =====
	DATA["beast_disciple"] = {
		"name": "宗门御兽弟子", "faction": "attacker", "type": "unit",
		"cost": 3, "hp": 5, "atk": 2, "move_speed": 0.8, "range": 0,
		"trait": "控制兽当肉盾", "rarity": "common"
	}
	DATA["body_disciple"] = {
		"name": "宗门体修弟子", "faction": "attacker", "type": "unit",
		"cost": 2, "hp": 4, "atk": 2, "move_speed": 1.0, "range": 0,
		"trait": "普通近战", "rarity": "common"
	}
	DATA["sword_disciple"] = {
		"name": "宗门剑修弟子", "faction": "attacker", "type": "unit",
		"cost": 3, "hp": 2, "atk": 3, "move_speed": 1.0, "range": 3,
		"trait": "远程飞剑", "rarity": "common"
	}

	# ===== 攻方 - 精英 =====
	DATA["elder_jindan"] = {
		"name": "金丹期长老", "faction": "attacker", "type": "elite",
		"cost": 6, "hp": 8, "atk": 4, "move_speed": 0.8, "range": 1,
		"trait": "5秒随机技能", "rarity": "rare"
	}

	# ===== 攻方 - 法术 =====
	DATA["wan_jian"] = {
		"name": "万剑归宗", "faction": "attacker", "type": "spell",
		"cost": 4, "hp": 0, "atk": 0, "move_speed": 0, "range": 0,
		"trait": "全员+1攻+加速", "rarity": "epic"
	}
	DATA["wu_lei"] = {
		"name": "五雷正法", "faction": "attacker", "type": "spell",
		"cost": 4, "hp": 0, "atk": 0, "move_speed": 0, "range": 3,
		"trait": "范围AOE伤害4", "rarity": "epic"
	}
	DATA["yu_feng"] = {
		"name": "御风诀", "faction": "attacker", "type": "spell",
		"cost": 2, "hp": 0, "atk": 0, "move_speed": 0, "range": 0,
		"trait": "单体+0.5速5秒", "rarity": "common"
	}
	DATA["zhen_hun"] = {
		"name": "镇魂符", "faction": "attacker", "type": "spell",
		"cost": 3, "hp": 0, "atk": 0, "move_speed": 0, "range": 0,
		"trait": "禁用阵法3秒", "rarity": "common"
	}
	DATA["jin_zhong"] = {
		"name": "金钟罩", "faction": "attacker", "type": "spell",
		"cost": 3, "hp": 0, "atk": 0, "move_speed": 0, "range": 0,
		"trait": "大殿护盾+3", "rarity": "epic"
	}
	DATA["yi_shan"] = {
		"name": "移山倒海", "faction": "attacker", "type": "spell",
		"cost": 5, "hp": 0, "atk": 0, "move_speed": 0, "range": 0,
		"trait": "推后2格+1伤", "rarity": "rare"
	}
	DATA["kun_xian"] = {
		"name": "困仙索", "faction": "attacker", "type": "spell",
		"cost": 3, "hp": 0, "atk": 0, "move_speed": 0, "range": 0,
		"trait": "单体stun2秒", "rarity": "epic"
	}
	DATA["tian_lei"] = {
		"name": "天雷诀", "faction": "attacker", "type": "spell",
		"cost": 4, "hp": 0, "atk": 0, "move_speed": 0, "range": 3,
		"trait": "范围伤害4", "rarity": "epic"
	}

	# ===== 守方 - 阵法 =====
	DATA["jiemai_formation"] = {
		"name": "截脉阵", "faction": "defender", "type": "formation",
		"cost": 2, "hp": 4, "atk": 2, "move_speed": 0, "range": 1,
		"trait": "基础拦截", "rarity": "common"
	}
	DATA["hanshuang_formation"] = {
		"name": "寒霜阵", "faction": "defender", "type": "formation",
		"cost": 3, "hp": 3, "atk": 1, "move_speed": 0, "range": 1,
		"trait": "命中减速1回合", "rarity": "common"
	}
	DATA["wanren_formation"] = {
		"name": "万刃阵", "faction": "defender", "type": "formation",
		"cost": 4, "hp": 5, "atk": 3, "move_speed": 0, "range": 1,
		"trait": "高输出拦截", "rarity": "epic"
	}
	DATA["fanzhen_formation"] = {
		"name": "反震阵", "faction": "defender", "type": "formation",
		"cost": 3, "hp": 3, "atk": 0, "move_speed": 0, "range": 1,
		"trait": "反伤50%", "rarity": "epic"
	}
	DATA["tianluo_formation"] = {
		"name": "天罗阵", "faction": "defender", "type": "formation",
		"cost": 5, "hp": 6, "atk": 2, "move_speed": 0, "range": 3,
		"trait": "范围拦截", "rarity": "rare"
	}

	# ===== 守方 - 单位 =====
	DATA["ying_jian"] = {
		"name": "影剑", "faction": "defender", "type": "unit",
		"cost": 3, "hp": 3, "atk": 3, "move_speed": 1.5, "range": 1,
		"trait": "冲向最近敌", "rarity": "common"
	}
	DATA["huti_jianling"] = {
		"name": "护体剑灵", "faction": "defender", "type": "unit",
		"cost": 4, "hp": 5, "atk": 2, "move_speed": 0, "range": 1,
		"trait": "大殿临时护盾", "rarity": "epic"
	}
	DATA["guardian_beast"] = {
		"name": "守门灵兽", "faction": "defender", "type": "unit",
		"cost": 3, "hp": 6, "atk": 1, "move_speed": 0.6, "range": 1,
		"trait": "高血量肉盾", "rarity": "common"
	}

	# ===== 通用 - 技能（长老随机技） =====
	DATA["elder_flying_sword"] = {
		"name": "长老·飞剑诀", "faction": "neutral", "type": "skill",
		"cost": 0, "hp": 0, "atk": 0, "move_speed": 0, "range": 3,
		"trait": "长老随机技-AOE", "rarity": "rare"
	}
	DATA["elder_pill"] = {
		"name": "长老·丹药", "faction": "neutral", "type": "skill",
		"cost": 0, "hp": 0, "atk": 0, "move_speed": 0, "range": 0,
		"trait": "长老随机技-治疗", "rarity": "rare"
	}


## 查表：根据 cardId 获取卡牌数据
## 存在返回卡牌属性字典，不存在返回空字典并报错
static func get_card(card_id: String) -> Dictionary:
	if not DATA.has(card_id):
		push_error("Cards: cardId '%s' not found in DATA" % card_id)
		return {}
	return DATA[card_id]

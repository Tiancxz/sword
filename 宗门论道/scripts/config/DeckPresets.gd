## ============================================================
## DeckPresets.gd - 预设卡组
## ============================================================
## 作用: 提供3套预设卡组，供玩家/AI选择使用。
## 设计: static var 数组，直接传给 Deck.init() 即可。
## 依赖: Cards（卡牌ID需在DATA中存在）
## ============================================================

class_name DeckPresets

## 速攻卡组：低费单位为主，快速施压
static var RUSH: Array[String] = [
	"body_disciple",   # 2费 近战
	"body_disciple",   # 2费 近战
	"yu_feng",         # 2费 加速
	"body_disciple",   # 2费 近战
	"sword_disciple",  # 3费 远程
	"beast_disciple",  # 3费 肉盾
	"sword_disciple",  # 3费 远程
	"zhen_hun",        # 3费 禁阵法
]

## 控制卡组：守方专用，阵法+守方单位为主，层层拦截
static var CONTROL: Array[String] = [
	"jiemai_formation",    # 2费 截脉阵 基础拦截
	"hanshuang_formation", # 3费 寒霜阵 命中减速
	"jiemai_formation",    # 2费 截脉阵 基础拦截
	"ying_jian",           # 3费 影剑 冲向最近敌
	"wanren_formation",    # 4费 万刃阵 高输出拦截
	"fanzhen_formation",   # 3费 反震阵 反伤50%
	"guardian_beast",      # 3费 守门灵兽 高血量肉盾
	"tianluo_formation",   # 5费 天罗阵 范围拦截
]

## 均衡卡组：单位+法术搭配，攻守兼备
static var BALANCED: Array[String] = [
	"body_disciple",   # 2费 近战
	"sword_disciple",  # 3费 远程
	"beast_disciple",  # 3费 肉盾
	"jin_zhong",       # 3费 护盾
	"sword_disciple",  # 3费 远程
	"wu_lei",          # 4费 AOE
	"beast_disciple",  # 3费 肉盾
	"elder_jindan",    # 6费 精英
]


## 根据名称获取预设卡组
static func get_preset(name: String) -> Array[String]:
	match name:
		"rush":
			return RUSH
		"control":
			return CONTROL
		"balanced":
			return BALANCED
		_:
			push_error("DeckPresets: unknown preset '%s'" % name)
			return BALANCED

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

## 控制卡组：法术+阵法为主，后期发力
static var CONTROL: Array[String] = [
	"jin_zhong",       # 3费 护盾
	"wu_lei",          # 4费 AOE
	"kun_xian",        # 3费 眩晕
	"tian_lei",        # 4费 AOE
	"jin_zhong",       # 3费 护盾
	"yi_shan",         # 5费 推后
	"elder_jindan",    # 6费 精英
	"wan_jian",        # 4费 全员增益
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

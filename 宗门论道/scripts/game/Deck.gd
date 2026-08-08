## ============================================================
## Deck.gd - 卡组系统
## ============================================================
## 作用: 管理抽牌堆、手牌、洗牌、抽牌、出牌等卡组逻辑。
## 设计: 非autoload，由 BattleController 实例化使用。
## 依赖: Const（常量）、Cards（查表）
## ============================================================

class_name Deck

## 抽牌堆
var draw_pile: Array[String] = []
## 弃牌堆
var discard_pile: Array[String] = []
## 手牌
var hand: Array[String] = []
## 出牌后自动补牌计时器（<=0 表示无待补牌）
var draw_timer: float = 0.0


## 初始化卡组：传入卡牌ID列表，洗牌后抽初始手牌
func init(card_ids: Array[String]) -> void:
	draw_pile.clear()
	discard_pile.clear()
	hand.clear()
	draw_timer = 0.0

	# 复制传入卡组到抽牌堆
	for card_id in card_ids:
		draw_pile.append(card_id)

	# 洗牌
	shuffle_deck()

	# 抽初始手牌
	for i in Const.INIT_HAND_SIZE:
		_draw_one()


## 洗牌（Fisher-Yates，Godot内置Array.shuffle()）
func shuffle_deck() -> void:
	draw_pile.shuffle()


## 抽一张牌（内部方法，不做上限检查）
func _draw_one() -> String:
	if draw_pile.is_empty():
		return ""
	var card_id: String = draw_pile.pop_back()
	hand.append(card_id)
	return card_id


## 抽牌（带手牌上限检查）
## 手牌满返回""，牌库空返回""，正常返回cardId
func draw() -> String:
	if hand.size() >= Const.HAND_MAX:
		return ""
	if draw_pile.is_empty():
		return ""
	return _draw_one()


## 每帧更新：处理出牌后延迟补牌
func update(delta: float) -> void:
	if draw_timer > 0.0:
		draw_timer -= delta
		if draw_timer <= 0.0:
			draw_timer = 0.0
			# 补牌时不超过手牌上限
			if hand.size() < Const.HAND_MAX and not draw_pile.is_empty():
				_draw_one()


## 出牌检查：灵力是否足够
func can_play(idx: int, energy: int) -> bool:
	if idx < 0 or idx >= hand.size():
		return false
	var card: Dictionary = Cards.get_card(hand[idx])
	if card.is_empty():
		return false
	return energy >= int(card.get("cost", 0))


## 打出牌：从手牌移除，设置补牌计时器，返回cardId
func play_card(idx: int) -> String:
	if idx < 0 or idx >= hand.size():
		push_error("Deck: play_card index %d out of range" % idx)
		return ""
	var card_id: String = hand.pop_at(idx)
	discard_pile.append(card_id)
	draw_timer = Const.DRAW_DELAY
	return card_id


## 获取手牌数量
func hand_size() -> int:
	return hand.size()


## 获取抽牌堆剩余数量
func deck_size() -> int:
	return draw_pile.size()

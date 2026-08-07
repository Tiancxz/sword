## ============================================================
## SpellSystem.gd - 法术系统
## ============================================================
## 作用: 处理所有法术卡的施放逻辑（攻方法术）。
## 设计: 纯静态方法，由 BattleLogic.play_card 在打出法术卡时调用。
##       每个法术对应一个 _cast_xxx 私有方法。
## 扩展: 新增法术只需在 cast() 的 match 中加分支 + 实现 _cast_xxx。
## 依赖: Const, Cards, Unit, Formation, Player
## 对应:
##   C6.01 法术入口 - cast
##   C6.02 万剑归宗 - _cast_wan_jian (全员+1攻+加速)
##   C6.03 五雷正法 - _cast_wu_lei (范围AOE伤害4)
##   C6.04 御风诀   - _cast_yu_feng (单体+0.5速5秒)
##   C6.05 镇魂符   - _cast_zhen_hun (禁用敌方阵法3秒)
##   C6.06 金钟罩   - _cast_jin_zhong (大殿护盾+3)
##   C6.07 移山倒海 - _cast_yi_shan (推后2格+1伤)
##   C6.08 困仙索   - _cast_kun_xian (单体stun2秒)
##   C6.09 天雷诀   - _cast_tian_lei (范围伤害4)
## ============================================================

class_name SpellSystem


## ============================================================
## C6.01 - 法术入口
## ============================================================

## 施放法术
## [param card_id] 法术卡牌ID
## [param caster_id] 施法者玩家ID
## [param model] 战斗模型
## [param target] 可选目标（Unit/Formation/null，为null时自动选择）
## [return] 是否施放成功
static func cast(card_id: String, caster_id: int, model: Dictionary, target: Variant = null) -> bool:
	# 验证法术卡
	var card: Dictionary = Cards.get_card(card_id)
	if card.is_empty():
		push_error("[SpellSystem] 法术卡不存在: " + card_id)
		return false

	# 分发到具体法术实现
	match card_id:
		"wan_jian":
			return _cast_wan_jian(caster_id, model)
		"wu_lei":
			return _cast_wu_lei(caster_id, model, target)
		"yu_feng":
			return _cast_yu_feng(caster_id, model, target)
		"zhen_hun":
			return _cast_zhen_hun(caster_id, model)
		"jin_zhong":
			return _cast_jin_zhong(caster_id, model)
		"yi_shan":
			return _cast_yi_shan(caster_id, model)
		"kun_xian":
			return _cast_kun_xian(caster_id, model, target)
		"tian_lei":
			return _cast_tian_lei(caster_id, model)
		_:
			push_error("[SpellSystem] 未实现的法术: " + card_id)
			return false


## ============================================================
## 辅助：目标选取
## ============================================================

## 获取敌方所有存活单位
## [param caster_id] 施法者ID
## [param model] 战斗模型
static func _get_enemy_units(caster_id: int, model: Dictionary) -> Array:
	var result: Array = []
	for u in model.get("units", []):
		if u is Unit and not u.is_dead() and u.owner != caster_id:
			result.append(u)
	return result


## 获取己方所有存活单位
static func _get_ally_units(caster_id: int, model: Dictionary) -> Array:
	var result: Array = []
	for u in model.get("units", []):
		if u is Unit and not u.is_dead() and u.owner == caster_id:
			result.append(u)
	return result


## 获取敌方所有未损毁阵法
static func _get_enemy_formations(caster_id: int, model: Dictionary) -> Array:
	var result: Array = []
	for f in model.get("formations", []):
		if f is Formation and not f.is_dead() and f.owner != caster_id:
			result.append(f)
	return result


## 自动选取最近的敌方单位（作为默认目标）
## [param caster_id] 施法者ID
## [param model] 战斗模型
## [return] 最近的敌方Unit，无则null
static func _get_nearest_enemy(caster_id: int, model: Dictionary) -> Unit:
	var enemies: Array = _get_enemy_units(caster_id, model)
	if enemies.is_empty():
		return null
	# 选HP最低的单位作为目标（集火残血）
	enemies.sort_custom(func(a, b): return a.hp < b.hp)
	return enemies[0]


## ============================================================
## C6.02 - 万剑归宗
## ============================================================

## 万剑归宗：己方全员+1攻+加速5秒
## [return] 始终成功（即使无单位也算施放）
static func _cast_wan_jian(caster_id: int, model: Dictionary) -> bool:
	var allies: Array = _get_ally_units(caster_id, model)
	for u in allies:
		u.atk += 1                       ## 永久+1攻击力
		u.add_buff("speed", 0.3, 5.0)    ## 加速5秒
	print("[SpellSystem] 万剑归宗：己方%d个单位获得强化" % allies.size())
	return true


## ============================================================
## C6.03 - 五雷正法
## ============================================================

## 五雷正法：范围AOE伤害4（对所有敌方单位+阵法）
## [param target] 未使用（范围法术全屏）
static func _cast_wu_lei(caster_id: int, model: Dictionary, _target: Variant) -> bool:
	var enemies: Array = _get_enemy_units(caster_id, model)
	var formations: Array = _get_enemy_formations(caster_id, model)

	for u in enemies:
		u.take_damage(4, null)
	for f in formations:
		f.take_damage(4, null, model)

	print("[SpellSystem] 五雷正法：对%d个敌方单位+%d个阵法造成4伤害" % [enemies.size(), formations.size()])
	return true


## ============================================================
## C6.04 - 御风诀
## ============================================================

## 御风诀：单体+0.5速5秒
## [param target] 目标单位，为null时自动选最近的己方单位
static func _cast_yu_feng(caster_id: int, model: Dictionary, target: Variant) -> bool:
	var ally: Unit = null
	if target is Unit and target.owner == caster_id and not target.is_dead():
		ally = target
	else:
		# 自动选最近的己方单位（选最靠前的，加速推进）
		var allies: Array = _get_ally_units(caster_id, model)
		if not allies.is_empty():
			allies.sort_custom(func(a, b): return a.position_y > b.position_y)
			ally = allies[0]

	if ally == null:
		print("[SpellSystem] 御风诀：无有效目标")
		return false

	ally.add_buff("speed", 0.5, 5.0)
	print("[SpellSystem] 御风诀：%s 获得5秒加速" % ally.unit_name)
	return true


## ============================================================
## C6.05 - 镇魂符
## ============================================================

## 镇魂符：禁用所有敌方阵法3秒
static func _cast_zhen_hun(caster_id: int, model: Dictionary) -> bool:
	var formations: Array = _get_enemy_formations(caster_id, model)
	for f in formations:
		f.set_silence(3.0)
	print("[SpellSystem] 镇魂符：禁用%d个敌方阵法3秒" % formations.size())
	return true


## ============================================================
## C6.06 - 金钟罩
## ============================================================

## 金钟罩：大殿护盾+3
static func _cast_jin_zhong(caster_id: int, model: Dictionary) -> bool:
	var players: Array = model.get("players", [])
	if caster_id >= players.size():
		return false
	var player: Player = players[caster_id]
	player.add_shield(3)
	print("[SpellSystem] 金钟罩：玩家%d大殿护盾+3 (当前%d)" % [caster_id, player.hall_shield])
	return true


## ============================================================
## C6.07 - 移山倒海
## ============================================================

## 移山倒海：推后所有敌方单位2格+1伤
static func _cast_yi_shan(caster_id: int, model: Dictionary) -> bool:
	var enemies: Array = _get_enemy_units(caster_id, model)
	for u in enemies:
		# 推后：朝敌方来时方向的反方向移动2格
		# 攻方单位facing=-1（向上），推后即向下(+2)；守方反之
		u.position_y -= 2.0 * float(u.facing)
		u.take_damage(1, null)
	print("[SpellSystem] 移山倒海：推后%d个敌方单位2格+1伤" % enemies.size())
	return true


## ============================================================
## C6.08 - 困仙索
## ============================================================

## 困仙索：单体stun2秒
## [param target] 目标单位，为null时自动选最近敌方
static func _cast_kun_xian(caster_id: int, model: Dictionary, target: Variant) -> bool:
	var enemy: Unit = null
	if target is Unit and target.owner != caster_id and not target.is_dead():
		enemy = target
	else:
		enemy = _get_nearest_enemy(caster_id, model)

	if enemy == null:
		print("[SpellSystem] 困仙索：无有效目标")
		return false

	# stun buff，value=0表示眩晕，duration=2秒
	enemy.add_buff("stun", 0.0, 2.0)
	# 眩晕的单位停止战斗状态
	enemy.state = "walking"
	print("[SpellSystem] 困仙索：%s 被眩晕2秒" % enemy.unit_name)
	return true


## ============================================================
## C6.09 - 天雷诀
## ============================================================

## 天雷诀：范围伤害4（对所有敌方单位+阵法）
static func _cast_tian_lei(caster_id: int, model: Dictionary) -> bool:
	var enemies: Array = _get_enemy_units(caster_id, model)
	var formations: Array = _get_enemy_formations(caster_id, model)

	for u in enemies:
		u.take_damage(4, null)
	for f in formations:
		f.take_damage(4, null, model)

	print("[SpellSystem] 天雷诀：对%d个敌方单位+%d个阵法造成4伤害" % [enemies.size(), formations.size()])
	return true

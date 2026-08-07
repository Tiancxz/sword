#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""《宗门论道》Godot版 — 开发主表数据生成
把原生JS的全部121个L3任务重构为GDScript + Godot节点系统
新增I.跨平台导出模块"""
import json

D=[]

# ===== A. 项目骨架（Godot引擎提供基础能力） =====
SC,SN='A','A.项目骨架'
for mod,items in [
    ('A1.主场景循环',[
        ('L3','A1.01','P1','主循环驱动','Godot内置_process(delta)，每帧自动调用。@export var running:bool=true。if not running: return。dt由引擎传入已钳制。','func _process(delta: float) -> void:','scripts/core/Main.gd','delta:float → void','—',0.2),
        ('L3','A1.02','P1','逻辑更新','var scene = scene_manager.current; if scene: scene.on_update(delta)','func on_update(delta: float) -> void:','scripts/core/Main.gd','delta:float → void','A1.01',0.2),
        ('L3','A1.03','P1','画面渲染','Godot节点自动渲染，无需手动clearRect。自定义绘制用queue_redraw()+_draw()','func _draw() -> void:','scripts/core/Main.gd','void → void','A1.01',0.2),
        ('L3','A1.04','P1','项目初始化','@onready var scene_manager=get_node("/root/SceneManager")。在_ready()中初始化autoload单例，切换到初始场景','func _ready() -> void:','scripts/core/Main.gd','void → void','A4.01',0.3),
    ]),
    ('A2.输入系统',[
        ('L3','A2.01','P1','触摸/点击监听','func _input(event): if event is InputEventScreenTouch and event.pressed: handle_tap(event.position)。自动支持多平台触屏。','func _input(event: InputEvent) -> void:','scripts/core/InputManager.gd','InputEvent → void','—',0.3),
        ('L3','A2.02','P1','点击区域注册','var regions: Array[Dictionary] = []。func register(id:String, rect:Rect2, cb:Callable)。场景onEnter注册，onExit时clear。','func register(id:String, rect:Rect2, cb:Callable) -> void:','scripts/core/InputManager.gd','id+Rect2+Callable → void','A2.01',0.3),
        ('L3','A2.03','P1','命中检测','for r in regions: if r.rect.has_point(pos): r.cb.call(pos); break','func handle_tap(pos: Vector2) -> void:','scripts/core/InputManager.gd','Vector2 → 触发cb','A2.02',0.2),
        ('L3','A2.04','P1','区域清理','regions.clear()。场景切换onExit必须调用，防止旧回调残留。','func clear() -> void:','scripts/core/InputManager.gd','void → void','A2.02',0.1),
    ]),
    ('A3.事件总线',[
        ('L3','A3.01','P1','信号定义','signal card_played(card_id: String, target: Vector2)。Godot信号系统替代手写EventSystem。','signal event_name(args)','scripts/core/EventBus.gd','autoload单例','—',0.2),
        ('L3','A3.02','P1','信号触发','EventBus.card_played.emit(card_id, target)。任何节点可监听autoload信号。','func emit_signal(args) -> void:','scripts/core/EventBus.gd','args → void','A3.01',0.1),
        ('L3','A3.03','P1','信号连接','EventBus.card_played.connect(_on_card_played)。在_ready中connect，在_exit_tree中断开。','func connect_signal(target: Callable) -> void:','scripts/core/EventBus.gd','Callable → void','A3.01',0.2),
    ]),
    ('A4.场景管理',[
        ('L3','A4.01','P1','场景注册','var scenes: Dictionary = {}。func register(name:String, path:String)。预注册场景路径。','func register(name:String, path:String) -> void:','scripts/core/SceneManager.gd','name+path → void','—',0.2),
        ('L3','A4.02','P1','场景切换','get_tree().change_scene_to_file(scenes[name])。Godot原生场景切换，自动调用_exit_tree和_enter_tree。','func switch(name: String) -> void:','scripts/core/SceneManager.gd','name → void','A4.01',0.2),
    ]),
    ('A5.渲染辅助',[
        ('L3','A5.01','P1','矩形绘制','draw_rect(Rect2(x,y,w,h), color, true)。在_draw()中调用，queue_redraw()触发重绘。','func draw_rect(rect: Rect2, color: Color, filled: bool) -> void:','scripts/core/Renderer.gd','Rect2+Color → void','—',0.2),
        ('L3','A5.02','P1','文字绘制','draw_string(font, Vector2(x,y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)。需先load_font。','func draw_string(font:Font,pos:Vector2,text:String,size:int,color:Color) -> void:','scripts/core/Renderer.gd','Font+pos+text → void','—',0.2),
        ('L3','A5.03','P1','血条绘制','draw_rect(bg, COLOR_RED, true); draw_rect(fg, COLOR_GREEN, true)。fg宽度=ratio*总宽。','func draw_health_bar(pos:Vector2,w:float,h:float,ratio:float) -> void:','scripts/core/Renderer.gd','pos+w+h+ratio → void','A5.01',0.2),
    ]),
    ('A6.粒子系统',[
        ('L3','A6.01','P6','粒子节点','使用CPUParticles2D节点。@export var amount:int=10。emitting=true触发。配置texture/color/方向。','func setup_particles(particles: CPUParticles2D, count: int, color: Color) -> void:','scripts/core/ParticleHelper.gd','CPUParticles2D+count+color → void','—',0.3),
        ('L3','A6.02','P6','粒子触发','particles.amount=count; particles.color=color; particles.emitting=true。自动更新和渲染，无需手写。','func emit(particles: CPUParticles2D, x: float, y: float) -> void:','scripts/core/ParticleHelper.gd','particles+pos → void','A6.01',0.2),
    ]),
    ('A7.音频管理',[
        ('L3','A7.01','P6','BGM播放','var bgm: AudioStreamPlayer = AudioStreamPlayer.new()。bgm.stream=load(path); bgm.autoplay=true; bgm.stream.loop=true。add_child(bgm)','func play_bgm(stream_path: String) -> void:','scripts/core/AudioManager.gd','path → void','—',0.2),
        ('L3','A7.02','P6','SFX播放','var sfx: AudioStreamPlayer = $SFXPlayer。sfx.stream=load(path); sfx.play()。one-shot自动停止。','func play_sfx(stream_path: String) -> void:','scripts/core/AudioManager.gd','path → void','—',0.2),
    ]),
]:
    D.append(('L1','','',SC,SN,'','','','','','','','','',''))
    D.append(('L2',mod.split('.')[0],'P1' if 'A6' not in mod and 'A7' not in mod else 'P6',SC,'',mod,'','','','','','','','V1',''))
    for it in items:
        D.append((it[0],it[1],it[2],SC,'',mod,it[3],it[4],it[5],it[6],it[7],it[8],it[9],'V1','待办'))

# ===== B. 游戏数据 =====
SC,SN='B','B.游戏数据'
for mod,items in [
    ('B1.常量配置',[('L3','B1.01','P2','全局常量','class_name Const。const BOARD_LENGTH:=9。const HALL_HP:=30。const ENERGY_START:=5。const ENERGY_REGEN:=2.8。静态常量，全局引用。','class_name Const','scripts/config/Const.gd','文件 → class引用','—',0.3)]),
    ('B2.卡牌数据表',[
        ('L3','B2.01','P2','卡牌配置','class_name Cards。static var DATA:={}。DATA["body_disciple"]={name:"宗门体修弟子",type:"unit",cost:2,hp:4,atk:2,...}。共20张。','static var DATA: Dictionary','scripts/config/Cards.gd','文件 → static引用','B1.01',0.8),
        ('L3','B2.02','P2','卡牌查表','static func get_card(card_id: String) -> Dictionary: return DATA.get(card_id, {})。不存在返回空字典+push_error。','static func get_card(card_id: String) -> Dictionary:','scripts/config/Cards.gd','cardId → Dictionary','B2.01',0.2),
    ]),
    ('B3.卡组手牌',[
        ('L3','B3.01','P2','卡组初始化','var draw_pile: Array[String]=[]。var hand: Array[String]=[]。func init(card_ids)。shuffle(); 抽3张。','func init(card_ids: Array[String]) -> void:','scripts/game/Deck.gd','cardIds[] → void','B2.01',0.4),
        ('L3','B3.02','P2','洗牌算法','draw_pile.shuffle()。Godot内置Array.shuffle()，Fisher-Yates算法。','func shuffle_deck() -> void:','scripts/game/Deck.gd','void → void','B3.01',0.1),
        ('L3','B3.03','P2','抽牌','if hand.size()>=4: return ""。if draw_pile.is_empty(): return ""。var c=draw_pile.pop_back(); hand.append(c); return c','func draw() -> String:','scripts/game/Deck.gd','void → cardId|""','B3.01',0.2),
        ('L3','B3.04','P2','打出后补牌','if draw_timer>0: draw_timer-=delta; if draw_timer<=0: draw(); draw_timer=0','func update(delta: float) -> void:','scripts/game/Deck.gd','delta → void','B3.03',0.2),
        ('L3','B3.05','P2','出牌检查','var card=Cards.get_card(hand[idx]); return energy>=card.cost','func can_play(idx: int, energy: int) -> bool:','scripts/game/Deck.gd','idx+energy → bool','B2.02',0.2),
        ('L3','B3.06','P2','打出牌','var card_id=hand.pop_at(idx); draw_timer=2.0; return card_id','func play_card(idx: int) -> String:','scripts/game/Deck.gd','idx → cardId','B3.05',0.2),
    ]),
    ('B4.预设卡组',[('L3','B4.01','P2','3套预设卡组','class_name DeckPresets。static var RUSH:=["body_disciple",...8张]。static var CONTROL:=[...]。static var BALANCED:=[...]','static var RUSH: Array[String]','scripts/config/DeckPresets.gd','文件 → Deck.init','B2.01',0.3)]),
]:
    D.append(('L1','','',SC,SN,'','','','','','','','','',''))
    D.append(('L2',mod.split('.')[0],'P2',SC,'',mod,'','','','','','','','V1',''))
    for it in items:
        D.append((it[0],it[1],it[2],SC,'',mod,it[3],it[4],it[5],it[6],it[7],it[8],it[9],'V1','待办'))

# ===== C. 战斗逻辑 =====
SC,SN='C','C.战斗逻辑'
for mod,items in [
    ('C1.战斗主循环',[('L3','C1.01','P3','每帧总入口','func on_update(delta): update_energy(delta); update_draw(delta); update_units(delta); update_formations(delta); update_elders(delta); update_ai(delta); remove_dead(); check_end(); model.time-=delta','func on_update(delta: float) -> void:','scripts/game/BattleLogic.gd','delta:float → void','C3.01,C4.01,C5.02,C7.01,C8.01',0.8)]),
    ('C2.单位实体',[
        ('L3','C2.01','P3','从卡牌创建单位','class_name Unit extends Node2D。var card_id:String。var owner:int。var hp:int。var atk:int。var speed:float。func init_from_card(card_id,owner,x,y)。','func init_from_card(card_id: String, owner: int, x: int, y: int) -> void:','scripts/game/Unit.gd','cardId+owner+x+y → void','B2.02',0.5),
        ('L3','C2.02','P3','buff系统','var buffs: Array[Dictionary]=[]。func add_buff(type:String,value:float,duration:float)。类型:slow/speed/stun/shield/atk_boost。','func add_buff(type:String,value:float,duration:float) -> void:','scripts/game/Unit.gd','type+value+duration → void','C2.01',0.4),
        ('L3','C2.03','P3','实际移速计算','var spd:=base_speed。for b in buffs: if b.type=="slow": spd-=0.5。if stun: return 0。return max(0,spd)','func get_effective_speed() -> float:','scripts/game/Unit.gd','void → float','C2.02',0.2),
        ('L3','C2.04','P3','受到伤害','if hp<=0: return 0。hp-=amount。if hp<=0: hp=0; state="dead"。return amount','func take_damage(amount: int, attacker: Object) -> int:','scripts/game/Unit.gd','amount+attacker → int','C2.01',0.3),
    ]),
    ('C3.移动系统',[
        ('L3','C3.01','P3','★单位移动★','class_name MovementSystem。if state!="walking": return。target=find_target(unit)。if target and check_collision: state="fighting"。else: position.y+=get_effective_speed()*delta*facing。if check_hall_reach: state="dead"; damage_hall()','static func move_unit(unit: Unit, delta: float, model: Dictionary) -> void:','scripts/game/MovementSystem.gd','Unit+delta+model → void','C2.03,C3.02,C3.04',0.8),
        ('L3','C3.02','P3','★目标选择★','var enemies=get_enemy_units(unit.owner)。var formations=get_enemy_formations(unit.owner)。var candidates=enemies+formations。filter(e=>e.grid_x==unit.grid_x)。sort by abs(y-unit.y)。nearest in range → return','static func find_target(unit: Unit, model: Dictionary) -> Variant:','scripts/game/MovementSystem.gd','Unit+model → Unit|Formation|null','C2.01',0.6),
        ('L3','C3.03','P3','碰撞检测','var dist=abs(target.position.y - unit.position.y)。return dist<=unit.attack_range','static func check_collision(unit: Unit, target: Node2D) -> bool:','scripts/game/MovementSystem.gd','Unit+target → bool','C3.02',0.2),
        ('L3','C3.04','P3','到达大殿检测','if owner==0 and position.y>=Const.BOARD_LENGTH-1: return true。if owner==1 and position.y<=0: return true。return false','static func check_hall_reach(unit: Unit) -> bool:','scripts/game/MovementSystem.gd','Unit → bool','B1.01',0.2),
    ]),
    ('C4.战斗系统',[
        ('L3','C4.01','P3','攻击主逻辑','class_name CombatSystem。if state!="fighting" or not target: return。if Time.get_ticks_msec()-last_attack>=interval*1000: melee/ranged attack。if target.hp<=0: handle_kill()','static func attack(unit: Unit, delta: float, model: Dictionary) -> void:','scripts/game/CombatSystem.gd','Unit+delta+model → void','C2.04,C4.02,C4.05',0.8),
        ('L3','C4.02','P3','近战互扣','target.take_damage(attacker.atk, attacker)。attacker.take_damage(target.atk, target)。双方同时掉血。','static func melee_attack(attacker: Unit, target: Unit) -> void:','scripts/game/CombatSystem.gd','attacker+target → void','C2.04',0.2),
        ('L3','C4.03','P3','远程单方','target.take_damage(attacker.atk, attacker)。攻击者不掉血。','static func ranged_attack(attacker: Unit, target: Node2D) -> void:','scripts/game/CombatSystem.gd','attacker+target → void','C2.04',0.2),
        ('L3','C4.04','P4','范围伤害','for t in targets: t.take_damage(damage, source)','static func aoe_attack(source: Node2D, targets: Array, damage: int) -> void:','scripts/game/CombatSystem.gd','source+targets+damage → void','C2.04',0.2),
        ('L3','C4.05','P3','★击杀后继续推进★','killer.state="walking"。killer.target=null。不消失继续走！核心修复。','static func handle_kill(killer: Unit, victim: Node2D) -> void:','scripts/game/CombatSystem.gd','killer+victim → void','C4.01',0.2),
        ('L3','C4.06','P3','大殿受伤','if player.hall_shield>0: return。player.hall_hp-=amount。if hall_hp<=0: hall_hp=0; model.state="ended"; model.winner=1-player.id','static func damage_hall(player: Dictionary, amount: int, model: Dictionary) -> void:','scripts/game/CombatSystem.gd','player+amount+model → void','C3.04',0.3),
    ]),
    ('C5.阵法系统',[
        ('L3','C5.01','P4','布阵','class_name Formation extends Area2D。var grid_x:int。var grid_y:int。检查冷却→创建节点→扣灵力→出牌。Area2D自动检测进入的敌人。','func place_formation(player, card_id, gx, gy, model) -> bool:','scripts/game/Formation.gd','player+cardId+gx+gy+model → bool','B3.06,C5.03',0.6),
        ('L3','C5.02','P4','阵法攻击','func _on_body_entered(body): if body is Unit and body.owner!=owner: attack_target(body)。Area2D信号自动触发。','func _on_body_entered(body: Node2D) -> void:','scripts/game/Formation.gd','body → void','C4.03',0.4),
        ('L3','C5.03','P4','阵法冷却','var cooldowns: Dictionary={}。key=gx+","+gy。return not cooldowns.has(key) or Time.get_ticks_msec()>=cooldowns[key]','func check_cooldown(gx: int, gy: int) -> bool:','scripts/game/Player.gd','gx+gy → bool','—',0.3),
        ('L3','C5.04','P4','阵法被禁','is_active=false。silence_timer=duration。在_process中倒数到0恢复。','func set_silence(duration: float) -> void:','scripts/game/Formation.gd','duration → void','C5.02',0.2),
    ]),
    ('C6.法术系统',[
        ('L3','C6.01','P4','法术入口','class_name SpellSystem。match card_id: "wan_jian": cast_wan_jian()。"wu_lei": cast_wu_lei()。...','static func cast(card_id: String, caster_id: int, target: Variant, model: Dictionary) -> void:','scripts/game/SpellSystem.gd','cardId+caster+target+model → void','—',0.4),
        ('L3','C6.02','P4','万剑归宗','for u in players[caster_id].units: u.atk+=1; u.add_buff("speed",0.3,5)','static func cast_wan_jian(caster_id: int, model: Dictionary) -> void:','scripts/game/SpellSystem.gd','casterId+model → void','C2.02',0.3),
        ('L3','C6.03','P4','五雷正法','var enemies=get_enemy_units(caster)+get_enemy_formations(caster)。filter范围3格。for e in range: e.take_damage(4)','static func cast_wu_lei(target: Vector2, caster_id: int, model: Dictionary) -> void:','scripts/game/SpellSystem.gd','target+casterId+model → void','C2.04,C4.04',0.4),
        ('L3','C6.04','P4','御风诀','target.add_buff("speed",0.5,5)','static func cast_yu_feng(target: Unit) -> void:','scripts/game/SpellSystem.gd','Unit → void','C2.02',0.2),
        ('L3','C6.05','P4','镇魂符','target.set_silence(3.0)','static func cast_zhen_hun(target: Formation) -> void:','scripts/game/SpellSystem.gd','Formation → void','C5.04',0.2),
        ('L3','C6.06','P4','金钟罩','players[caster_id].hall_shield=3','static func cast_jin_zhong(caster_id: int, model: Dictionary) -> void:','scripts/game/SpellSystem.gd','casterId+model → void','—',0.2),
        ('L3','C6.07','P4','移山倒海','for t in targets: t.position.y-=2*t.facing; t.take_damage(1)','static func cast_yi_shan(targets: Array) -> void:','scripts/game/SpellSystem.gd','targets[] → void','C2.04',0.2),
        ('L3','C6.08','P4','困仙索','target.add_buff("stun",0,2)','static func cast_kun_xian(target: Unit) -> void:','scripts/game/SpellSystem.gd','Unit → void','C2.02',0.2),
        ('L3','C6.09','P4','天雷诀','for t in targets: t.take_damage(4)','static func cast_tian_lei(targets: Array) -> void:','scripts/game/SpellSystem.gd','targets[] → void','C2.04',0.2),
    ]),
    ('C7.长老技能',[
        ('L3','C7.01','P4','技能计时','class_name ElderSkillSystem。if not unit.is_elder: return。unit.elder_timer+=delta。if elder_timer>=5.0: elder_timer=0; trigger_random()','static func update(unit: Unit, delta: float, model: Dictionary) -> void:','scripts/game/ElderSkillSystem.gd','Unit+delta+model → void','C2.01',0.3),
        ('L3','C7.02','P4','★随机分支★','var branches=["flying_sword","pill","talisman","beast"]。var idx=randi()%4。call(branches[idx], elder, model)','static func trigger_random(elder: Unit, model: Dictionary) -> void:','scripts/game/ElderSkillSystem.gd','Unit+model → void','C7.01',0.3),
        ('L3','C7.03','P4','飞剑分支','var enemies=get_enemy_units(elder.owner)。var nearby=enemies.filter(func(e): return abs(e.y-elder.y)<=3)。aoe_attack(elder, nearby, 3)','static func flying_sword(elder: Unit, model: Dictionary) -> void:','scripts/game/ElderSkillSystem.gd','Unit+model → void','C4.04',0.3),
        ('L3','C7.04','P4','丹药分支','elder.hp=min(elder.max_hp, elder.hp+3)。var allies=get_units(elder.owner)。for a in allies: if a!=elder and abs(a.y-elder.y)<=2: a.hp=min(a.max_hp, a.hp+2)','static func pill(elder: Unit, model: Dictionary) -> void:','scripts/game/ElderSkillSystem.gd','Unit+model → void','—',0.3),
        ('L3','C7.05','P4','符箓分支','var enemies=get_enemy_units()。var front=enemies.filter(范围3格)。cast_tian_lei(front)','static func talisman(elder: Unit, model: Dictionary) -> void:','scripts/game/ElderSkillSystem.gd','Unit+model → void','C6.09',0.2),
        ('L3','C7.06','P4','御兽分支','var beast=Unit.new()。beast.init_from_card("guardian_beast", elder.owner, elder.grid_x, elder.grid_y)。model.units.append(beast)','static func beast(elder: Unit, model: Dictionary) -> void:','scripts/game/ElderSkillSystem.gd','Unit+model → void','C2.01',0.3),
    ]),
    ('C8.灵力系统',[
        ('L3','C8.01','P4','实时回复','class_name Player。var energy:int。var energy_max:int。var energy_timer:float。regen_rate = 2.8 if not overtime else 2.8/1.5。energy_timer+=delta。if energy_timer>=regen_rate: energy_timer-=regen_rate; energy=min(energy_max, energy+1)','func update_energy(delta: float, model: Dictionary) -> void:','scripts/game/Player.gd','delta+model → void','B1.01',0.3),
        ('L3','C8.02','P4','上限增长','var new_max=min(Const.ENERGY_MAX_CAP, Const.ENERGY_START + int(model.elapsed_time/30))。energy_max=new_max','func update_energy_max(model: Dictionary) -> void:','scripts/game/Player.gd','model → void','B1.01',0.2),
    ]),
    ('C9.出牌执行',[
        ('L3','C9.01','P4','出兵','var card=Cards.get_card(card_id)。if not spend_energy(card.cost): return null。var unit=Unit.new()。unit.init_from_card(card_id, player.id, x, spawn_y)。model.units.append(unit)。play_card(hand_idx)。return unit','func spawn_unit(player, card_id, x, model) -> Unit:','scripts/game/BattleLogic.gd','player+cardId+x+model → Unit','B3.06,C2.01',0.4),
        ('L3','C9.02','P4','施法','var card=Cards.get_card(card_id)。if not spend_energy(card.cost): return。SpellSystem.cast(card_id, player.id, target, model)。play_card(hand_idx)','func cast_spell(player, card_id, target, model) -> void:','scripts/game/BattleLogic.gd','player+cardId+target+model → void','B3.06,C6.01',0.4),
    ]),
    ('C10.胜负判定',[
        ('L3','C10.01','P4','大殿摧毁','class_name BattleChecker。if model.players[0].hall_hp<=0: return 1。if model.players[1].hall_hp<=0: return 0。return -1','static func check_hall(model: Dictionary) -> int:','scripts/game/BattleChecker.gd','model → int(-1|0|1)','C4.06',0.2),
        ('L3','C10.02','P4','时限检测','if model.time>0: return -1。if p0.hp!=p1.hp: return 0 if p0.hp>p1.hp else 1。model.state="overtime"; model.time=60。return -1','static func check_time(model: Dictionary) -> int:','scripts/game/BattleChecker.gd','model → int','C8.01',0.2),
        ('L3','C10.03','P4','加时结算','if model.time>0: return -1。return 0 if p0.energy>p1.energy else 1','static func check_overtime(model: Dictionary) -> int:','scripts/game/BattleChecker.gd','model → int','C10.02',0.2),
    ]),
    ('C11.死亡清理',[
        ('L3','C11.01','P4','清理死亡单位','for p in model.players: p.units=p.units.filter(func(u): if u.state=="dead": if u.has_trait("kamikaze"): CombatSystem.kamikaze(u,model); u.queue_free(); return false; return true)','func remove_dead(model: Dictionary) -> void:','scripts/game/BattleLogic.gd','model → void','C4.05',0.3),
        ('L3','C11.02','P4','清理被毁阵法','for p in model.players: p.formations=p.formations.filter(func(f): if f.hp<=0: cooldowns[key]=Time.get_ticks_msec()+8000; f.queue_free(); return false; return true)','func remove_dead_formations(model: Dictionary) -> void:','scripts/game/BattleLogic.gd','model → void','C5.03',0.3),
    ]),
]:
    D.append(('L1','','',SC,SN,'','','','','','','','','',''))
    ph = 'P3' if mod.startswith('C1') or mod.startswith('C2') or mod.startswith('C3') or mod.startswith('C4') else 'P4'
    D.append(('L2',mod.split('.')[0],ph,SC,'',mod,'','','','','','','','V1',''))
    for it in items:
        D.append((it[0],it[1],it[2],SC,'',mod,it[3],it[4],it[5],it[6],it[7],it[8],it[9],'V1','待办'))

# ===== D. AI系统 =====
SC,SN='D','D.AI系统'
D.append(('L1','','',SC,SN,'','','','','','','','','',''))
D.append(('L2','D1','P5',SC,'','D1.AI决策','','','','','','','','V1',''))
for it in [
    ('L3','D1.01','P5','AI主循环','class_name AI extends Node。var think_timer:float=0。think_timer+=delta。if think_timer>=think_interval: think_timer=0; think(model)','func on_update(delta: float, model: Dictionary) -> void:','scripts/game/AI.gd','delta+model → void','C1.01',0.3),
    ('L3','D1.02','P5','★决策核心★','var player=model.players[player_id]。var ratio=decide_attack_ratio(model)。var card_idx=pick_card(player.energy, ratio, player.deck.hand)。if card_idx<0: return。var card=Cards.get_card(hand[card_idx])。if card.type=="unit": spawn_unit()。elif card.type=="formation": place_formation()。else: cast_spell()','func think(model: Dictionary) -> void:','scripts/game/AI.gd','model → void','D1.03,D1.04,D1.05,C9.01,C9.02,C5.01',1.2),
    ('L3','D1.03','P5','攻守比计算','var pct=float(player.hall_hp)/float(Const.HALL_HP)。if pct>0.6: return 0.7。if pct<0.3: return 0.2。return 0.4','func decide_attack_ratio(model: Dictionary) -> float:','scripts/game/AI.gd','model → float','B1.01',0.2),
    ('L3','D1.04','P5','选牌逻辑','var playable=range(hand.size()).filter(func(i): return can_play(i, energy))。if playable.is_empty(): return -1。if ratio>0.5: sort by unit优先。else: sort by formation优先。return playable[0]','func pick_card(energy: int, ratio: float, hand: Array) -> int:','scripts/game/AI.gd','energy+ratio+hand → int','B2.02',0.4),
    ('L3','D1.05','P5','布阵位置','match difficulty: "easy": return random_pos()。"normal": return near_own_hall()。"hard": return in_front_of_fastest_enemy()','func pick_formation_pos(model: Dictionary) -> Vector2i:','scripts/game/AI.gd','model → Vector2i','B1.01',0.4),
]:
    D.append((it[0],it[1],it[2],SC,'','D1.AI决策',it[3],it[4],it[5],it[6],it[7],it[8],it[9],'V1','待办'))

# ===== E. 渲染与UI =====
SC,SN='E','E.渲染与UI'
for mod,items in [
    ('E1.战斗场景',[
        ('L3','E1.01','P6','场景进入','func _ready(): model=init_game_model(deck0, deck1)。battle_logic=BattleLogic.new()。battle_logic.model=model。register_input()','func _ready() -> void:','scripts/scenes/BattleScene.gd','void → void','A4.02,C1.01',0.4),
        ('L3','E1.02','P6','场景更新','func _process(delta): battle_logic.on_update(delta)。自动驱动所有子节点更新。','func _process(delta: float) -> void:','scripts/scenes/BattleScene.gd','delta → void','C1.01',0.2),
        ('L3','E1.03','P6','场景渲染(分层)','Godot节点树自动分层渲染。YSort节点自动按y排序。背景→阵法→单位→粒子→UI(Control层)','func _draw() -> void:','scripts/scenes/BattleScene.gd','void → void','E2.01,E3.01,E4.01,E5.01,E6.01',0.4),
        ('L3','E1.04','P6','场景退出','func _exit_tree(): input_manager.clear()。model.clear()。清理信号连接。','func _exit_tree() -> void:','scripts/scenes/BattleScene.gd','void → void','A2.04',0.2),
    ]),
    ('E2.背景渲染',[
        ('L3','E2.01','P6','山道背景','使用ColorRect或Sprite节点。gradient用GradientTexture2D。颜色#1a3a2a→#2d5a3d。编辑器拖拽即可。','@onready var bg: ColorRect = $Background','scripts/scenes/BattleScene.gd','节点 → void','A5.01',0.2),
        ('L3','E2.02','P6','棋盘格子线','func _draw(): for i in range(Const.BOARD_LENGTH+1): draw_line(...)。在自定义绘制节点中实现。','func _draw() -> void:','scripts/scenes/GridRenderer.gd','void → void','B1.01',0.2),
    ]),
    ('E3.大殿渲染',[
        ('L3','E3.01','P6','大殿Sprite','使用Sprite2D节点+纹理。@onready var hall_top: Sprite2D = $HallTop。编辑器配置texture。','@onready var hall_top: Sprite2D','scripts/scenes/BattleScene.gd','节点 → void','A5.01',0.2),
        ('L3','E3.02','P6','大殿血条','使用TextureProgress节点。value=hp/max_hp*100。@onready var hall_hp_bar: TextureProgress','@onready var hall_hp_bar: TextureProgress','scripts/scenes/BattleScene.gd','节点 → void','A5.03',0.2),
        ('L3','E3.03','P6','受击特效','func shake(): var tween=create_tween()。tween.tween_property(self, "position", Vector2(randf()*6, randf()*6), 0.05)。Godot Tween动画。','func on_hall_hit() -> void:','scripts/scenes/BattleScene.gd','void → void','—',0.3),
    ]),
    ('E4.单位渲染',[
        ('L3','E4.01','P6','单位Sprite','class_name UnitView extends Sprite2D。@export var unit_color: Color。使用YSort节点自动按y排序。','@onready var sprite: Sprite2D','scripts/views/UnitView.gd','节点 → void','A5.01',0.4),
        ('L3','E4.02','P6','单位血条','使用TextureProgress子节点。position在单位上方。value=hp/max_hp*100。','@onready var hp_bar: TextureProgress','scripts/views/UnitView.gd','节点 → void','A5.03',0.2),
    ]),
    ('E5.阵法渲染',[
        ('L3','E5.01','P6','阵法Sprite','class_name FormationView extends Sprite2D。modulate.a=0.4 if active else 0.2。颜色区分激活/禁用。','@onready var sprite: Sprite2D','scripts/views/FormationView.gd','节点 → void','A5.01',0.3),
    ]),
    ('E6.UI-手牌栏',[
        ('L3','E6.01','P6','手牌显示','使用HBoxContainer+TextureButton。4个卡牌槽。modulate=Color.GRAY if not can_play。','@onready var hand_container: HBoxContainer','scripts/ui/HandBar.gd','节点 → void','A5.01,B2.02',0.5),
        ('L3','E6.02','P6','点击选中','func _on_card_pressed(idx): selected = -1 if selected==idx else idx。Signal连接到button.pressed。','func _on_card_pressed(idx: int) -> void:','scripts/ui/HandBar.gd','idx → void','A2.02',0.2),
    ]),
    ('E7.UI-灵力条',[('L3','E7.01','P6','灵力显示','使用TextureProgress节点。value=energy/max*100。Label显示"energy/max"。','@onready var energy_bar: TextureProgress','scripts/ui/EnergyBar.gd','节点 → void','A5.01',0.2)]),
    ('E8.UI-顶部HUD',[
        ('L3','E8.01','P6','双方血条','使用CanvasLayer+TextureProgress。左右各一条。value=hp/max*100。','@onready var p0_hp: TextureProgress','scripts/ui/HUD.gd','节点 → void','A5.01',0.2),
        ('L3','E8.02','P6','计时器','使用Label节点。text=str(ceil(model.time))+"s"。modulate=COLOR_RED if time<=30。','@onready var timer_label: Label','scripts/ui/HUD.gd','节点 → void','A5.02',0.2),
    ]),
    ('E9.出牌交互',[
        ('L3','E9.01','P6','手牌→选目标','func _on_card_pressed(idx): if selected==idx: selected=-1; return。var card=Cards.get_card(hand[idx])。if energy<card.cost: return。selected=idx','func on_card_tap(idx: int) -> void:','scripts/scenes/BattleScene.gd','idx → void','B2.02,B3.05',0.3),
        ('L3','E9.02','P6','格子点击执行','func _on_grid_tapped(gx, gy): if selected<0: return。var card=Cards.get_card(hand[selected])。match card.type: "unit": spawn_unit()。"formation": place_formation()。_: cast_spell()。selected=-1','func on_grid_tap(gx: int, gy: int) -> void:','scripts/scenes/BattleScene.gd','gx+gy → void','C9.01,C5.01,C9.02',0.4),
    ]),
    ('E10.结算场景',[
        ('L3','E10.01','P6','胜负展示','使用Label节点。text="胜利" if winner==0 else "失败"。modulate=COLOR_GREEN or COLOR_RED。','@onready var result_label: Label','scripts/scenes/ResultScene.gd','节点 → void','A5.02',0.2),
        ('L3','E10.02','P6','摧毁度','var r0=round((1-p1.hp/30.0)*100)。var r1=round((1-p0.hp/30.0)*100)。label.text="我方%d%% vs 敌方%d%%" % [r0, r1]','func show_destroy_rate() -> void:','scripts/scenes/ResultScene.gd','void → void','A5.02',0.2),
        ('L3','E10.03','P6','再来一局','func _on_replay_pressed(): SceneManager.switch("battle")。Button信号连接。','func _on_replay_pressed() -> void:','scripts/scenes/ResultScene.gd','void → void','A4.02',0.2),
    ]),
    ('E11.新手引导',[
        ('L3','E11.01','P6','引导1-出牌','高亮第一张牌(AnimationPlayer)+向下箭头(Sprite2D)+Label"点击出兵"→监听到点击后step=2','var step: int = 1','scripts/ui/TutorialGuide.gd','节点 → void','A5.01',0.4),
        ('L3','E11.02','P6','引导2-灵力','高亮灵力条+"灵力不够时等待回复"→await get_tree().create_timer(3.0).timeout→step=3','await get_tree().create_timer(3.0).timeout','scripts/ui/TutorialGuide.gd','节点 → void','A5.01',0.3),
        ('L3','E11.03','P6','引导3-布阵','高亮阵法区格子+"点击布阵拦截"→监听到布阵后step=4','signal formation_placed','scripts/ui/TutorialGuide.gd','节点 → void','A5.01',0.3),
        ('L3','E11.04','P6','引导4-目标','画指向敌方大殿箭头+"摧毁大殿获胜"→await 2秒后引导结束','await get_tree().create_timer(2.0).timeout','scripts/ui/TutorialGuide.gd','节点 → void','A5.01',0.2),
    ]),
]:
    D.append(('L1','','',SC,SN,'','','','','','','','','',''))
    D.append(('L2',mod.split('.')[0],'P6',SC,'',mod,'','','','','','','','V1',''))
    for it in items:
        D.append((it[0],it[1],it[2],SC,'',mod,it[3],it[4],it[5],it[6],it[7],it[8],it[9],'V1','待办'))

# ===== F. 社交系统(V1.5) — 通过平台抽象层调用 =====
SC,SN='F','F.社交系统(V1.5)'
D.append(('L1','','',SC,SN,'','','','','','','','','',''))
for it in [
    ('L3','F1.01','P9','平台登录','PlatformAdapter.login()→await→openid。微信端调用wx.login，Steam端调用SteamAPI，安卓端调用GoogleSignIn。','func login() -> String:','scripts/social/CloudManager.gd','void → openid','I1.01',0.8),
    ('L3','F1.02','P10','云存档','PlatformAdapter.save_data(data)。微信端wx.cloud.database，Steam端SteamCloud，安卓端GooglePlayCloudSave。','func save_data(data: Dictionary) -> void:','scripts/social/CloudManager.gd','data → void','F1.01',0.6),
    ('L3','F2.01','P11','布阵上传','PlatformAdapter.upload("challenges", layout)→challenge_id。跨平台统一接口。','func upload_layout(layout: Dictionary) -> String:','scripts/social/AsyncPvP.gd','layout → challengeId','F1.01',0.8),
    ('L3','F2.02','P11','加载对手','PlatformAdapter.download("challenges", id)→layout→本地AI模拟','func load_opponent(id: String) -> Dictionary:','scripts/social/AsyncPvP.gd','id → layout','F2.01',0.8),
    ('L3','F3.01','P12','好友排行','微信端wx.getOpenDataContext()。Steam端SteamLeaderboards。安卓端GooglePlayLeaderboards。','func render_friend_rank() -> void:','scripts/social/RankManager.gd','void → void','F1.01',0.8),
    ('L3','F3.02','P12','分享','PlatformAdapter.share(title, img)。微信端wx.shareAppMessage，Steam端SteamFriends，安卓端Intent分享。','func share(title: String, img: String) -> void:','scripts/social/ShareManager.gd','title+img → void','—',0.4),
]:
    mod='F1.登录' if 'F1' in it[1] else ('F2.异步PvP' if 'F2' in it[1] else 'F3.排行分享')
    D.append((it[0],it[1],it[2],SC,'',mod,it[3],it[4],it[5],it[6],it[7],it[8],it[9],'V1.5','待办'))

# ===== G. 养成变现(V1.5) =====
SC,SN='G','G.养成变现(V1.5)'
D.append(('L1','','',SC,SN,'','','','','','','','','',''))
for it in [
    ('L3','G1.01','P13','弟子升级','unit.level+=1。unit.hp=base_hp*(1+level*0.1)。unit.atk=base_atk*(1+level*0.08)','func level_up(unit_id: String) -> void:','scripts/game/ProgressionSystem.gd','unitId → void','—',0.8),
    ('L3','G1.02','P13','弟子升星','unit.star+=1。练气→筑基→金丹→元婴。','func star_up(unit_id: String) -> void:','scripts/game/ProgressionSystem.gd','unitId → void','G1.01',0.8),
    ('L3','G2.01','P14','激励广告','PlatformAdapter.show_reward_ad()→await→is_ended→cb()。跨平台广告接口。','func show_reward(cb: Callable) -> void:','scripts/monetize/AdManager.gd','cb → void','I1.03',0.8),
    ('L3','G2.02','P14','内购','PlatformAdapter.purchase(product_id)→await→success→cb()。微信支付/Steam支付/GooglePlay支付。','func purchase(product_id: String, cb: Callable) -> void:','scripts/monetize/IAPManager.gd','productId+cb → void','I1.04',0.8),
]:
    mod='G1.养成' if 'G1' in it[1] else 'G2.变现'
    D.append((it[0],it[1],it[2],SC,'',mod,it[3],it[4],it[5],it[6],it[7],it[8],it[9],'V1.5','待办'))

# ===== H. 实时PvP(V2) =====
SC,SN='H','H.实时PvP(V2)'
D.append(('L1','','',SC,SN,'','','','','','','','','',''))
for it in [
    ('L3','H1.01','P16','WebSocket','class_name NetworkClient extends Node。var ws: WebSocketPeer = WebSocketPeer.new()。ws.connect_to_url(url)。ws.poll()。在_process中轮询。','func connect_to_url(url: String) -> void:','scripts/net/NetworkClient.gd','url → void','—',1.5),
    ('L3','H1.02','P16','断线重连','func _on_closed(): save_model()。reconnect()。ws.send_text(JSON.stringify({type:"reconnect",room_id}))','func reconnect() -> void:','scripts/net/NetworkClient.gd','void → void','H1.01',0.8),
    ('L3','H2.01','P17','操作上报','ws.send_text(JSON.stringify({type:"action",action:{card_id,target,timestamp}}))','func send_action(action: Dictionary) -> void:','scripts/net/SyncManager.gd','action → void','H1.01',0.8),
    ('L3','H2.02','P17','状态接收','func _process(delta): ws.poll()。while ws.get_available_packet_count()>0: var msg=JSON.parse_string(ws.get_packet().get_string_from_utf8())。if msg.type=="state": apply_state(msg.state)','func on_state(state: Dictionary) -> void:','scripts/net/SyncManager.gd','state → void','H2.01',0.8),
    ('L3','H3.01','P18','匹配系统','PlatformAdapter.call_function("match", {elo: elo})→{room_id, opponent_elo}。跨平台匹配。','func match(elo: int) -> Dictionary:','scripts/net/MatchMaker.gd','elo → Dictionary','F1.01',1.2),
    ('L3','H3.02','P18','段位赛','if win: elo+=20。else: elo-=15。rank=elo_to_rank(elo)','func update_rank(win: bool) -> void:','scripts/net/RankSystem.gd','bool → void','—',0.8),
]:
    mod='H1.网络' if 'H1' in it[1] else ('H2.同步' if 'H2' in it[1] else 'H3.匹配')
    D.append((it[0],it[1],it[2],SC,'',mod,it[3],it[4],it[5],it[6],it[7],it[8],it[9],'V2','待办'))

# ===== I. 跨平台导出（新增） =====
SC,SN='I','I.跨平台导出'
for mod,items in [
    ('I1.平台抽象层',[
        ('L3','I1.01','P8','平台检测','class_name PlatformAdapter (autoload)。enum Platform {WECHAT, STEAM, ANDROID, WEB, DESKTOP}。static var current: Platform。func detect()→检测OS.get_name()和Engine.has_feature()','static func detect_platform() -> Platform:','scripts/platform/PlatformAdapter.gd','void → Platform','—',0.5),
        ('L3','I1.02','P8','存储接口','微信端wx.setStorageSync/getStorageSync。Steam端FileAccess+SteamCloud。安卓端OS.get_user_data_dir()文件读写。统一save/load接口。','func save_data(key: String, data: Variant) -> bool:','scripts/platform/PlatformAdapter.gd','key+data → bool','I1.01',0.8),
        ('L3','I1.03','P8','广告接口','微信端wx.createRewardedVideoAd。Steam端无广告(改DLC)。安卓端GoogleAdMob。统一show_reward接口。','func show_reward_ad() -> bool:','scripts/platform/PlatformAdapter.gd','void → bool(看完)','I1.01',0.8),
        ('L3','I1.04','P8','支付接口','微信端wx.requestPayment。Steam端steamworks.purchase。安卓端GooglePlayBilling。统一purchase接口。','func purchase(product_id: String) -> bool:','scripts/platform/PlatformAdapter.gd','productId → bool','I1.01',0.8),
    ]),
    ('I2.微信小游戏导出',[
        ('L3','I2.01','P8','安装导出插件','下载godot_for_minigame插件→放入addons/→Project Settings→Plugins→启用→底部出现Mini Game Export面板','编辑器操作','addons/godot_mini_game/','插件安装','—',0.5),
        ('L3','I2.02','P8','配置导出预设','Project→Export→Add→Web→命名"MiniGame"。配置资源筛选、纹理压缩。插件用--export-pack生成.pck。','编辑器操作','export_presets.cfg','预设配置','I2.01',0.5),
        ('L3','I2.03','P8','微信API适配','MiniGameSDK autoload封装wx.* API。通过PlatformAdapter.current==WECHAT时调用wx接口。插件已处理WXWebAssembly兼容。','#ifdef平台宏','addons/godot_mini_game/MiniGameSDK.gd','适配层','I2.01,I1.01',0.8),
        ('L3','I2.04','P8','分包加载配置','微信主包<4MB限制。配置subpackages：主包=引擎+核心逻辑，分包1=美术资源，分包2=音频。wx.loadSubpackage加载。','JSON配置','subpackages.json','分包配置','I2.02',0.8),
        ('L3','I2.05','P8','微信开发者工具测试','导出→用微信开发者工具打开导出目录→真机预览→调试→上传提审。','工具操作','微信开发者工具','测试上传','I2.04',0.5),
    ]),
    ('I3.Steam导出',[
        ('L3','I3.01','P8','Steamworks集成','下载godot-steam模块→编译GDExtension或使用预编译版→放入addons/→配置steam_appid.txt','编辑器配置','addons/godotsteam/','Steam SDK集成','—',1.0),
        ('L3','I3.02','P8','Steam成就就系统','SteamAchievements.gd。Steam.setAchievement("first_win")。配置成就API in Steamworks后台。','func unlock_achievement(id: String) -> void:','scripts/platform/SteamAchievements.gd','id → void','I3.01',0.5),
        ('L3','I3.03','P8','Steam云存档','SteamCloudFileWrite(name, data)。SteamCloudFileRead(name)→data。自动同步到Steam云。','func cloud_save(key: String, data: PackedByteArray) -> bool:','scripts/platform/SteamCloud.gd','key+data → bool','I3.01',0.5),
        ('L3','I3.04','P8','Steam导出配置','Project→Export→Add→Windows Desktop→配置签名→导出.exe+.pck。macOS同理导出.dmg。','编辑器操作','export_presets.cfg','导出配置','I3.01',0.5),
    ]),
    ('I4.安卓/谷歌商店导出',[
        ('L3','I4.01','P8','Android导出配置','安装Android Build Template→配置keystore→Project→Export→Add→Android→配置包名/权限/图标→导出.aab','编辑器操作','export_presets.cfg','导出配置','—',0.8),
        ('L3','I4.02','P8','触屏适配','确保所有UI使用Control节点锚点自适应。InputEventScreenTouch已自动支持。检查安全区域(DisplayServer.get_display_safe_area())。','func _get_safe_area() -> Rect2i:','scripts/platform/MobileAdapter.gd','void → Rect2i','I4.01',0.5),
        ('L3','I4.03','P8','谷歌支付','集成GooglePlayBilling插件→连接BillingClient→querySkuDetails→launchBillingFlow→onPurchasesUpdated','func google_purchase(sku: String) -> bool:','scripts/platform/GoogleBilling.gd','sku → bool','I4.01',0.8),
        ('L3','I4.04','P8','签名打包上架','生成release keystore→jarsigner签名→zipalign对齐→上传.aab到Google Play Console→填写商品信息→发布','命令行+后台操作','Google Play Console','上架','I4.03',0.5),
    ]),
]:
    D.append(('L1','','',SC,SN,'','','','','','','','','',''))
    D.append(('L2',mod.split('.')[0],'P8',SC,'',mod,'','','','','','','','V1',''))
    for it in items:
        D.append((it[0],it[1],it[2],SC,'',mod,it[3],it[4],it[5],it[6],it[7],it[8],it[9],'V1','待办'))

print(f'Godot版数据: {len(D)}行, L3={len([d for d in D if d[0]=="L3"])}个功能点')
with open('/workspace/_data_godot.json','w') as f:
    json.dump(D,f)
print('已保存到 _data_godot.json')

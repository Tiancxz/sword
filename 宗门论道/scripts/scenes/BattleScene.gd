## ============================================================
## BattleScene.gd - 战斗场景（渲染层 + 交互层）
## ============================================================
## 作用: 连接纯逻辑层(BattleLogic)与渲染层，每帧驱动逻辑并绘制画面。
## 设计: 持有一个 BattleLogic 实例，_process 调 logic.on_update，
##       _draw 分层绘制（背景→棋盘→大殿→单位→阵法→UI）。
##       纯代码绘制（无图片资源），用几何图形+文字表现。
## 坐标系: 竖屏720x1280。棋盘5列x9行，屏幕坐标翻转（玩家在底部）。
## 依赖: BattleLogic, Renderer(颜色常量), InputManager, SceneManager,
##       EventBus, Const, Cards, DeckPresets
## 对应:
##   E1.01 场景进入 - _ready
##   E1.02 场景更新 - _process
##   E1.03 场景渲染(分层) - _draw
##   E1.04 场景退出 - _exit_tree
##   E2.01 山道背景 - _draw_background
##   E2.02 棋盘格子线 - _draw_board_grid
##   E3.01 大殿Sprite - _draw_halls
##   E3.02 大殿血条 - _draw_halls
##   E3.03 受击特效 - _draw_hall_hit_fx
##   E4.01 单位Sprite - _draw_units
##   E4.02 单位血条 - _draw_units
##   E5.01 阵法Sprite - _draw_formations
##   E6.01 手牌显示 - _draw_hand
##   E6.02 点击选中 - _handle_hand_click
##   E7.01 灵力显示 - _draw_energy
##   E8.01 双方血条 - _draw_top_hud
##   E8.02 计时器 - _draw_top_hud
##   E9.01 手牌→选目标 - _input
##   E9.02 格子点击执行 - _handle_board_click
## ============================================================

extends Node2D

# ===== 棋盘布局常量（单路设计）=====
const BOARD_COLS: int = 1                ## 棋盘列数（单路=1，所有单位在一条直线上推进）
const CELL_W: float = 280.0             ## 格子宽度（单路加宽，居中显示）
const CELL_H: float = 95.0              ## 格子高度（像素）
const BOARD_LEFT: float = 220.0         ## 棋盘左边距（居中: (720-280)/2）
const BOARD_TOP: float = 110.0          ## 棋盘顶部（HUD下方）

# ===== UI布局常量 =====
const HAND_Y: float = 1010.0            ## 手牌栏顶部
const HAND_H: float = 200.0             ## 手牌栏高度
const HAND_CARD_W: float = 140.0        ## 单张手牌宽度
const HAND_CARD_H: float = 180.0        ## 单张手牌高度
const HAND_GAP: float = 15.0            ## 手牌间距
const ENERGY_Y: float = 975.0           ## 灵力条Y坐标
const HUD_H: float = 100.0              ## 顶部HUD高度

# ===== 玩家身份 =====
const PLAYER_ID: int = 0                ## 真人玩家=攻方(id=0)
const AI_ID: int = 1                    ## 对手=守方(id=1)

# ===== 逻辑层 =====
var _logic: BattleLogic = null           ## 战斗逻辑实例

# ===== 正式AI（守方决策，D1.01-D1.05）=====
var _ai: AIBrain = null                  ## AI决策实例

# ===== 交互状态 =====
var _selected_hand_idx: int = -1        ## 选中的手牌索引（-1=未选中）

# ===== 大殿受击特效 =====
## {player_id: {timer, alpha}} 受击闪烁计时
var _hall_hit_fx: Dictionary = {}

# ===== 结束界面延迟返回计时（避免误触）=====
var _end_delay: float = 0.0

# ===== 大殿血量追踪（轮询触发受击特效，不依赖事件总线）=====
var _last_hall_hp: Array = [Const.HALL_HP, Const.HALL_HP]


## ============================================================
## E1.01 - 场景进入
## ============================================================

func _ready() -> void:
	# 像素素材用最近邻采样，缩放时不模糊
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	print("[BattleScene] 战斗场景就绪")

	# 创建逻辑层实例
	_logic = BattleLogic.new()

	# 用预设卡组初始化战斗
	# 玩家=攻方用均衡卡组，对手=守方用控制卡组
	_logic.init_battle(DeckPresets.BALANCED, DeckPresets.CONTROL)

	# 创建正式AI（守方），默认普通难度
	_ai = AIBrain.new()
	_ai.setup(_logic, AI_ID, AIBrain.Difficulty.NORMAL)
	add_child(_ai)  ## 挂载为子节点，场景销毁时自动释放

	# 连接事件总线信号（用于受击特效等）
	EventBus.hall_damaged.connect(_on_hall_damaged)
	EventBus.battle_ended.connect(_on_battle_ended)

	# 广播战斗开始
	EventBus.battle_started.emit()


## ============================================================
## E1.02 - 场景更新
## ============================================================

func _process(delta: float) -> void:
	# 1. 驱动战斗逻辑
	_logic.on_update(delta)

	# 2. 正式AI守方决策（D1.01-D1.05）
	if _ai != null:
		_ai.update(delta)

	# 3. 更新受击特效计时
	_update_hit_fx(delta)

	# 4. 结束后延迟计时（防止战斗刚结束就误触返回）
	if _logic.get_state() == "ended":
		_end_delay += delta

	# 5. 轮询大殿血量变化，触发受击特效（E3.03）
	_check_hall_damage()

	# 6. 触发重绘（每帧重绘以反映实时状态）
	queue_redraw()


## 检测大殿血量下降并触发受击闪烁
func _check_hall_damage() -> void:
	var players: Array = _logic.model.get("players", [])
	for pid in range(mini(players.size(), 2)):
		var p: Player = players[pid]
		if not p is Player:
			continue
		if p.hall_hp < int(_last_hall_hp[pid]):
			_hall_hit_fx[pid] = {"timer": 0.5, "alpha": 0.6}
		_last_hall_hp[pid] = p.hall_hp


## ============================================================
## E1.03 - 场景渲染（分层绘制）
## ============================================================

func _draw() -> void:
	# 分层绘制：从下到上
	_draw_background()        ## E2.01 山道背景
	_draw_board_grid()        ## E2.02 棋盘格子线
	_draw_halls()             ## E3.01-E3.03 大殿+血条+特效
	_draw_formations()        ## E5.01 阵法
	_draw_units()             ## E4.01-E4.02 单位+血条
	_draw_top_hud()           ## E8.01-E8.02 顶部HUD
	_draw_energy()            ## E7.01 灵力条
	_draw_hand()              ## E6.01 手牌栏

	# 战斗结束时绘制遮罩提示
	if _logic.get_state() == "ended":
		_draw_end_overlay()


## ============================================================
## E1.04 - 场景退出
## ============================================================

func _exit_tree() -> void:
	# 断开信号，防止场景销毁后回调到已释放对象
	if EventBus.hall_damaged.is_connected(_on_hall_damaged):
		EventBus.hall_damaged.disconnect(_on_hall_damaged)
	if EventBus.battle_ended.is_connected(_on_battle_ended):
		EventBus.battle_ended.disconnect(_on_battle_ended)
	# 清理输入区域（SceneManager.switch也会调，但主动清理更安全）
	InputManager.clear()
	print("[BattleScene] 场景退出，已清理资源")


## ============================================================
## 坐标转换（逻辑坐标 → 屏幕坐标）
## ============================================================

## 棋盘逻辑坐标(grid_x, position_y) → 屏幕像素坐标
## position_y=0(攻方出发/顶部大殿) 显示在屏幕底部，翻转Y轴
func _grid_to_screen(grid_x: int, position_y: float) -> Vector2:
	var screen_x: float = BOARD_LEFT + float(grid_x) * CELL_W + CELL_W * 0.5
	# 翻转：position_y=0 → 屏幕底部；position_y=BOARD_LENGTH-1 → 屏幕顶部
	var flipped_y: float = float(Const.BOARD_LENGTH - 1) - position_y
	var screen_y: float = BOARD_TOP + flipped_y * CELL_H + CELL_H * 0.5
	return Vector2(screen_x, screen_y)


## 屏幕像素坐标 → 棋盘列号（用于点击出牌）
## [return] 列号0~4，越界返回-1
func _screen_to_col(screen_x: float) -> int:
	if screen_x < BOARD_LEFT or screen_x > BOARD_LEFT + float(BOARD_COLS) * CELL_W:
		return -1
	var col: int = int((screen_x - BOARD_LEFT) / CELL_W)
	return clampi(col, 0, BOARD_COLS - 1)


## ============================================================
## 贴图加载（像素风素材，带缓存+缺图回退）
## ============================================================

## 贴图缓存 { 资源路径: Texture2D/null }
var _tex_cache: Dictionary = {}

## 加载素材贴图（缓存，未导入/缺失时返回null）
func _get_art(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_tex_cache[path] = tex
	return tex

## 获取单位贴图（按卡牌ID映射: unit_<card_id>.jpg）
func _get_unit_tex(card_id: String) -> Texture2D:
	if card_id.is_empty():
		return null
	return _get_art("res://assets/art/unit_%s.jpg" % card_id)

## 获取大殿贴图（0=攻方 1=守方）
func _get_hall_tex(player_id: int) -> Texture2D:
	var path: String = "res://assets/art/hall_attacker.jpg" if player_id == 0 \
		else "res://assets/art/hall_defender.jpg"
	return _get_art(path)


## ============================================================
## E2.01 - 山道背景
## ============================================================

func _draw_background() -> void:
	# 全屏深紫黑背景
	draw_rect(Rect2(0, 0, 720, 1280), Renderer.COLOR_BG, true)

	# 山道效果：上下两端渐变暗色（模拟山脉纵深）
	# 顶部山脉（守方区域，暗红色调）
	for i in range(5):
		var alpha: float = 0.15 + float(i) * 0.05
		var rect_y: float = BOARD_TOP + float(i) * CELL_H
		draw_rect(Rect2(BOARD_LEFT, rect_y, float(BOARD_COLS) * CELL_W, CELL_H),
			Color(0.3, 0.1, 0.15, alpha), true)

	# 底部山脉（攻方区域，暗蓝色调）
	for i in range(5):
		var alpha: float = 0.15 + float(i) * 0.05
		var rect_y: float = BOARD_TOP + float(Const.BOARD_LENGTH - 1 - i) * CELL_H
		draw_rect(Rect2(BOARD_LEFT, rect_y, float(BOARD_COLS) * CELL_W, CELL_H),
			Color(0.1, 0.15, 0.3, alpha), true)


## ============================================================
## E2.02 - 棋盘格子线
## ============================================================

func _draw_board_grid() -> void:
	var board_w: float = float(BOARD_COLS) * CELL_W
	var board_h: float = float(Const.BOARD_LENGTH) * CELL_H

	# 棋盘外框
	draw_rect(Rect2(BOARD_LEFT, BOARD_TOP, board_w, board_h),
		Color(0.4, 0.35, 0.2, 0.6), false, 2.0)

	# 竖线
	for col in range(BOARD_COLS + 1):
		var x: float = BOARD_LEFT + float(col) * CELL_W
		draw_line(Vector2(x, BOARD_TOP), Vector2(x, BOARD_TOP + board_h),
			Color(0.3, 0.25, 0.15, 0.5), 1.0)

	# 横线
	for row in range(Const.BOARD_LENGTH + 1):
		var y: float = BOARD_TOP + float(row) * CELL_H
		draw_line(Vector2(BOARD_LEFT, y), Vector2(BOARD_LEFT + board_w, y),
			Color(0.3, 0.25, 0.15, 0.5), 1.0)

	# 中线（双方分界）
	var mid_y: float = BOARD_TOP + float(Const.BOARD_LENGTH) * CELL_H * 0.5
	draw_line(Vector2(BOARD_LEFT, mid_y), Vector2(BOARD_LEFT + board_w, mid_y),
		Color(0.9, 0.8, 0.5, 0.8), 2.0)


## ============================================================
## E3.01-E3.03 - 大殿渲染（Sprite+血条+受击特效）
## ============================================================

func _draw_halls() -> void:
	var font = Renderer.get_font()
	var players: Array = _logic.model.get("players", [])
	for player in players:
		if not player is Player:
			continue
		# 大殿位置：攻方在 position_y=0（屏幕底部），守方在 position_y=BOARD_LENGTH-1（屏幕顶部）
		var hall_pos_y: float = 0.0 if player.id == 0 else float(Const.BOARD_LENGTH - 1)
		var screen_pos: Vector2 = _grid_to_screen(0, hall_pos_y)  ## 大殿居中在单路(列0)

		# E3.03 受击特效：闪烁红色遮罩
		var hit_alpha: float = 0.0
		if _hall_hit_fx.has(player.id):
			hit_alpha = float(_hall_hit_fx[player.id].get("alpha", 0.0))

		# E3.01 大殿贴图（像素素材，等比居中显示）
		var hall_size: float = CELL_H * 0.8
		var hall_tex: Texture2D = _get_hall_tex(player.id)
		var hall_rect: Rect2

		if hall_tex != null:
			hall_rect = Rect2(screen_pos.x - hall_size * 0.5, screen_pos.y - hall_size * 0.5,
				hall_size, hall_size)
			draw_texture_rect(hall_tex, hall_rect, false)
			draw_rect(hall_rect, Renderer.COLOR_GOLD, false, 2.0)
		else:
			# 素材未导入时回退为色块矩形
			var hall_w: float = float(BOARD_COLS - 1) * CELL_W + CELL_W
			hall_rect = Rect2(screen_pos.x - hall_w * 0.5, screen_pos.y - CELL_H * 0.4, hall_w, CELL_H * 0.8)
			var base_color: Color = Color(0.3, 0.4, 0.7, 0.9) if player.id == 0 else Color(0.7, 0.3, 0.3, 0.9)
			draw_rect(hall_rect, base_color, true)
			draw_rect(hall_rect, Renderer.COLOR_GOLD, false, 2.0)

		# 受击闪烁（覆盖在贴图上）
		if hit_alpha > 0.0:
			draw_rect(hall_rect, Color(1, 0.2, 0.2, hit_alpha), true)

		# 大殿名称（贴图内下方，黑描边保证可读）
		var label: String = "攻方大殿" if player.id == 0 else "守方大殿"
		if player.id == PLAYER_ID:
			label += "(你)"
		if font:
			var name_y: float = hall_rect.position.y + hall_rect.size.y - 6.0
			draw_string_outline(font, Vector2(screen_pos.x, name_y), label,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 20, 4, Color(0, 0, 0, 0.85))
			draw_string(font, Vector2(screen_pos.x, name_y), label,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Renderer.COLOR_GOLD)

		# E3.02 大殿血条（大殿下方）
		var bar_y: float = hall_rect.position.y + hall_rect.size.y + 5
		var bar_w: float = CELL_W * 0.8
		var hp_ratio: float = player.get_hall_hp_ratio()
		_draw_bar(Vector2(screen_pos.x - bar_w * 0.5, bar_y), bar_w, 16, hp_ratio,
			Renderer.COLOR_RED, Renderer.COLOR_GREEN)

		# 血量数值
		if font:
			var hp_text: String = "%d/%d" % [player.hall_hp, Const.HALL_HP]
			draw_string(font, Vector2(screen_pos.x - 40, bar_y + 18), hp_text,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Renderer.COLOR_WHITE)

		# 护盾显示
		if player.hall_shield > 0:
			if font:
				draw_string(font, Vector2(screen_pos.x + 60, screen_pos.y - 5),
					"护盾:%d" % player.hall_shield, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Renderer.COLOR_BLUE)


## 受击特效更新
func _update_hit_fx(delta: float) -> void:
	for pid in _hall_hit_fx.keys():
		var fx: Dictionary = _hall_hit_fx[pid]
		fx["timer"] = float(fx.get("timer", 0.0)) - delta
		fx["alpha"] = maxf(0.0, float(fx.get("alpha", 0.0)) - delta * 2.0)
		if float(fx.get("timer", 0.0)) <= 0.0:
			_hall_hit_fx.erase(pid)


## 大殿受伤回调（触发闪烁特效）
func _on_hall_damaged(player_id: int, _damage: int) -> void:
	_hall_hit_fx[player_id] = {"timer": 0.5, "alpha": 0.6}


## ============================================================
## E4.01-E4.02 - 单位渲染（Sprite+血条）
## ============================================================

func _draw_units() -> void:
	var font = Renderer.get_font()
	for unit in _logic.get_units():
		if not unit is Unit or unit.is_dead():
			continue

		var screen_pos: Vector2 = _grid_to_screen(unit.grid_x, unit.position_y)

		# 贴图尺寸：普通52，精英64（radius用于光环/血条/方向线定位）
		var radius: float = 22.0
		var sprite_size: float = 52.0
		if unit.unit_type == "elite":
			radius = 28.0
			sprite_size = 64.0
			# 精英金色光环
			draw_circle(screen_pos, radius + 4, Color(0.9, 0.8, 0.5, 0.3))

		# 眩晕判定（贴图变暗 / 回退色块变暗）
		var stunned: bool = unit.get_effective_speed() == 0.0 and unit.base_speed > 0.0

		# E4.01 单位贴图（像素素材，按卡牌ID映射）
		var unit_tex: Texture2D = _get_unit_tex(unit.card_id)
		if unit_tex != null:
			var sprite_rect: Rect2 = Rect2(screen_pos.x - sprite_size * 0.5,
				screen_pos.y - sprite_size * 0.5, sprite_size, sprite_size)
			var modulate: Color = Color(0.55, 0.55, 0.55) if stunned else Color.WHITE
			draw_texture_rect(unit_tex, sprite_rect, false, modulate)
			draw_rect(sprite_rect, Renderer.COLOR_WHITE, false, 1.0)
		else:
			# 素材未导入时回退为色块圆形
			var body_color: Color = Renderer.COLOR_BLUE
			if unit.owner == 1:
				body_color = Renderer.COLOR_RED
			if unit.unit_type == "elite":
				body_color = Renderer.COLOR_GOLD
			if stunned:
				body_color = body_color.darkened(0.4)
			draw_circle(screen_pos, radius, body_color)
			draw_arc(screen_pos, radius, 0, TAU, 32, Renderer.COLOR_WHITE, 1.5)

		# 远程单位画一个小三角标识方向
		if unit.attack_range > 0:
			var dir: Vector2 = Vector2(0, float(unit.facing)) * (radius + 8)
			draw_line(screen_pos, screen_pos + dir, Renderer.COLOR_WHITE, 2.0)

		# E4.02 单位血条（头顶）
		var hp_ratio: float = float(unit.hp) / float(unit.max_hp) if unit.max_hp > 0 else 0.0
		var bar_w: float = 40.0
		_draw_bar(Vector2(screen_pos.x - bar_w * 0.5, screen_pos.y - radius - 12),
			bar_w, 5, hp_ratio, Renderer.COLOR_RED, Renderer.COLOR_GREEN)

		# 名称+属性 一行显示（贴图下方，黑描边保证可读）
		if font:
			var info_text: String = ""
			if unit.unit_name.length() > 0:
				info_text = unit.unit_name.substr(0, 2) + " "
			info_text += "%d/%d" % [unit.atk, unit.hp]
			draw_string_outline(font, Vector2(screen_pos.x, screen_pos.y + radius + 18), info_text,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 15, 4, Color(0, 0, 0, 0.85))
			draw_string(font, Vector2(screen_pos.x, screen_pos.y + radius + 18), info_text,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 15, Renderer.COLOR_WHITE)


## ============================================================
## E5.01 - 阵法渲染（Sprite）
## ============================================================

func _draw_formations() -> void:
	var font = Renderer.get_font()
	for f in _logic.get_formations():
		if not f is Formation or f.is_dead():
			continue

		var screen_pos: Vector2 = _grid_to_screen(f.grid_x, f.position_y)

		# 阵法形状：菱形（区别于圆形单位）
		var size: float = 30.0
		var color: Color = Color(0.6, 0.2, 0.6, 0.85) if f.owner == 1 else Color(0.2, 0.6, 0.6, 0.85)
		# 沉默状态变灰
		if not f.is_active:
			color = Color(0.4, 0.4, 0.4, 0.7)

		# 画菱形（4个顶点）
		var pts: PackedVector2Array = [
			Vector2(screen_pos.x, screen_pos.y - size),        ## 上
			Vector2(screen_pos.x + size, screen_pos.y),        ## 右
			Vector2(screen_pos.x, screen_pos.y + size),        ## 下
			Vector2(screen_pos.x - size, screen_pos.y),        ## 左
		]
		draw_colored_polygon(pts, color)
		# 边框
		for i in range(4):
			draw_line(pts[i], pts[(i + 1) % 4], Renderer.COLOR_GOLD, 1.5)

		# 阵法名称（首字）
		if font and f.formation_name.length() > 0:
			var short_name: String = f.formation_name.substr(0, 2)
			draw_string(font, Vector2(screen_pos.x - 16, screen_pos.y + 7), short_name,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 17, Renderer.COLOR_WHITE)

		# 阵法血条
		var hp_ratio: float = f.get_hp_ratio()
		_draw_bar(Vector2(screen_pos.x - 25, screen_pos.y - size - 10),
			50, 5, hp_ratio, Renderer.COLOR_RED, Renderer.COLOR_GREEN)

		# 攻击范围标识（虚线圈）
		if f.attack_range > 1 and f.is_active:
			var range_r: float = (float(f.attack_range) + 1) * CELL_H * 0.5
			draw_arc(screen_pos, range_r, 0, TAU, 32, Color(0.9, 0.5, 0.2, 0.3), 1.0)


## ============================================================
## E8.01-E8.02 - 顶部HUD（双方血条+计时器）
## ============================================================

func _draw_top_hud() -> void:
	var font = Renderer.get_font()
	var players: Array = _logic.model.get("players", [])

	# HUD背景条
	draw_rect(Rect2(0, 0, 720, HUD_H), Color(0.05, 0.04, 0.08, 0.9), true)
	draw_line(Vector2(0, HUD_H), Vector2(720, HUD_H), Renderer.COLOR_GOLD, 2.0)

	# 左侧：攻方(玩家)信息
	if players.size() > 0 and players[0] is Player:
		var p0: Player = players[0]
		# 血条
		_draw_bar(Vector2(20, 25), 280, 20, p0.get_hall_hp_ratio(),
			Renderer.COLOR_RED, Renderer.COLOR_GREEN)
		if font:
			draw_string(font, Vector2(20, 22), "攻方(你)",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Renderer.COLOR_BLUE)
			draw_string(font, Vector2(20, 58), "HP: %d/%d" % [p0.hall_hp, Const.HALL_HP],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Renderer.COLOR_WHITE)
			# 灵力数值
			draw_string(font, Vector2(200, 58), "灵力: %d/%d" % [p0.energy, p0.energy_max],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Renderer.COLOR_BLUE)

	# 右侧：守方(对手)信息
	if players.size() > 1 and players[1] is Player:
		var p1: Player = players[1]
		_draw_bar(Vector2(420, 25), 280, 20, p1.get_hall_hp_ratio(),
			Renderer.COLOR_RED, Renderer.COLOR_GREEN)
		if font:
			draw_string(font, Vector2(700, 22), "守方(敌)",
				HORIZONTAL_ALIGNMENT_RIGHT, -1, 22, Renderer.COLOR_RED)
			draw_string(font, Vector2(700, 58), "HP: %d/%d" % [p1.hall_hp, Const.HALL_HP],
				HORIZONTAL_ALIGNMENT_RIGHT, -1, 18, Renderer.COLOR_WHITE)

	# E8.02 中央计时器
	var time_left: float = _logic.get_time()
	var mins: int = int(time_left) / 60
	var secs: int = int(time_left) % 60
	var time_text: String = "%d:%02d" % [mins, secs]
	var state: String = _logic.get_state()
	var time_color: Color = Renderer.COLOR_WHITE
	if state == "overtime":
		time_color = Color(1, 0.5, 0.2)  ## 加时赛橙色
		time_text = "加时 " + time_text
	if font:
		draw_string(font, Vector2(360, 50), time_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 28, time_color)


## ============================================================
## E7.01 - 灵力条（玩家底部）
## ============================================================

func _draw_energy() -> void:
	var font = Renderer.get_font()
	var players: Array = _logic.model.get("players", [])
	if players.size() <= PLAYER_ID or not players[PLAYER_ID] is Player:
		return

	var player: Player = players[PLAYER_ID]
	var ratio: float = player.get_energy_ratio()

	# 灵力条
	var bar_x: float = 40.0
	var bar_w: float = 640.0
	var bar_h: float = 18.0
	_draw_bar(Vector2(bar_x, ENERGY_Y), bar_w, bar_h, ratio,
		Renderer.COLOR_DARK, Renderer.COLOR_BLUE)

	# 灵力数值
	if font:
		var text: String = "灵力 %d / %d" % [player.energy, player.energy_max]
		draw_string(font, Vector2(360, ENERGY_Y - 6), text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Renderer.COLOR_WHITE)

	# 灵力槽刻度（每个槽位标记）
	for i in range(player.energy_max):
		var tick_x: float = bar_x + bar_w * (float(i + 1) / float(player.energy_max))
		draw_line(Vector2(tick_x, ENERGY_Y), Vector2(tick_x, ENERGY_Y + bar_h),
			Color(0, 0, 0, 0.5), 1.0)


## ============================================================
## E6.01 - 手牌栏显示
## ============================================================

func _draw_hand() -> void:
	var font = Renderer.get_font()
	var hand: Array[String] = _logic.get_hand(PLAYER_ID)

	# 手牌栏背景
	draw_rect(Rect2(0, HAND_Y, 720, HAND_H), Color(0.05, 0.04, 0.08, 0.92), true)
	draw_line(Vector2(0, HAND_Y), Vector2(720, HAND_Y), Renderer.COLOR_GOLD, 2.0)

	# 居中排列手牌
	var total_w: float = float(hand.size()) * HAND_CARD_W + float(maxi(0, hand.size() - 1)) * HAND_GAP
	var start_x: float = (720.0 - total_w) * 0.5

	for i in range(hand.size()):
		var card_id: String = hand[i]
		var card: Dictionary = Cards.get_card(card_id)
		if card.is_empty():
			continue

		var card_x: float = start_x + float(i) * (HAND_CARD_W + HAND_GAP)
		var card_y: float = HAND_Y + 10.0
		var card_rect: Rect2 = Rect2(card_x, card_y, HAND_CARD_W, HAND_CARD_H)

		# 是否可出（灵力够）
		var playable: bool = player_can_afford(i)

		# 卡牌背景色（按类型）
		var bg_color: Color = Renderer.COLOR_PANEL
		match card.get("type", ""):
			"unit", "elite":
				bg_color = Color(0.15, 0.25, 0.45, 0.92)  ## 蓝色（单位）
			"formation":
				bg_color = Color(0.25, 0.15, 0.35, 0.92)  ## 紫色（阵法）
			"spell":
				bg_color = Color(0.4, 0.3, 0.1, 0.92)     ## 金棕（法术）

		if not playable:
			bg_color = bg_color.darkened(0.5)  ## 不可出时变暗

		# 选中高亮
		if i == _selected_hand_idx:
			bg_color = bg_color.lightened(0.3)

		# 绘制卡牌
		draw_rect(card_rect, bg_color, true)
		var border_color: Color = Renderer.COLOR_GOLD if playable else Renderer.COLOR_GRAY
		var border_w: float = 3.0 if i == _selected_hand_idx else 1.5
		draw_rect(card_rect, border_color, false, border_w)

		# 卡牌内容
		if font:
			# 名称
			draw_string(font, Vector2(card_x + 8, card_y + 28),
				card.get("name", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
				Renderer.COLOR_WHITE)
			# 类型
			var type_text: String = ""
			match card.get("type", ""):
				"unit": type_text = "单位"
				"elite": type_text = "精英"
				"formation": type_text = "阵法"
				"spell": type_text = "法术"
			draw_string(font, Vector2(card_x + 8, card_y + 54),
				type_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Renderer.COLOR_GRAY)
			# 特性
			draw_string(font, Vector2(card_x + 8, card_y + 80),
				card.get("trait", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				Color(0.7, 0.7, 0.7))
			# 属性（HP/ATK）
			var hp_val: int = int(card.get("hp", 0))
			var atk_val: int = int(card.get("atk", 0))
			if hp_val > 0 or atk_val > 0:
				draw_string(font, Vector2(card_x + 8, card_y + 108),
					"HP:%d  ATK:%d" % [hp_val, atk_val],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Renderer.COLOR_WHITE)
			# 费用（左下角，大字）
			var cost_color: Color = Renderer.COLOR_BLUE if playable else Renderer.COLOR_RED
			draw_string(font, Vector2(card_x + 8, card_y + HAND_CARD_H - 12),
				"灵力 %d" % int(card.get("cost", 0)),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20, cost_color)

	# 手牌栏提示文字
	if hand.is_empty() and font:
		draw_string(font, Vector2(360, HAND_Y + 100), "无手牌（等待补牌...）",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Renderer.COLOR_GRAY)

	# 操作提示
	if font:
		var hint: String = "点击手牌选中 → 点击棋盘出牌"
		if _selected_hand_idx >= 0:
			hint = "已选中手牌，点击棋盘放置（法术直接点任意位置施放）"
		draw_string(font, Vector2(360, HAND_Y + HAND_H - 10), hint,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Renderer.COLOR_GOLD)


## 判断玩家手牌是否负担得起
func player_can_afford(hand_idx: int) -> bool:
	var hand: Array[String] = _logic.get_hand(PLAYER_ID)
	if hand_idx < 0 or hand_idx >= hand.size():
		return false
	var card: Dictionary = Cards.get_card(hand[hand_idx])
	if card.is_empty():
		return false
	return _logic.get_energy(PLAYER_ID) >= int(card.get("cost", 0))


## ============================================================
## E9.01-E9.02 - 出牌交互（点击处理）
## ============================================================

func _input(event: InputEvent) -> void:
	var pos: Vector2 = Vector2.ZERO
	var is_press: bool = false

	# 鼠标点击
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		is_press = event.pressed
	# 触屏点击
	elif event is InputEventScreenTouch:
		pos = event.position
		is_press = event.pressed

	if not is_press:
		return

	# 战斗结束不响应出牌
	if _logic.get_state() == "ended":
		return

	# E6.02 优先处理手牌点击
	if _handle_hand_click(pos):
		get_viewport().set_input_as_handled()
		return

	# E9.02 棋盘点击出牌
	if _handle_board_click(pos):
		get_viewport().set_input_as_handled()


## 处理手牌点击（选中/取消选中）
## [return] true=点击命中手牌区
func _handle_hand_click(pos: Vector2) -> bool:
	if pos.y < HAND_Y or pos.y > HAND_Y + HAND_H:
		return false

	var hand: Array[String] = _logic.get_hand(PLAYER_ID)
	if hand.is_empty():
		return false

	# 计算手牌区域
	var total_w: float = float(hand.size()) * HAND_CARD_W + float(maxi(0, hand.size() - 1)) * HAND_GAP
	var start_x: float = (720.0 - total_w) * 0.5

	for i in range(hand.size()):
		var card_x: float = start_x + float(i) * (HAND_CARD_W + HAND_GAP)
		var card_rect: Rect2 = Rect2(card_x, HAND_Y + 10.0, HAND_CARD_W, HAND_CARD_H)
		if card_rect.has_point(pos):
			# 重复点击取消选中
			if _selected_hand_idx == i:
				_selected_hand_idx = -1
				EventBus.card_selected.emit(-1)
			else:
				_selected_hand_idx = i
				EventBus.card_selected.emit(i)
				print("[BattleScene] 选中手牌: %s" % hand[i])
			return true

	# 点击手牌区空白处取消选中
	_selected_hand_idx = -1
	EventBus.card_selected.emit(-1)
	return true


## 处理棋盘点击出牌
## [return] true=成功出牌或消耗了点击
func _handle_board_click(pos: Vector2) -> bool:
	if _selected_hand_idx < 0:
		return false

	var hand: Array[String] = _logic.get_hand(PLAYER_ID)
	if _selected_hand_idx >= hand.size():
		_selected_hand_idx = -1
		return false

	var card_id: String = hand[_selected_hand_idx]
	var card: Dictionary = Cards.get_card(card_id)
	var card_type: String = card.get("type", "")

	# 法术卡：点击任意位置直接施放（SpellSystem自动选目标）
	if card_type == "spell":
		var ok: bool = _logic.play_card(PLAYER_ID, _selected_hand_idx, 0, null)
		if ok:
			print("[BattleScene] 玩家施放法术: %s" % card.get("name", ""))
		_selected_hand_idx = -1
		return true

	# 单位/阵法卡：单路模式下点击棋盘区域直接出在列0
	if pos.y < BOARD_TOP or pos.y > HAND_Y:
		return false  # 点击非棋盘区，不处理

	# 单路设计：只有1列，点击棋盘任意位置都出在列0
	var col: int = 0

	var ok: bool = _logic.play_card(PLAYER_ID, _selected_hand_idx, col, null)
	if ok:
		print("[BattleScene] 玩家出牌: %s" % card.get("name", ""))
		EventBus.card_played.emit(card_id, pos, PLAYER_ID)
	else:
		print("[BattleScene] 出牌失败（灵力不足或冷却中）")

	_selected_hand_idx = -1
	EventBus.card_selected.emit(-1)
	return true


## ============================================================
## 战斗结束处理
## ============================================================

func _on_battle_ended(winner: int) -> void:
	print("[BattleScene] 战斗结束，胜者: 玩家%d" % winner)


## 绘制结束遮罩
## E10.01 胜负展示 / E10.02 摧毁度 / E10.03 再来一局
func _draw_end_overlay() -> void:
	var font = Renderer.get_font()
	# 半透明遮罩
	draw_rect(Rect2(0, 0, 720, 1280), Color(0, 0, 0, 0.75), true)

	var winner: int = _logic.get_winner()
	var result_text: String = ""
	var result_color: Color = Renderer.COLOR_GOLD
	if winner == PLAYER_ID:
		result_text = "胜  利"
		result_color = Renderer.COLOR_GREEN
	elif winner == AI_ID:
		result_text = "失  败"
		result_color = Renderer.COLOR_RED
	else:
		result_text = "平  局"
		result_color = Renderer.COLOR_WHITE

	if font:
		# E10.01 胜负标题
		draw_string(font, Vector2(360, 460), result_text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 72, result_color)

		# E10.02 摧毁度（双方大殿剩余血量百分比）
		var players: Array = _logic.model.get("players", [])
		if players.size() >= 2:
			var p0: Player = players[0]
			var p1: Player = players[1]
			var dmg0: int = Const.HALL_HP - p1.hall_hp  ## 攻方对守方造成的摧毁
			var dmg1: int = Const.HALL_HP - p0.hall_hp  ## 守方对攻方造成的摧毁
			draw_string(font, Vector2(360, 540),
				"摧毁敌方大殿: %d/%d" % [dmg0, Const.HALL_HP],
				HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Renderer.COLOR_BLUE)
			draw_string(font, Vector2(360, 575),
				"己方大殿损失: %d/%d" % [dmg1, Const.HALL_HP],
				HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Renderer.COLOR_RED)

		# E10.03 延迟1秒后显示按钮提示（防误触）
		if _end_delay > 1.0:
			# 再来一局按钮区域
			var btn_rect: Rect2 = Rect2(210, 680, 300, 70)
			draw_rect(btn_rect, Color(0.2, 0.5, 0.3, 0.9), true)
			draw_rect(btn_rect, Renderer.COLOR_GREEN, false, 2.0)
			draw_string(font, Vector2(360, 725), "再来一局",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 28, Renderer.COLOR_WHITE)

			# 返回主菜单按钮区域
			var btn2_rect: Rect2 = Rect2(210, 780, 300, 70)
			draw_rect(btn2_rect, Color(0.3, 0.2, 0.15, 0.9), true)
			draw_rect(btn2_rect, Renderer.COLOR_GOLD, false, 2.0)
			draw_string(font, Vector2(360, 825), "返回主菜单",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 28, Renderer.COLOR_WHITE)


## 通用血条绘制（背景色+前景色）
func _draw_bar(pos: Vector2, w: float, h: float, ratio: float, bg_color: Color, fg_color: Color) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	draw_rect(Rect2(pos.x, pos.y, w, h), bg_color, true)
	var fg_w: float = w * ratio
	if fg_w > 0:
		draw_rect(Rect2(pos.x, pos.y, fg_w, h), fg_color, true)
	draw_rect(Rect2(pos.x, pos.y, w, h), Renderer.COLOR_WHITE, false, 1.0)


## 结束界面点击处理（延迟1秒后响应，防误触）
## E10.03 再来一局 / 返回主菜单
func _unhandled_input(event: InputEvent) -> void:
	if _logic.get_state() != "ended":
		return
	if _end_delay < 1.0:
		return
	var pos: Vector2 = Vector2.ZERO
	var is_press: bool = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		is_press = event.pressed
	elif event is InputEventScreenTouch:
		pos = event.position
		is_press = event.pressed
	if not is_press:
		return

	# 再来一局按钮 (210,680,300,70)
	var btn1: Rect2 = Rect2(210, 680, 300, 70)
	if btn1.has_point(pos):
		_restart_battle()
		return
	# 返回主菜单按钮 (210,780,300,70)
	var btn2: Rect2 = Rect2(210, 780, 300, 70)
	if btn2.has_point(pos):
		SceneManager.switch("main")
		return


## 重新开始一局战斗（重置逻辑层与AI状态）
func _restart_battle() -> void:
	_logic.init_battle(DeckPresets.BALANCED, DeckPresets.CONTROL)
	if _ai != null:
		_ai.reset()
	_selected_hand_idx = -1
	_end_delay = 0.0
	_hall_hit_fx.clear()
	_last_hall_hp = [Const.HALL_HP, Const.HALL_HP]
	EventBus.battle_started.emit()
	print("[BattleScene] 重新开始战斗")

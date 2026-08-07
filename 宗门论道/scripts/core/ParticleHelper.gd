## ============================================================
## ParticleHelper.gd - 粒子特效辅助工具
## ============================================================
## 作用: 统一创建和触发CPUParticles2D粒子特效。
## 设计: 工具类，提供setup配置和emit触发两个核心方法。
##       粒子使用CPUParticles2D（兼容性最佳，微信小游戏可用）。
## 扩展: 新增粒子类型时，在create()中添加预设即可。
## ============================================================

extends Node

# ===== 粒子预设类型枚举 =====
enum Preset {
	HIT,        ## 击中特效（红色火花）
	HEAL,       ## 治疗特效（绿色光点）
	CAST,       ## 施法特效（蓝色螺旋）
	DEATH,      ## 死亡特效（灰色消散）
	SPAWN,      ## 召唤特效（金色爆发）
}

## 粒子对象池（复用，避免频繁创建/销毁）
var _pool: Array[CPUParticles2D] = []


## ============================================================
## 粒子配置
## ============================================================

## 配置粒子节点
## [param particles] 要配置的CPUParticles2D节点
## [param count] 粒子数量
## [param color] 粒子颜色
func setup_particles(particles: CPUParticles2D, count: int, color: Color) -> void:
	particles.amount = count
	particles.color = color
	# 基础配置
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.lifetime = 0.6
	particles.direction = Vector2(0, -1)
	particles.spread = 60.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 150.0
	particles.gravity = Vector2(0, 200)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0


## 按预设类型配置粒子
## [param particles] 粒子节点
## [param preset] 预设类型
func setup_preset(particles: CPUParticles2D, preset: Preset) -> void:
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.emitting = false

	match preset:
		Preset.HIT:
			particles.amount = 12
			particles.color = Color(1.0, 0.4, 0.2, 1)
			particles.lifetime = 0.4
			particles.direction = Vector2(0, -1)
			particles.spread = 90.0
			particles.initial_velocity_min = 100.0
			particles.initial_velocity_max = 200.0
			particles.gravity = Vector2(0, 300)
			particles.scale_amount_min = 2.0
			particles.scale_amount_max = 5.0
		Preset.HEAL:
			particles.amount = 16
			particles.color = Color(0.3, 1.0, 0.4, 1)
			particles.lifetime = 0.8
			particles.direction = Vector2(0, 1)
			particles.spread = 30.0
			particles.initial_velocity_min = 40.0
			particles.initial_velocity_max = 80.0
			particles.gravity = Vector2(0, -50)
			particles.scale_amount_min = 3.0
			particles.scale_amount_max = 6.0
		Preset.CAST:
			particles.amount = 20
			particles.color = Color(0.4, 0.6, 1.0, 1)
			particles.lifetime = 0.6
			particles.direction = Vector2(0, -1)
			particles.spread = 180.0
			particles.initial_velocity_min = 30.0
			particles.initial_velocity_max = 80.0
			particles.gravity = Vector2.ZERO
			particles.scale_amount_min = 2.0
			particles.scale_amount_max = 4.0
		Preset.DEATH:
			particles.amount = 24
			particles.color = Color(0.6, 0.6, 0.6, 1)
			particles.lifetime = 1.0
			particles.direction = Vector2(0, -1)
			particles.spread = 180.0
			particles.initial_velocity_min = 50.0
			particles.initial_velocity_max = 120.0
			particles.gravity = Vector2(0, 100)
			particles.scale_amount_min = 3.0
			particles.scale_amount_max = 8.0
		Preset.SPAWN:
			particles.amount = 18
			particles.color = Color(1.0, 0.85, 0.3, 1)
			particles.lifetime = 0.5
			particles.direction = Vector2(0, 1)
			particles.spread = 180.0
			particles.initial_velocity_min = 80.0
			particles.initial_velocity_max = 160.0
			particles.gravity = Vector2(0, -100)
			particles.scale_amount_min = 2.0
			particles.scale_amount_max = 5.0


## ============================================================
## 粒子触发
## ============================================================

## 在指定位置触发粒子
## [param particles] 粒子节点
## [param x] 世界坐标X
## [param y] 世界坐标Y
func emit(particles: CPUParticles2D, x: float, y: float) -> void:
	particles.position = Vector2(x, y)
	particles.emitting = true
	# one_shot模式会自动停止，无需手动处理


## 按预设触发粒子（一步到位）
## [param parent] 粒子挂载的父节点
## [param x] 世界坐标X
## [param y] 世界坐标Y
## [param preset] 预设类型
## [return] 创建的粒子节点（用完可自动回收）
func emit_preset(parent: Node, x: float, y: float, preset: Preset) -> CPUParticles2D:
	var p = _get_from_pool()
	setup_preset(p, preset)
	parent.add_child(p)
	emit(p, x, y)
	# 延迟回收
	_recycle_timer(p, p.lifetime + 0.5)
	return p


## ============================================================
## 对象池
## ============================================================

## 从池中获取粒子节点（无可用则新建）
func _get_from_pool() -> CPUParticles2D:
	for p in _pool:
		if not p.emitting and p.get_parent() == null:
			return p
	# 池空，新建
	var p = CPUParticles2D.new()
	_pool.append(p)
	return p


## 延迟回收粒子到对象池
func _recycle_timer(particles: CPUParticles2D, delay: float) -> void:
	var timer = get_tree().create_timer(delay)
	timer.timeout.connect(func():
		particles.emitting = false
		if particles.get_parent():
			particles.get_parent().remove_child(particles)
	)

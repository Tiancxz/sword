## ============================================================
## Const.gd - 全局常量
## ============================================================
## 作用: 存储游戏核心数值常量，所有模块通过 Const.xxx 引用。
## 设计: 纯静态常量类，不可实例化。
## 来源: 数值与《5.数值配置》表一致。
## ============================================================

class_name Const

# ===== 棋盘 =====
const BOARD_LENGTH: int = 9          ## 棋盘长度（格），双方大殿间隔
const HALL_HP: int = 30              ## 大殿血量，到0即败

# ===== 灵力系统 =====
const ENERGY_START: int = 5          ## 开局初始灵力
const ENERGY_REGEN: float = 2.8      ## 灵力回复速率（秒/点）
const ENERGY_MAX_CAP: int = 10       ## 灵力上限（5→10，每30秒+1）
const ENERGY_CAP_GROWTH_INTERVAL: float = 30.0  ## 灵力上限增长间隔（秒）

# ===== 对局时间 =====
const BATTLE_TIME: float = 120.0     ## 对局时长（秒），到时比血量
const OVERTIME_TIME: float = 60.0    ## 加时赛时长（秒），平局加时比灵力

# ===== 手牌系统 =====
const HAND_MAX: int = 4              ## 手牌上限，满不抽
const DRAW_DELAY: float = 2.0        ## 出牌后自动补牌延迟（秒）
const INIT_HAND_SIZE: int = 3        ## 开局初始手牌数

# ===== 战斗数值 =====
const ELDER_SKILL_INTERVAL: float = 5.0  ## 长老技能间隔（秒）
const FORMATION_COOLDOWN: float = 8.0    ## 阵法冷却（秒）
const BASE_SPEED: float = 1.0            ## 移速基准（格/秒）
const SLOW_AMOUNT: float = 0.5           ## 减速效果（格/秒）
const ATTACK_INTERVAL: float = 1.0       ## 攻击间隔（秒）
const MAX_SHIELD: int = 3                ## 护盾最大层数

# ===== AI =====
const AI_THINK_INTERVAL: float = 3.0     ## AI思考间隔（秒）

# ===== 卡组 =====
const DECK_SIZE: int = 8                 ## 卡组张数

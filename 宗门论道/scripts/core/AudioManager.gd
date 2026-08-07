## ============================================================
## AudioManager.gd - 音频管理器
## ============================================================
## 作用: 统一管理BGM(背景音乐)和SFX(音效)的播放。
## 设计: autoload单例，内部维护两个AudioStreamPlayer:
##       - BGM播放器: 循环播放，同时只播一首
##       - SFX播放器: 单次播放，可叠加多个
## 扩展: 可添加音量渐变、音频总线控制、多SFX通道等。
## ============================================================

extends Node

## BGM播放器（循环背景音乐）
var _bgm_player: AudioStreamPlayer = null

## SFX播放器池（支持多音效同时播放）
var _sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_CHANNELS: int = 8

## BGM音量（0.0~1.0）
var bgm_volume: float = 0.6

## SFX音量（0.0~1.0）
var sfx_volume: float = 0.8

## 是否静音
var muted: bool = false

## 当前BGM路径
var _current_bgm_path: String = ""


## ============================================================
## 初始化
## ============================================================

func _ready() -> void:
	# 创建BGM播放器
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	add_child(_bgm_player)
	_bgm_player.volume_db = linear_to_db(bgm_volume)

	# 创建SFX播放器池
	for i in range(MAX_SFX_CHANNELS):
		var sfx = AudioStreamPlayer.new()
		sfx.name = "SFXPlayer_%d" % i
		add_child(sfx)
		sfx.volume_db = linear_to_db(sfx_volume)
		_sfx_players.append(sfx)

	print("[AudioManager] 初始化完成 (BGM + %d SFX通道)" % MAX_SFX_CHANNELS)


## ============================================================
## BGM 播放
## ============================================================

## 播放BGM（循环）
## [param stream_path] 音频资源路径（如"res://assets/audio/bgm_battle.ogg"）
func play_bgm(stream_path: String) -> void:
	if muted:
		return
	# 相同BGM不重复播放
	if stream_path == _current_bgm_path and _bgm_player.playing:
		return

	# 加载音频资源
	var stream = load(stream_path)
	if stream == null:
		push_error("[AudioManager] 无法加载BGM: " + stream_path)
		return

	# 设置循环（OGG/MP3等支持循环的格式）
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamMP3:
		stream.loop = true

	_bgm_player.stream = stream
	_bgm_player.volume_db = linear_to_db(bgm_volume)
	_bgm_player.play()
	_current_bgm_path = stream_path
	print("[AudioManager] 播放BGM: ", stream_path)


## 停止BGM
func stop_bgm() -> void:
	_bgm_player.stop()
	_current_bgm_path = ""


## 暂停BGM
func pause_bgm() -> void:
	_bgm_player.stream_paused = true


## 恢复BGM
func resume_bgm() -> void:
	_bgm_player.stream_paused = false


## ============================================================
## SFX 播放
## ============================================================

## 播放音效（单次，不阻塞）
## [param stream_path] 音频资源路径
func play_sfx(stream_path: String) -> void:
	if muted:
		return

	# 加载音频资源
	var stream = load(stream_path)
	if stream == null:
		push_error("[AudioManager] 无法加载SFX: " + stream_path)
		return

	# 找一个空闲的SFX通道
	var player = _get_idle_sfx_player()
	if player == null:
		# 所有通道忙，复用第一个
		player = _sfx_players[0]

	player.stream = stream
	player.volume_db = linear_to_db(sfx_volume)
	player.play()


## 停止所有音效
func stop_all_sfx() -> void:
	for sfx in _sfx_players:
		sfx.stop()


## 获取空闲的SFX播放器
## [return] 空闲的AudioStreamPlayer，无空闲返回null
func _get_idle_sfx_player() -> AudioStreamPlayer:
	for sfx in _sfx_players:
		if not sfx.playing:
			return sfx
	return null


## ============================================================
## 音量控制
## ============================================================

## 设置BGM音量
## [param volume] 0.0~1.0
func set_bgm_volume(volume: float) -> void:
	bgm_volume = clampf(volume, 0.0, 1.0)
	_bgm_player.volume_db = linear_to_db(bgm_volume)


## 设置SFX音量
## [param volume] 0.0~1.0
func set_sfx_volume(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)
	for sfx in _sfx_players:
		sfx.volume_db = linear_to_db(sfx_volume)


## 静音/取消静音
func set_muted(is_muted: bool) -> void:
	muted = is_muted
	if muted:
		_bgm_player.stream_paused = true
		stop_all_sfx()
	else:
		_bgm_player.stream_paused = false


## ============================================================
## 工具函数
## ============================================================

## 线性音量转分贝
func linear_to_db(volume: float) -> float:
	if volume <= 0.0:
		return -80.0  # 几乎静音
	return 20.0 * log(volume) / log(10.0)

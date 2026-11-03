extends MainGameSubManager
class_name DaySunsManagner
## 天降阳光管理器

## 当前实际天降周期，单位为百分之一游戏秒；除以100后交给原生计时器。
@export var production_interval: float
@export var curr_sun_sum_value := 0
## 本局累计新种双子向日葵次数；移除植物不扣减，轮间存档保留，新开局从0开始。
var twin_sunflower_plantings: int = 0

@onready var production_timer: Timer = $ProductionTimer

@export var sun_x_min : float = 50
@export var sun_x_max : float = 750

@export var sun_y_min : float = 130
@export var sun_y_max : float = 550

@export var sun_y_ori : float = -40

@export var sun_y_speed : float = 200


func _ready():
	production_timer.timeout.connect(_on_production_timer_timeout)

func init_manager() -> void:
	pass

func start_day_sun():
	# 如果计时器是暂停状态，取消暂停
	if production_timer.paused:
		production_timer.paused = false

	if production_timer.is_stopped():
		change_production_interval()
		production_timer.start(production_interval/100)

func pause_day_sun():
	production_timer.paused = true

## 每次新种双子永久累计2.5秒减时；当前已抽取周期同步缩短，保留已等待进度和暂停状态。
func register_twin_sunflower_planting() -> void:
	twin_sunflower_plantings += 1
	if production_timer.is_stopped():
		return
	# 当前周期总长与已等待时间，均为游戏秒，不重新抽取随机间隔。
	var old_period: float = production_interval / 100.0
	var elapsed: float = maxf(old_period - production_timer.time_left, 0.0)
	# 下限约束整个周期；已经等待的时间不重新开始，也不延长原本即将到点的任务。
	var new_period: float = maxf(old_period - 2.5, 1.0)
	if new_period >= old_period:
		return
	# 原生Timer使用正时长；缩短后已到期的任务在下一次计时更新中触发。
	var was_paused: bool = production_timer.paused
	production_interval = new_period * 100.0
	production_timer.start(maxf(new_period - elapsed, 0.001))
	production_timer.paused = was_paused


func _on_production_timer_timeout():
	spawn_sun()
	change_production_interval()

## 创建阳光
func spawn_sun():
	var new_sun = SceneRegistry.SUN.instantiate()
	if new_sun is Sun:
		Global.main_game.suns.add_child(new_sun)
		curr_sun_sum_value += new_sun.sun_value
		# 控制阳光下落
		# 出生移动绑定阳光，离场后不再由全局场景树继续运行回调。
		new_sun.spawn_sun_tween = new_sun.create_tween()
		new_sun.position = Vector2(randf_range(sun_x_min, sun_x_max), sun_y_ori)
		var target_y = randf_range(sun_y_min, sun_y_max)
		var distance = float(abs(target_y - sun_y_ori))
		var duration = distance / sun_y_speed
		new_sun.spawn_sun_tween.tween_property(new_sun, "position:y", target_y, duration)

		new_sun.spawn_sun_tween.finished.connect(new_sun.on_sun_tween_finished)



func change_production_interval():
	var A : float = 10 * curr_sun_sum_value + 425
		# 下次天降阳光时间
	if A<950:
		production_interval = (A + randf_range(0,274))
	else:
		production_interval = 950 + randf_range(0,274)

	# 在原随机周期上扣除本局累计种植奖励，最终完整周期至少1游戏秒。
	production_interval = maxf(100.0, production_interval - 250.0 * twin_sunflower_plantings)
	production_timer.start(production_interval/100)

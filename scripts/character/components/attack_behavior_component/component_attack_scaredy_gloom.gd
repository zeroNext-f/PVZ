## 胆小菇专用无攻击动画调度：沿用忧郁菇四个脉冲时点，第四次结束后通知植物施毒。
extends AttackComponentGloom
class_name AttackComponentScaredyGloom

## 一轮完整结束只发送一次；休眠、禁用或死亡中断不发送。
signal round_finished
## 原忧郁菇的四个攻击动作时点，单位为正常倍率下的游戏秒。
const PULSE_TIMES: Array[float] = [0.666667, 1.0, 1.34211, 1.66667]
## 当前是否存在已启动但尚未完成的轮次。
var _round_active: bool = false
## 本轮累计动作时间，与个体速度和全局游戏速度同步。
var _round_elapsed: float = 0.0
## 下一个待结算脉冲的索引。
var _next_pulse: int = 0

## [param is_enable_factor] 本次禁用原因；中断轮次不补发剩余伤害或轮末剧毒。
func disable_component(is_enable_factor:E_IsEnableFactor):
	_round_active = false
	super(is_enable_factor)

## 原2秒SpeedTimer到期后只启动逻辑轮次，不请求AnimationTree播放攻击动作。
func _on_bullet_attack_cd_timer_timeout() -> void:
	if _round_active or not is_enabling or not is_attack_res or owner.is_death:
		return
	_round_active = true
	_round_elapsed = 0.0
	_next_pulse = 0

## [param delta] 游戏帧秒数；高倍速跨越多个关键点时逐个补齐，完整四次后施毒一次。
func _process(delta: float) -> void:
	if not _round_active:
		return
	if not is_enabling or owner.is_death or owner.is_queued_for_deletion():
		_round_active = false
		return
	_round_elapsed += delta * GlobalUtils.get_dic_product(owner.influence_speed_factors)
	while _next_pulse < PULSE_TIMES.size() and _round_elapsed >= PULSE_TIMES[_next_pulse]:
		_next_pulse += 1
		attack_once()
		if owner.is_death or owner.is_queued_for_deletion() or not is_enabling:
			_round_active = false
			return
	if _next_pulse == PULSE_TIMES.size():
		_round_active = false
		round_finished.emit()

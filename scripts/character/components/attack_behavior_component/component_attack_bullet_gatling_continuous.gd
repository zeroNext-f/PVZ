## 机枪射手专属持续连发：不启动攻击间隔计时器，目标存在时由循环射击动画持续驱动出弹。
extends AttackComponentBulletBase
class_name AttackComponentBulletGatlingContinuous

## 是否已经进入循环射击，避免重复检测信号将动画不断重置到开头。
var _continuous_firing:bool = false
## 待机与循环射击的切换权重；不用OneShot请求，避免循环仍受单次播放结束条件控制。
const CONTINUOUS_BLEND_PARAMETER:StringName = &"parameters/ContinuousFire/blend_amount"

## 检测到有效目标后直接启动循环动画，不调用父类的随机等待或1.5秒攻击周期。
func attack_start() -> void:
	if _continuous_firing or not is_enabling or not is_attack_res or owner.is_death:
		return
	_continuous_firing = true
	signal_change_is_attack.emit(true)
	animation_tree.set(CONTINUOUS_BLEND_PARAMETER, 1.0)

## 无目标或组件禁用时立刻退出射击动画，不让已启动的循环继续空射。
func attack_end() -> void:
	signal_change_is_attack.emit(false)
	if not _continuous_firing:
		return
	_continuous_firing = false
	animation_tree.set(CONTINUOUS_BLEND_PARAMETER, 0.0)

## [param _speed_product] 角色动作倍率；出弹随角色动画推进，专属组件不再维护攻击间隔计时。
func owner_update_speed(_speed_product:float) -> void:
	pass

## 循环动画发射事件；每次同步重查检测区域，防止目标离开后的物理缓存导致多射。
func _shoot_bullet() -> void:
	if not _continuous_firing or not is_enabling or not is_attack_res or owner.is_death:
		return
	if not is_instance_valid(detect_component.update_first_enemy()):
		update_is_attack_factors(false, E_IsAttackFactors.RayEnemy)
		return
	super()

## 大喷菇检测到目标后立即启动首次攻击动画，保留原发射事件和一次性死亡流程。
extends AttackComponentBulletBase

## 取消首次随机等待；只在计时器尚未运行时请求攻击，不因重复检测重启动画。
func attack_start():
	# 父类初始化第一轮计时器；记录启动前状态，避免重复信号再次请求发射。
	var starts_first_attack: bool = bullet_attack_cd_timer.is_stopped()
	super()
	if starts_first_attack:
		# 不等待随机首轮计时，动画仍在原0.833333秒关键帧创建子弹。
		bullet_attack_cd_timer.start_scaled(attack_cd)
		_on_bullet_attack_cd_timer_timeout()

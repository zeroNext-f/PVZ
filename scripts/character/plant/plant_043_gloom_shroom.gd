## 忧郁菇保留原四连发动画，周身脉冲与粒子交由和胆小菇共用的攻击组件执行。
extends Plant000Base
class_name Plant043GloomShroom

## 与胆小菇复用同一攻击实现，避免两株伤害及粒子处理分叉。
@onready var attack_component: AttackComponentGloom = $AttackComponent

## 正常出战时同步个体与异常速度因素到攻击调度计时器。
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(attack_component.owner_update_speed)

## 原动画的四个方法事件调用一次共用脉冲，不改变忧郁菇原攻击节奏。
func attack_once():
	attack_component.attack_once()

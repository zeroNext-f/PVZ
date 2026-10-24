## 小喷菇：无主动攻击，啃食致死时使凶手中毒；铲除沿用基础植物流程。
extends Plant000Base
class_name Plant009Puff

## [param attack_value] 本次啃食伤害；[param attack_zombie] 只在本次啃食致死时接受剧毒的攻击者。
## 其他伤害、铲除与搬运不经过此入口，不触发中毒。
func be_zombie_eat(attack_value:int, attack_zombie:Zombie000Base):
	if is_death or hp_component.is_death or is_queued_for_deletion():
		return
	super(attack_value, attack_zombie)
	if attack_value > 0 and hp_component.is_death and is_instance_valid(attack_zombie):
		attack_zombie.be_poisoned()

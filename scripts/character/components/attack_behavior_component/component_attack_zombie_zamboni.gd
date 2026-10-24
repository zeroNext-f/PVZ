extends AttackComponentBase
class_name AttackComponentZombieZamboni

## 开始攻击
func attack_start():
	crush_detected_target(detect_component, owner)

## 共用即时碾压；[param detection] 提供当前目标，[param attacker] 提供反制调用对象。
static func crush_detected_target(detection:DetectComponent, attacker:Character000Base) -> void:
	if is_instance_valid(detection.enemy_can_be_attacked):
		detection.enemy_can_be_attacked.be_flattened_from_enemy(attacker)
	elif is_instance_valid(detection.brain):
		# 脑子沿用原有碾压入口。
		var brain:BrainOnZombieMode = detection.brain
		brain.be_flattened()

## 结束攻击
func attack_end():
	pass

## 修改速度
func owner_update_speed(_speed_product:float):
	pass

## 潜水僵尸专属植物筛选；沿用原碰撞范围、同行、阵营和梯子判定。
extends DetectComponent

## [param enemy] 当前重叠角色；潜水开始后，植物仅允许末格或缠绕水草，魅惑后的僵尸目标仍沿用共用规则。
func _judge_enemy_is_can_be_attack(enemy:Character000Base) -> bool:
	if not super._judge_enemy_is_can_be_attack(enemy):
		return false
	if enemy is Plant000Base:
		return (owner as Zombie012Snorkle).can_attack_pool_plant(enemy)
	return true

## [param plant] 检测到的植物；保护层重选后再次筛选，防止用合格检测对象绕过末格限制。
func get_first_be_hit_plant_in_cell(plant:Plant000Base) -> Plant000Base:
	# 保护层仍使用原选择顺序，但最终实际啃食对象也必须合格。
	var target:Plant000Base = super.get_first_be_hit_plant_in_cell(plant)
	return target if is_instance_valid(target) and (owner as Zombie012Snorkle).can_attack_pool_plant(target) else null

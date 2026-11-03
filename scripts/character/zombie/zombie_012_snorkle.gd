## 小体型潜水僵尸；潜入后仅攻击末格植物或水草，水草在水下啃食而不浮起。
extends Zombie000Base
class_name Zombie012Snorkle

## 本次游泳是否已完成首次潜入；浮起啃食期间仍保留植物筛选，离开泳池才清除。
var has_started_diving:bool = false
## 正在水下啃食水草；保持游泳姿态与水下受击分类，但普通攻击组件仍持续扣血。
var is_eating_kelp_underwater: bool = false

## [param plant] 待攻击植物；水中潜入后仅放行缠绕水草和本行世界X最小格内的植物。
func can_attack_pool_plant(plant:Plant000Base) -> bool:
	if not is_instance_valid(plant) or plant.is_death or plant.is_queued_for_deletion():
		return false
	if not is_swimming or not has_started_diving:
		return true
	if plant.plant_type == CharacterRegistry.PlantType.P020TangleKelp:
		return true
	# 以实际格子位置查找靠小推车的一格，不使用编辑器的倒序编号。
	var cells:Array = Global.main_game.plant_cell_manager.all_plant_cells[lane]
	# 保存世界X最小的实际格子，不能把场外或其他行的植物当作末格。
	var last_cell:PlantCell = null
	for cell:PlantCell in cells:
		if last_cell == null or cell.global_position.x < last_cell.global_position.x:
			last_cell = cell
	return is_instance_valid(last_cell) and plant.plant_cell == last_cell

## 角色死亡
func character_death():
	super()
	## 不在泳池中，死亡后消失
	if not is_swimming:
		await get_tree().create_timer(2.0, false).timeout
		queue_free()


## [param value] 原攻击检测结果；只有从攻击退出时等待下潜动画，空水路不能因重复无目标信号永久停步。
func change_is_attack(value:bool):
	# 保存切换前的攻击状态，区分真正结束攻击和重复无目标通知。
	var was_attacking:bool = is_attack
	# 记录上一次是否无需浮起，失去水草后直接恢复游泳，不能等待不存在的下潜动画。
	var was_underwater: bool = is_eating_kelp_underwater
	var target: Character000Base = attack_component.detect_component.enemy_can_be_attacked
	is_eating_kelp_underwater = value and is_swimming and has_started_diving \
		and is_instance_valid(target) and target is Plant020Tanglekelp
	is_attack = value
	if is_eating_kelp_underwater:
		curr_be_attack_status = E_BeAttackStatusZombie.IsDownPool
		move_component.update_move_factor(false, MoveComponent.E_MoveFactor.IsAnimGap)
	elif was_underwater:
		move_component.update_move_factor(false, MoveComponent.E_MoveFactor.IsAnimGap)
	elif was_attacking and not value and is_swimming:
		move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsAnimGap)

## [param value] 是否接触泳池；离水时解除潜水植物限制，保留原正常状态、影子与横向位置修正。
func change_is_swimming(value:bool):
	is_swimming = value
	## 如果是跳入泳池
	if is_swimming:
		curr_be_attack_status = E_BeAttackStatusZombie.IsJumpInPool

	## 如果是离开泳池
	else:
		is_eating_kelp_underwater = false
		has_started_diving = false
		curr_be_attack_status = E_BeAttackStatusZombie.IsNorm
		shadow.visible = true
		position.x -= 40
		move_component.update_move_factor(false, MoveComponent.E_MoveFactor.IsAnimGap)
	attack_component.detect_component.need_judge = true

#region 动画调用
## 跳入泳池动画结束
func jump_to_pool_end():
	has_started_diving = true
	move_component.update_move_mode(MoveComponent.E_MoveMode.Speed)
	curr_be_attack_status = E_BeAttackStatusZombie.IsDownPool
	shadow.visible = false
	move_component.update_move_factor(false, MoveComponent.E_MoveFactor.IsAnimGap)
	attack_component.detect_component.need_judge = true

## 普通末格目标的浮起关键帧；中途改为水草目标时仍保持水下受击分类。
func up_to_attack_start():
	if is_eating_kelp_underwater:
		return
	curr_be_attack_status = E_BeAttackStatusZombie.IsNorm

## 攻击完植物后潜入水里
func down_to_pool():
	curr_be_attack_status = E_BeAttackStatusZombie.IsDownPool
	move_component.update_move_factor(false, MoveComponent.E_MoveFactor.IsAnimGap)
	attack_component.detect_component.need_judge = true

#endregion

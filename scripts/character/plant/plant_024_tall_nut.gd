## 坚果的紫卡升级，可同格补种；免疫行进碾压并反推，实际阻跳与反碾压消耗本体生命。
extends Plant000Base
class_name Plant024TallNut

## 本体破损阶段组件，阈值由场景显式配置。
@onready var hp_stage_change_component: HpStageChangeComponent = $HpStageChangeComponent

## 连接原生命损失通知，保留破损贴图更新。
func ready_norm_signal_connect():
	super()
	## 连接信号
	hp_component.signal_hp_loss.connect(hp_stage_change_component.judge_body_change)

## [param _zombie] 真正完成阻跳的僵尸；只在越障被中止或跳杆被阻断时消耗720生命。
func on_jump_blocked(_zombie: Zombie000Base) -> void:
	if is_death or hp_component.is_death or is_queued_for_deletion():
		return
	body.body_light()
	hp_component.Hp_loss(720, BulletRegistry.AttackMode.Real, true, false)

## [param character] 行进碾压的发起者；反推1.5实际格并扣1800本体生命，不走强制压扁。
func be_crushed_from_enemy(character: Character000Base) -> void:
	if is_death or hp_component.is_death or is_queued_for_deletion():
		return
	# 仅普通僵尸具备行进反推；同次推退期间的重复检测不再次扣血。
	var zombie: Zombie000Base = character as Zombie000Base
	if not is_instance_valid(zombie):
		return
	# 当前行真实格中心，计算相邻格距而不是固定屏幕像素。
	var cells: Array = Global.main_game.plant_cell_manager.all_plant_cells[lane]
	var pitch: float = INF
	# 取与本格最近的另一个格中心；泳池标准行存在多个实际格子。
	for cell: PlantCell in cells:
		if cell != plant_cell:
			pitch = minf(pitch, absf(cell.global_position.x - plant_cell.global_position.x))
	if not is_finite(pitch) or pitch <= 0.0:
		return
	if zombie.start_tall_nut_repulse(pitch * 1.5):
		body.body_light()
		hp_component.Hp_loss(1800, BulletRegistry.AttackMode.Real, true, false)

## [param area] 进入阻跳范围的区域；仅普通僵尸具有跳跃阻挡属性，僵王和非角色区域直接跳过。
func _on_area_2d_stop_jump_area_entered(area: Area2D) -> void:
	# 安全转换，避免僵王受击框进入范围时被强制赋给普通僵尸类型。
	var zombie := area.owner as Zombie000Base
	if not is_instance_valid(zombie) or zombie.is_death or zombie.is_queued_for_deletion():
		return
	if zombie.lane == lane and zombie.is_trigger_tall_nut_stop_jump:
		zombie.jump_be_stop(self)


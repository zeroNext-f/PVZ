## 高生命水草阻挡潜水僵尸；主动排除潜水/海豚，其他正常目标触发一次整格清除。
extends Plant000Base
class_name Plant020Tanglekelp

## 独立整格清除组件，可波及潜水、海豚及水下目标，只显示水花。
@onready var grap_component: GrapComponent = $GrapComponent
## 查找当前仍处于受击范围内的目标。
@onready var detect_component: DetectComponent = $DetectComponent
## 僵王不会被拖入水中，改为一次穿透伤害；命中后海草仍消耗自身。
@export_range(0, 10000, 1, "or_greater") var boss_attack_value: int = 1800
## 海草是一次性攻击，防止等待动画期间重复响应索敌信号。
var _is_attacking: bool = false


## 正常出战连接一次性抓取触发；水下目标由潜水僵尸专属检测器主动攻击本株。
func ready_norm_signal_connect():
	super()
	detect_component.signal_can_attack.connect(start_grap_zombie)

## 同步确认正常状态目标及所在实际格子后，启动一次抓取；水下目标不消耗水草。
func start_grap_zombie():
	if _is_attacking or is_death:
		return
	# 同步检查范围和受击窗口，避免对已抬头的僵王开始攻击。
	var enemy: Character000Base = detect_component.update_first_enemy()
	if not (enemy is Zombie000Base or enemy is ZB000Base):
		return
	if enemy is Zombie000Base:
		if not GrapComponent.can_grab_target(enemy) or grap_component.get_target_cell(enemy) == null:
			return
	_is_attacking = true
	detect_component.disable_component(ComponentNormBase.E_IsEnableFactor.Attack)
	blink_component.disable_component(ComponentNormBase.E_IsEnableFactor.Attack)
	grap_in_pool(enemy)

## [param target_zombie] 合格主目标；普通僵尸所在格直接清除，仅显示水花，僵王保留1800穿透，主动攻击后消耗水草。
func grap_in_pool(target_zombie:Character000Base):
	if target_zombie is ZB000Base:
		target_zombie.be_attacked_bullet(boss_attack_value, BulletRegistry.AttackMode.Penetration, false, false)
		GrapComponent.show_cell_splash(lane, plant_cell.global_position.x, plant_cell.size.x)
	elif target_zombie is Zombie000Base:
		grap_component.activate_it_to_grap_zombie(target_zombie)
	if not is_death and not is_queued_for_deletion():
		character_death()


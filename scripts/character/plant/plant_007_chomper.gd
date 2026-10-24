## 大嘴花优先啃咬最低权重目标；进入攻击后免疫啃食伤害，咬合后无论命中或落空均死亡。
extends Plant000Base
class_name Plant007Chomper

## 咬合时重新查询范围内目标，避免攻击已抬头的僵王。
@onready var detect_component: DetectComponent = $DetectComponent

## 咀嚼时间计时器
@onready var chew_timer: SpeedTimer = $ChewTimer
## 啃咬伤害
@export var eat_attack:int = 1800
## 保留旧场景的咀嚼参数以兼容资源；当前命中后立即死亡，不再启动咀嚼计时。
@export var eat_CD :float = 5

## 单次攻击结算锁；在扣血前置位，避免同步回调或重复动画事件再次造成伤害。
var _bite_resolved: bool = false
## 首次进入啃咬后锁定啃食免疫，直到本株死亡，不因动画末尾重置 is_bite 而失效。
var _immune_to_zombie_bites:bool = false

@export_group("动画状态")
## 是否啃咬
@export var is_bite := false:
	set(value):
		is_bite = value
		if value:
			_immune_to_zombie_bites = true
## 是否咀嚼
@export var is_chewing = false


func ready_norm() -> void:
	super()
	## 基础咀嚼时间不含倍率，进入角色时同步已有速度因素。
	chew_timer.base_wait_time = eat_CD
	owner_update_speed(GlobalUtils.get_dic_product(influence_speed_factors))

func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(owner_update_speed)
	detect_component.signal_can_attack.connect(change_is_attack.bind(true))

## 速度改变保留剩余咀嚼进度，零速由计时器暂停，避免除零。
func owner_update_speed(speed_product:float):
	chew_timer.set_speed_scale(speed_product)

## 改变是否正在攻击,即攻击范围内是否有敌人
func change_is_attack(is_attack:bool):
	if is_attack and not is_death and not _bite_resolved:
		## 不在咀嚼状态,并且不在啃咬状态
		if not is_chewing and not is_bite:
			is_bite = true

## [param attack_value] 僵尸本次啃食伤害；[param attack_zombie] 啃食者。[br]
## 进入攻击后只拦截啃食扣血，不关闭受击组件，也不改变其他伤害入口。
func be_zombie_eat(attack_value:int, attack_zombie:Zombie000Base):
	if _immune_to_zombie_bites:
		return
	super(attack_value, attack_zombie)


## 咀嚼完成
func _on_chew_timer_timeout() -> void:
	is_chewing = false
#endregion

#region 动画轨道调用
## 吞咽动画结束
func swallow_end():
	if is_instance_valid(detect_component.update_first_enemy()):
		is_bite = true

## 啃咬动画结束
func bite_end():
	is_bite = false
	## 如果没有啃咬到僵尸
	if not is_chewing:
		if is_instance_valid(detect_component.update_first_enemy()):
			is_bite = true
#endregion

## 咬合关键帧重新索敌；小、中体型直接移除，大体型与僵王结算伤害，随后与空咬共用自身死亡流程。
func _eat_zombie():
	if is_death or is_queued_for_deletion() or _bite_resolved:
		return
	SoundManager.play_character_SFX(&"BigChomp")
	# 当前关键帧仍处于攻击范围和受击窗口内的目标。
	var enemy: Character000Base = _select_lowest_weight_enemy()
	# 咬合即消耗本株，空咬也必须锁定，避免重复动画事件再次进入。
	_bite_resolved = true
	if enemy is ZB000Base:
		enemy.be_attacked_bullet(eat_attack, BulletRegistry.AttackMode.Penetration, false, false)
	elif enemy is Zombie000Base:
		if enemy.zombie_body_size in [Zombie000Base.BodySize.Small, Zombie000Base.BodySize.Medium]:
			# 直接清除而不扣血；死亡通知仍更新敌人数、普通成长和自然波次统计，关闭目标亡语。
			enemy.is_can_death_language = false
			enemy.character_death()
			enemy.queue_free()
		else:
			# 大体型仍使用原本的 1800 基础穿透伤害及其共用受伤结算。
			enemy.be_chomper_eat(eat_attack)
	chew_timer.stop()
	character_death()


## 从当前合格目标中选择出怪权重最低者；同权重按受击框 X 坐标选择靠前者。[br]
## 普通自然波次使用管理器已计算的当前权重；无权重的特殊角色排在已定义权重的角色之后。
func _select_lowest_weight_enemy() -> Character000Base:
	# 默认读取公共权重；非自然出怪模式也能获得同一角色的基础优先级。
	var weights: Dictionary = CharacterRegistry.ZombieSpawnWeights
	if is_instance_valid(Global.main_game):
		weights = Global.main_game.zombie_manager.zombie_wave_manager.zombie_wave_create_manager.zombie_weights
	# 当前最佳目标及其权重，INF 代表尚无定义权重的普通僵尸。
	var selected: Character000Base = null
	var selected_weight: float = INF
	# 检测组件已经筛选行号、状态和僵王受击窗口，并对目标去重。
	for candidate: Character000Base in detect_component.get_all_enemy_can_be_attacked():
		# 特殊角色不参与自然权重池时使用最低优先级，不伪造其权重数值。
		var weight: float = INF
		if candidate is Zombie000Base and weights.has(candidate.zombie_type):
			weight = float(weights[candidate.zombie_type])
		if selected == null or weight < selected_weight:
			selected = candidate
			selected_weight = weight
		elif weight == selected_weight \
			and candidate.hurt_box_component.global_position.x < selected.hurt_box_component.global_position.x:
			selected = candidate
	return selected

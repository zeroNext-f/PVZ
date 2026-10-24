## 忧郁菇与胆小菇共用的周身脉冲攻击；动画事件发起一次范围穿透伤害及原忧郁菇粒子。
extends AttackComponentBulletBase
class_name AttackComponentGloom

## 同级的四组喷雾粒子，场景共用同一个独立特效资源。
@onready var _clouds: Node2D = $"../AllBullet_FX"
## 当前脉冲轮换使用的粒子组编号，四组独立播放避免相邻喷发重启前一组。
var _cloud_index: int = 0
## 每个目标每次脉冲的基础穿透伤害，保持忧郁菇原数值。
const PULSE_DAMAGE: int = 20

## 动画调用一次脉冲：沿用忧郁菇粒子随机数量与范围内角色去重，不创建飞行子弹。
func attack_once() -> void:
	# 当前脉冲使用的独立粒子组。
	var group: Node2D = _clouds.get_child(_cloud_index) as Node2D
	# 八方向粒子仅负责表现，不把八个方向算成八次命中。
	for particles: GPUParticles2D in group.get_children():
		particles.amount_ratio = [0.6, 0.8, 1.0].pick_random()
		particles.emitting = true
	_cloud_index = wrapi(_cloud_index + 1, 0, _clouds.get_child_count())
	# 每次重新查询当前范围内的全部合格目标，同一角色仅结算一次。
	var enemies: Array[Character000Base] = detect_component.get_all_enemy_can_be_attacked()
	# 上一个目标的伤害可能同步释放后续目标，结算前重新检查引用和死亡状态。
	for enemy: Character000Base in enemies:
		if is_instance_valid(enemy) and not enemy.is_death and not enemy.is_queued_for_deletion():
			enemy.be_attacked_bullet(PULSE_DAMAGE, BulletRegistry.AttackMode.Penetration)

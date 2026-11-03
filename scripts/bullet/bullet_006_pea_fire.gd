## 火焰豌豆共用命中：解冻并施加烧灼；已烧灼目标实际受伤后按烧灼规则向后连锁灰烬。
extends BulletLinear000Base
class_name Bullet006PeaFire

## 火豌豆自身的循环表现动画。
@onready var anim_lib: AnimationPlayer = $Body/AnimLib

## 启动现有火焰循环表现，不额外创建状态音画或计时器。
func _ready() -> void:
	super()
	anim_lib.play(&"ALL_ANIMS")

## [param enemy] 基类确认的命中目标；撞地为空时不附加状态，也不伤害周围目标。[br]
## 解冻先于扣血，防止解冻回调覆盖致死伤害启动的死亡动画速度。
func _attack_enemy(enemy:Character000Base):
	# 先取受击前状态，首次点燃本身不视为已经烧灼后的再次受伤。
	var burning_hit:Dictionary = BurningState.capture_hit(enemy)
	if _can_attack_character(enemy):
		prepare_fire_hit(enemy)
	super(enemy)
	BurningState.finish_hit(burning_hit)

## [param enemy] 已通过命中资格检查的目标；烧灼字段共用入口负责先解除寒冰，不在此结算伤害。
static func prepare_fire_hit(enemy:Character000Base) -> void:
	if not is_instance_valid(enemy):
		return
	enemy.has_burning_placeholder = true

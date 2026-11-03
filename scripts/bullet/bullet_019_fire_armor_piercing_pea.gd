## 火焰破甲原弹40伤害并解冻/烧灼；分裂弹20伤害且仅保留火焰外观，均沿用原破甲命中与单代分裂规则。
extends Bullet018ArmorPiercingPea
class_name Bullet019FireArmorPiercingPea

## 现有火焰循环播放器，视觉与火焰豌豆一致。
@onready var anim_lib:AnimationPlayer = $Body/AnimLib
## 分裂弹的基础直接伤害，不继承火焰原弹的40伤害；仍跳过一类防具。
const SPLIT_ATTACK_VALUE:int = 20

## 分裂任务及过火转换均在入树前设置can_split；据此区分分裂弹，仅复用火焰视觉。
func _ready() -> void:
	if not can_split:
		attack_value = SPLIT_ATTACK_VALUE
	super()
	anim_lib.play(&"ALL_ANIMS")

## [param enemy] 已命中的目标；只有原弹解冻和设置烧灼，分裂弹只走普通破甲伤害入口。
func _attack_enemy(enemy:Character000Base):
	# 仅原弹具有火焰属性，只有火焰外观的分裂弹不触发烧灼连锁。
	var burning_hit:Dictionary = BurningState.capture_hit(enemy) if can_split else {}
	if can_split and _can_attack_character(enemy):
		Bullet006PeaFire.prepare_fire_hit(enemy)
	super(enemy)
	BurningState.finish_hit(burning_hit)

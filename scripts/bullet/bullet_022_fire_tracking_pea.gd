## 固定80伤害的火焰追踪豌豆，保留追踪轨迹及火焰命中行为。
extends Bullet021TrackingPea
class_name Bullet022FireTrackingPea

## 火焰表现的循环播放器。
@onready var anim_lib:AnimationPlayer = $Body/AnimLib

## 恢复追踪状态并播放原火焰豌豆动画。
func _ready() -> void:
	super()
	anim_lib.play(&"ALL_ANIMS")

## [param enemy] 基类确认的命中目标；沿用火焰豌豆解冻、烧灼及已烧灼受伤后的灰烬连锁。
func _attack_enemy(enemy:Character000Base):
	# 首次点燃本身不视为已烧灼后的再次受伤。
	var burning_hit:Dictionary = BurningState.capture_hit(enemy)
	if _can_attack_character(enemy):
		Bullet006PeaFire.prepare_fire_hit(enemy)
	super(enemy)
	BurningState.finish_hit(burning_hit)
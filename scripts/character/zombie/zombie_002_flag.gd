## 小体型旗帜入场获得十倍移动加速，首次受到正伤害后失去加速并召唤出土普通僵尸。
extends Zombie001Norm
class_name Zombie002Flag

## 旗帜只提升移动位移，不改变啃食伤害或动作播放速度。
const ENTRY_MOVE_MULTIPLIER:float = 10.0
## 首次伤害前为 true；先置 false，避免多颗子弹或范围伤害重复触发。
var has_entry_boost:bool = false


## 只对正常出战实例开启加速，开局预览和图鉴展示不启用。
func _ready() -> void:
	super()
	if character_init_type != E_CharacterInitType.IsNorm:
		return
	has_entry_boost = true
	move_component.ground_move_multiplier = ENTRY_MOVE_MULTIPLIER
	(hp_component as HpComponentZombie).signal_before_damage.connect(_on_first_damage)


## 在扣血之前登记召唤，即使本次伤害致死，普通僵尸仍会生成并出土。
func _on_first_damage() -> void:
	if not has_entry_boost:
		return
	has_entry_boost = false
	move_component.ground_move_multiplier = 1.0
	if is_instance_valid(Global.main_game):
		Global.main_game.zombie_manager.queue_flag_summon(self)

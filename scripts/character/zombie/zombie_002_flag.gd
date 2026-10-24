## 小体型旗帜入场通过十倍动画同步加速行走，首次受伤后恢复动画与移动并召唤出土普通僵尸。
extends Zombie001Norm
class_name Zombie002Flag

## 入场动画与地面行走同步提升的倍率，不额外叠加地面位移倍率。
const ENTRY_MOVE_MULTIPLIER:float = 10.0
## 首次伤害前为 true；先置 false，避免多颗子弹或范围伤害重复触发。
var has_entry_boost:bool = false
## 入场加速前的动画基础速度，首次受伤时原样恢复；角色随机速度与寒冰因素另行叠加。
var _entry_base_animation_speed:float = 1.0


## 只对正常出战实例开启加速，开局预览和图鉴展示不启用。
func _ready() -> void:
	super()
	if character_init_type != E_CharacterInitType.IsNorm:
		return
	has_entry_boost = true
	_entry_base_animation_speed = anim_component.get_animation_origin_speed()
	# Ground 模式直接跟随动画地面轨道，动画十倍即可实现十倍行走，不能再把位移乘十。
	anim_component.set_animation_origin_speed(_entry_base_animation_speed * ENTRY_MOVE_MULTIPLIER)
	anim_component.owner_update_speed(GlobalUtils.get_dic_product(influence_speed_factors))
	(hp_component as HpComponentZombie).signal_before_damage.connect(_on_first_damage)


## 在扣血之前登记召唤，即使本次伤害致死，普通僵尸仍会生成并出土。
func _on_first_damage() -> void:
	if not has_entry_boost:
		return
	has_entry_boost = false
	# 在扣血和死亡动画前恢复基础节奏，同时保留当前随机速度、寒冰减速及冻结因素。
	anim_component.set_animation_origin_speed(_entry_base_animation_speed)
	anim_component.owner_update_speed(GlobalUtils.get_dic_product(influence_speed_factors))
	if is_instance_valid(Global.main_game):
		Global.main_game.zombie_manager.queue_flag_summon(self)

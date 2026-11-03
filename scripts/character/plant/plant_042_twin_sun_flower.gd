## 满成长向日葵免费升级的双头产光植物，每次新种永久缩短本局天降周期。
extends Plant000Base
class_name Plant042TwinSunFlower

## 原公共生产组件，每轮整株发光并同时生成两颗阳光。
@onready var create_sun_component: CreateSunComponent = $CreateSunComponent


## 正式新种实例登记一次天降减时；读档恢复不重复计入种植次数。
func ready_norm() -> void:
	super()
	if not plant_cell.is_restoring_plant_from_save:
		Global.main_game.day_suns_manager.register_twin_sunflower_planting()
	if is_zombie_mode:
		create_sun_component.disable_component(ComponentNormBase.E_IsEnableFactor.GameMode)

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(create_sun_component.owner_update_speed)


## 被僵尸啃食一次特殊效果,魅惑\大蒜\我是僵尸生产阳光
func _be_zombie_eat_once_special(_attack_zombie:Zombie000Base):
	if is_zombie_mode:
		create_sun_component._on_be_eat_once()

## 植物死亡
func character_death():
	if is_zombie_mode:
		create_sun_component._on_character_death()
	super()

## 向日葵每次生产阳光固定成长 100 生命；上限达到 900 后持续发亮。
extends Plant000Base
class_name Plant002SunFlower

@onready var create_sun_component: CreateSunComponent = $CreateSunComponent

## 向日葵的基础本体生命，用于旧存档缺少成长数据时恢复默认值。
const BASE_MAX_HP: int = 300
## 通过生产阳光可达到的生命上限，达到后不再增长或通过生产恢复生命。
const GROWTH_MAX_HP: int = 900
## 每次实际产光固定增加的最大、当前生命，与阳光价值无关。
const GROWTH_PER_PRODUCTION: int = 100
## 满成长向日葵被铲除时额外生成的阳光个数。
const SHOVEL_REFUND_COUNT:int = 6
## 每个额外阳光的价值，合计 6 × 25 = 150。
const SHOVEL_REFUND_SUN_VALUE:int = 25
## 先锁定返还，防止重复铲除回调在死亡完成前再次生成阳光。
var _shovel_refund_paid:bool = false


func ready_norm() -> void:
	super()
	if is_zombie_mode:
		create_sun_component.disable_component(ComponentNormBase.E_IsEnableFactor.GameMode)

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(create_sun_component.owner_update_speed)
	create_sun_component.signal_sun_produced.connect(_on_sun_produced)


## 每次产光固定增加 100 最大、当前血量，成长总量封顶 900。[br]
## [param value] 仅用于确认实际生产了正价值阳光，不参与成长量计算。
func _on_sun_produced(value: int) -> void:
	if is_death or hp_component.is_death or value <= 0 or hp_component.max_hp >= GROWTH_MAX_HP:
		return
	# 最后一次成长仅取剩余空间，保持已受伤害，不会把受伤植物直接恢复满血。
	var growth: int = mini(GROWTH_PER_PRODUCTION, GROWTH_MAX_HP - hp_component.max_hp)
	hp_component.max_hp += growth
	hp_component.curr_hp = mini(hp_component.curr_hp + growth, hp_component.max_hp)
	if hp_component.max_hp == GROWTH_MAX_HP:
		create_sun_component.set_persistent_production_glow(true)


## 仅生命上限为 900 的存活出战向日葵被铲除时返还 150 阳光，当前血量可低于上限。
func be_shovel_kill() -> void:
	if is_death or hp_component.is_death or is_queued_for_deletion():
		return
	if not _shovel_refund_paid and hp_component.max_hp == GROWTH_MAX_HP \
		and character_init_type == E_CharacterInitType.IsNorm \
		and is_instance_valid(Global.main_game) \
		and Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
		_shovel_refund_paid = true
		# 额外返还不属于生产，不发送成长通知，沿用已有阳光抛出和收集表现。
		create_sun_component.spawn_suns(SHOVEL_REFUND_COUNT, SHOVEL_REFUND_SUN_VALUE, false)
	super()


## 将成长后的生命上限写入植物快照，供多轮关卡恢复。
func gat_save_game_data_plant() -> Dictionary:
	# 保留基础植物已有的血量、角色编号和模仿者数据。
	var save_data: Dictionary = super()
	save_data["sunflower_max_hp"] = hp_component.max_hp
	return save_data


## 恢复 [param save_game_data_plant] 中的成长上限后再恢复当前血量，旧档默认 300。
func load_game_data_plant(save_game_data_plant: Dictionary):
	hp_component.max_hp = clampi(int(save_game_data_plant.get("sunflower_max_hp", BASE_MAX_HP)),
		BASE_MAX_HP, GROWTH_MAX_HP)
	super(save_game_data_plant)
	create_sun_component.set_persistent_production_glow(hp_component.max_hp == GROWTH_MAX_HP)


## 被僵尸啃食一次特殊效果,魅惑\大蒜\我是僵尸生产阳光
func _be_zombie_eat_once_special(_attack_zombie:Zombie000Base):
	if is_zombie_mode:
		create_sun_component._on_be_eat_once()

## 植物死亡
func character_death():
	if is_zombie_mode:
		create_sun_component._on_character_death()
	super()

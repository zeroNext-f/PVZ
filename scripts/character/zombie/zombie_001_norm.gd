## 普僵及其继承角色；全模式普通群体成长，路障与铁桶可为最近普通或铁门添加防具。
extends Zombie000Base
class_name Zombie001Norm

@onready var anim_innerarm: Node2D = $Body/BodyCorrect/Anim_innerarm
@onready var zombie_outerarm_upper: Node2D = $Body/BodyCorrect/Zombie_outerarm_upper

@export_group("动画状态")
## 动画状态（僵尸有某类动画有多种）
@export var idle_status := 1
@export var walk_status := 1
@export var death_status := 1

@export_subgroup("最大动画状态")
@export var idle_status_max := 2
@export var walk_status_max := 2
@export var death_status_max := 2

@export_group("普僵初始化精灵节点")
@export var init_sprite_random:Array[Node2D]

## 海草精灵节点
@onready var sprite_seaweed:Array[Sprite2D] = [
	$Body/BodyCorrect/Anim_head/Anim_head1/ZombieSeaweed3,
	$Body/BodyCorrect/Zombie_duckytube/Zombie_duckytube/ZombieSeaweed,
	$Body/BodyCorrect/Zombie_duckytube/Zombie_duckytube/ZombieSeaweed2,
	$Body/BodyCorrect/Zombie_outerarm_upper/Zombie_outerarm_upper/ZombieSeaweed4,
	$Body/BodyCorrect/Anim_head/Anim_head1/ZombieSeaweed2,
]
## 铁桶海草精灵
@onready var sprite_seaweed_bucket: Sprite2D = $Body/BodyCorrect/Anim_bucket/Anim_bucket/ZombieSeaweed4

## 未显式传入关卡参数时，每个其他存活普通僵尸提供的默认本体生命加成。
const ADVENTURE_HEALTH_PER_OTHER: int = 50
## 首次获得同类生命加成前的本体生命上限；-1 表示尚未记录。
var _adventure_base_max_hp: int = -1

## 路障僵尸出生或换装后的生存等待秒数，不受个体随机速度或冰冻倍率缩放。
const ADVENTURE_CONE_DELAY: float = 5.0
## 铁桶僵尸出生或换装后的生存等待秒数，不受个体随机速度或冰冻倍率缩放。
const ADVENTURE_BUCKET_DELAY: float = 10.0
## 每次出生或换装只尝试一次；附近没有存活普僵也会消耗本次机会。
var _adventure_armor_attempted: bool = false
## 单次换装等待计时器，服从游戏暂停和全局游戏速度。
var _adventure_armor_timer: Timer
## 本实例是否已经接受过换装传播；防具被打掉或吸走后也不清除，禁止再次接受传播。
var has_received_adventure_armor:bool = false
## 传播得到的铁桶铁器；铁门仍存在时保留原铁门铁器入口，门消失后再切换至此节点。
var _adventure_bucket_iron:IronNodeArmor


## 按 [param other_count] 个其他存活普通僵尸同步生命上限与当前生命，保留已受伤害。[br]
## [param health_per_other] 本关每名其他普通僵尸的加成，白天前两关为 25，默认 50。
## 只由关卡管理器对普通僵尸类型调用；不重置掉手、掉头阈值，减益可触发原死亡流程。
func update_adventure_group_health(other_count: int, health_per_other:int=ADVENTURE_HEALTH_PER_OTHER) -> void:
	if is_death or hp_component.is_death:
		return
	if _adventure_base_max_hp < 0:
		_adventure_base_max_hp = hp_component.max_hp
	# 本次数量对应的满血值；数量最少为零，不得减低角色原始满血。
	var new_max_hp: int = _adventure_base_max_hp + maxi(other_count, 0) * maxi(health_per_other, 0)
	# 本次生命加成差值，同时应用于当前血量以保留已经承受的伤害。
	var health_delta: int = new_max_hp - hp_component.max_hp
	if health_delta == 0:
		return
	hp_component.max_hp = new_max_hp
	hp_component.curr_hp = maxi(hp_component.curr_hp + health_delta, 0)
	hp_stage_change_component.judge_body_change(hp_component.curr_hp)


## 对所有模式正常出战的路障或铁桶启动一次生存计时，展示角色不启用。
func start_adventure_armor_timer() -> void:
	if character_init_type != E_CharacterInitType.IsNorm or is_death \
		or not is_instance_valid(Global.main_game):
		return
	# 当前角色对应的等待时间；普通僵尸和其他继承角色不启动。
	var delay: float = 0.0
	match zombie_type:
		CharacterRegistry.ZombieType.Z003Cone:
			delay = ADVENTURE_CONE_DELAY
		CharacterRegistry.ZombieType.Z005Bucket:
			delay = ADVENTURE_BUCKET_DELAY
		_:
			return
	_adventure_armor_attempted = false
	if not is_instance_valid(_adventure_armor_timer):
		_adventure_armor_timer = Timer.new()
		_adventure_armor_timer.name = "AdventureArmorTimer"
		_adventure_armor_timer.one_shot = true
		add_child(_adventure_armor_timer)
		_adventure_armor_timer.timeout.connect(_on_adventure_armor_timeout)
	_adventure_armor_timer.start(delay)


## 等待结束时仅存活且仍属于当前战斗的角色可尝试一次换装。
func _on_adventure_armor_timeout() -> void:
	if _adventure_armor_attempted:
		return
	_adventure_armor_attempted = true
	if is_death or hp_component.is_death or is_queued_for_deletion() \
		or not is_instance_valid(Global.main_game) or not Global.main_game.is_ancestor_of(self):
		return
	Global.main_game.zombie_manager.equip_nearest_adventure_norm(self)


## 为普通或铁门添加 [param armor_type] 对应的一类防具，返回是否成功。[br]
## 普通转换编号并继续传播；铁门保留全部原属性与二类防具，不成为传播源；每个目标最多接受一次。
func equip_adventure_armor(armor_type: CharacterRegistry.ZombieType) -> bool:
	if zombie_type not in [CharacterRegistry.ZombieType.Z001Norm, CharacterRegistry.ZombieType.Z007ScreenDoor] \
		or is_death or hp_component.is_death \
		or is_queued_for_deletion() or not is_instance_valid(Global.main_game):
		return false
	if has_received_adventure_armor or (hp_component as HpComponentZombie).curr_hp_armor1 > 0:
		return false
	if armor_type not in [CharacterRegistry.ZombieType.Z003Cone, CharacterRegistry.ZombieType.Z005Bucket]:
		return false
	# 铁门只添加防具，不转换编号、体型、攻击、二类防具或传播身份。
	var preserve_screen_door:bool = zombie_type == CharacterRegistry.ZombieType.Z007ScreenDoor
	# 离树模板只用于读取正式场景的防具资源，不启动其生命周期或计时。
	var template: Zombie001Norm = Global.character_registry.get_zombie_info(
		armor_type, CharacterRegistry.ZombieInfoAttribute.ZombieScenes).instantiate() as Zombie001Norm
	# 正式防具的生命与阶段配置，保留当前角色的本体配置。
	var template_hp: HpComponentZombie = template.get_node("HpComponent") as HpComponentZombie
	var template_stages: HpStageChangeComponent = template.get_node("HpStageChangeComponent") as HpStageChangeComponent
	# 当前实例的僵尸生命组件，只更新防具字段，不改写本体当前或最大生命。
	var current_hp: HpComponentZombie = hp_component as HpComponentZombie
	# 两种防具在共用场景中的表现节点名。
	var armor_name: String = "Anim_cone" if armor_type == CharacterRegistry.ZombieType.Z003Cone else "Anim_bucket"
	# 防具精灵使用模板的原始贴图，后续破损由阶段资源接管。
	var armor_sprite: Sprite2D = get_node("Body/BodyCorrect/" + armor_name + "/" + armor_name) as Sprite2D
	var template_sprite: Sprite2D = template.get_node("Body/BodyCorrect/" + armor_name + "/" + armor_name) as Sprite2D
	armor_sprite.texture = template_sprite.texture
	# 只显示此次添加的帽子，继续使用共用动画中已有的位移与旋转轨道。
	get_node("Body/BodyCorrect/Anim_cone").visible = false
	get_node("Body/BodyCorrect/Anim_bucket").visible = false
	get_node("Body/BodyCorrect/" + armor_name).visible = true
	# 普僵场景没有防具掉落物，复制正式防具场景的节点以支持破甲表现。
	var armor_drop: ZombieDropBase = template.get_node("Body/NodeDrop/Node2D_Arm1_Drop").duplicate() as ZombieDropBase
	get_node("Body/NodeDrop").add_child(armor_drop)
	armor_drop.owner = self
	armor_drop.zombie = self
	hp_stage_change_component.body_change_armor1 = template_stages.body_change_armor1.duplicate()
	hp_stage_change_component.boundary_value_hp_armor1 = [
		int(template_hp.max_hp_armor1 * 2.0 / 3.0) - 1,
		int(template_hp.max_hp_armor1 / 3.0) - 1,
		0,
	]
	hp_stage_change_component.curr_hp_armor1_stage = -1
	current_hp.max_hp_armor1 = template_hp.max_hp_armor1
	current_hp.sfx_be_attack_armor1 = template_hp.sfx_be_attack_armor1
	current_hp.curr_hp_armor1 = current_hp.max_hp_armor1
	current_hp.armor_1_control.visible = true
	if not preserve_screen_door:
		# 普通保留原转换规则，铁门不进入此分支。
		zombie_type = armor_type
		zombie_body_size = template.zombie_body_size
	if armor_type == CharacterRegistry.ZombieType.Z005Bucket:
		# 铁桶铁器独立复制并重新绑定当前角色的精灵，避免引用即将释放的模板。
		var bucket_iron: IronNodeArmor = template.get_node("Body/BodyCorrect/IronNode").duplicate() as IronNodeArmor
		bucket_iron.name = "PropagationBucketIron"
		get_node("Body/BodyCorrect").add_child(bucket_iron)
		bucket_iron.owner = self
		bucket_iron.iron_armor_sprite = bucket_iron.get_node("Anim_bucket") as Sprite2D
		bucket_iron.body_armor_sprite = armor_sprite
		bucket_iron.all_disappear_nodes = [armor_drop]
		_adventure_bucket_iron = bucket_iron
		if not preserve_screen_door or current_hp.curr_hp_armor2 <= 0:
			iron_type = IronType.IronArmor1
			iron_node = bucket_iron
		# 铁门尚存时继续允许磁力菇吸门，门消失后仍可吸走剩余铁桶。
		if preserve_screen_door and not current_hp.signal_armor2_death.is_connected(_on_adventure_screen_door_lost):
			current_hp.signal_armor2_death.connect(_on_adventure_screen_door_lost)
		if not current_hp.signal_armor1_death.is_connected(_on_adventure_bucket_armor_lost):
			current_hp.signal_armor1_death.connect(_on_adventure_bucket_armor_lost)
	template.free()
	has_received_adventure_armor = true
	if not preserve_screen_door:
		start_adventure_armor_timer()
	return true


## 铁桶耗尽时保留仍存活的铁门铁器，其余情况恢复无铁器状态。
func _on_adventure_bucket_armor_lost() -> void:
	if zombie_type == CharacterRegistry.ZombieType.Z007ScreenDoor \
		and (hp_component as HpComponentZombie).curr_hp_armor2 > 0:
		return
	iron_type = IronType.Null


## 铁门消失后，仅在传播铁桶仍有耐久时切换磁力目标，不影响原二类防具脱落表现。
func _on_adventure_screen_door_lost() -> void:
	if (hp_component as HpComponentZombie).curr_hp_armor1 > 0 and is_instance_valid(_adventure_bucket_iron):
		iron_type = IronType.IronArmor1
		iron_node = _adventure_bucket_iron

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	_random_anim_status()
	_random_sprit_appear()
	if is_seaweed:
		sprite_seaweed.shuffle()
		var pick3 = sprite_seaweed.slice(0, 3)
		for s in pick3:
			s.visible = true
		sprite_seaweed_bucket.visible = true
	start_adventure_armor_timer()

## 随机选择动画状态种类
func _random_anim_status():
	idle_status = randi_range(1, idle_status_max)
	walk_status = randi_range(1, walk_status_max)
	death_status = randi_range(1, death_status_max)

func _random_sprit_appear():
	for sprite in init_sprite_random:
		sprite.visible = [true, false].pick_random()


## 死亡动画开始时,将里面的胳膊显示(旗帜\铁门)
func anim_death_start():
	anim_innerarm.visible = true

## 小体型铁门：入场一秒后仅判断一次冲到本行最前，失去铁门或被魅惑后永久取消入场机制。
extends Zombie001Norm
class_name Zombie007ScreenDoor

## 入场正常行走的游戏秒数，服从暂停与全局速度，不随个体随机速度缩放。
const ENTRY_WAIT_SECONDS:float = 1.0
## 赶到本行最前时的动画与地面行走倍率。
const ENTRY_SPRINT_MULTIPLIER:float = 10.0
## 完成入场后的持续行走倍率。
const CRUISE_MULTIPLIER:float = 1.25
## 入场阶段；取消后不再恢复或重新判定。
enum EntryPhase { Disabled, Waiting, Sprinting, Cruising }
## 当前入场阶段，仅正常出战、未被魅惑且有铁门时开启。
var _entry_phase:EntryPhase = EntryPhase.Disabled
## 独立入场判定计时器，只在创建时启动一次。
var _entry_timer:Timer
## 加速前的动画基础速度，铁门脱落或被魅惑时恢复，保留随机速度与其他异常状态倍率。
var _entry_base_animation_speed:float = 1.0


## 沿用普通僵尸初始化，展示和图鉴不启动入场机制。
func _ready() -> void:
	super()
	if character_init_type != E_CharacterInitType.IsNorm:
		return
	_entry_base_animation_speed = anim_component.get_animation_origin_speed()
	# 二类防具归零同时覆盖普通击碎和磁力移除；不受新增一类防具影响。
	var zombie_hp:HpComponentZombie = hp_component as HpComponentZombie
	zombie_hp.signal_armor2_death.connect(_disable_entry_mechanics)
	signal_character_death.connect(_disable_entry_mechanics)
	# 所有来源的魅惑（包括临时卡出生后转换）均立即停止等待、冲刺及巡航。
	signal_character_be_hypno.connect(_disable_entry_mechanics)
	if zombie_hp.curr_hp_armor2 <= 0 or is_death or is_hypno:
		return
	_entry_phase = EntryPhase.Waiting
	_entry_timer = Timer.new()
	_entry_timer.one_shot = true
	_entry_timer.wait_time = ENTRY_WAIT_SECONDS
	_entry_timer.timeout.connect(_on_entry_wait_timeout)
	add_child(_entry_timer)
	_entry_timer.start()


## 入场唯一一次判定：前方有单位才启动十倍追赶，无单位直接进入巡航。
func _on_entry_wait_timeout() -> void:
	if _entry_phase != EntryPhase.Waiting or not _can_use_entry_mechanics():
		return
	if _has_zombie_ahead():
		_entry_phase = EntryPhase.Sprinting
		_set_entry_move_multiplier(ENTRY_SPRINT_MULTIPLIER)
	else:
		_finish_entry_sprint()


## [param _delta] 本帧游戏秒数；只监测已经启动的追赶是否完成，不重复启动入场判定。
func _process(_delta:float) -> void:
	if _entry_phase != EntryPhase.Sprinting:
		return
	if not _can_use_entry_mechanics():
		_disable_entry_mechanics()
	elif not _has_zombie_ahead():
		_finish_entry_sprint()


## 返回是否仍存活、未魅惑、处于战斗树且保有铁门；一类路障或铁桶不会替代此条件。
func _can_use_entry_mechanics() -> bool:
	return not is_hypno and not is_death and not is_queued_for_deletion() and not hp_component.is_death \
		and (hp_component as HpComponentZombie).curr_hp_armor2 > 0 \
		and is_instance_valid(Global.main_game) and Global.main_game.is_ancestor_of(self)


## 查询本行其他存活僵尸是否处于实际行进方向前方，包括魅惑实例，不计死亡与已离场目标。
func _has_zombie_ahead() -> bool:
	# 管理器同时保存普通和魅惑实例，避免只扫描敌方行列表遗漏已有单位。
	for reference:Variant in Global.main_game.zombie_manager.all_zombies_1d:
		if not is_instance_valid(reference) or not reference is Zombie000Base:
			continue
		# 有效同行目标，读取坐标前先排除即将删除或不在当前战斗树中的单位。
		var zombie:Zombie000Base = reference as Zombie000Base
		if zombie == self or zombie.lane != lane or zombie.is_death or zombie.is_queued_for_deletion() \
			or zombie.hp_component.is_death or not Global.main_game.is_ancestor_of(zombie):
			continue
		if (zombie.global_position.x - global_position.x) * direction_x_root <= 0.0:
			return true
	return false


## 完成后固定进入 1.25 倍，不因后续出现新的前方僵尸重新冲刺。
func _finish_entry_sprint() -> void:
	_entry_phase = EntryPhase.Cruising
	_set_entry_move_multiplier(CRUISE_MULTIPLIER)


## [param multiplier] 相对原基础动画的倍率；Ground 移动跟随动画，不再额外乘位移，避免平方加速。
func _set_entry_move_multiplier(multiplier:float) -> void:
	anim_component.set_animation_origin_speed(_entry_base_animation_speed * multiplier)
	anim_component.owner_update_speed(GlobalUtils.get_dic_product(influence_speed_factors))


## 铁门归零、被魅惑或死亡时永久取消判定、冲刺和巡航，恢复基础动画及移动节奏。
func _disable_entry_mechanics() -> void:
	_entry_phase = EntryPhase.Disabled
	if is_instance_valid(_entry_timer):
		_entry_timer.stop()
	_set_entry_move_multiplier(1.0)

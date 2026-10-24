## 中体型橄榄球：敌方冲刺顶飞并撞植物；魅惑冲刺撞敌方僵尸，收势后慢走并恢复啃食。
extends Zombie000Base
class_name Zombie008Football

## 冲刺、撞击演出和慢走阶段；死亡由共用生命链路处理。
enum FootballPhase { Charging, Impact, Walking, Dead }
## 当前专属行为阶段，动画组件据此选择已制作的动作。
var football_phase:FootballPhase = FootballPhase.Charging
## 独立冲刺接触区，不改变普通啃食的检测条件。
@onready var _tackle_area:Area2D = %FootballTackleArea
## 原橄榄球行走轨道，用于计算原速而不是将动画位移再乘一次。
const ORIGINAL_WALK:Animation = preload("res://animation/character/zombie/008_zombie_football/Zombie_football_walk.tres")
## 普通僵尸行走轨道，两个通常行走变体的地面位移及长度一致。
const NORMAL_WALK:Animation = preload("res://animation/character/zombie/001_zombie_norm/Zombie_walk.tres")
## 普通僵尸场景的常规基础动作倍率；个体随机及异常因素另行叠乘。
const NORMAL_ANIMATION_MULTIPLIER:float = 1.2
## 入场实际移动速度相对原橄榄球的倍率。
const CHARGE_SPEED_MULTIPLIER:float = 2.0
## 完成前扑时只对最初接触的那株植物结算一次穿透伤害。
const IMPACT_DAMAGE:int = 6000
## 魅惑冲刺对首个敌方僵尸的基础穿透伤害，来源分类为普通，参与读报同类抗性。
const HYPNO_IMPACT_DAMAGE:int = 1800
## 同格僵尸沿实际行进方向移动的格数。
const LAUNCH_CELLS:int = 3
## 是否已经消耗首次僵尸接触，不因落地或后续接触再次触发。
var _has_launched_zombies:bool = false
## 最初撞击的植物或敌方僵尸使用弱引用，死亡后不会误伤替补目标。
var _impact_target:WeakRef
## 防止动画重复事件造成多次撞击伤害。
var _impact_damage_applied:bool = false
## 通常普通僵尸的基准移速，初始化时由轨道换算。
var _walking_speed:float = 0.0


## 正常出战才启动入场机制；图鉴与选关展示沿用原版待机。
func _ready() -> void:
	super()
	if character_init_type != E_CharacterInitType.IsNorm:
		return
	_walking_speed = _track_speed(NORMAL_WALK, NORMAL_ANIMATION_MULTIPLIER)
	move_component.update_move_mode(MoveComponent.E_MoveMode.Speed)
	move_component.ori_speed = _track_speed(ORIGINAL_WALK, anim_component.get_animation_origin_speed()) * CHARGE_SPEED_MULTIPLIER
	move_component.owner_update_speed(GlobalUtils.get_dic_product(influence_speed_factors))
	# 独立原因只禁用冲刺期啃食，不覆盖冻结、死亡等已有开关。
	attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.FootballCharge)
	anim_component.signal_animation_finished.connect(_on_football_animation_finished)
	_tackle_area.set_deferred("monitoring", true)


## 从 [param animation] 的地面轨道及 [param multiplier] 基础倍率计算像素/游戏秒。
func _track_speed(animation:Animation, multiplier:float) -> float:
	# 当前轨道编号，只有地面位置轨道参与平均速度计算。
	for track_index:int in range(animation.get_track_count()):
		if String(animation.track_get_path(track_index)) != "Body/BodyCorrect/_ground:position":
			continue
		# 轨道首末位置；不把骨骼局部位移当成角色速度。
		var first:Vector2 = animation.track_get_key_value(track_index, 0)
		var last:Vector2 = animation.track_get_key_value(track_index, animation.track_get_key_count(track_index) - 1)
		return absf(last.x - first.x) / animation.length * multiplier
	return 20.0


## [param _delta] 物理帧时间；接触通过独立区域获取，冻结或被顶飞时不结算冲刺碰撞。
func _physics_process(_delta:float) -> void:
	if character_init_type != E_CharacterInitType.IsNorm or football_phase != FootballPhase.Charging \
		or is_death or hp_component.is_death or is_queued_for_deletion() or football_launch_active or _football_blowing_away:
		return
	if not is_instance_valid(Global.main_game):
		return
	# 友方冲刺没有撞到敌人就保持奔跑；越过既有右侧清理边界时走正常死亡登记及释放。
	# 不依赖仅末波/无出怪模式开启的全局离场检查计时器，避免中间波次残留场外实例。
	if is_hypno and global_position.x > Global.main_game.zombie_manager.zombie_range_pos_x.y:
		character_death_disappear()
		return
	if not Global.main_game.zombie_manager.is_game_running() \
		or GlobalUtils.get_dic_product(influence_speed_factors) <= 0.0:
		return
	# 同一帧接触多个对象时按实际前方距离取首个，植物先转换成同格最外保护层。
	# 入场通过延迟调用开启监测，首个物理帧可能尚未生效；关闭时不能读取重叠缓存。
	if not is_instance_valid(_tackle_area) or not _tackle_area.monitoring:
		return
	var nearest:Character000Base
	var nearest_distance:float = INF
	for area:Area2D in _tackle_area.get_overlapping_areas():
		# 受击区域所属角色；排除自身、预览、死亡和不同道路。
		var candidate:Character000Base = area.owner as Character000Base
		if not is_instance_valid(candidate) or candidate == self or candidate.is_death \
			or candidate.is_queued_for_deletion() or candidate.lane != lane \
			or candidate.character_init_type != E_CharacterInitType.IsNorm:
			continue
		if candidate is Zombie000Base:
			# 魅惑冲刺只撞敌方僵尸，且不受此前敌方阶段是否已经顶飞过的限制。
			if is_hypno and candidate.is_hypno:
				continue
			if not is_hypno and _has_launched_zombies:
				continue
		elif candidate is Plant000Base:
			if is_hypno:
				continue
			candidate = _first_plant((candidate as Plant000Base).plant_cell)
		else:
			continue
		if not is_instance_valid(candidate) or candidate.hp_component.is_death \
			or not candidate.hurt_box_component.is_enabling:
			continue
		# 根方向1向左，-1向右；区域虽已朝前，仍排除完全处于身后的根节点。
		var forward_distance:float = (global_position.x - candidate.global_position.x) * direction_x_root
		if forward_distance < -20.0:
			continue
		if maxf(forward_distance, 0.0) < nearest_distance:
			nearest_distance = maxf(forward_distance, 0.0)
			nearest = candidate
	if nearest is Plant000Base:
		_begin_impact(nearest)
	elif nearest is Zombie000Base:
		if is_hypno:
			_begin_impact(nearest)
		else:
			_launch_first_zombie_cell(nearest as Zombie000Base)


## [param cell] 接触格；按保护层优先只选择一株，不把6000伤害分发到整格。
func _first_plant(cell:PlantCell) -> Plant000Base:
	if not is_instance_valid(cell):
		return null
	# 冲撞允许接触底座及地刺，普通啃食检测不随之放宽。
	for place:CharacterRegistry.PlacePlantInCell in [CharacterRegistry.PlacePlantInCell.Shell,
		CharacterRegistry.PlacePlantInCell.Norm, CharacterRegistry.PlacePlantInCell.Imitater,
		CharacterRegistry.PlacePlantInCell.Down, CharacterRegistry.PlacePlantInCell.Float]:
		# 格子可能保留已释放引用，必须先用Variant接收并验证，再转换为植物类型。
		var plant_reference: Variant = cell.plant_in_cell.get(place)
		if not is_instance_valid(plant_reference):
			continue
		# 已确认引用有效的候选植物。
		var plant: Plant000Base = plant_reference as Plant000Base
		if plant != null and not plant.is_death and not plant.is_queued_for_deletion() \
			and is_instance_valid(plant.hurt_box_component) and plant.hurt_box_component.is_enabling:
			return plant
	return null


## [param target] 首次接触的僵尸；按所在虚拟格分组，场外也不把所有单位挤到边缘一格。
func _launch_first_zombie_cell(target:Zombie000Base) -> void:
	# 本路植物格数组用于读取实际格距，兼容前院、泳池和屋顶。
	var cells:Array = Global.main_game.plant_cell_manager.all_plant_cells[lane]
	if cells.size() < 2:
		return
	# 从左右格中心换算平均格距，场外延伸同一网格。
	var left_center:float = cells[0].global_position.x + cells[0].size.x * 0.5
	var right_center:float = cells[-1].global_position.x + cells[-1].size.x * 0.5
	var pitch:float = absf(right_center - left_center) / (cells.size() - 1)
	if pitch <= 0.0:
		return
	var column:int = floori((target.global_position.x - left_center) / pitch + 0.5)
	var displacement:float = -direction_x_root * pitch * LAUNCH_CELLS
	_has_launched_zombies = true
	# 行节点包含普通和魅惑实例，不以阵营过滤整格效果。
	for child:Node in Global.main_game.zombie_manager.all_zombie_rows[lane].get_children():
		var zombie:Zombie000Base = child as Zombie000Base
		if not is_instance_valid(zombie) or zombie == self or zombie.is_death \
			or zombie.is_queued_for_deletion() or zombie.hp_component.is_death:
			continue
		var zombie_column:int = floori((zombie.global_position.x - left_center) / pitch + 0.5)
		if zombie_column == column:
			zombie.start_football_launch(displacement)


## [param target] 只锁定最初接触的植物或敌方僵尸；立即停步并播放前扑、定格和收势。
func _begin_impact(target:Character000Base) -> void:
	football_phase = FootballPhase.Impact
	_impact_target = weakref(target)
	_impact_damage_applied = false
	_tackle_area.set_deferred("monitoring", false)
	move_component.update_move_factor(true, MoveComponent.E_MoveFactor.FootballImpact)


## 前扑完成关键帧调用；只结算一次，目标已被清除时落空，不伤害后补植物。
func football_impact_hit() -> void:
	if football_phase != FootballPhase.Impact or _impact_damage_applied or is_death or _football_blowing_away:
		return
	_impact_damage_applied = true
	# 弱引用可能已经失效，读取后再核对存活资格。
	var target:Character000Base = _impact_target.get_ref() as Character000Base if _impact_target != null else null
	if is_instance_valid(target) and not target.is_death and not target.is_queued_for_deletion() \
		and not target.hp_component.is_death:
		if target is Plant000Base and not is_hypno:
			target.hp_component.Hp_loss(IMPACT_DAMAGE, BulletRegistry.AttackMode.Penetration)
		elif target is Zombie000Base and is_hypno and not target.is_hypno:
			# 穿透是防具结算模式，普通是来源分类；显式传入普通，不能走灰烬或碾压清除。
			if target.hp_component is HpComponentPaper:
				(target.hp_component as HpComponentPaper).lose_categorized_hp(
					HYPNO_IMPACT_DAMAGE, HpComponentPaper.DamageKind.Normal, BulletRegistry.AttackMode.Penetration)
			else:
				target.hp_component.Hp_loss(HYPNO_IMPACT_DAMAGE, BulletRegistry.AttackMode.Penetration)
	_impact_target = null


## [param animation_name] 撞击收势完成才恢复啃食；循环动作不会重复触发阶段切换。
func _on_football_animation_finished(animation_name:StringName) -> void:
	if animation_name != &"football/impact" or football_phase != FootballPhase.Impact or is_death:
		return
	# 极高全局倍速可能同帧越过关键帧和片段末尾，补结算仍由一次性标记去重。
	football_impact_hit()
	football_phase = FootballPhase.Walking
	move_component.ori_speed = _walking_speed
	move_component.owner_update_speed(GlobalUtils.get_dic_product(influence_speed_factors))
	move_component.update_move_factor(false, MoveComponent.E_MoveFactor.FootballImpact)
	attack_component.enable_component(ComponentNormBase.E_IsEnableFactor.FootballCharge)


## 死亡立即取消待结算撞击，原版死亡动作由动画组件接续。
func character_death() -> void:
	football_phase = FootballPhase.Dead
	_impact_damage_applied = true
	_impact_target = null
	# 专属逻辑使用Speed位移，死亡时必须显式停步，不能依赖原Ground死亡动作没有位移。
	if is_instance_valid(move_component):
		move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsDeath)
	if is_instance_valid(_tackle_area):
		_tackle_area.set_deferred("monitoring", false)
	super()

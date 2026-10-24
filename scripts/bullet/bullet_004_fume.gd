## 穿透喷雾：记录本次命中者携带的状态，720像素（约一整行）飞行结束统一扩散，避免命中顺序破坏优先级。
extends BulletLinear000Base
class_name Bullet004Fume

## 扩散分支；魅惑压制全部，烧灼/冻结/减速只取最高，黄油与剧毒可与寒冰分支共存。
enum SpreadState { Hypno, Burning, Freeze, Slow, Poison, Butter }
## 仅本颗大喷菇子弹扩散寒冰状态时，在采集的剩余秒数上增加的时长。
const ICE_SPREAD_BONUS_SECONDS: float = 2.0
## 本颗子弹已命中的普通僵尸弱引用，防止重复碰撞与已释放引用。
var _spread_targets:Dictionary[int, WeakRef] = {}
## 状态快照：计时状态保存命中瞬间剩余秒数，同类多个来源取最大值。
var _spread_states:Dictionary = {}
## 防止正常结束与其他移除入口重复结算。
var _spread_resolved:bool = false


## [param enemy] 候选目标；[param check_lane] 沿用同行限制。魅惑僵尸可携带扩散来源，但不会被友军喷雾扣血。
func _can_attack_character(enemy:Character000Base, check_lane:bool = true) -> bool:
	if enemy is Zombie000Base and is_instance_valid(enemy) and enemy.is_hypno:
		return not enemy.is_death and not enemy.is_queued_for_deletion() \
			and is_instance_valid(enemy.hurt_box_component) and enemy.hurt_box_component.is_enabling \
			and (enemy.curr_be_attack_status & can_attack_zombie_status) != 0 \
			and (not check_lane or not is_activate_lane or enemy.lane == lane)
	return super(enemy, check_lane)


## [param enemy] 本次命中对象；先读取受击前状态，致死来源也可将原状态贡献给本次扩散。
func attack_once(enemy:Character000Base):
	if enemy is Zombie000Base and _can_attack_character(enemy):
		# 同一僵尸只结算一次伤害与状态采样，不因多个受击框重复贡献。
		var instance_id:int = enemy.get_instance_id()
		if _spread_targets.has(instance_id):
			return
		_spread_targets[instance_id] = weakref(enemy)
		_capture_states(enemy)
		if enemy.is_hypno:
			return
	super(enemy)


## [param zombie] 当前命中的状态载体，不直接向未被同颗子弹命中的角色扩散。
func _capture_states(zombie:Zombie000Base) -> void:
	if zombie.is_hypno:
		_spread_states[SpreadState.Hypno] = true
	if zombie.has_burning_placeholder:
		_spread_states[SpreadState.Burning] = true
	if zombie.is_poisoned:
		_spread_states[SpreadState.Poison] = true
	_capture_timer(zombie, Character000Base.E_TimerType.IceFreeze, SpreadState.Freeze)
	_capture_timer(zombie, Character000Base.E_TimerType.IceDecelerate, SpreadState.Slow)
	_capture_timer(zombie, Character000Base.E_TimerType.Butter, SpreadState.Butter)


## [param zombie] 状态载体；[param timer_type] 原角色计时器类别；[param state] 本次扩散键。
func _capture_timer(zombie:Zombie000Base, timer_type:Character000Base.E_TimerType, state:SpreadState) -> void:
	# 原计时器只用于取样，不改动其剩余时间或冻结状态。
	var timer:Timer = zombie.all_timer.get(timer_type)
	if is_instance_valid(timer) and timer.time_left > 0.0:
		_spread_states[state] = maxf(float(_spread_states.get(state, 0.0)), timer.time_left)


## [param delta] 物理帧秒数；沿用直线移动，在达到射程前完成唯一一次统一扩散。
func _physics_process(delta:float) -> void:
	if global_position.distance_to(start_pos) + speed * delta > max_distance:
		_resolve_spread()
	super(delta)


## 统一选择本颗子弹的最高优先级分支；保留目标原有状态，不移除其已存在的低级状态。
func _resolve_spread() -> void:
	if _spread_resolved:
		return
	_spread_resolved = true
	# 遍历独立快照，魅惑改变阵营或管理器时不影响本次遍历集合。
	for reference:WeakRef in _spread_targets.values():
		# 先校验弱引用再转换，跳过本次穿透已经杀死或移除的目标。
		var value:Variant = reference.get_ref()
		if not is_instance_valid(value) or value.is_death or value.is_queued_for_deletion():
			continue
		# 存活的本次命中目标，不要求它此时仍与喷雾同阵营敌对。
		var zombie:Zombie000Base = value as Zombie000Base
		if _spread_states.has(SpreadState.Hypno):
			if not zombie.is_hypno:
				zombie.be_hypno()
			continue
		if _spread_states.has(SpreadState.Burning):
			zombie.has_burning_placeholder = true
		elif _spread_states.has(SpreadState.Freeze):
			zombie.be_snow_pea_frozen(float(_spread_states[SpreadState.Freeze]) + ICE_SPREAD_BONUS_SECONDS)
		elif _spread_states.has(SpreadState.Slow):
			zombie.be_ice_decelerate(float(_spread_states[SpreadState.Slow]) + ICE_SPREAD_BONUS_SECONDS)
		if _spread_states.has(SpreadState.Poison):
			zombie.be_poisoned()
		if _spread_states.has(SpreadState.Butter):
			# 黄油原接口会重置倒计时，仅当本次扩散能延长现有定身时施加。
			var butter_timer:Timer = zombie.all_timer.get(Character000Base.E_TimerType.Butter)
			if not is_instance_valid(butter_timer) or butter_timer.time_left < float(_spread_states[SpreadState.Butter]):
				zombie.be_butter(float(_spread_states[SpreadState.Butter]))

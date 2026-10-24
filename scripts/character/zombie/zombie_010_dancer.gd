extends Zombie009Jackson
class_name Zombie010Dancer

## 是否为被召唤的伴舞僵尸
var is_call := false
## 是否被魅惑舞王召唤
var is_call_be_hypno:bool = false
## 本伴舞独立持有的四个普通僵尸槽位；弱引用不阻止死亡实例释放。
var _normal_summon_slots:Array[WeakRef] = [null, null, null, null]
## 连续需要补召的检查次数，第二次检查补齐空槽，与舞王规则一致。
var _normal_summon_checks:int = 0
## 首次召唤必须等到出土后的下一次有效缺员检查，不在入场初始化中立即召唤。
var _normal_first_summon_waiting:bool = true
## 合并同帧召唤请求，避免物理回调或多个动画回调重复创建。
var _normal_summon_pending:bool = false

## 初始化伴舞赋值，被召唤的伴舞，舞王管理器调用
func init_dancer_be_call(curr_dancer_id, curr_animation_origin_speed, animation_curr_speed, jackson_init_random_speed, curr_jackson_manager, is_hypnotized):
	is_call = true
	self.dancer_id = curr_dancer_id
	self.jackson_manager = curr_jackson_manager
	## 如果舞王被魅惑
	is_call_be_hypno = is_hypnotized
	call_deferred(&"init_anim_speed_dance", curr_animation_origin_speed, animation_curr_speed, jackson_init_random_speed)

## 重写舞王初始方法，ready调用
func _init_dance():
	if not is_call:
		jackson_manager = SceneRegistry.JACKSON_MANAGER.instantiate()
		add_child(jackson_manager)
		dancer_id = 0
		jackson_manager.zombie_dancers[0] = self
		state_machine.jackson_manager = jackson_manager
		state_machine.init_state(JacksonStateMachine.E_JacksonStatus.Norm)

	else:
		state_machine.jackson_manager = jackson_manager
		## 初始化状态为入场状态,伴舞入场状态不攻击
		state_machine.init_state(JacksonStateMachine.E_JacksonStatus.Enter)
		await zombie_appear_from_ground()
		state_machine.change_jackson_anim_status(state_machine.curr_jackson_status,state_machine.judge_curr_status())

	if is_call_be_hypno:
		be_hypno()
	# 普通僵尸首次召唤留给管理器下一次缺员检查，出土结束不直接生成。


## 舞王管理器在每轮缺员检查点调用；仅正常状态且未被控制停滞时累计补召。
func check_normal_summon_slots() -> void:
	if is_death or is_queued_for_deletion() or not is_instance_valid(Global.main_game) \
		or state_machine.curr_jackson_status != JacksonStateMachine.E_JacksonStatus.Norm:
		return
	if GlobalUtils.get_dic_product(influence_speed_factors) <= 0.0:
		return
	# 仅关心合法方向仍存活的实例，不将已换装普通误当成空槽。
	var has_empty_slot:bool = false
	for slot:int in range(4):
		# 复用舞王的边界与水路校验，不为非法方向重复累积召唤。
		var location:Variant = jackson_manager.get_new_zombie_dancer_lane_and_glo_pos(slot, lane, global_position)
		if location and not _normal_slot_alive(slot):
			has_empty_slot = true
	if not has_empty_slot:
		_normal_summon_checks = 0
		return
	if _normal_first_summon_waiting:
		_normal_first_summon_waiting = false
		_normal_summon_checks = 0
		_queue_normal_summons()
		return
	_normal_summon_checks += 1
	if _normal_summon_checks >= 2:
		_normal_summon_checks = 0
		_queue_normal_summons()


## [param slot] 四向槽位；存活引用继续占位，死亡、删除或离场后可补召。
func _normal_slot_alive(slot:int) -> bool:
	if _normal_summon_slots[slot] == null:
		return false
	# 弱引用先校验，之后再转换角色类型。
	var reference:Variant = _normal_summon_slots[slot].get_ref()
	return is_instance_valid(reference) and not reference.is_death and not reference.is_queued_for_deletion() \
		and Global.main_game.is_ancestor_of(reference)


## 初次出土和后续缺员检查共用请求，实际创建放到安全帧。
func _queue_normal_summons() -> void:
	if _normal_summon_pending or is_death or is_queued_for_deletion():
		return
	_normal_summon_pending = true
	_summon_normal_slots.call_deferred()


## 各合法空槽生成一只普通僵尸；不创建伴舞或新舞王管理器，避免递归召唤。
func _summon_normal_slots() -> void:
	_normal_summon_pending = false
	if is_death or is_queued_for_deletion() or not is_instance_valid(Global.main_game) \
		or not Global.main_game.is_ancestor_of(self):
		return
	# 四个位置与舞王一致：上下邻行、左右各 100 像素。
	for slot:int in range(4):
		if _normal_slot_alive(slot):
			continue
		# 非法邻行不召唤，其他合法位置沿用普通创建和出土表现。
		var location:Variant = jackson_manager.get_new_zombie_dancer_lane_and_glo_pos(slot, lane, global_position)
		if not location:
			continue
		# 不占自然出怪额度，刷新归属与伴舞来源一致。
		var parameters:Dictionary = {
			Zombie000Base.E_ZInitAttr.CharacterInitType:E_CharacterInitType.IsNorm,
			Zombie000Base.E_ZInitAttr.Lane:location.lane,
			Zombie000Base.E_ZInitAttr.CurrWave:-1,
			Zombie000Base.E_ZInitAttr.ParticipatesNaturalRefresh:participates_natural_refresh,
		}
		# 正式普通僵尸仍遵循群体生命成长和后续换装规则，不加入伴舞速度联动组。
		var zombie:Zombie000Base = Global.main_game.zombie_manager.create_norm_zombie(
			CharacterRegistry.ZombieType.Z001Norm, Global.main_game.zombie_manager.all_zombie_rows[location.lane], parameters, location.pos)
		_normal_summon_slots[slot] = weakref(zombie)
		if is_hypno:
			zombie.be_hypno()
		Global.main_game.zombie_manager._rise_flag_normal(zombie)

## 召唤伴舞初始化时重置动画播放速度, 舞王管理器调用
func init_anim_speed_dance(curr_animation_origin_speed, curr_speed, jackson_init_random_speed):
	## 获取动画初始速度
	self.animation_origin_speed = curr_animation_origin_speed
	update_speed_factor(jackson_init_random_speed, E_Influence_Speed_Factor.InitRandomSpeed)
	anim_component.set_animation_origin_speed(animation_origin_speed)
	anim_component.owner_update_speed(jackson_init_random_speed)
	anim_component.update_anim_speed_scale(curr_speed)

## 随机初始化角色速度,继承重写
func init_random_speed():
	if is_call:
		return
	super()

## 伴舞僵尸从地下出现
func zombie_appear_from_ground():
	await zombie_up_from_ground()
	#dirt.start_dirt()
	#body.visible = false
	#mask.visible = true
	#body_in_mask.position.y = 300.0
	#var tween = create_tween()
	##await get_tree().process_frame
	#tween.tween_property(body_in_mask, ^"global_position", body.global_position, 1.0)
	#await tween.finished
	#body.visible = true
	#mask.visible = false

## 初始化展示角色
func _init_show_jackon():
	while true:
		animation_player.play("armraise")
		await animation_player.animation_finished
		body.scale.x = -body.scale.x

## 伴舞被魅惑额外操作
func jackson_be_hypno():
	## 如果是被魅惑舞王召唤、无需处理
	if is_call_be_hypno:
		return

	dancer_manager_change()

	jackson_manager = SceneRegistry.JACKSON_MANAGER.instantiate()
	state_machine.jackson_manager = jackson_manager
	add_child(jackson_manager)
	jackson_manager.zombie_dancers[0] = self

	jackson_manager.start_anim()
	jackson_manager.init_anim_speed(animation_origin_speed, influence_speed_factors[E_Influence_Speed_Factor.InitRandomSpeed])
	jackson_manager.is_hypnotized = true
	#print("舞王或伴舞被魅惑")

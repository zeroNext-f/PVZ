## 大体型雪橇：缺冰持续自损，死亡必定释放四位队员及至多四位同波同行的小体型搭载成员。
extends Zombie000Base
class_name Zombie014Bobsled

## 雪橇主体图片，死亡后按原流程淡出。
@onready var zombie_bobsled_1:Sprite2D = $ZombieBobsled1
## 每0.3游戏秒检查冰道，缺冰时自损100生命，直到死亡释放队员。
@onready var judge_is_in_ice_road_timer:Timer = $JudgeIsInIceRoadTimer
## 四个队员的显示身体，同时提供每次队员生成时的横向基准。
@onready var all_zombie_bobsled_single_body:Array[BodyCharacter] = [$Body, $Body2, $Body3, $Body4]
## 四个身体的原动画播放器，保持现有推车、上车与同步速度表现。
@onready var all_anim_player:Array[AnimationPlayer] = [$Body/AnimationPlayer, $Body2/AnimationPlayer, $Body3/AnimationPlayer, $Body4/AnimationPlayer]
## 原流程兼容开关；本版缺冰仅自损，不再置位或生成留车状态。
var _has_dismounted:bool = false
## 入场携带的角色类型，最多四名；搭载移除原实例，亡语按原类型重新生成。
var _carried_types: Array[CharacterRegistry.ZombieType] = []
## 所有死亡入口共用的亡语生成标记，最多释放一批队员与搭载成员。
var _death_squad_released:bool = false
## 死亡清理是否已经开始，避免重复回调再次发死亡信号或重复安排淡出。
var _death_cleanup_started:bool = false

## 入场仍按原流程推车4秒再跳上滑行；期间死亡不再恢复动画及滑行。
func ready_norm():
	super()
	_capture_wave_passengers.call_deferred()
	judge_is_in_ice_road_timer.start()
	_play_anim("Zombie_bobsled_push")
	await get_tree().create_timer(4.0, false).timeout
	if _has_dismounted or is_death or is_queued_for_deletion():
		return
	_play_anim("Zombie_bobsled_jump")
	move_component.update_move_mode(MoveComponent.E_MoveMode.Speed)

## 展示实例保持原待机，不执行缺冰检查或召唤。
func ready_show():
	super()
	_play_anim("Zombie_bobsled_idle")

## [param anim_name] 同步播放的现有动画名，不改变各播放器已设置的速度倍率。
func _play_anim(anim_name:StringName):
	for anim_player:AnimationPlayer in all_anim_player:
		anim_player.play(anim_name)

## 同行缺少满足left_x < 自身X-50的冰道时，每次检查自损100，不单独下车或生成队员。
func judge_is_in_ice_road():
	if is_death or hp_component.is_death:
		return
	for road: IceRoad in Global.main_game.zombie_manager.all_ice_roads[lane]:
		if is_instance_valid(road) and road.left_x < global_position.x - 50:
			return
	hp_component.Hp_loss(100, BulletRegistry.AttackMode.Real, true, false)

## 同波创建批次结束后一次性选取同行同阵营的存活小体型，避免创建先后顺序漏选。
func _capture_wave_passengers() -> void:
	if is_death or is_queued_for_deletion() or curr_wave < 0:
		return
	# 候选快照按世界X从左到右挑选，每个原实例被搭载移除后不能被其他车再次选中。
	var candidates: Array[Zombie000Base] = []
	for zombie: Zombie000Base in Global.main_game.zombie_manager.all_zombies_1d.duplicate():
		if is_instance_valid(zombie) and zombie != self and not zombie.is_death and not zombie.hp_component.is_death \
			and not zombie.is_queued_for_deletion() and zombie.lane == lane and zombie.curr_wave == curr_wave \
			and zombie.is_hypno == is_hypno and zombie.zombie_body_size == BodySize.Small:
			candidates.append(zombie)
	candidates.sort_custom(func(a: Zombie000Base, b: Zombie000Base): return a.global_position.x < b.global_position.x)
	for zombie: Zombie000Base in candidates:
		if _carried_types.size() >= 4:
			break
		_carried_types.append(zombie.zombie_type)
		# 搭载属于移除原位置，不触发被搭载者的死亡技能。
		zombie.is_can_death_language = false
		zombie.character_death_disappear()
## 所有真实死亡先登记亡语生成请求，再保留原死亡通知与淡出。
func character_death():
	if _death_cleanup_started:
		return
	_death_cleanup_started = true
	death_language()
	judge_is_in_ice_road_timer.stop()
	move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsDeath)
	super()
	for passenger_body:BodyCharacter in all_zombie_bobsled_single_body:
		passenger_body.hide()
	await get_tree().create_timer(1, false).timeout
	# 雪橇实际死亡后才沿用原淡出，不在缺冰下车时释放其可受击实例。
	var fade_tween:Tween = create_tween()
	fade_tween.tween_property(zombie_bobsled_1, "modulate:a", 0, 1)
	fade_tween.tween_callback(queue_free)

## [param attack_value] 咬合按原穿透伤害结算；不设亡语禁用，所有死亡入口统一由character_death释放。
func be_chomper_eat(attack_value:int):
	if is_death or is_queued_for_deletion():
		return
	hp_component.Hp_loss(attack_value, BulletRegistry.AttackMode.Penetration, false, false)
	if is_death:
		hp_stage_change_component.judge_body_change(0, true)

## 所有真正死亡均释放一次，不再受is_can_death_language影响，重复入口不会重复生成。
func death_language():
	if _death_squad_released:
		return
	_death_squad_released = true
	_release_squad()
## 四名独立队员与搭载成员按四个身体前移一格的位置生成；不足四名搭载者按世界X靠左排列。
func _release_squad() -> void:
	# 先快照位置和来源，后续由管理器独立生成，不依赖本雪橇存活。
	var positions: Array[Vector2] = []
	var cells: Array = Global.main_game.plant_cell_manager.all_plant_cells[lane]
	var pitch: float = cells[0].size.x
	if cells.size() > 1:
		pitch = absf(cells[1].global_position.x - cells[0].global_position.x)
	for passenger_body: BodyCharacter in all_zombie_bobsled_single_body:
		positions.append(Vector2(passenger_body.global_position.x - direction_x_root * pitch,
			Global.main_game.zombie_manager.all_zombie_rows[lane].zombie_create_position.global_position.y))
	positions.sort_custom(func(a: Vector2, b: Vector2): return a.x < b.x)
	# 每个请求包含生成所需纯数值，管理器保障待生成期间不会提前判胜。
	var requests: Array[Dictionary] = []
	for index: int in range(4):
		requests.append({"type": CharacterRegistry.ZombieType.Z1001BobsledSingle, "lane": lane,
			"wave": curr_wave, "natural": participates_natural_refresh, "position": positions[index], "hypno": is_hypno})
		if index < _carried_types.size():
			requests.append({"type": _carried_types[index], "lane": lane, "wave": curr_wave,
				"natural": participates_natural_refresh, "position": positions[index], "hypno": is_hypno})
	Global.main_game.zombie_manager.queue_bobsled_release(requests)

## 原上车动画调整显示顺序；已下车或死亡后到达的动画事件不得再抬升队员。
func update_bobsled_order():
	if _has_dismounted or is_death:
		return
	move_child(zombie_bobsled_1, -1)
	for passenger_body:BodyCharacter in all_zombie_bobsled_single_body:
		# 只保留原身体上移表现，不改变队员生成的横向前移格距。
		var body_tween:Tween = create_tween()
		body_tween.tween_property(passenger_body, ^"position:y", passenger_body.position.y - 10, 1)

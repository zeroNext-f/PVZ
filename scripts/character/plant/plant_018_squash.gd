## 窝瓜从原种植格向前一格起跳，吸附范围仍为原格及左右相邻格，聚至新落点后碾压并正常死亡。
extends Plant000Base
class_name Plant018Squash

## 原落地伤害区域，保持80×5尺寸，使用实时形状相交判断。
@onready var area_2d_squash_attack:Area2D = $Area2DSquashAttack
## 沿用正常及水下状态资格，不吸附跳跃、空中、地下或魅惑友军。
@export_flags("1 正常", "2 跳跃", "4 水下", "8 空中", "16 地下") var can_attack_zombie_status:int = 5
## 非小体型及僵王承受的基础穿透伤害；读报另记录碾压来源。
@export_range(0, 10000, 1, "or_greater") var attack_value:int = 1800
## 吸附及窝瓜前跃的横移耗时，单位为游戏秒，沿用原吸附时长。
const PULL_SECONDS:float = 0.1667

@export_group("动画状态")
## 本株是否已开始一次性起跳，防止重复启动。
@export var is_attack:bool = false
## 保留原动画树的朝向参数，前跃只按自身朝向，不依赖索敌目标。
@export var is_right:bool = true
## 本次落地是否已经结算，防止重复方法事件。
var _has_squashed:bool = false
## 捕获目标的弱引用与起止横坐标，避免目标提前释放导致无效访问。
var _pull_targets:Array[Dictionary] = []
## 落地表现参考格，不覆盖plant_cell，避免死亡清场误操作前方格内的植物。
var _landing_cell:PlantCell

## 正常出战立即启动原起跳动画；展示及花园保持待机，不连接索敌信号。
func _ready() -> void:
	super()
	if character_init_type == E_CharacterInitType.IsNorm:
		attack_start()

## 不需要目标，跳过左右观察和等待索敌，直接启动向前一格的跳跃。
func attack_start() -> void:
	if is_attack or is_death:
		return
	is_attack = true
	SoundManager.play_character_SFX("SquashHmm")
	hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	# 主动指定起跳状态，沿用原起跳和落地动画的关键帧。
	var playback:AnimationNodeStateMachinePlayback = $AnimationTree.get("parameters/StateMachine/playback")
	playback.start(&"Squash_jumpup")

## 起跳时先按原格确定吸附范围，再将聚点及自身落点移到前方一格；不占用或替换落点格植物。
func jump_up_start() -> void:
	z_index += 50
	# 用实际行数组定位格子，不能使用可能倒序的编辑器子节点编号。
	var cells:Array = Global.main_game.plant_cell_manager.all_plant_cells[lane]
	var own_column:int = cells.find(plant_cell)
	if own_column < 0:
		return
	# 自身格加左右各一格，边缘裁剪到场内；不将场外僵尸归到边缘格。
	var first_cell:PlantCell = cells[maxi(own_column - 1, 0)]
	var last_cell:PlantCell = cells[mini(own_column + 1, cells.size() - 1)]
	var left_x:float = first_cell.global_position.x
	var right_x:float = last_cell.global_position.x + last_cell.size.x
	# 植物正常面向右，反向实例按自身朝向前跃；场地边缘仍前移完整一格，不钳回原格。
	var forward:int = 1 if direction_x_root >= 0 else -1
	var destination_column:int = own_column + forward # 前方目标格的实际数组索引，允许越界后延伸虚拟落点。
	var origin_center_x:float = plant_cell.global_position.x + plant_cell.size.x * 0.5 # 原种植格中心，不随自身跳跃改变。
	# 前方越界时使用后方相邻格距延伸虚拟落点，保持完整的一格距离。
	var neighbor_column:int = own_column + 1 if own_column + 1 < cells.size() else own_column - 1
	var pitch:float = plant_cell.size.x # 单格场地的后备格距，多格时改取实际相邻中心间距。
	if neighbor_column >= 0:
		pitch = absf(cells[neighbor_column].global_position.x + cells[neighbor_column].size.x * 0.5 - origin_center_x)
	_landing_cell = cells[destination_column] if destination_column >= 0 and destination_column < cells.size() else plant_cell
	var center_x:float = origin_center_x + float(forward) * pitch # 同时作为吸附聚点和窝瓜前跃的横向目标。
	if _landing_cell != plant_cell:
		center_x = _landing_cell.global_position.x + _landing_cell.size.x * 0.5
	# 屋顶等相邻格存在高度差时，身体落点随地形变化，受击检测仍补偿到同行基准。
	var ground_shift_y:float = _landing_cell.global_position.y - plant_cell.global_position.y
	var jump_destination:Vector2 = global_position + Vector2(center_x - origin_center_x, ground_shift_y) # 保留自身相对格中心的原偏移。
	var jump_tween:Tween = create_tween() # 前跃与检测高度补偿同步完成，不改变原垂直跳跃动画。
	jump_tween.set_parallel(true)
	jump_tween.tween_property(self, "global_position", jump_destination, PULL_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if ground_shift_y != 0.0:
		jump_tween.tween_property(area_2d_squash_attack, "position:y", area_2d_squash_attack.position.y - ground_shift_y, PULL_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _landing_cell.curr_condition & (8 | 16):
		shadow.visible = false
	# 管理器列表快照不会被其他同步死亡或召唤回调改变。
	var candidates:Array = Global.main_game.zombie_manager.all_zombies_1d.duplicate()
	for candidate_reference:Variant in candidates:
		if not is_instance_valid(candidate_reference):
			continue
		# 先检查引用再转换，避免已经释放的角色进入强类型变量。
		var zombie:Zombie000Base = candidate_reference as Zombie000Base
		if not _can_affect_zombie(zombie) or zombie.global_position.x < left_x or zombie.global_position.x >= right_x:
			continue
		# 原三格内的目标统一吸到前方一格的落点，只移动横坐标，保持所在行和水陆高度。
		var end_x:float = center_x - (zombie.hurt_box_component.global_position.x - zombie.global_position.x)
		_pull_targets.append({"target":weakref(zombie), "start_x":zombie.global_position.x, "end_x":end_x})
		zombie.move_component.begin_squash_pull(get_instance_id())
	if not _pull_targets.is_empty():
		# 插值回调通过弱引用取目标，不把可能提前死亡的角色直接绑定到属性Tween。
		var pull_tween:Tween = create_tween()
		pull_tween.tween_method(_advance_pull, 0.0, 1.0, PULL_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## [param progress] 吸附进度0～1；目标死亡、失效或转为友军后不再移动它。
func _advance_pull(progress:float) -> void:
	for pull_data:Dictionary in _pull_targets:
		# 弱引用可能返回已释放对象，先验证再转换。
		var target_reference:Variant = (pull_data["target"] as WeakRef).get_ref()
		if not is_instance_valid(target_reference):
			continue
		var zombie:Zombie000Base = target_reference as Zombie000Base
		if _can_affect_zombie(zombie):
			zombie.global_position.x = lerpf(pull_data["start_x"], pull_data["end_x"], progress)

## [param zombie] 普通僵尸；仅同行、存活、可受击、正常或水下状态的敌方目标有效。
func _can_affect_zombie(zombie:Zombie000Base) -> bool:
	return is_instance_valid(zombie) and not zombie.is_queued_for_deletion() and not zombie.is_death \
		and not zombie.hp_component.is_death and not zombie.is_hypno and zombie.lane == lane \
		and (zombie.curr_be_attack_status & can_attack_zombie_status) != 0 \
		and is_instance_valid(zombie.hurt_box_component) and zombie.hurt_box_component.is_enabling

## 落地结算一次；小体型以当前全生命作为致死穿透伤害，其余1800，之后正常死亡。
func squash_all_area_zombie() -> void:
	if _has_squashed or is_death:
		return
	_has_squashed = true
	# 普通僵尸和独立挂载的僵王各遍历一次，不按受击区域数量重复伤害。
	var candidates:Array = Global.main_game.zombie_manager.all_zombies_1d.duplicate()
	candidates.append_array(Global.main_game.zombie_manager.get_living_bosses())
	for candidate_reference:Variant in candidates:
		if not is_instance_valid(candidate_reference):
			continue
		var enemy:Character000Base = candidate_reference as Character000Base
		if enemy is Zombie000Base:
			if not _can_affect_zombie(enemy) or not _overlaps_landing_area(enemy):
				continue
			# 包括本体与两类防具，适配普通僵尸生命成长，不写死小体型血量。
			var damage:int = enemy.hp_component.get_all_hp() if enemy.zombie_body_size == Zombie000Base.BodySize.Small else attack_value
			enemy.be_squash(damage)
		elif enemy is ZB000Base and not enemy.is_death and not enemy.is_queued_for_deletion() \
			and (can_attack_zombie_status & Zombie000Base.E_BeAttackStatusZombie.IsNorm) != 0 \
			and enemy.hurt_box_component.is_enabling and _overlaps_landing_area(enemy):
			# 僵王保留原受击窗口及范围判断，不吸附也不套小体型致死规则。
			enemy.be_attacked_bullet(attack_value, BulletRegistry.AttackMode.Penetration, false, false)
	_release_pull_targets()
	judge_jump_pool()
	character_death()

## [param enemy] 已通过阵营、行和状态筛选的角色；使用当前世界形状，避免位移后重叠缓存漏伤。
func _overlaps_landing_area(enemy:Character000Base) -> bool:
	for landing_child:Node in area_2d_squash_attack.get_children():
		# 落地形状必须已经启用且有有效资源。
		var landing_shape:CollisionShape2D = landing_child as CollisionShape2D
		if landing_shape == null or landing_shape.disabled or landing_shape.shape == null:
			continue
		for area_child:Node in enemy.hurt_box_component.get_children():
			# 只处理原掩码允许的受击区域，不把攻击检测框算作命中。
			var target_area:Area2D = area_child as Area2D
			if target_area == null or not target_area.monitorable \
				or (target_area.collision_layer & area_2d_squash_attack.collision_mask) == 0:
				continue
			for shape_child:Node in target_area.get_children():
				# 任一启用的目标形状相交即可，不依赖上一物理帧缓存。
				var target_shape:CollisionShape2D = shape_child as CollisionShape2D
				if target_shape != null and not target_shape.disabled and target_shape.shape != null \
					and landing_shape.shape.collide(landing_shape.global_transform, target_shape.shape, target_shape.global_transform):
					return true
	return false

## 撤销本株的停步；其他窝瓜、寒冰、攻击或角色自己的移动限制继续保留。
func _release_pull_targets() -> void:
	for pull_data:Dictionary in _pull_targets:
		# 已死亡目标可能已经释放，仅对仍存在的移动组件撤销原因。
		var target_reference:Variant = (pull_data["target"] as WeakRef).get_ref()
		if is_instance_valid(target_reference):
			var zombie:Zombie000Base = target_reference as Zombie000Base
			if is_instance_valid(zombie.move_component):
				zombie.move_component.end_squash_pull(get_instance_id())
	_pull_targets.clear()

## 铲除、清场或其他提前移除也释放吸附，避免存活僵尸永久停步。
func _exit_tree() -> void:
	_release_pull_targets()

## 落地只播放水花或砸地音效，伤害入口统一触发正常死亡，避免水陆重复死亡信号。
func judge_jump_pool() -> void:
	# 只用落点格决定地形表现，种植占位与死亡通知仍归原种植格。
	var effect_cell:PlantCell = _landing_cell if is_instance_valid(_landing_cell) else plant_cell
	if effect_cell.curr_condition & (8 | 16):
		# 水花挂到落点格，不随一次性窝瓜一起释放。
		var splash:Splash = SceneRegistry.SPLASH.instantiate()
		effect_cell.add_child(splash)
		splash.global_position = Vector2(global_position.x, effect_cell.global_position.y + effect_cell.size.y)
		splash.z_as_relative = z_as_relative
		splash.z_index = z_index
	else:
		SoundManager.play_character_SFX(&"gargantuar_thump")

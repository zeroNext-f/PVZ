## 地刺保留周期真实伤害与扎胎反制；新种下时触发全场所有地刺上的合格僵尸竖直击飞。
extends Plant000Base
class_name Plant022Caltrop

## 攻击关键帧查询可受击目标的范围检测组件。
@onready var detect_component: DetectComponent = $DetectComponent

## 每次攻击造成的真实伤害。
@export var attack_value:=20
@export_group("动画状态")
## 范围内存在可攻击目标时播放攻击动画。
@export var is_attack:=false
## 是否已触发过被碾压反击，避免同次碾压重复处理。
var is_flattened := false

## 正常新种植立即触发；展示、花园和存档恢复不重放落地技能。
func _ready() -> void:
	super()
	if character_init_type == E_CharacterInitType.IsNorm and is_instance_valid(Global.main_game) \
		and not plant_cell.is_restoring_plant_from_save:
		_lift_all_spike_targets()

## 按每株地刺当前75×5区域与目标实时形状相交，收集全场踩在地刺上的敌方小/中体型后统一击飞。
## 新实例_ready时格子占位尚未写入，因此显式包含本株；同一目标跨两株区域也只击飞一次。
func _lift_all_spike_targets() -> void:
	# 本株先参与，随后收集其他存活地刺；不把地刺王作为本次技能的地刺来源。
	var spikes:Array[Plant022Caltrop] = [self]
	for cells:Array in Global.main_game.plant_cell_manager.all_plant_cells:
		for cell:PlantCell in cells:
			# 格子可能保留失效植物引用，先验证再转换。
			var plant_reference:Variant = cell.plant_in_cell[CharacterRegistry.PlacePlantInCell.Norm]
			if is_instance_valid(plant_reference) and plant_reference is Plant022Caltrop \
				and plant_reference != self and not plant_reference.is_death and not plant_reference.is_queued_for_deletion():
				spikes.append(plant_reference as Plant022Caltrop)
	# 目标引用快照与去重集合不受击飞后的状态变化影响。
	var candidates:Array = Global.main_game.zombie_manager.all_zombies_1d.duplicate()
	var targets:Dictionary[int, WeakRef] = {}
	for spike:Plant022Caltrop in spikes:
		for candidate_reference:Variant in candidates:
			if not is_instance_valid(candidate_reference):
				continue
			# 一次施加前先筛选阵营、体型、异常免疫、行及地刺原可攻击状态。
			var zombie:Zombie000Base = candidate_reference as Zombie000Base
			if zombie == null or zombie.is_hypno or zombie.is_death or zombie.hp_component.is_death \
				or zombie.is_queued_for_deletion() or zombie.lane != spike.lane or not zombie.can_receive_abnormal_status() \
				or zombie.zombie_body_size not in [Zombie000Base.BodySize.Small, Zombie000Base.BodySize.Medium] \
				or (zombie.curr_be_attack_status & spike.detect_component.can_attack_zombie_status) == 0 \
				or not zombie.hurt_box_component.is_enabling:
				continue
			if spike._overlaps_spike_now(zombie):
				targets[zombie.get_instance_id()] = weakref(zombie)
	for target_reference:WeakRef in targets.values():
		# 前一个目标的状态变化可引起同步角色回调，开始击飞前再检查引用。
		var target_value:Variant = target_reference.get_ref()
		if is_instance_valid(target_value):
			(target_value as Zombie000Base).start_caltrop_lift()

## [param zombie] 合格候选；用双方当前世界形状判定踩踏，避免新种地刺尚未更新重叠缓存而漏目标。
func _overlaps_spike_now(zombie:Zombie000Base) -> bool:
	for region:Area2D in detect_component.all_ray_area:
		for child:Node in region.get_children():
			# 仅启用且配置了资源的地刺攻击形状参与。
			var spike_shape:CollisionShape2D = child as CollisionShape2D
			if spike_shape == null or spike_shape.disabled or spike_shape.shape == null:
				continue
			for area_child:Node in zombie.hurt_box_component.get_children():
				# 仅取原检测掩码允许的受击区域，不使用僵尸自身的攻击探测框。
				var area:Area2D = area_child as Area2D
				if area == null or not area.monitorable or (area.collision_layer & region.collision_mask) == 0:
					continue
				for shape_child:Node in area.get_children():
					# 当前根节点/屋顶/底座的实际世界变换都保留，不按格中心替代范围判断。
					var target_shape:CollisionShape2D = shape_child as CollisionShape2D
					if target_shape != null and not target_shape.disabled and target_shape.shape != null \
						and spike_shape.shape.collide(spike_shape.global_transform, target_shape.shape, target_shape.global_transform):
						return true
	return false


## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	detect_component.signal_can_attack.connect(func():is_attack = true)
	detect_component.signal_not_can_attack.connect(func():is_attack = false)

## 攻击一次
func _attack_once():
	SoundManager.play_character_SFX("Throw")
	# 检测组件已按角色去重，并过滤僵王的关闭受击状态。
	var targets: Array[Character000Base] = detect_component.get_all_enemy_can_be_attacked()
	# 前一个目标死亡可能影响后续引用，检查有效性后才执行伤害。
	for target_reference: Variant in targets:
		if not is_instance_valid(target_reference):
			continue
		# 普通僵尸和僵王共用真实伤害入口；不调用冰车的地刺反伤逻辑。
		var enemy := target_reference as Character000Base
		if (enemy is Zombie000Base or enemy is ZB000Base) and not enemy.is_death and not enemy.is_queued_for_deletion():
			enemy.be_attacked_bullet(attack_value, BulletRegistry.AttackMode.Real, true, true)

## 被压扁
## [character:Character000Base] 发动攻击的角色
func be_flattened_from_enemy(character:Character000Base):
	if not is_flattened:
		is_flattened = true
		character.be_caltrop()
		super(character)

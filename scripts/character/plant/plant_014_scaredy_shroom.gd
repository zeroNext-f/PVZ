extends Plant000Base
class_name Plant014ScaredyShroom

@onready var scaredy_component: ScaredyComponent = $ScaredyComponent

@export_group("动画状态")
@export var is_scared := false

## 直接复用忧郁菇的周身攻击；害怕只控制表现，不再禁用范围内才能生效的近身脉冲。
@onready var attack_component: AttackComponentScaredyGloom = $AttackComponent



func ready_norm_signal_connect():
	super()
	scaredy_component.signal_scaredy_start.connect(change_is_scared.bind(true))
	scaredy_component.signal_scaredy_end.connect(change_is_scared.bind(false))

	signal_update_speed.connect(attack_component.owner_update_speed)
	attack_component.round_finished.connect(_poison_neighbors_after_round)

## [param curr_is_scared] 害怕检测的新状态，仅切换缩头/恢复表现，不施加异常状态。
func change_is_scared(curr_is_scared:bool):
	self.is_scared = curr_is_scared

## 完整四次周身脉冲结束后，对自身及八邻格敌人施毒；已中毒者改为立即结算一次普通剧毒伤害。
## 按实际格子边界及逻辑行定位，空中高度不改变归格；边缘只取存在的格子。
func _poison_neighbors_after_round() -> void:
	if is_death or is_sleeping or not is_instance_valid(Global.main_game) or not is_instance_valid(plant_cell):
		return
	# 场地实际格子行，避免使用害怕胶囊或周身攻击矩形替代九格范围。
	var rows: Array = Global.main_game.plant_cell_manager.all_plant_cells
	if lane < 0 or lane >= rows.size():
		return
	# 由本株格子引用取得中心列，兼容编辑器中的子节点倒序。
	var center_column: int = rows[lane].find(plant_cell)
	if center_column < 0:
		return
	# 施毒前保存当前僵尸引用，不向友方魅惑实例施毒。
	for reference: Variant in Global.main_game.zombie_manager.all_zombies_1d.duplicate():
		if not is_instance_valid(reference) or not reference is Zombie000Base:
			continue
		# 当前目标按自身行号和根节点横坐标归入格子。
		var zombie: Zombie000Base = reference as Zombie000Base
		if zombie.is_hypno or zombie.is_death or zombie.is_queued_for_deletion() \
			or zombie.lane < 0 or zombie.lane >= rows.size() or absi(zombie.lane - lane) > 1:
			continue
		# 本行中心列及左右邻列，越出场地的列不参与。
		for column: int in range(maxi(center_column - 1, 0), mini(center_column + 2, rows[zombie.lane].size())):
			# 格子横向边界不受僵尸跳跃、潜水或顶飞的显示高度影响。
			var bounds: Rect2 = (rows[zombie.lane][column] as PlantCell).get_global_rect()
			if zombie.global_position.x >= bounds.position.x and zombie.global_position.x < bounds.end.x:
				# 每个目标只进入一格分支：已有剧毒追加一次跳伤，未中毒则只施加状态。
				if zombie.is_poisoned:
					zombie.settle_poison_damage_once()
				else:
					zombie.be_poisoned()
				break

## 战斗手套的原实例搬运事务，不调用种植、铲除或死亡接口，不重置组件状态。
extends RefCounted
class_name BattlePlantMover


## [param plant] 待移动的存活植物；[param target] 放置格。支撑层可保留，不能覆盖或交换植物。
static func can_move(plant:Plant000Base, target:PlantCell) -> bool:
	if not is_instance_valid(plant) or plant.is_death or plant.is_queued_for_deletion() \
		or not is_instance_valid(target) or not is_instance_valid(plant.plant_cell) or target == plant.plant_cell:
		return false
	# 模仿者使用被模仿植物的实际种植层和地形条件。
	var type:CharacterRegistry.PlantType = plant.imitater_plant_type if plant is Plant999Imitater else plant.plant_type
	# 只读查询，不执行紫卡前置植物替换。
	var condition:ResourcePlantCondition = Global.character_registry.get_plant_info(type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	if not _empty_target(target, condition.place_plant_in_cell, plant is Plant036CoffeeBean):
		return false
	if plant is Plant012GraveBuster or plant is Plant036CoffeeBean:
		return condition.judge_is_can_plant(target, type)
	if not target.can_common_plant:
		return false
	# 猫尾草升级后自带水上表现，搬运不要求再消耗一株睡莲。
	if plant is Plant044Cattail:
		return (target.curr_condition & (8 | 16)) != 0
	if (condition.plant_condition & target.curr_condition) == 0:
		return false
	# 不拆走仍承载其他植物的睡莲或花盆，避免留下悬空植物和错误容器关系。
	if plant is Plant000DownBase:
		# 与种植次序检查保持一致，先接收可能失效的引用，再判断是否仍有承载植物。
		for occupant:Variant in plant.plant_cell.plant_in_cell.values():
			if is_instance_valid(occupant) and occupant != plant:
				return false
	if plant is Plant048CobCannon:
		# 玉米炮保持双格占位，目标右侧必须存在且能承载另一半炮身。
		var next_cell:PlantCell = _right_cell(target)
		return is_instance_valid(next_cell) and next_cell.can_common_plant \
			and _empty_target(next_cell, condition.place_plant_in_cell) \
			and (condition.plant_condition & next_cell.curr_condition) != 0
	return true


## [param cell] 待检查格；[param place] 搬运植物占位层；[param coffee] 咖啡豆允许目标有睡眠植物。
static func _empty_target(cell:PlantCell, place:int, coffee:bool=false) -> bool:
	for slot:int in cell.plant_in_cell:
		# 睡莲、花盆作为地形支撑保留；咖啡豆允许其唤醒对象留在普通层。
		if slot == CharacterRegistry.PlacePlantInCell.Down and place != slot:
			continue
		if coffee and slot == CharacterRegistry.PlacePlantInCell.Norm:
			continue
		if is_instance_valid(cell.plant_in_cell[slot]):
			return false
	return true


## [param cell] 炮身后轮格；返回右侧前轮格，越界时返回 null。
static func _right_cell(cell:PlantCell) -> PlantCell:
	# 各模式可能具有不同列数，按实际行长度检查。
	var cells:Array = Global.main_game.plant_cell_manager.all_plant_cells[cell.row_col.x]
	return cells[cell.row_col.y + 1] if cell.row_col.y + 1 < cells.size() else null


## [param plant] 原植物实例；[param target] 放置格。全部前置检查通过后同步迁移，成功返回 true。
static func move(plant:Plant000Base, target:PlantCell) -> bool:
	if not can_move(plant, target):
		return false
	# 迁移前的格子和实际登记层，模仿者可能挂在专用容器但登记在被模仿植物层。
	var source:PlantCell = plant.plant_cell
	# 查找真实占位，不依赖植物编号推断模仿者占位。
	var place:int = -1
	for slot:int in source.plant_in_cell:
		if source.plant_in_cell[slot] == plant:
			place = slot
			break
	if place < 0:
		return false
	# SpeedTimer 离树时主动 stop，保存剩余时间后恢复，避免重置准备、连发或生产进度。
	var timers:Array[Dictionary] = []
	for node:Node in plant.find_children("*", "Timer", true, false):
		# 当前原生计时器及其运行状态。
		var timer:Timer = node as Timer
		timers.append({"timer":timer, "remaining":timer.time_left, "period":timer.wait_time,
			"stopped":timer.is_stopped(), "paused":timer.paused})
	# 原死亡回调必须移至新格，数量统计保持不变，不能发出种植或死亡信号。
	_disconnect_cell(plant, source)
	if plant is Plant048CobCannon:
		_disconnect_cell(plant, plant.plant_cell_next)
		plant.plant_cell_next.plant_in_cell[place] = null
	if plant is Plant012GraveBuster and is_instance_valid(source.tombstone):
		source.tombstone.failure_eat_tombstone()
	if plant is Plant026Plantern:
		_update_plantern_pots(plant, source, false)
	if plant is Plant000DownBase:
		_detach_support(plant, source)
		source.down_plant_change_condition(source.plant_cell_type == PlantCell.PlantCellType.Pool)
	source.plant_in_cell[place] = null
	if is_instance_valid(source.ladder) and not is_instance_valid(source.get_plant_ladder()):
		# 梯子属于格子，失去承载植物后沿用原移除逻辑，不附着到搬运植物上。
		source.ladder.ladder_death()
	plant.plant_cell = target
	plant.row_col = target.row_col
	plant.lane = target.row_col.x
	# 仅调整空间补偿；其余血量、动画、目标、冷却及特殊机制变量均保留原值。
	for node:Node2D in plant.node2d_detect_in_slope:
		if is_instance_valid(node):
			node.position.y += source.position.y - target.position.y
	plant.reparent(target.plant_container_node[CharacterRegistry.PlacePlantInCell.Imitater if plant is Plant999Imitater else place], false)
	target.plant_in_cell[place] = plant
	plant.signal_character_death.connect(target.one_plant_free.bind(plant))
	if plant is Plant000DownBase:
		target.down_plant_change_condition(target.plant_cell_type == PlantCell.PlantCellType.Pool)
		_attach_support(plant, target)
	if plant is Plant048CobCannon:
		plant.plant_cell_next = _right_cell(target)
		plant.plant_cell_next.plant_in_cell[place] = plant
		plant.signal_character_death.connect(plant.plant_cell_next.one_plant_free.bind(plant))
	if plant is Plant012GraveBuster and is_instance_valid(target.tombstone):
		target.tombstone.start_be_grave_buster_eat()
	if plant is Plant026Plantern:
		_update_plantern_pots(plant, target, true)
	# 清雾组件离树时注销自身，重新挂载后恢复登记，不重复调用植物 ready。
	for component:Node in plant.find_children("*", "Node2D", true, false):
		if component is FogClearerComponent and is_instance_valid(component.fog_node) \
			and not component.fog_node.fog_clearers.has(component.area_2d_fog_clear):
			component.fog_node.add_fog_clearer(component.area_2d_fog_clear)
	# 原有每个 Timer 仍是同一对象，包括动态创建的充能与连发计时器。
	for state:Dictionary in timers:
		# 恢复剩余时间后写回原周期，保留循环计时器后续周期。
		var timer:Timer = state.timer
		if state.stopped:
			timer.stop()
		else:
			timer.start(maxf(state.remaining, 0.000001))
		timer.wait_time = state.period
		timer.paused = state.paused
	plant.signal_ladder_update.emit()
	# 清除僵尸当前指向搬运植物的啃食目标缓存。
	for detector:Node in Global.main_game.find_children("*", "Node2D", true, false):
		if detector is DetectComponent and detector.owner is Zombie000Base and detector.enemy_can_be_attacked == plant:
			# 等待新物理重叠结果期间，原格僵尸不能通过缓存引用继续啃食。
			detector.enemy_can_be_attacked = null
	# 等物理重叠结果更新后重判目标，旧格僵尸不能继续隔行啃食原引用。
	_refresh_detection.call_deferred(plant)
	return true


## [param plant] 被搬运植物；[param cell] 解除绑定的旧格，保留其他死亡监听。
static func _disconnect_cell(plant:Plant000Base, cell:PlantCell) -> void:
	# 只解绑由指定格子绑定的回调。
	var callback:Callable = cell.one_plant_free.bind(plant)
	if plant.signal_character_death.is_connected(callback):
		plant.signal_character_death.disconnect(callback)


## [param _plant] 保留的底层支撑植物接口参数；[param cell] 原格子。空的普通层和壳层容器留在原格。
static func _detach_support(_plant:Plant000DownBase, cell:PlantCell) -> void:
	for slot:int in [CharacterRegistry.PlacePlantInCell.Norm, CharacterRegistry.PlacePlantInCell.Shell]:
		# 保留原格容器，不随支撑植物一起搬走。
		var container:Control = cell.plant_container_node[slot]
		container.reparent(cell, false)
		container.global_position = cell.plant_postion_node_ori_global_position[slot]


## [param plant] 底层支撑植物；[param cell] 新格子，按原种植逻辑接入其普通层和壳层。
static func _attach_support(plant:Plant000DownBase, cell:PlantCell) -> void:
	for slot:int in [CharacterRegistry.PlacePlantInCell.Norm, CharacterRegistry.PlacePlantInCell.Shell]:
		# 新格子的空容器挂在支撑植物的浮动容器内。
		var container:Control = cell.plant_container_node[slot]
		container.reparent(plant.down_plant_container, false)
		container.global_position = cell.plant_postion_node_ori_global_position[slot] - plant.plant_up_position


## [param plant] 路灯花；[param cell] 旧或新格；[param adding] 添加或解除周围罐子的透视登记。
static func _update_plantern_pots(plant:Plant000Base, cell:PlantCell, adding:bool) -> void:
	for nearby:PlantCell in cell.get_plant_cell_surrounding():
		if not is_instance_valid(nearby.pot):
			continue
		# 罐子的死亡监听需同时解除，避免再次进入原范围时重复连接。
		var callback:Callable = nearby.pot.erase_plant_can_look_pot.bind(plant)
		if adding:
			nearby.pot.add_plant_can_look_pot(plant)
		else:
			if plant.signal_character_death.is_connected(callback):
				plant.signal_character_death.disconnect(callback)
			nearby.pot.erase_plant_can_look_pot(plant)


## [param plant] 已移动植物；延后两次物理更新，让双方检测器读取新坐标对应的重叠结果。
static func _refresh_detection(plant:Plant000Base) -> void:
	if not is_instance_valid(plant) or not plant.is_inside_tree():
		return
	# 等待期间植物可能死亡，只保留场景树引用，避免第二次等待解引用已释放植物。
	var tree:SceneTree = plant.get_tree()
	await tree.physics_frame
	await tree.physics_frame
	if not is_instance_valid(plant) or not is_instance_valid(Global.main_game) \
		or not Global.main_game.is_ancestor_of(plant):
		return
	# 所有植物与僵尸检测器重新按实际重叠范围和行号索敌。
	for detector:Node in Global.main_game.find_children("*", "Node2D", true, false):
		if detector is DetectComponent:
			detector.need_judge = true

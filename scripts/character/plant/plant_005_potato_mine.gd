extends Plant000Base
class_name Plant005PotatoMine

@onready var detect_component: DetectComponent = $DetectComponent
@onready var bomb_component: BombComponentBase = $BombComponent
@onready var prepare_timer: SpeedTimer = $PrepareTimer

## 准备时间
@export var prepare_time := 10.0

@export_group("动画状态")
@export var is_prepare_end := false

## 每株地雷只在第一次出土动画开始时检查一次邻格；读档恢复后也不重复部署。
var _spread_checked: bool = false


## 初始化正常出战角色
func ready_norm():
	super()
	## 土豆雷默认禁用攻击射线检测组件
	detect_component.disable_component(ComponentNormBase.E_IsEnableFactor.Prepare)
	## 默认禁用眨眼组件
	blink_component.disable_component(ComponentNormBase.E_IsEnableFactor.Prepare)

	# 已有速度因素先同步；在零速下种植也能保留完整准备任务。
	update_prepare_speed(GlobalUtils.get_dic_product(influence_speed_factors))
	prepare_timer.start_scaled(prepare_time)

	if is_zombie_mode:
		prepare_timer.stop()
		_on_prepare_timer_timeout()

func ready_norm_signal_connect():
	super()
	## 准备完成后才会检测到敌人(触发爆炸\直接死亡)
	detect_component.signal_can_attack.connect(bomb_component.bomb_once)
	detect_component.signal_can_attack.connect(character_death)

	## 角色速度改变
	signal_update_speed.connect(update_prepare_speed)

## 亡语
func death_language():
	bomb_component.judge_death_bomb()

## 土豆类出土动画结束调用
func _rise_end():
	detect_component.enable_component(ComponentNormBase.E_IsEnableFactor.Prepare)
	blink_component.enable_component(ComponentNormBase.E_IsEnableFactor.Prepare)
	bomb_component.is_auto_bomb_in_death = true


## 出土动画开始时安排一次邻格检查；展示角色不部署，延迟到安全时机创建新节点。
func _rise_start() -> void:
	if _spread_checked or character_init_type != E_CharacterInitType.IsNorm or is_death:
		return
	_spread_checked = true
	call_deferred("_deploy_adjacent_mine")


## 上下左右没有存活土豆地雷时，随机选择一个可种植邻格免费部署一株初始地雷。
func _deploy_adjacent_mine() -> void:
	if is_death or is_queued_for_deletion() or not is_instance_valid(plant_cell) \
		or not is_instance_valid(Global.main_game) or not Global.main_game.is_ancestor_of(self):
		return
	# 当前战场实际行列，禁止跨越地图边界或按固定五行地图假设索引。
	var cells: Array[Array] = Global.main_game.plant_cell_manager.all_plant_cells
	# 四个相邻格的行列偏移，不检查对角线或自身。
	var offsets: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	# 本次部署沿用土豆地雷的正式种植地形和占位条件。
	var condition: ResourcePlantCondition = Global.character_registry.get_plant_info(
		CharacterRegistry.PlantType.P005PotatoMine, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	# 没有同类阻止部署时可随机选择的合法相邻格。
	var candidates: Array[PlantCell] = []
	# 当前检查的四邻格偏移；行列以 row_col.x、row_col.y 分别表示。
	for offset: Vector2i in offsets:
		# 候选格坐标，先检查范围再读取二维数组。
		var coordinates: Vector2i = row_col + offset
		if coordinates.x < 0 or coordinates.x >= cells.size() \
			or coordinates.y < 0 or coordinates.y >= cells[coordinates.x].size():
			continue
		# 当前邻格及普通植物位置，已死亡或待删除的地雷不阻止部署。
		var cell: PlantCell = cells[coordinates.x][coordinates.y] as PlantCell
		var neighbor: Variant = cell.plant_in_cell[CharacterRegistry.PlacePlantInCell.Norm]
		if is_instance_valid(neighbor) and not neighbor.is_death and not neighbor.is_queued_for_deletion() \
			and neighbor.plant_type == CharacterRegistry.PlantType.P005PotatoMine:
			return
		if condition.judge_is_can_plant(cell, CharacterRegistry.PlantType.P005PotatoMine):
			candidates.append(cell)
	if candidates.is_empty():
		return
	# 从合法邻格等概率选择一个；不消耗卡牌或阳光，不继承父株准备进度或伤害。
	var destination: PlantCell = candidates.pick_random()
	destination.create_plant(CharacterRegistry.PlantType.P005PotatoMine, false, true, false, false)


## 保存已经检查过邻格的标记，避免多轮关卡恢复时重复部署。
func gat_save_game_data_plant() -> Dictionary:
	# 基础植物快照，附加本机制的一次性状态。
	var save_data: Dictionary = super()
	save_data["potato_spread_checked"] = _spread_checked
	return save_data


## 恢复 [param save_game_data_plant] 的邻格检查标记，其余属性沿用基础植物读档。
func load_game_data_plant(save_game_data_plant: Dictionary):
	_spread_checked = bool(save_game_data_plant.get("potato_spread_checked", false))
	super(save_game_data_plant)

## 准备时间结束
func _on_prepare_timer_timeout() -> void:
	is_prepare_end = true

## 重新设置准备时间
func set_prepare_time(new_prepare_time:float):
	prepare_time = new_prepare_time
	prepare_timer.start_scaled(prepare_time)

## 改变准备倍率时保留进度，不重复缩放剩余时间。
func update_prepare_speed(speed_factor:float):
	prepare_timer.set_speed_scale(speed_factor)

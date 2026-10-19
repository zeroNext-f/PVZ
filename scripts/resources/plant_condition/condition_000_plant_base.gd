extends Resource
class_name ResourcePlantCondition

@export_group("植物种植")
@export_flags("1 无", "2 草地", "4 花盆", "8 水", "16 睡莲", "32 屋顶/裸地")
## 植物种植地形条件（满足一个即可），默认（草地2+花盆4+睡莲16 = 22）
var plant_condition:int = 22

## 植物在格子中占的位置，
@export var place_plant_in_cell :CharacterRegistry.PlacePlantInCell = CharacterRegistry.PlacePlantInCell.Norm

## 是否为特殊植物，非特殊植物满足上面两点（地形条件、格子位置）种植即可,
## 特殊植物调用重写方法判断是否可以种植judge_special_plants_condition
@export var is_special_plants := false
## 是否为紫卡  紫卡非特殊植物, 特殊植物只走特殊植物判定方法,特殊紫卡(玉米炮)走特殊植物判定方法
@export var is_purple_card := false
## 是否允许替换同一种存活植物；默认关闭，仅坚果的独立种植条件资源开启。
@export var can_replant_same_type: bool = false
## 必须在格子没有任何其他植物时先行种植；仅花盆开启，避免后补到已有植物下方。
@export var requires_empty_cell_before_plant:bool = false
### 是否为双格植物,用于南瓜壳判断是否可以种植
#@export var is_double_plant_cell:=false


## 判断是否可以种植
func judge_is_can_plant(plant_cell:PlantCell, curr_plant_type:CharacterRegistry.PlantType) -> bool:
	if not judge_planting_order(plant_cell):
		return false
	## 特殊植物
	if is_special_plants:
		return judge_special_plants_condition(plant_cell)
	## 普通植物非紫卡
	elif not is_purple_card:
		# 当前占位引用可能已释放，先检查有效性，再判断是否允许同类补种。
		var existing_plant: Variant = plant_cell.plant_in_cell[place_plant_in_cell]
		# 普通植物默认只接受空位；配置允许补种时也接受相同种类的存活植物。
		var place_available: bool = not is_instance_valid(existing_plant)
		if not place_available and can_replant_same_type:
			place_available = existing_plant.plant_type == curr_plant_type \
				and not existing_plant.is_death and not existing_plant.is_queued_for_deletion()
		## 同类补种仍必须满足原本的格子可用状态和地形条件。
		if plant_cell.can_common_plant and plant_condition & plant_cell.curr_condition and place_available:
			## 如果是壳类植物,若当前植物格子中Norm为玉米加农炮
			if place_plant_in_cell == CharacterRegistry.PlacePlantInCell.Shell \
			and is_instance_valid(plant_cell.plant_in_cell[CharacterRegistry.PlacePlantInCell.Norm])\
			and plant_cell.plant_in_cell[CharacterRegistry.PlacePlantInCell.Norm].plant_type == CharacterRegistry.PlantType.P048CobCannon:
				return false

			return true
		else:
			return false
	else:
		if get_preplant_purple(plant_cell, curr_plant_type) != null:
			return true
		else:
			return false


## [param plant_cell] 待种植格；先种限制开启时，所有种植层都必须为空。
## 此检查同时供种植预览与实际创建入口调用，避免直接创建绕过种植次序。
func judge_planting_order(plant_cell:PlantCell) -> bool:
	if not requires_empty_cell_before_plant:
		return true
	# 植物死亡后格子可能保留已释放引用，先作为 Variant 接收，不能在有效性检查前强制转换。
	for existing_plant:Variant in plant_cell.plant_in_cell.values():
		if is_instance_valid(existing_plant):
			return false
	return true


## 判断当前场上是否有紫卡预种植植物,紫卡是否可以种植
func judge_purple_card_can_plant(all_plant_cells, curr_plant_type:CharacterRegistry.PlantType)->bool:
	for plant_cells_row in all_plant_cells:
		for plant_cell in plant_cells_row:
			if get_preplant_purple(plant_cell, curr_plant_type) != null:
				return true
	return false

## 获取当前格子紫卡预种植植物
## 返回预种植植物,若当前植物格子可以种植紫卡,返回预种植紫卡,
func get_preplant_purple(plant_cell:PlantCell, curr_plant_type:CharacterRegistry.PlantType) ->Plant000Base:
	## 紫卡前置植物
	var precondition_plant:CharacterRegistry.PlantType = Global.character_registry.AllPrePlantPurple[curr_plant_type]
	## 当前格子存在前置种植植物
	var condition_precondition_plant :ResourcePlantCondition = Global.character_registry.get_plant_info(precondition_plant, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
	var place_precondition_plant:CharacterRegistry.PlacePlantInCell = condition_precondition_plant.place_plant_in_cell
	if is_instance_valid(plant_cell.plant_in_cell[place_precondition_plant]) and\
	plant_cell.plant_in_cell[place_precondition_plant].plant_type == precondition_plant:
		## 如果种植位置不相同,并且当前植物格子已有紫卡植物位置的植物
		if place_precondition_plant != place_plant_in_cell and is_instance_valid(plant_cell.plant_in_cell[place_plant_in_cell]):
			return null
		else:
			return plant_cell.plant_in_cell[place_precondition_plant]
	else:
		return null


## 获取当前场上所有的紫卡植物的对应预种植植物
func get_all_preplant_purple(all_plant_cells, curr_plant_type:CharacterRegistry.PlantType):
	var all_preplant_purple:Array[Plant000Base]
	for plant_cells_row in all_plant_cells:
		for plant_cell in plant_cells_row:
			var preplant_purple:Plant000Base = get_preplant_purple(plant_cell, curr_plant_type)
			if preplant_purple != null:
				all_preplant_purple.append(preplant_purple)

	return all_preplant_purple

## 一般特殊植物(不能有同一位置植物)种植函数判断是否可以种植
func judge_special_plants_condition(plant_cell:PlantCell) -> bool:
	if is_instance_valid(plant_cell.plant_in_cell[place_plant_in_cell]):
		return false
	else:
		return _judge_special_plants_condition(plant_cell)

## 特殊植物种植函数判断是否可以种植，特殊植物重写,如墓碑吞噬者，咖啡豆等
func _judge_special_plants_condition(_plant_cell) -> bool:
	return true

## 水草整格清除能力；不播放抓取/下沉，不按伤害结算，只保留水花及其原音效。
extends Node2D
class_name GrapComponent

## 主动攻击只结算一次；补种的三格能力使用静态入口独立调用。
var _has_activated: bool = false

## [param zombie] 待抓取目标；按行和世界X查找实际场内格子，场外不折算到边缘格。
func get_target_cell(zombie:Zombie000Base) -> PlantCell:
	if not is_instance_valid(zombie) or not is_instance_valid(Global.main_game):
		return null
	# 实际行数组已按场地初始化，不使用可能倒序的row_col.y作为数组下标。
	var cells:Array = Global.main_game.plant_cell_manager.all_plant_cells[zombie.lane]
	for cell:PlantCell in cells:
		if zombie.global_position.x >= cell.global_position.x and zombie.global_position.x < cell.global_position.x + cell.size.x:
			return cell
	return null

## [param zombie] 合格主动目标；立即清除所在格，不施加抓取锁或播放身体动画。
func activate_it_to_grap_zombie(zombie: Zombie000Base) -> void:
	if _has_activated or not can_grab_target(zombie):
		return
	# 只读取主目标所在实际格，执行能力不依赖主目标随后继续存在。
	var cell: PlantCell = get_target_cell(zombie)
	if not is_instance_valid(cell):
		return
	_has_activated = true
	execute_cell_range(cell.row_col.x, cell.global_position.x, cell.size.x)

## [param zombie] 整格致死候选；潜水/海豚和水下状态均可被波及，仍排除死亡与魅惑友军。
static func _can_execute(zombie:Zombie000Base) -> bool:
	return is_instance_valid(zombie) and not zombie.is_death and not zombie.is_queued_for_deletion() \
		and not zombie.hp_component.is_death and not zombie.is_hypno

## [param zombie] 主动抓取候选；潜水与海豚无论浮起、骑乘或潜行均排除，其他水下目标也不主动抓。
static func can_grab_target(zombie: Zombie000Base) -> bool:
	return _can_execute(zombie) and not (zombie is Zombie012Snorkle or zombie is Zombie015Dolphinrider) \
		and (zombie.curr_be_attack_status & Zombie000Base.E_BeAttackStatusZombie.IsDownPool) == 0

## [param lane] 实际行号；[param start_x] 格子左界；[param width] 格宽。[br]
## 独立整格能力，不要求有水草、抓取主目标或水面实体，不创建额外植物，也不消耗新株。
static func execute_cell_range(lane: int, start_x: float, width: float) -> void:
	if not is_instance_valid(Global.main_game):
		return
	show_cell_splash(lane, start_x, width)
	# 快照避免死亡回调改变管理器列表；每次处理前都重新验证引用。
	var candidates:Array = Global.main_game.zombie_manager.all_zombies_1d.duplicate()
	for candidate_reference:Variant in candidates:
		if not is_instance_valid(candidate_reference):
			continue
		# 普通列表不包含独立僵王，僵王继续使用植物脚本的1800穿透分支。
		var zombie:Zombie000Base = candidate_reference as Zombie000Base
		if not _can_execute(zombie) or zombie.lane != lane:
			continue
		if zombie.global_position.x < start_x or zombie.global_position.x >= start_x + width:
			continue
		zombie.is_can_death_language = false
		zombie.character_death_disappear()

## [param source_cell] 成功补种的位置；[param direction] 新株朝向，正常植物向世界X正方向。[br]
## 本格及前后相邻格各执行一次；任一侧没有场内格时延伸一个虚拟格，不要求有植物或水面。
static func execute_replant_cells(source_cell: PlantCell, direction: int) -> void:
	if not is_instance_valid(source_cell) or not is_instance_valid(Global.main_game):
		return
	# 先保存三格范围，致死回调即使移除来源植物也不影响后续结算。
	var lane: int = source_cell.row_col.x
	var start_x: float = source_cell.global_position.x
	var width: float = source_cell.size.x
	var next_x: float = start_x + width * direction
	var next_width: float = width
	var nearest_distance: float = INF
	# 身后一格的默认虚拟范围及最近实际相邻格距离。
	var previous_x: float = start_x - width * direction
	var previous_width: float = width
	var nearest_previous_distance: float = INF
	# 按实际世界位置分别寻找前后最近格，兼容编辑器倒序列号。
	for cell: PlantCell in Global.main_game.plant_cell_manager.all_plant_cells[lane]:
		# 相对来源格的有向距离，正值为前方、负值为身后。
		var distance: float = (cell.global_position.x - start_x) * direction
		if distance > 0.0 and distance < nearest_distance:
			nearest_distance = distance
			next_x = cell.global_position.x
			next_width = cell.size.x
		elif distance < 0.0 and -distance < nearest_previous_distance:
			nearest_previous_distance = -distance
			previous_x = cell.global_position.x
			previous_width = cell.size.x
	execute_cell_range(lane, start_x, width)
	execute_cell_range(lane, next_x, next_width)
	execute_cell_range(lane, previous_x, previous_width)

## [param lane] 行号；[param start_x] 格子左界；[param width] 格宽；原水花场景自行播放入水音效。
static func show_cell_splash(lane: int, start_x: float, width: float) -> void:
	if not is_instance_valid(Global.main_game):
		return
	# 水花挂在行节点上，来源水草及目标立即移除后仍能完整播放。
	var row: ZombieRow = Global.main_game.zombie_manager.all_zombie_rows[lane]
	var splash: Splash = SceneRegistry.SPLASH.instantiate()
	row.add_child(splash)
	splash.global_position = Vector2(start_x + width * 0.5, row.zombie_create_position.global_position.y + 10.0)

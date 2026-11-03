## 海豚骑士；入场只决定一次是否插入水下潜行，出水后恢复原骑乘与跳跃流程。
extends Zombie000Base
class_name Zombie015Dolphinrider


## 原骑乘越障组件；潜行与出水期间保持默认禁用。
@onready var jump_component: JumpComponent = $JumpComponent
## 普通啃食检测；原越障结束后才开放。
@onready var detect_component: DetectComponent = %DetectComponent
## 原角色骨骼整体；潜行时隐藏，出水动画恢复显示。
@onready var _body_correct: Node2D = $Body/BodyCorrect
## 独立透明背鳍、水花与波纹素材，潜行时显示，独立于隐藏的骑士和海豚身体。
@onready var _underwater_fin: Sprite2D = $Body/UnderwaterFin

## 原越障动作是否正在播放，供动画状态机读取。
@export var is_jumping := false
## 保留原阻跳接口字段。
var is_jump_stop := false
## 保留原阻跳位置字段。
var jump_stop_postion :Vector2
## 入场时固定的分支选择；之后出现潜水僵尸不会再次开启潜行。
var _will_dive: bool = false
## 潜行或出水过渡尚未完成；此期间维持水下受击资格。
var is_underwater: bool = false
## 已提出出水请求，状态机只播放一次出水动画。
var is_surfacing: bool = false

## 是否骑着海豚(出泳池时,骑海豚时切换动画移动本体位置\死亡时判断(没有对应死亡动画))
var is_ride := true

## 正式入场时检查同路前方存活潜水僵尸，展示实例不参与该机制。
func ready_norm() -> void:
	super()
	detect_component.disable_component(ComponentNormBase.E_IsEnableFactor.Jump)
	_will_dive = not _get_forward_snorkles().is_empty()

## 返回同路、行进前方的所有存活潜水僵尸；不限定魅惑阵营，也不要求其当前已潜入水下。
func _get_forward_snorkles() -> Array[Zombie000Base]:
	# 每次读取当前全场列表，单只死亡不会覆盖其他仍存活的前方潜水僵尸。
	var result: Array[Zombie000Base] = []
	if not is_instance_valid(Global.main_game):
		return result
	# 当前列表项可能正在死亡或离树，先验证再读取身体位置。
	for zombie: Zombie000Base in Global.main_game.zombie_manager.all_zombies_1d:
		if not is_instance_valid(zombie) or zombie.is_queued_for_deletion() or zombie.is_death:
			continue
		if not zombie is Zombie012Snorkle or zombie.hp_component.is_death:
			continue
		if zombie.lane != lane:
			continue
		if (shadow.global_position.x - zombie.shadow.global_position.x) * direction_x_root > 0.0:
			result.append(zombie)
	return result

## [param world_x] 脚下世界横坐标；按实际格中心及相邻格距定位，场外返回空以免提前抵达边缘格。
func _get_pool_cell(world_x: float) -> PlantCell:
	# 当前行实际格子，不依赖编辑器倒序列号或固定格宽。
	var cells: Array = Global.main_game.plant_cell_manager.all_plant_cells[lane]
	# 距离最近的格子及中心距离。
	var nearest: PlantCell = null
	var distance: float = INF
	# 行内每个实际格子，用于确定最近中心。
	for cell: PlantCell in cells:
		if absf(cell.global_position.x - world_x) < distance:
			nearest = cell
			distance = absf(cell.global_position.x - world_x)
	if nearest == null:
		return null
	# 最近相邻中心的间距，用于排除场外坐标。
	var pitch: float = INF
	# 与最近格不同的格子，跳过自身的零距离。
	for cell: PlantCell in cells:
		if cell != nearest:
			pitch = minf(pitch, absf(cell.global_position.x - nearest.global_position.x))
	return nearest if distance <= pitch * 0.5 else null

## [param _delta] 物理帧耗时；仅在已进入潜行的这一次流程中检查到格和前方存活条件。
func _physics_process(_delta: float) -> void:
	if not is_underwater or is_surfacing or is_death or not is_swimming:
		return
	# 已入场开启潜行后，动态检查全部前方目标，而非绑定某一只的死亡信号。
	var snorkles: Array[Zombie000Base] = _get_forward_snorkles()
	if snorkles.is_empty():
		_request_surface()
		return
	# 使用脚下位置匹配实际格，避免骑乘贴图与本体的原有62像素偏移误判。
	var current_cell: PlantCell = _get_pool_cell(shadow.global_position.x)
	if current_cell == null:
		return
	# 任一仍存活的前方潜水僵尸与自身同格，即正常抵达并出水。
	for snorkle: Zombie000Base in snorkles:
		if _get_pool_cell(snorkle.shadow.global_position.x) == current_cell:
			_request_surface()
			return

## 请求一次出水；过渡完成前不开放越障，也不叠加自主移动。
func _request_surface() -> void:
	if is_surfacing or not is_underwater or is_death:
		return
	is_surfacing = true
	# 使用项目现有水面遮罩，骑士和海豚从水线下升起，避免直接显出完整身体。
	body.body_mask_start()
	move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsSwimingChange)

## 出水动画末帧调用；恢复原正常受击和80基础骑乘速度模式，再开放原越障检测。
func dolphin_surface_end() -> void:
	if is_death or not is_swimming:
		return
	body.body_mask_end()
	is_underwater = false
	is_surfacing = false
	_resume_riding()
	move_component.update_move_factor(false, MoveComponent.E_MoveFactor.IsSwimingChange)

## 入水直接骑乘和潜行出水共用的原骑乘入口，不重置原速度倍率。
func _resume_riding() -> void:
	# 潜行穿越过的高坚果不能把旧阻跳位置带入之后的越障动画。
	jump_component.is_jump_stop = false
	jump_component.jump_stop_postion = Vector2.ZERO
	jump_component._jump_stop_plant = null
	jump_component._jump_stop_cost_paid = false
	curr_be_attack_status = E_BeAttackStatusZombie.IsNorm
	signal_status_update.emit()
	move_component.update_move_mode(MoveComponent.E_MoveMode.Speed)
	shadow.visible = false
	jump_component.enable_component(ComponentNormBase.E_IsEnableFactor.Default)
	_refresh_forward_tall_nut_blocker()

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	jump_component.signal_jump_start.connect(jump_start)
	jump_component.signal_jump_end.connect(jump_end)
	jump_component.signal_jump_end_end.connect(jump_end_end)

	jump_component.signal_jump_end_end.connect(detect_component.enable_component.bind(ComponentNormBase.E_IsEnableFactor.Jump))
	## 跳跃对移动影响
	jump_component.signal_jump_start.connect(move_component.update_move_factor.bind(true, MoveComponent.E_MoveFactor.IsJump))
	jump_component.signal_jump_end_end.connect(move_component.update_move_factor.bind(false, MoveComponent.E_MoveFactor.IsJump))


## 开始跳跃,跳跃组件信号发射调用
func jump_start():
	print("开始跳跃")
	is_jumping = true
	is_ride = false
	curr_be_attack_status = E_BeAttackStatusZombie.IsJump
	signal_status_update.emit()
	_refresh_forward_tall_nut_blocker()

## 僵尸跳跃结束,跳跃组件信号发射调用
func jump_end():
	is_jumping = false
	jump_component.disable_component(ComponentNormBase.E_IsEnableFactor.Jump)


## 僵尸跳跃后摇结束
func jump_end_end():
	curr_be_attack_status = E_BeAttackStatusZombie.IsNorm
	move_component.update_move_mode(MoveComponent.E_MoveMode.Ground)
	is_trigger_squash_pos_judge = false
	is_trigger_tall_nut_stop_jump = false
	print("是否触发倭瓜位置判断修改")

## [param plant] 触发阻跳的高坚果；潜行、出水过渡和已越过的植物不记录阻跳，避免后续跳跃被拉回。
func jump_be_stop(plant:Plant000Base):
	if is_underwater or is_surfacing or not is_swimming or is_death \
		or not is_instance_valid(plant) or plant.is_death or plant.is_queued_for_deletion():
		return
	if (shadow.global_position.x - plant.global_position.x) * direction_x_root < 0.0:
		return
	jump_component.jump_be_stop(plant)

## 恢复骑乘或实际起跳时核对仍接触的前方高坚果，补齐潜行期间已进入区域而不会重新发进入信号的情况。
func _refresh_forward_tall_nut_blocker() -> void:
	if is_underwater or is_surfacing or not is_swimming or is_death or not is_instance_valid(Global.main_game):
		return
	for cell:PlantCell in Global.main_game.plant_cell_manager.all_plant_cells[lane]: # 当前水路真实格子。
		# 格子可能短暂保留已释放植物引用，必须先以Variant验证，再做类型判断和强制转换。
		var occupant:Variant = cell.plant_in_cell.get(CharacterRegistry.PlacePlantInCell.Norm)
		if not is_instance_valid(occupant):
			continue
		if not occupant is Plant024TallNut:
			continue
		# 已验证仍存活的实例类型，仅使用当前格内高坚果，不转用旧植物引用。
		var plant:Plant024TallNut = occupant as Plant024TallNut
		if plant.is_death or plant.is_queued_for_deletion():
			continue
		if (shadow.global_position.x - plant.global_position.x) * direction_x_root < 0.0:
			continue
		# 使用原高坚果实际阻跳区域，保持正常阻跳距离和720伤害结算时机。
		var stop_area:Area2D = plant.get_node("Area2DStopJump") as Area2D
		if not stop_area.monitoring:
			continue
		for area:Area2D in stop_area.get_overlapping_areas(): # 当前实际接触阻跳区的角色受击框。
			if area.owner == self:
				jump_be_stop(plant)
				return

## [param value] 是否接触泳池；离水清理潜行表现，保留原骑乘离水位置补偿。
func change_is_swimming(value:bool):
	if is_swimming == value:
		return
	is_swimming = value
	#move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsSwimingChange)
	#shadow.visible = not value
	## 如果是跳入泳池
	if is_swimming:
		# 已失去海豚后重新接触水面应回游泳，不重播携海豚入水或恢复骑乘速度。
		curr_be_attack_status = E_BeAttackStatusZombie.IsJumpInPool if is_ride else E_BeAttackStatusZombie.IsNorm
		if not is_ride:
			shadow.visible = false
			move_component.update_move_mode(MoveComponent.E_MoveMode.Ground)
		#print("当前状态:", curr_be_attack_status)
		signal_status_update.emit()
	else:
		if is_underwater:
			if is_surfacing:
				body.body_mask_end()
			is_underwater = false
			is_surfacing = false
			_underwater_fin.visible = false
			_body_correct.visible = true
			curr_be_attack_status = E_BeAttackStatusZombie.IsNorm
			signal_status_update.emit()
			move_component.update_move_factor(false, MoveComponent.E_MoveFactor.IsSwimingChange)
		move_component.update_move_mode(MoveComponent.E_MoveMode.Ground)
		## 如果骑海豚到泳池边缘离开泳池
		if is_ride:
			await get_tree().process_frame
			global_position.x -= 62
			move_component._walking_start()


## 动画调用函数
## 共用原入水动画的末帧入口；只按入场快照插入一次潜行，入水原水花关键帧保持。
func zombie_jump_in_pool_end():
	if is_death:
		return
	move_component.update_move_mode(MoveComponent.E_MoveMode.Speed)
	shadow.visible = false
	if _will_dive:
		is_underwater = true
		curr_be_attack_status = E_BeAttackStatusZombie.IsDownPool
		signal_status_update.emit()
	else:
		_resume_riding()

## 角色死亡
func character_death():
	if is_surfacing:
		body.body_mask_end()
	super()
	## 如果骑着海豚死亡,没有对应死亡动画
	if is_ride:
		await get_tree().create_timer(2.0, false).timeout
		queue_free()

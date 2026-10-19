## 与铲子同属手持道具，选择原植物并在合法目标格完成实例迁移。
extends Node
class_name HMGlove

## 共用的手持管理器。
@onready var hand_manager:HandManager = %HandManager
## 工具栏图标、快捷键和冷却入口。
@onready var ui_glove:UIBattleGlove = %UIBattleGlove
## 已选择的原植物；携带期间仍在原格正常运行，取消不会损失植物。
var carried_plant:Plant000Base
## 预选植物，未拿起时按铲子的鼠标分层规则选择。
var hovered_plant:Plant000Base
## 当前鼠标所在目标格。
var target_cell:PlantCell
## 搬运展示的父节点，保留原植物缩放。
var hand_preview:Node2D
## 目标格的半透明静态预览。
var target_preview:Node2D


## 激活手套，不在此时扣冷却。
func activate() -> void:
	ui_glove.set_using(true)
	SoundManager.play_other_SFX("tap2")


## 每帧确认来源存活，并更新分层预选、手持展示与落点虚影。
func item_process() -> void:
	if is_instance_valid(carried_plant):
		if carried_plant.is_death or carried_plant.is_queued_for_deletion():
			hand_manager.curr_hm_status = HandManager.E_HandManagerStatus.Null
			return
		if is_instance_valid(hand_preview):
			# 携带展示与手套图标都在前景画布，不能使用工具栏画布的鼠标坐标。
			hand_preview.global_position = hand_preview.get_global_mouse_position() + Vector2(0, -20)
	elif is_instance_valid(target_cell):
		_set_hover(target_cell.return_plant_be_shovel_look())
	if is_instance_valid(target_preview):
		target_preview.visible = is_instance_valid(carried_plant) and BattlePlantMover.can_move(carried_plant, target_cell)


## [param plant] 新预选植物，切换前恢复旧预选颜色。
func _set_hover(plant:Plant000Base) -> void:
	if hovered_plant == plant:
		return
	if is_instance_valid(hovered_plant):
		hovered_plant.be_shovel_look_end()
	hovered_plant = plant
	if is_instance_valid(hovered_plant) and not hovered_plant.is_death:
		hovered_plant.be_shovel_look()


## [param cell] 鼠标进入的格子；拿起后仅建立合法目标虚影。
func mouse_enter(cell:PlantCell) -> void:
	target_cell = cell
	_clear_target_preview()
	if is_instance_valid(carried_plant):
		if BattlePlantMover.can_move(carried_plant, cell):
			target_preview = _make_preview(carried_plant)
			target_preview.modulate.a = 0.6
			target_preview.global_position = cell.plant_container_node[_place(carried_plant)].global_position
	else:
		_set_hover(cell.return_plant_be_shovel_look())


## 鼠标移出格子，清理落点虚影与未拿起的高亮。
func mouse_exit() -> void:
	target_cell = null
	_clear_target_preview()
	if not is_instance_valid(carried_plant):
		_set_hover(null)


## [param cell] 左键格子；第一次拿起，第二次尝试放置；返回 true 表示应退出手持状态。
func click_cell(cell:PlantCell) -> bool:
	if not is_instance_valid(carried_plant):
		_set_hover(cell.return_plant_be_shovel_look())
		if not is_instance_valid(hovered_plant) or hovered_plant.is_death or hovered_plant.is_queued_for_deletion():
			return true
		carried_plant = hovered_plant
		_set_hover(null)
		hand_preview = _make_preview(carried_plant)
		hand_preview.global_position = hand_preview.get_global_mouse_position() + Vector2(0, -20)
		carried_plant.body.set_other_color(BodyCharacter.E_ChangeColors.GloveColor, Color(0.3, 0.3, 0.3))
		carried_plant.signal_character_death.connect(_on_source_dead)
		return false
	if not BattlePlantMover.can_move(carried_plant, cell):
		return true
	# 格子按钮回调在空闲帧执行，迁移后才开始冷却。
	if BattlePlantMover.move(carried_plant, cell):
		ui_glove.start_cooldown()
		SoundManager.play_other_SFX("plant2")
	return true


## 来源在携带期间死亡时立即取消，预览不能复活或复制植物。
func _on_source_dead() -> void:
	hand_manager.curr_hm_status = HandManager.E_HandManagerStatus.Null


## 退出手套，清理展示并恢复仍存活来源的颜色，不触发铲除或死亡效果。
func exit_status() -> void:
	_set_hover(null)
	if is_instance_valid(carried_plant):
		carried_plant.body.set_other_color(BodyCharacter.E_ChangeColors.GloveColor, Color.WHITE)
		if carried_plant.signal_character_death.is_connected(_on_source_dead):
			carried_plant.signal_character_death.disconnect(_on_source_dead)
	carried_plant = null
	target_cell = null
	if is_instance_valid(hand_preview):
		hand_preview.queue_free()
	hand_preview = null
	_clear_target_preview()
	ui_glove.set_using(false)


## 删除旧目标预览，不影响目标格的真实植物。
func _clear_target_preview() -> void:
	if is_instance_valid(target_preview):
		target_preview.queue_free()
	target_preview = null


## [param plant] 来源植物；仅复制无脚本的身体展示，剔除碰撞和粒子，不生成战斗实例。
func _make_preview(plant:Plant000Base) -> Node2D:
	# 展示容器放到鼠标前景层，与真实植物生命周期独立。
	var preview:Node2D = Node2D.new()
	preview.scale = plant.scale
	preview.z_index = 90
	# 不复制脚本、信号、组或实例化逻辑，因此不启动生产、攻击和特殊机制。
	var body:Node2D = plant.body.duplicate(0) as Node2D
	if plant == carried_plant and plant.body.change_color.get(BodyCharacter.E_ChangeColors.GloveColor, Color.WHITE) != Color.WHITE:
		# 来源变暗只属于原格，目标虚影保留原有生产、冻结与受击颜色。
		body.modulate /= Color(0.3, 0.3, 0.3, 1.0)
	_strip_preview(body)
	preview.add_child(body)
	get_tree().current_scene.get_node("CanvasLayerTemp").add_child(preview)
	return preview


## [param node] 静态展示子树；移除碰撞对象、计时器和动画播放器，防止复制行为或鼠标拦截。
func _strip_preview(node:Node) -> void:
	for child:Node in node.get_children():
		if child is CollisionObject2D or child is Timer or child is AnimationPlayer or child is AnimationTree:
			node.remove_child(child)
			child.free()
		else:
			if child is GPUParticles2D or child is CPUParticles2D:
				child.set("emitting", false)
			if child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_strip_preview(child)


## [param plant] 原植物或模仿者，返回用于目标虚影的占位层。
func _place(plant:Plant000Base) -> int:
	# 模仿者登记层由被模仿植物决定。
	var type:int = plant.imitater_plant_type if plant is Plant999Imitater else plant.plant_type
	return Global.character_registry.get_plant_info(type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource).place_plant_in_cell

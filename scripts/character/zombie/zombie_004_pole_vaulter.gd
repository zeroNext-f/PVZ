extends Zombie000Base
class_name Zombie004PoleVaulter

@onready var jump_component: JumpComponent = $JumpComponent
@onready var detect_component: DetectComponent = %DetectComponent

@export var is_jumping := false
var is_jump_stop := false
var jump_stop_postion :Vector2

## 监测到脑子
var is_detect_brain:=false

## 每次出战只释放一名落地小丑，防止阻跳与动画结束重复通知。
var _landing_jackbox_spawned:bool = false

func ready_norm() -> void:
	super()
	detect_component.disable_component(ComponentNormBase.E_IsEnableFactor.Jump)

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

	## 我是僵尸模式检测到脑子
	jump_component.signal_detect_brain.connect(_on_jump_detect_brain)

## 开始跳跃,跳跃组件信号发射调用
func jump_start():
	is_jumping = true
	curr_be_attack_status = E_BeAttackStatusZombie.IsJump
	signal_status_update.emit()

## 僵尸跳跃结束,跳跃组件信号发射调用
func jump_end():
	is_jumping = false
	jump_component.disable_component(ComponentNormBase.E_IsEnableFactor.Jump)

## 僵尸跳跃后摇结束
func jump_end_end():
	curr_be_attack_status = E_BeAttackStatusZombie.IsNorm
	signal_status_update.emit()
	is_trigger_squash_pos_judge = false
	is_trigger_tall_nut_stop_jump = false
	if not _landing_jackbox_spawned:
		_landing_jackbox_spawned = true
		# 高坚果阻跳的坐标在信号返回后才写入；提前使用同一修正值锁定落点。
		var landing_x:float = jump_component.jump_stop_postion.x + 20.0 if jump_component.is_jump_stop else global_position.x
		_spawn_landing_jackbox.call_deferred(landing_x)


## 等待最终落点后生成开盒小丑，成功释放后自身直接死亡移除；死亡、离树或战斗结束时取消。[br]
## [param landing_x] 跳跃结束瞬间锁定的落点世界横坐标，不随随后步行变化。
func _spawn_landing_jackbox(landing_x:float) -> void:
	await get_tree().process_frame
	if is_death or is_queued_for_deletion() or not is_inside_tree() or not is_instance_valid(Global.main_game):
		return
	# 复用正式创建入口，参与存活敌人数，但不占用自然波次预算与提前刷新统计。
	var manager:ZombieManager = Global.main_game.zombie_manager
	if not manager.is_game_running() or lane < 0 or lane >= manager.all_zombie_rows.size():
		return
	# 行基准高度不含坡面修正，新僵尸 ready 时会按落点 X 应用一次坡面高度。
	var row:ZombieRow = manager.all_zombie_rows[lane]
	# 保留落点横坐标，避免屋顶上重复叠加来源的坡面高度。
	var landing_position:Vector2 = Vector2(landing_x, row.zombie_create_position.global_position.y)
	# 衍生单位独立于自然波次，使用通用管理器登记死亡与胜负计数。
	var parameters:Dictionary = {
		Zombie000Base.E_ZInitAttr.CharacterInitType: E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
		Zombie000Base.E_ZInitAttr.CurrWave: -1,
		Zombie000Base.E_ZInitAttr.ParticipatesNaturalRefresh: false,
	}
	# 初始化回调在入树前标记立即开盒，正常播放全部开盒关键帧。
	var jackbox:Zombie000Base = manager.create_norm_zombie(
		CharacterRegistry.ZombieType.Z016Jackbox, row, parameters, landing_position, _prepare_landing_jackbox)
	if not is_instance_valid(jackbox):
		return
	if is_hypno:
		jackbox.be_hypno()
	# 先完成小丑登记与阵营继承，再移除自身，避免末波敌人数在召唤前短暂归零。
	character_death_disappear()


## [param zombie] 正式创建入口刚实例化的小丑，在 ready 前注入开盒出生标记。
func _prepare_landing_jackbox(zombie:Zombie000Base) -> void:
	(zombie as Zombie016Jackbox).spawn_with_open_box = true

## 跳跃被强行停止,高坚果调用
func jump_be_stop(plant:Plant000Base):
	jump_component.jump_be_stop(plant)

## 跳跃之前检测到脑子
func _on_jump_detect_brain():
	is_detect_brain=true
	detect_component.enable_component(ComponentNormBase.E_IsEnableFactor.Jump)

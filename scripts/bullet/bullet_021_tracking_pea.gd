## 独立追踪豌豆：固定40伤害，整理0.3游戏秒后初选，飞行中目标失效后不重新寻敌。
extends BulletLinear000Base
class_name Bullet021TrackingPea

## 猫尾草贝塞尔移动组件，复用移动能力但不使用尖刺的索敌脚本。
@onready var tracking_movement:BulletMovementTrack = $MovementComponent
## 统一出弹整理耗时，单位为游戏秒。
const LAUNCH_SECONDS:float = 0.3
## 整理结束时调用的初选委托。
var _initial_target_selector:Callable
## 本弹当前追踪目标，死亡和离树信号清除引用，其他资格变化由物理帧检查。
var _target_enemy:Character000Base = null
## 是否已结束出弹整理。
var _tracking_started:bool = false
## 当前纵向整理动画。
var _launch_tween:Tween
## 纵向整理的原始起止世界高度及已推进比例。
var _launch_start_y:float = 0.0
## 纵向整理的终点世界高度。
var _launch_target_y:float = 0.0
## 原始整理过程归一化进度。
var _launch_progress:float = 0.0
## 过火前保存的运行状态，入树后恢复。
var _pending_tracking_state:Dictionary = {}

## 初始化移动组件后恢复过火快照，不重新索敌或重启完整整理。
func _ready() -> void:
	super()
	if not _pending_tracking_state.is_empty():
		_restore_tracking_state()

## [param selector] 初选委托；[param target_y] 上中下弹的目标世界高度。
func start_launch(selector:Callable, target_y:float) -> void:
	_initial_target_selector = selector
	_launch_start_y = global_position.y
	_launch_target_y = target_y
	_start_launch_tween(0.0)

## [param progress] 原始整理进度；过火后只运行剩余游戏时间。
func _start_launch_tween(progress:float) -> void:
	_launch_progress = progress
	_launch_tween = create_tween()
	_launch_tween.tween_method(_advance_launch, progress, 1.0, maxf(LAUNCH_SECONDS * (1.0 - progress), 0.001))
	_launch_tween.tween_callback(_choose_initial_target)

## [param progress] 线性进度，通过正弦缓出调整纵向位置。
func _advance_launch(progress:float) -> void:
	_launch_progress = progress
	global_position.y = lerpf(_launch_start_y, _launch_target_y, sin(progress * PI * 0.5))

## 返回过火所需运行快照；移动轨迹、整理进度与原目标保持，不复制伤害计数。
func capture_tracking_state() -> Dictionary:
	# 贝塞尔组件中仅保存值类型运行字段，不保存节点引用。
	var movement:Dictionary = {}
	for key:String in ["all_time", "curr_time", "start_global_pos", "start_control_point", "second_control_point", "end_global_pos", "bezier_next_point", "bezier_t", "next_point", "curr_bullet_speed_r", "curr_target_type"]: # 待保留的移动运行字段。
		movement[key] = tracking_movement.get(key)
	return {"started":_tracking_started, "target":weakref(_target_enemy) if _target_enemy != null else null,
		"selector":_initial_target_selector, "launch_start_y":_launch_start_y, "launch_target_y":_launch_target_y,
		"launch_progress":_launch_progress, "movement":movement, "start_pos":start_pos, "rotation":$Body.rotation}

## [param state] 过火前快照；由火炬在新子弹入树前注入。
func restore_tracking_state_on_ready(state:Dictionary) -> void:
	_pending_tracking_state = state

## 组件就绪后还原快照，重新连接同一目标的生命周期信号。
func _restore_tracking_state() -> void:
	_tracking_started = _pending_tracking_state.started
	_initial_target_selector = _pending_tracking_state.selector
	_launch_start_y = _pending_tracking_state.launch_start_y
	_launch_target_y = _pending_tracking_state.launch_target_y
	_launch_progress = _pending_tracking_state.launch_progress
	start_pos = _pending_tracking_state.start_pos
	$Body.rotation = _pending_tracking_state.rotation
	for key:String in _pending_tracking_state.movement: # 恢复原贝塞尔状态，不重新起飞。
		tracking_movement.set(key, _pending_tracking_state.movement[key])
	# 弱引用避免过火帧间目标已销毁时使用失效实例。
	var reference:WeakRef = _pending_tracking_state.target
	_target_enemy = reference.get_ref() if reference != null else null
	if is_instance_valid(_target_enemy) and not _target_enemy.is_death and not _target_enemy.is_queued_for_deletion():
		_target_enemy.signal_character_death.connect(_on_target_lost)
		_target_enemy.tree_exiting.connect(_on_target_lost)
	else:
		_target_enemy = null
	_pending_tracking_state = {}
	if not _tracking_started:
		_start_launch_tween(_launch_progress)

## 整理完成后调用植物委托初选，后续目标失效后不再选择新敌人。
func _choose_initial_target() -> void:
	if is_queued_for_deletion():
		return
	_tracking_started = true
	# 此处保留植物初选与鼠标引导，飞行期间目标失效后仅清空目标。
	var candidate:Variant = _initial_target_selector.call() if _initial_target_selector.is_valid() else null
	_initial_target_selector = Callable()
	if is_instance_valid(candidate) and _can_attack_character(candidate, false):
		_target_enemy = candidate as Character000Base
		_target_enemy.signal_character_death.connect(_on_target_lost)
		_target_enemy.tree_exiting.connect(_on_target_lost)
		tracking_movement.reset_track_movement(true, true, _target_enemy.hurt_box_component.global_position)
		_try_attack_initial_target_if_overlapping()
	else:
		tracking_movement.reset_track_movement(false)

## [param area] 进入弹体的区域；沿用猫尾草只命中当前目标，其他角色不阻挡或消耗本弹，坡面规则保持原样。
func _on_area_2d_attack_area_entered(area:Area2D) -> void:
	if area.owner is Slope:
		super(area)
		return
	if not _tracking_started or not is_instance_valid(_target_enemy) or area.owner != _target_enemy:
		return
	if not _can_attack_character(_target_enemy, false):
		return
	if max_attack_num == -1 or curr_attack_num < max_attack_num:
		attack_once(_target_enemy)

## [param delta] 游戏物理帧秒数；目标失效后不重选，按开关跟鼠标或以自身基础速度离场。
func _physics_process(delta:float) -> void:
	if not _tracking_started:
		position += direction * speed * delta
		if global_position.distance_to(start_pos) > max_distance:
			queue_free()
		return
	if is_instance_valid(_target_enemy) and _can_attack_character(_target_enemy, false):
		tracking_movement.reset_track_movement(true, false, _target_enemy.hurt_box_component.global_position)
	else:
		_on_target_lost()
		if not Global.config_service.track_bullet_mouse:
			_move_out_without_target(delta)
			return
		else:
			tracking_movement.reset_track_movement(false)
	super(delta)

## [param delta] 游戏物理帧秒数；无目标时按自身speed沿当前方向离场，不额外加速或减速，出视野或到距离上限即释放。
func _move_out_without_target(delta:float) -> void:
	# 当前方向由上一段追踪保留，极端零向量退回向右，避免无目标弹滞留场内。
	var exit_direction:Vector2 = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	global_position += exit_direction * speed * delta
	# 将世界位置转换为视口坐标，兼容战场摄像机；留32像素余量让贴图完整离开画面再清除。
	var screen_position:Vector2 = get_global_transform_with_canvas().origin
	var visible_area:Rect2 = get_viewport_rect().grow(32.0)
	if not visible_area.has_point(screen_position) or global_position.distance_to(start_pos) > max_distance:
		queue_free()

## 初选完成后补判已经重叠的目标受击框，避免没有新area_entered导致漏击；仅补判有限命中子弹。
func _try_attack_initial_target_if_overlapping() -> void:
	if not is_instance_valid(_target_enemy) or not _can_attack_character(_target_enemy, false) \
		or max_attack_num == -1 or curr_attack_num >= max_attack_num or not area_2d_attack.monitoring:
		return
	for area:Area2D in area_2d_attack.get_overlapping_areas(): # 初选目标可能已位于当前子弹碰撞范围内。
		if area.owner == _target_enemy:
			attack_once(_target_enemy)
			return

## 目标死亡或离树时清除引用，按开关跟鼠标或离场，不重新寻敌。
func _on_target_lost() -> void:
	_disconnect_target()
	_target_enemy = null

## 清理本弹独立的生命周期订阅。
func _disconnect_target() -> void:
	if not is_instance_valid(_target_enemy):
		return
	if _target_enemy.signal_character_death.is_connected(_on_target_lost):
		_target_enemy.signal_character_death.disconnect(_on_target_lost)
	if _target_enemy.tree_exiting.is_connected(_on_target_lost):
		_target_enemy.tree_exiting.disconnect(_on_target_lost)

## 命中、过火或清场时释放目标订阅。
func _exit_tree() -> void:
	_disconnect_target()

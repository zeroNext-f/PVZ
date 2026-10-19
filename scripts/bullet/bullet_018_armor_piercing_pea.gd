## 编号 18 的破甲豌豆：原弹命中后只分裂一代，上下 45 度各两颗；跳过一类防具，二类防具阻止分裂。
extends BulletLinear000Base
class_name Bullet018ArmorPiercingPea

## 独立的延迟生成任务，避免原弹命中释放后分裂丢失，也避开物理碰撞回调创建节点。
const SPLIT_BURST_SCRIPT:Script = preload("res://scripts/bullet/component/armor_pea_split_burst.gd")
## 原弹允许分裂；生成的四颗子弹在入树前设为 false，确保一轮两原弹最多共十颗。
@export var can_split:bool = true
## 分裂弹跳过触发分裂的原目标，防止出生在其受击框内立刻重复命中。
var ignored_target_id:int = 0
## 一颗子弹只允许一次命中结算，防止目标多个受击框重复生成分裂。
var _hit_resolved:bool = false
## 出生时相对所属行的垂直偏移，仅用于斜向飞行时同步绘制行和层级。
var _row_height_offset:float = 0.0


## 记录原本飞行高度，分裂弹仍按普通豌豆速度沿归一化方向飞行。
func _ready() -> void:
	super()
	if is_instance_valid(Global.main_game):
		# 本场地的僵尸行标记，使用世界坐标避免混用不同画布。
		var rows:Array[ZombieRow] = Global.main_game.zombie_manager.all_zombie_rows
		if lane >= 0 and lane < rows.size():
			_row_height_offset = global_position.y - rows[lane].zombie_create_position.global_position.y


## [param enemy] 候选目标；[param check_lane] 保留基类行检查，分裂弹由初始化参数关闭行限制。
func _can_attack_character(enemy:Character000Base, check_lane:bool=true) -> bool:
	if is_instance_valid(enemy) and enemy.get_instance_id() == ignored_target_id:
		return false
	return super(enemy, check_lane)


## [param enemy] 本次命中目标；撞地或命中尚存二类防具的目标不分裂，是否阻挡以扣血前状态为准。
func attack_once(enemy:Character000Base):
	if _hit_resolved or is_queued_for_deletion():
		return
	if enemy != null and not _can_attack_character(enemy):
		return
	_hit_resolved = true
	# 在伤害结算前读取二类防具，即使本次击碎防具，也不能触发分裂。
	var target_hp:HpComponentZombie = enemy.hp_component as HpComponentZombie if enemy != null else null
	# 无二类防具组件的目标沿用原分裂规则，已耗尽或脱落的二类防具不再阻挡。
	var blocked_by_armor2:bool = target_hp != null and target_hp.curr_hp_armor2 > 0
	if enemy != null and can_split and not blocked_by_armor2:
		_queue_split(enemy)
	super(enemy)


## [param enemy] 触发分裂的目标，只保存实例编号，不持有可能被致死释放的目标引用。
func _queue_split(enemy:Character000Base) -> void:
	# 分裂任务和子弹统一使用原弹父容器的坐标空间。
	var bullet_parent:Node2D = get_parent() as Node2D
	if bullet_parent == null or bullet_parent.is_queued_for_deletion():
		return
	# 独立任务在入树后的安全帧生成四颗分裂弹，原弹无需等待任务完成。
	var burst:Node2D = SPLIT_BURST_SCRIPT.new()
	burst.position = position
	burst.set("shot_parameters", get_bullet_paras())
	burst.set("shot_camp", bullet_camp)
	burst.set("ignored_target_id", enemy.get_instance_id())
	bullet_parent.call_deferred("add_child", burst)


## [param delta] 物理帧时长；移动和销毁沿用普通豌豆，斜向弹仅按位置更新显示层级。
func _physics_process(delta:float) -> void:
	super(delta)
	if can_split or not is_instance_valid(Global.main_game):
		return
	# 当前最近的行及其距离，仅用于绘制；实际命中由空间碰撞和状态过滤决定。
	var nearest_lane:int = lane
	var nearest_distance:float = INF
	# 本场地实际行高，允许泳池、屋顶等不同布局。
	var rows:Array[ZombieRow] = Global.main_game.zombie_manager.all_zombie_rows
	for row_index:int in range(rows.size()):
		# 将子弹的原始飞行高度偏移还原后比较行标记。
		var distance:float = absf(global_position.y - _row_height_offset - rows[row_index].zombie_create_position.global_position.y)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_lane = row_index
	lane = nearest_lane
	z_index = lane * 50 + 45

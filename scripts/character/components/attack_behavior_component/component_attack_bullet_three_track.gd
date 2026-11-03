## 三线射手全场自动索敌或持续跟随手动指定目标，发射三颗固定40伤害追踪豌豆。
extends AttackComponentBulletTrack
class_name AttackComponentBulletThreeTrack

## 边路补偿：1为最上行，-1为最下行，0为中间行。
var bullet_border_compensation:int = 0

## 保留父类1.5秒攻击周期与全局信号订阅，仅记录当前边路规则。
func _ready() -> void:
	super()
	if is_instance_valid(Global.main_game):
		if owner.lane == 0:
			bullet_border_compensation = 1
		elif owner.lane == Global.main_game.plant_cell_manager.row_col.x - 1:
			bullet_border_compensation = -1

## 原三线动画的发射事件入口，一轮仍为三颗；每颗使用追踪豌豆固定伤害。
func _shoot_bullet() -> void:
	if guide_selection_active or not is_attack_res or owner.is_death:
		return
	for shot_index:int in range(3):
		if (bullet_border_compensation == 1 and shot_index == 0) or (bullet_border_compensation == -1 and shot_index == 2):
			_create_tracking_pea(0.3, 1)
		else:
			_create_tracking_pea(0.0, shot_index)
	SoundManager.play_character_SFX(&"Throw")

## [param delay_seconds] 仅边路补偿沿用旧0.3秒延迟；[param shot_index] 0/1/2分别为上/中/下弹。
## 独立构造追踪弹参数，整理结束后才选择目标。
func _create_tracking_pea(delay_seconds:float, shot_index:int) -> void:
	# 记录本轮状态版本，防止暂停后又恢复时旧的边路延迟补发混入新攻击。
	var attack_revision:int = _guide_attack_revision
	if delay_seconds > 0.0:
		await get_tree().create_timer(delay_seconds).timeout
	if guide_selection_active or attack_revision != _guide_attack_revision \
		or owner.is_death or owner.is_queued_for_deletion():
		return
	# 当前主场地有效行号，边缘补偿不会创建越界行。
	var bullet_lane:int = owner.lane + shot_index - 1
	# 全部子弹使用相同的旧三线发射点，而不是改成猫尾草的身体节点。
	var spawn_position:Vector2 = markers_2d_bullet[0].global_position
	# 使用追踪豌豆固定40伤害，过火为固定80伤害的火焰追踪豌豆。
	var bullet:Bullet021TrackingPea = Global.bullet_registry.get_bullet_scenes(attack_bullet_type).instantiate() as Bullet021TrackingPea
	# 追踪可跨行，保持普通豌豆的正常受击状态过滤。
	var parameters:Dictionary = {
		Bullet000NormBase.E_InitParasAttr.IsActivateLane:false,
		Bullet000NormBase.E_InitParasAttr.BulletLane:bullet_lane,
		Bullet000NormBase.E_InitParasAttr.Position:bullets.to_local(spawn_position),
		Bullet000NormBase.E_InitParasAttr.Direction:Vector2.RIGHT,
		Bullet000NormBase.E_InitParasAttr.CanAttackPlantState:can_attack_plant_status,
		Bullet000NormBase.E_InitParasAttr.CanAttackZombieState:can_attack_zombie_status,
	}
	bullet.init_bullet(parameters)
	bullets.add_child(bullet)
	bullet.start_launch(get_enemy, spawn_position.y + (shot_index - 1) * 100.0)

## 玩家手动指定的持续锁定目标；自动候选不写入此缓存。
var _guided_enemy:Character000Base = null
## 选择状态变更版本，用于作废尚未实际生成的边路补发。
var _guide_attack_revision:int = 0
## 鼠标引导闪动期间禁止本株攻击；退出时按当前全局敌人及组件状态恢复，已在场子弹不受影响。
var guide_selection_active:bool = false:
	set(value):
		if guide_selection_active == value:
			return
		guide_selection_active = value
		_guide_attack_revision += 1
		if is_node_ready():
			update_is_attack_factors(not value, E_IsAttackFactors.Character)
			if value:
				animation_tree.set(attack_para, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)

## 停攻期间忽略已排队的计时器回调，避免重新启动攻击动画。
func _on_bullet_attack_cd_timer_timeout() -> void:
	if guide_selection_active or not is_attack_res or owner.is_death:
		return
	super()

## 每颗子弹整理结束后重新从全场选择最靠近房子的正常目标，仅手动目标持续锁定。
func get_enemy() -> Character000Base:
	if is_instance_valid(_guided_enemy) and not _guided_enemy.is_death and not _guided_enemy.is_queued_for_deletion():
		return _guided_enemy
	_guided_enemy = null
	# 本次自动初选目标，不缓存、不优先前方、不比较权重或血量。
	var best:Character000Base = null
	for enemy:Character000Base in detect_component_global.get_all_enemy_can_be_attacked(): # 全场合格候选。
		if not _matches_pea_status(enemy):
			continue
		if best == null or enemy.hurt_box_component.global_position.x < best.hurt_box_component.global_position.x:
			best = enemy
	return best

## [param enemy] 玩家指定的目标；合格时替换手动锁定，不影响已在场子弹。
func set_guided_target(enemy:Zombie000Base) -> bool:
	if not _matches_pea_status(enemy) or enemy.is_hypno or enemy.hp_component.is_death:
		return false
	_guided_enemy = enemy
	return true

## [param enemy] 初选或手动候选，保持普通豌豆的受击资格。
func _matches_pea_status(enemy:Character000Base) -> bool:
	if not is_instance_valid(enemy) or enemy.is_death or enemy.is_queued_for_deletion():
		return false
	if enemy is ZB000Base:
		return (can_attack_zombie_status & Zombie000Base.E_BeAttackStatusZombie.IsNorm) != 0
	return enemy is Zombie000Base and (enemy.curr_be_attack_status & can_attack_zombie_status) != 0

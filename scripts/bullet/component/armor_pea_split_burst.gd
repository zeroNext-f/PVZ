## 命中点的一次性分裂任务：上下各 45 度，每个方向两颗，生成后立即释放任务节点。
extends Node2D

## 每个方向的分裂弹数量，两方向共四颗。
const SHOTS_PER_DIRECTION:int = 2
## 相对原弹方向旋转的角度，单位弧度。
const SPLIT_ANGLE:float = PI / 4.0
## 原弹的行号、方向、受击状态等参数；子弹独立复制后修改。
var shot_parameters:Dictionary = {}
## 原弹阵营，分裂不能改变敌我关系。
var shot_camp:CharacterRegistry.CharacterType = CharacterRegistry.CharacterType.Plant
## 触发分裂的目标编号，供子弹排除出生点重复命中。
var ignored_target_id:int = 0


## 延迟生成，避免父容器正在添加本任务时再次改变其子节点。
func _ready() -> void:
	_fire.call_deferred()


## 同时生成四颗编号 18 的子弹，关闭二次分裂；关卡已结束时取消。
func _fire() -> void:
	# 原弹使用的最终子弹父容器。
	var bullet_parent:Node2D = get_parent() as Node2D
	if bullet_parent == null or bullet_parent.is_queued_for_deletion() \
		or not is_instance_valid(Global.main_game) \
		or Global.main_game.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME:
		queue_free()
		return
	# 以原弹飞行方向为中轴旋转，不改变普通豌豆的总移动速度。
	var forward:Vector2 = shot_parameters.get(Bullet000NormBase.E_InitParasAttr.Direction, Vector2.RIGHT)
	for turn:int in [-1, 1]:
		# 上下各一个斜向方向，同一方向的两颗子弹分别独立结算。
		var split_direction:Vector2 = forward.normalized().rotated(float(turn) * SPLIT_ANGLE)
		for _shot_index:int in range(SHOTS_PER_DIRECTION):
			# 避免在辅助脚本中预加载自身子弹场景，实例化统一通过注册表。
			var bullet:Bullet000NormBase = Global.bullet_registry.get_bullet_scenes(
				BulletRegistry.BulletType.Bullet018ArmorPiercingPea).instantiate() as Bullet000NormBase
			bullet.set("can_split", false)
			bullet.set("ignored_target_id", ignored_target_id)
			bullet.bullet_camp = shot_camp
			# 每颗弹独立保存初始化参数，斜向运动允许按实际碰撞攻击其他行。
			var parameters:Dictionary = shot_parameters.duplicate()
			parameters[Bullet000NormBase.E_InitParasAttr.Position] = bullet_parent.to_local(global_position)
			parameters[Bullet000NormBase.E_InitParasAttr.Direction] = split_direction
			parameters[Bullet000NormBase.E_InitParasAttr.IsActivateLane] = false
			bullet.init_bullet(parameters)
			bullet_parent.add_child(bullet)
	SoundManager.play_character_SFX(&"Throw")
	queue_free()

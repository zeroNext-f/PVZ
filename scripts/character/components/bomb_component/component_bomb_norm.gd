extends BombComponentBase
class_name BombComponentNorm
## 普通炸弹使用爆炸组件

## 爆炸表现，与伤害筛选独立触发。
@onready var bomb_effect: BombEffectBase = $BombEffect

## 仅由土豆地雷场景开启；对范围及状态筛选通过的小体型僵尸结算致死伤害，其他目标沿用 bomb_value。
@export var instant_kill_small_zombies: bool = false

## 单次物理查询的分页大小；每页排除已命中区域后继续查询，不限制爆炸总目标数。
const QUERY_PAGE_SIZE: int = 64

## 爆炸特效
func _start_bomb_fx():
	bomb_effect.activate_bomb_effect()

## 收集范围内的有效敌人并按角色去重；僵王跨行由受击区域决定，致死后保留死亡演出。
func _bomb_all_enemy():
	# 保存未转换的引用，前一个目标的死亡回调可能释放后续目标。
	var targets: Array = []
	# 梯子同样先收集再处理，避免收集过程中改变场景和后续范围判断。
	var ladders: Array[Ladder] = []
	# 同一角色可能有多个受击区域，一次爆炸只登记一次。
	var seen_ids: Dictionary[int, bool] = {}
	# 爆炸实际覆盖的受击区域；范围外的僵王不会被全场命中。
	for area: Area2D in _query_current_bomb_areas():
		# 区域所属对象，梯子继续沿用原有销毁规则。
		var area_owner: Variant = area.owner
		if not is_instance_valid(area_owner):
			continue
		if area_owner is Ladder:
			if (bomb_lane == -1 or absi(owner.lane - area_owner.lane) <= bomb_lane) \
				and not seen_ids.has(area_owner.get_instance_id()):
				seen_ids[area_owner.get_instance_id()] = true
				ladders.append(area_owner)
		elif area_owner is Character000Base and _can_bomb_character(area_owner):
			# 用实例编号去重，不将区域数量当作敌人数量。
			var instance_id: int = area_owner.get_instance_id()
			if not seen_ids.has(instance_id):
				seen_ids[instance_id] = true
				targets.append(area_owner)
	# 每次结算前重新检查存活与受击状态，抵御同步死亡回调和延迟禁用碰撞。
	for target_reference: Variant in targets:
		if not is_instance_valid(target_reference):
			continue
		# 通过引用检查后才转换为角色。
		var target := target_reference as Character000Base
		if not _can_bomb_character(target):
			continue
		if target is ZB000Base:
			target.be_attacked_bullet(bomb_value, BulletRegistry.AttackMode.Penetration, false, false)
		elif target is Zombie000Base:
			# 取足以清空当前本体和所有防具的伤害，不受小体型目标的生命加成限制。
			var damage: int = target.hp_component.get_all_hp() \
				if instant_kill_small_zombies and target.zombie_body_size == Zombie000Base.BodySize.Small else bomb_value
			target.be_bomb(damage, is_cherry_bomb)
	# 全部角色伤害结算后才销毁已捕获的梯子，处理期间可能已由其他死亡流程移除。
	for ladder: Ladder in ladders:
		if is_instance_valid(ladder) and not ladder.is_queued_for_deletion():
			ladder.ladder_death()


## 按爆炸碰撞形状的当前世界位置即时查询区域，不依赖 Area2D 的上次物理帧重叠缓存。[br]
## 刚生成的补种爆炸与刚出土的地雷均可完整取样；按 RID 分页排除，不设置总命中上限。
func _query_current_bomb_areas() -> Array[Area2D]:
	# 多个爆炸形状共享去重结果，避免同一区域被重复交给后续角色收集流程。
	var areas: Array[Area2D] = []
	var seen_area_ids: Dictionary[int, bool] = {}
	if not is_instance_valid(area_2d_bomb) or not area_2d_bomb.is_inside_tree():
		return areas
	# 查询使用当前世界的物理空间，而不是新生成爆炸区域尚未刷新的重叠列表。
	var space_state: PhysicsDirectSpaceState2D = area_2d_bomb.get_world_2d().direct_space_state
	# 当前工程普通爆炸均使用 CollisionShape2D；每个启用形状独立查询并合并。
	for child: Node in area_2d_bomb.get_children():
		if not child is CollisionShape2D:
			continue
		# 保留场景的真实形状和全部父级变换，不改变原有范围、屋顶修正或碰撞掩码。
		var collision_shape: CollisionShape2D = child as CollisionShape2D
		if collision_shape.disabled or collision_shape.shape == null:
			continue
		var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		query.shape = collision_shape.shape
		query.transform = collision_shape.global_transform
		query.collision_mask = area_2d_bomb.collision_mask
		query.collide_with_areas = true
		query.collide_with_bodies = false
		# 只限制每次查询的返回数量，持续排除已返回的碰撞区域直至当前形状没有剩余结果。
		var excluded_rids: Array[RID] = []
		while true:
			query.exclude = excluded_rids
			# 本页物理区域；不同区域仍可能属于同一角色，角色级去重在伤害前完成。
			var hits: Array[Dictionary] = space_state.intersect_shape(query, QUERY_PAGE_SIZE)
			if hits.is_empty():
				break
			# 防止异常查询反复返回同一 RID 导致循环无法前进。
			var has_new_rid: bool = false
			# 本页的一条形状查询结果，包含碰撞区域及其物理 RID。
			for hit: Dictionary in hits:
				# 即使区域不可被攻击，也必须从后续分页中排除，才能继续获取其他目标。
				var area_rid: RID = hit["rid"]
				if not excluded_rids.has(area_rid):
					excluded_rids.append(area_rid)
					has_new_rid = true
				# 直接空间查询可能包含不可监测区域，继续遵守原 Area2D 的可被检测要求。
				var collider: Variant = hit["collider"]
				if not is_instance_valid(collider) or not collider is Area2D or not collider.monitorable:
					continue
				if not seen_area_ids.has(collider.get_instance_id()):
					seen_area_ids[collider.get_instance_id()] = true
					areas.append(collider as Area2D)
			if not has_new_rid:
				break
	return areas


## [param enemy] 已与爆炸区域重叠的角色；返回是否可结算伤害，不扩大爆炸范围。
func _can_bomb_character(enemy: Character000Base) -> bool:
	if not is_instance_valid(enemy) or enemy.is_death or enemy.is_queued_for_deletion() \
		or not enemy.is_inside_tree():
		return false
	if enemy is ZB000Base:
		return enemy.character_init_type == Character000Base.E_CharacterInitType.IsNorm \
			and is_instance_valid(enemy.hurt_box_component) and enemy.hurt_box_component.is_enabling \
			and (can_attack_zombie_status & Zombie000Base.E_BeAttackStatusZombie.IsNorm) != 0
	return enemy is Zombie000Base and (enemy.curr_be_attack_status & can_attack_zombie_status) != 0 \
		and judge_lane(enemy)


## [param enemy] 普通角色；返回是否处于配置的爆炸行范围，-1 表示不限制行。
func judge_lane(enemy:Character000Base) -> bool:
	return bomb_lane == -1 or (owner.lane + bomb_lane >= enemy.lane and owner.lane - bomb_lane <= enemy.lane )

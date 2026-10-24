## 末日菇按当前受击框补全爆炸目标，避免物理空间查询漏掉已经入场的僵尸。
extends BombComponentNorm

## 合并原查询与场上角色的实时形状相交结果；继承统一去重、伤害及死亡处理。
func _query_current_bomb_areas() -> Array[Area2D]:
	# 原查询继续负责梯子等道具，已有命中不会重复加入。
	var areas: Array[Area2D] = super()
	if not is_instance_valid(area_2d_bomb) or not area_2d_bomb.is_inside_tree() \
		or not is_instance_valid(Global.main_game):
		return areas
	# 正常入场、召唤及读档角色都由同一管理器登记；快照不受后续死亡回调修改。
	var manager: ZombieManager = Global.main_game.zombie_manager
	# 同时覆盖普通僵尸和独立挂载的僵王，不按所在格中心替代受击框判定。
	var characters: Array = manager.all_zombies_1d.duplicate()
	characters.append_array(manager.get_living_bosses())
	# 当前候选角色；死亡、阵营、状态及行范围沿用普通爆炸的规则。
	for character_reference: Variant in characters:
		if not is_instance_valid(character_reference):
			continue
		# 通过存活筛选后才访问受击组件。
		var character: Character000Base = character_reference as Character000Base
		if not _can_bomb_character(character) or not is_instance_valid(character.hurt_box_component):
			continue
		# 仅检测受击组件内的区域，避免把攻击或跳跃探测框算成被命中。
		for child: Node in character.hurt_box_component.get_children():
			# 继续遵守原碰撞层和可被检测开关，魅惑友军不会因补查被命中。
			var area: Area2D = child as Area2D
			if area == null or not area.monitorable \
				or (area.collision_layer & area_2d_bomb.collision_mask) == 0 or areas.has(area):
				continue
			if _overlaps_current_bomb_shape(area):
				areas.append(area)
	return areas


## [param area] 候选受击区域；按双方当前世界变换和启用形状判断相交，不依赖重叠缓存。
func _overlaps_current_bomb_shape(area: Area2D) -> bool:
	# 本次爆炸的实际形状，保持场景原尺寸及屋顶位置修正。
	for bomb_child: Node in area_2d_bomb.get_children():
		# 禁用或未配置形状不参与伤害范围。
		var bomb_shape: CollisionShape2D = bomb_child as CollisionShape2D
		if bomb_shape == null or bomb_shape.disabled or bomb_shape.shape == null:
			continue
		# 目标可能包含多个受击形状，任意一个相交即可登记区域。
		for target_child: Node in area.get_children():
			# 使用目标实际形状，保留边缘部分重叠也能被命中的行为。
			var target_shape: CollisionShape2D = target_child as CollisionShape2D
			if target_shape == null or target_shape.disabled or target_shape.shape == null:
				continue
			if bomb_shape.shape.collide(bomb_shape.global_transform,
				target_shape.shape, target_shape.global_transform):
				return true
	return false

## 空手累计选择多株三线射手并闪动，点选僵尸统一锁定，目标闪动1游戏秒确认。
extends RefCounted
class_name ThreePeaterGuide

## 等待统一指令的三线射手集合，再次点击同株将其退出选择。
var sources:Array[Plant019ThreePeater] = []
## 鼠标当前指向的合格僵尸。
var hovered:Zombie000Base = null
## 闪动累计游戏秒数。
var flash_seconds:float = 0.0

## [param hand] 当前手持管理器；[param plant] 玩家点击的正式战斗实体。
func start(hand:HandManager, plant:Plant019ThreePeater) -> void:
	if not hand.main_game.zombie_manager.is_game_running() or plant.is_death or plant.is_queued_for_deletion() \
		or plant.character_init_type != Character000Base.E_CharacterInitType.IsNorm:
		return
	# 再次点击仅解除该株的选择与索敌暂停，其他已选植物继续闪动。
	var attack:AttackComponentBulletThreeTrack = plant.attack_component as AttackComponentBulletThreeTrack
	if sources.has(plant):
		sources.erase(plant)
		attack.guide_selection_active = false
		plant.body.set_other_color(BodyCharacter.E_ChangeColors.ThreePeaterGuide, Color.WHITE)
		if sources.is_empty():
			_set_hover(null)
		return
	sources.append(plant)
	attack.guide_selection_active = true
	plant.body.set_other_color(BodyCharacter.E_ChangeColors.ThreePeaterGuide, Color(2, 2, 2))

## [param hand] 当前手持管理器；[param delta] 游戏帧秒数，刷新闪动和鼠标悬停。
func update(hand:HandManager, delta:float) -> void:
	_prune_sources()
	if sources.is_empty():
		_set_hover(null)
		return
	if not hand.main_game.zombie_manager.is_game_running():
		cancel()
		return
	flash_seconds += delta
	# 所有选中植物同步进行每游戏秒一次的明暗往返。
	var brightness:float = 1.3 + 0.7 * cos(flash_seconds * TAU)
	for plant:Plant019ThreePeater in sources: # 本次仍有效的选中植物。
		plant.body.set_other_color(BodyCharacter.E_ChangeColors.ThreePeaterGuide, Color(brightness, brightness, brightness))
	_set_hover(_pick_target(hand) if hand.curr_hm_status == HandManager.E_HandManagerStatus.Null else null)

## 清除死亡或被移除的来源，只取消该株，不影响其他已选三线射手。
func _prune_sources() -> void:
	for index:int in range(sources.size() - 1, -1, -1): # 倒序删除避免索引偏移。
		# 先以Variant验证，避免对已释放植物进行强类型转换。
		var plant:Variant = sources[index]
		if not is_instance_valid(plant):
			sources.remove_at(index)
		elif plant.is_death or plant.is_queued_for_deletion():
			plant.attack_component.guide_selection_active = false
			plant.body.set_other_color(BodyCharacter.E_ChangeColors.ThreePeaterGuide, Color.WHITE)
			sources.remove_at(index)
## [param hand] 当前战场；沿用魅惑菇受击框点查询和前景优先，不受魅惑免疫或体型限制。
func _pick_target(hand:HandManager) -> Zombie000Base:
	# 仅查询敌方僵尸受击框。
	var query:PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = hand.main_game.get_global_mouse_position()
	query.collision_mask = 4
	query.collide_with_areas = true
	query.collide_with_bodies = false
	# 本次覆盖的受击框及最终前景目标。
	var hits:Array[Dictionary] = hand.main_game.get_world_2d().direct_space_state.intersect_point(query, 128)
	var target:Zombie000Base = null
	# 本株攻击组件负责受击状态资格。
	var attack:AttackComponentBulletThreeTrack = sources[0].attack_component as AttackComponentBulletThreeTrack
	for hit:Dictionary in hits: # 当前受击框。
		# 受击框所属僵尸，排除友方、死亡、预览和普通豌豆不可命中的状态。
		var zombie:Zombie000Base = hit.collider.owner as Zombie000Base
		if not is_instance_valid(zombie) or zombie.is_hypno or zombie.hp_component.is_death \
			or zombie.character_init_type != Character000Base.E_CharacterInitType.IsNorm \
			or not hand.main_game.zombie_manager.all_zombies_1d.has(zombie) or not attack._matches_pea_status(zombie):
			continue
		if target == null or zombie.lane > target.lane or (zombie.lane == target.lane and zombie.get_index() > target.get_index()):
			target = zombie
	return target

## [param target] 新悬停僵尸，独立因素提供魅惑菇同款两倍亮度。
func _set_hover(target:Zombie000Base) -> void:
	if is_instance_valid(hovered) and hovered == target:
		return
	if is_instance_valid(hovered) and is_instance_valid(hovered.body):
		hovered.body.set_other_color(BodyCharacter.E_ChangeColors.ThreePeaterHover, Color.WHITE)
	hovered = target
	if is_instance_valid(hovered):
		hovered.body.set_other_color(BodyCharacter.E_ChangeColors.ThreePeaterHover, Color(2, 2, 2))

## [param hand] 当前管理器；[param event] 输入事件；空手左键指定僵尸或再次点击来源退出闪动，右键及切工具不取消选择。
func handle_input(hand:HandManager, event:InputEvent) -> bool:
	if hand.curr_hm_status != HandManager.E_HandManagerStatus.Null:
		return false
	_prune_sources()
	if sources.is_empty():
		return false
	if not event is InputEventMouseButton or not event.pressed:
		return false
	if event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if not hand.main_game.zombie_manager.is_game_running():
		cancel()
		return true
	# 点击僵尸时统一下达指令，仍沿用原受击框前景选择规则。
	var target:Zombie000Base = _pick_target(hand)
	if is_instance_valid(target):
		# 只影响选中各株后续出弹，已在场子弹保持自己的目标。
		var assigned:bool = false
		for plant:Plant019ThreePeater in sources: # 本次参与统一指令的植物。
			# 每株分别写入手动锁定。
			var attack:AttackComponentBulletThreeTrack = plant.attack_component as AttackComponentBulletThreeTrack
			if attack.set_guided_target(target):
				assigned = true
		cancel()
		if assigned:
			target.body.show_threepeater_target_confirmation()
		return true
	# 场地内点击其他三线射手时直接追加，避免原输入拦截吞掉选格按钮。
	if is_instance_valid(hand.curr_plant_cell):
		# 格内引用先验证，防止铲除后残留已释放对象。
		var occupant:Variant = hand.curr_plant_cell.plant_in_cell.get(CharacterRegistry.PlacePlantInCell.Norm)
		if is_instance_valid(occupant) and occupant is Plant019ThreePeater:
			start(hand, occupant as Plant019ThreePeater)
		return true
	return false

## 恢复全部来源的闪动及悬停颜色，不清除已确认的手动锁定。
func cancel() -> void:
	_set_hover(null)
	for reference:Variant in sources: # 来源可能已在清场中被释放，先验证再访问身体。
		if is_instance_valid(reference) and is_instance_valid(reference.body):
			reference.attack_component.guide_selection_active = false
			reference.body.set_other_color(BodyCharacter.E_ChangeColors.ThreePeaterGuide, Color.WHITE)
	sources.clear()
	flash_seconds = 0.0

## 魅惑菇的指向收编交互；只生成临时僵尸卡，不实例化场地植物。
extends RefCounted
class_name HypnoCapture

## 当前被鼠标指向的敌方僵尸，切换或退出手持时恢复独立高亮。
var hovered_zombie: Zombie000Base

## [param hand] 当前手持管理器；按世界坐标查询鼠标下的敌方僵尸受击检测框。
## 返回仍存活、未被魅惑且已登记在当前战场的实例，重叠时优先视觉靠前者。
func pick_target(hand: HandManager) -> Zombie000Base:
	# 点查询只命中敌方僵尸检测层，植物和友方魅惑僵尸均不参与。
	var query := PhysicsPointQueryParameters2D.new()
	query.position = hand.main_game.get_global_mouse_position()
	query.collision_mask = 4
	query.collide_with_areas = true
	query.collide_with_bodies = false
	# 当前点重叠的受击框，允许多只僵尸叠在同一位置。
	var hits: Array[Dictionary] = hand.main_game.get_world_2d().direct_space_state.intersect_point(query, 128)
	# 本次选中的前景目标。
	var target: Zombie000Base = null
	for hit: Dictionary in hits:
		# 受击区域的角色所有者，僵王不属于普通僵尸卡类别。
		var zombie: Zombie000Base = hit.collider.owner as Zombie000Base
		if not is_instance_valid(zombie) or zombie.is_hypno or zombie.is_death \
			or zombie.is_queued_for_deletion() or zombie.hp_component.is_death \
			or zombie.character_init_type != Character000Base.E_CharacterInitType.IsNorm \
			or not hand.main_game.zombie_manager.all_zombies_1d.has(zombie):
			continue
		if target == null or zombie.lane > target.lane \
			or (zombie.lane == target.lane and zombie.get_index() > target.get_index()):
			target = zombie
	return target

## [param hand] 当前手持管理器；刷新悬停目标，鼠标下无合格目标时撤销提示。
func update_hover(hand: HandManager) -> void:
	set_hover(pick_target(hand))

## [param target] 新悬停对象；只改专用颜色因素，安全处理目标在两帧间死亡的情况。
func set_hover(target: Zombie000Base) -> void:
	if is_instance_valid(hovered_zombie) and hovered_zombie == target:
		return
	if is_instance_valid(hovered_zombie):
		hovered_zombie.body.set_other_color(BodyCharacter.E_ChangeColors.HypnoCaptureHover, Color.WHITE)
	hovered_zombie = target
	if is_instance_valid(hovered_zombie):
		hovered_zombie.body.set_other_color(BodyCharacter.E_ChangeColors.HypnoCaptureHover, Color(2, 2, 2))

## [param hand] 当前手持管理器，[param source_card] 本次使用的魅惑菇卡。
## 重验目标及卡片后生成免费单次卡并清除原僵尸；失败不消耗费用或冷却。
func capture(hand: HandManager, source_card: Card) -> bool:
	if not hand.main_game.zombie_manager.is_game_running() or not is_instance_valid(source_card) \
		or source_card.is_queued_for_deletion() or not source_card.is_can_click:
		return false
	source_card.judge_card_ready()
	if not source_card.is_can_click:
		return false
	# 点击瞬间重新命中，不能捕获上帧已离开光标的目标。
	var target: Zombie000Base = pick_target(hand)
	if not is_instance_valid(target):
		return false
	# 仅保存僵尸种类，不复制原生命、耐久、异常或已使用技能阶段。
	var card_reference := ResourceCardReference.create(ResourceCardReference.CardType.Zombie, target.zombie_type)
	# 卡片属于前景画布，使用该画布鼠标坐标；预先成功创建才能安全清除来源。
	var temp_card: Card = hand.main_game.card_manager.create_temp_card(card_reference, Vector2.ZERO, 25.0)
	if temp_card == null:
		return false
	temp_card.global_position = temp_card.get_global_mouse_position()
	temp_card.is_hypno_zombie_card = true
	temp_card.sun_cost = 0
	temp_card.card_change_cool_time(0)
	temp_card.judge_sun_enough(0)
	temp_card.character_static.modulate = Color(1, 0.5, 1)
	set_hover(null)
	# 收编是强制清除，不触发原僵尸亡语；读报沿用强制最终清除，不能获得第二生命逃脱。
	target.is_can_death_language = false
	target.character_death_disappear()
	SoundManager.play_character_SFX("MindControlled")
	source_card.signal_card_use_end.emit(source_card)
	return true

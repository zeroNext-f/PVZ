## 普通卡槽负责选择、重选与预选，所有内容统一使用卡牌引用。
extends Control
class_name CardSlotNorm

## 移动选卡时的临时挂载节点，防止卡片被原卡槽遮挡。
@onready var temporary_card: Control = $TemporaryCard
## 备选卡页面与返回容器的管理节点。
@onready var card_slot_candidate: CardSlotCandidate = $CardSlotCandidate
## 出战卡槽及阳光结算节点。
@onready var card_slot_battle: CardSlotBattle = $CardSlotBattle
## 最近选中且尚未配对的墓碑吞噬者，下一次成功的新选卡填入它的下层。
var _pending_grave_slot: Card
## 关卡配置的不可取消预选实例；与玩家的“已选择”状态分别记录。
var _locked_cards: Array[Card] = []
## 每张卡当前的移动补间；快速取消/重排时替换旧目标，防止旧回调将卡移回错误槽位。
var _card_move_tweens: Dictionary[Card, Tween] = {}

## 使用 [param game_para] 初始化槽位、候选点击信号和不可取消的预选卡。
func init_card_slot_norm(game_para: ResourceLevelData) -> void:
	card_slot_battle.init_card_slot_battle(game_para.max_choosed_card_num, game_para.start_sun)
	# 候选容器按引用的完整选择键定位，模仿修饰决定点击处理方法。
	for container: CardCandidateContainer in card_slot_candidate.candidate_containers.values():
		if container.card.card_reference.is_imitater:
			container.card.signal_card_click.connect(_on_imitater_card_click)
		else:
			container.card.signal_card_click.connect(_on_card_click)
	if not game_para.prechosen_cards.is_empty():
		init_pre_choosed_card(game_para.prechosen_cards)

## 读取上次的统一选卡引用，只恢复仍可出战且存在于本次候选页的内容。
func _on_re_card_button_pressed() -> void:
	Global.save_service.load_selected_cards()
	# 存档明确记录配对关系，避免未配对的墓碑卡误吞后面本来独立的槽位。
	var restore_root: Card = null
	# 上次选卡的引用只读，候选卡拥有自己的引用副本。
	for reference: ResourceCardReference in Global.global_game_state.selected_cards:
		_pending_grave_slot = restore_root
		restore_root = null
		if not AllCards.is_battle_card(reference):
			continue
		# 根据完整选择键同时区分普通植物和模仿植物。
		var container: CardCandidateContainer = card_slot_candidate.get_candidate(reference)
		if container == null or not container.visible:
			continue
		if not container.card.is_choosed_pre_card:
			if reference.is_imitater and card_slot_candidate.card_imitater.is_be_choosed_imitater:
				continue
			container.card._on_button_pressed()
		if reference.shares_slot_with_next:
			# 系统预选使用独立副本，按选择键查找真实根卡，不能把隐藏候选当作根卡。
			for slot_card: Card in card_slot_battle.curr_cards:
				if slot_card.card_reference.get_selection_key() == reference.get_selection_key() \
					and not is_instance_valid(slot_card.shared_slot_partner):
					restore_root = slot_card
					break
	if is_instance_valid(restore_root):
		_pending_grave_slot = restore_root

## 倒序单独取消所有实际卡片；系统锁定预选保持不变。
func _on_cancal_card_button_pressed() -> void:
	# 先取消下层再取消根卡，避免根卡单独取消后晋升的下层漏过全部取消操作。
	var selected_slots: Array[Card] = card_slot_battle.get_all_cards()
	selected_slots.reverse()
	# 本次待单独取消的实际卡，包含当前隐藏的下层。
	for card: Card in selected_slots:
		_cancel_selected_card(card)

## 开始游戏并保存独立的选卡引用，由 SaveService 统一序列化。
func _on_texture_button_pressed() -> void:
	EventBus.push_event("card_slot_norm_start_game")
	Global.global_game_state.selected_cards.clear()
	# 保存引用副本，避免运行中的卡片修改影响持久化身份。
	for card: Card in card_slot_battle.curr_cards:
		# 列表仍保存具体卡牌身份，在根卡上注明紧随其后的引用属于共用下层。
		var reference: ResourceCardReference = card.card_reference.copy_reference()
		reference.shares_slot_with_next = is_instance_valid(card.shared_slot_partner)
		Global.global_game_state.selected_cards.append(reference)
		if is_instance_valid(card.shared_slot_partner):
			# 下层不再携带下一层关系，即使其自身也是模仿墓碑卡，仍只组成双卡槽。
			var partner_reference: ResourceCardReference = card.shared_slot_partner.card_reference.copy_reference()
			partner_reference.shares_slot_with_next = false
			Global.global_game_state.selected_cards.append(partner_reference)
	Global.save_service.save_selected_cards()

## 按 [param references] 的顺序创建不可取消的预选卡；无效或未注册的出战引用不会进入卡槽。
func init_pre_choosed_card(references: Array[ResourceCardReference]) -> void:
	# 单个预选引用表示一个完整卡片，不再依赖两个补零数组的同下标组合。
	for reference: ResourceCardReference in references:
		if not AllCards.is_battle_card(reference):
			push_error("CardSlotNorm：预选卡必须是已注册的出战卡牌。")
			continue
		if not _has_pending_grave_slot() and card_slot_battle.curr_cards.size() >= card_slot_battle.cards_placeholder.size():
			break
		# 隐藏对应的候选卡，保持预选卡不可取消。
		var container: CardCandidateContainer = card_slot_candidate.get_candidate(reference)
		if container != null:
			container.card.visible = false
			container.card.is_choosed_pre_card = true
		# 实际出战卡是独立实例；开始战斗时再切换上下文。
		var card: Card = AllCards.create_card(reference, Card.CardContext.Selection)
		if card == null:
			continue
		_locked_cards.append(card)
		_add_selected_card(card, false)
		if reference.is_imitater:
			card_slot_candidate.imitater_be_choosed()
	card_disconnect_click_in_choose()

## 返回当前是否处于开局选卡或下一轮重选阶段。
func _is_choosing() -> bool:
	return Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.CHOOSE_CARD \
		or Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.RE_CHOOSE_CARD

## [param card] 的正常选择信号；只接纳具有出战能力的卡片。
func _on_card_click(card: Card) -> void:
	if not _is_choosing() or not AllCards.is_battle_card(card.card_reference):
		return
	SoundManager.play_other_SFX("tap")
	if card.is_choosed_pre_card:
		_cancel_selected_card(card)
	elif not _add_selected_card(card):
		SoundManager.play_other_SFX("buzzer")

## [param card] 的模仿植物选择信号；独立入口本身不作为出战卡。
func _on_imitater_card_click(card: Card) -> void:
	if not _is_choosing() or not AllCards.is_battle_card(card.card_reference):
		return
	SoundManager.play_other_SFX("tap")
	if card.is_choosed_pre_card:
		_cancel_selected_card(card)
	elif card_slot_candidate.card_imitater.is_be_choosed_imitater or not _add_selected_card(card):
		SoundManager.play_other_SFX("buzzer")
		card_slot_candidate.imitater_card_slot_disappear()
	else:
		card_slot_candidate.imitater_be_choosed()

## 返回是否有仍在槽中的未配对墓碑卡；满槽时也允许补选它的下层。
func _has_pending_grave_slot() -> bool:
	return is_instance_valid(_pending_grave_slot) and card_slot_battle.curr_cards.has(_pending_grave_slot) \
		and not is_instance_valid(_pending_grave_slot.shared_slot_partner)

## [param card] 新选择的卡，[param animate] 为false时直接挂载系统预选；成功只占一个物理槽。
func _add_selected_card(card: Card, animate: bool = true) -> bool:
	# 本次放置的物理占位，不以展开后的卡牌数量计算容量。
	var target_slot: Control
	if _has_pending_grave_slot():
		_pending_grave_slot.shared_slot_partner = card
		card.shared_slot_owner = _pending_grave_slot
		target_slot = card_slot_battle.cards_placeholder[card_slot_battle.curr_cards.find(_pending_grave_slot)]
		_pending_grave_slot = null
		card.shared_slot_active = false
		card.hide()
	else:
		if card_slot_battle.curr_cards.size() >= card_slot_battle.cards_placeholder.size():
			return false
		card_slot_battle.curr_cards.append(card)
		target_slot = card_slot_battle.cards_placeholder[card_slot_battle.curr_cards.size() - 1]
		if card.card_reference.card_type == ResourceCardReference.CardType.Plant \
			and card.card_reference.content_id == CharacterRegistry.PlantType.P012GraveBuster:
			_pending_grave_slot = card
	card.is_choosed_pre_card = true
	if animate:
		move_card_to(card, target_slot)
	else:
		pre_choosed_card(card, target_slot)
	return true

## [param card] 仅取消该卡；取消墓碑根卡时下层晋升独立槽位，取消下层时保留墓碑根卡。
func _cancel_selected_card(card: Card) -> void:
	if not is_instance_valid(card) or not card.is_choosed_pre_card:
		return
	# 系统预选的角色池占位绑定候选副本，先解析成真实已选实例，再检查锁定。
	if not card_slot_battle.curr_cards.has(card) and not is_instance_valid(card.shared_slot_owner):
		# 当前已选的根卡或下层，与角色池占位按完整选择键匹配。
		for selected_card: Card in card_slot_battle.get_all_cards():
			if selected_card.card_reference.get_selection_key() == card.card_reference.get_selection_key():
				card = selected_card
				break
	if not card_slot_battle.curr_cards.has(card) and not is_instance_valid(card.shared_slot_owner):
		return
	if _locked_cards.has(card):
		return
	if is_instance_valid(card.shared_slot_owner):
		_detach_partner(card.shared_slot_owner)
		return
	if is_instance_valid(card.shared_slot_partner):
		# 保留同一物理槽，将下层实际实例提升；只把墓碑吞噬者归还角色池。
		var partner: Card = card.shared_slot_partner
		# 原根卡的物理槽号，提升后容量与后续槽序均不改变。
		var slot_index: int = card_slot_battle.curr_cards.find(card)
		card.shared_slot_partner = null
		partner.shared_slot_owner = null
		partner.shared_slot_active = true
		partner.show()
		card_slot_battle.curr_cards[slot_index] = partner
		if _pending_grave_slot == card:
			_pending_grave_slot = null
		if partner.card_reference.card_type == ResourceCardReference.CardType.Plant \
			and partner.card_reference.content_id == CharacterRegistry.PlantType.P012GraveBuster:
			_pending_grave_slot = partner
		_return_candidate(card)
		move_card_to(partner, card_slot_battle.cards_placeholder[slot_index])
		return
	if _pending_grave_slot == card:
		_pending_grave_slot = null
	card_slot_battle.curr_cards.erase(card)
	_return_candidate(card)
	_relayout_slots()

## [param root_card] 仍保留的墓碑槽位根；解除可取消下层后等待下一次新选卡。
func _detach_partner(root_card: Card) -> void:
	# 原下层实例独立归还，根卡不移动、不丢失自己的卡片身份。
	var partner: Card = root_card.shared_slot_partner
	if not is_instance_valid(partner) or _locked_cards.has(partner):
		return
	root_card.shared_slot_partner = null
	partner.shared_slot_owner = null
	partner.shared_slot_active = true
	root_card.set_shared_slot_layer(false)
	_return_candidate(partner)
	_pending_grave_slot = root_card

## [param card] 已取消的实际卡牌，回原候选位置并恢复模仿者入口。
func _return_candidate(card: Card) -> void:
	card.is_choosed_pre_card = false
	card.shared_slot_active = true
	card.show()
	if card.card_reference.is_imitater:
		card_slot_candidate.imitater_be_choosed_cancel()
	move_card_to(card, card.card_candidate_container)

## 移除物理槽位后重排剩余根卡及其下层，同槽两张卡使用同一个占位。
func _relayout_slots() -> void:
	# 当前实际保留的物理槽位索引，不因同槽有两张卡而多占位置。
	for index: int in range(card_slot_battle.curr_cards.size()):
		# 当前槽位的所有卡牌即使下层隐藏也必须跟随根卡移动。
		for card: Card in card_slot_battle.curr_cards[index].get_slot_cards():
			move_card_to(card, card_slot_battle.cards_placeholder[index])

## 将 [param card] 动画移动到 [param target_parent] 的全局位置，再重新挂载。
## 移动期间暂停按钮鼠标交互，耗时保持为 0.2 秒。
func move_card_to(card: Card, target_parent: Control) -> void:
	if _card_move_tweens.has(card):
		_card_move_tweens[card].kill()
	card.button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.reparent(temporary_card)
	# 临时挂载后的移动动画。
	var tween: Tween = create_tween()
	_card_move_tweens[card] = tween
	tween.tween_property(card, "global_position", target_parent.global_position, 0.2)
	tween.tween_callback(_finish_card_move.bind(card, target_parent))

## [param card] 及 [param target_parent] 为最新移动目标；旧补间取消后不再有归位回调。
func _finish_card_move(card: Card, target_parent: Control) -> void:
	_card_move_tweens.erase(card)
	if not is_instance_valid(card) or not is_instance_valid(target_parent):
		return
	card.reparent(target_parent)
	card.position = Vector2.ZERO
	card.button.mouse_filter = Control.MOUSE_FILTER_PASS

## 锁定预选仍不可取消；点击交由统一处理函数检查锁定，不影响玩家卡在角色池单独取消。
func card_disconnect_click_in_choose() -> void:
	# 系统预选卡不会恢复为候选卡。
	for card: Card in _locked_cards:
		if not card.signal_card_click.is_connected(_on_card_click):
			card.signal_card_click.connect(_on_card_click)

## 将 [param card] 挂到 [param target_parent]；罐子模式仍保留原有零冷却规则。
func pre_choosed_card(card: Card, target_parent: Control) -> void:
	target_parent.add_child(card)
	card.position = Vector2.ZERO
	if Global.main_game.game_para.is_pot_mode:
		match card.card_reference.card_type:
			ResourceCardReference.CardType.Plant:
				if Global.global_read_data.zero_cd_plnat_card_type_on_pot_mode.has(card.card_reference.content_id):
					card.card_change_cool_time(0)
			ResourceCardReference.CardType.Zombie:
				card.card_change_cool_time(0)

## 根据 [param is_appeal] 显示或隐藏候选卡槽，等待原有 0.2 秒移动完成。
func move_card_slot_candidate(is_appeal: bool) -> void:
	# 候选卡槽位移动画。
	var tween: Tween = create_tween()
	tween.tween_property(card_slot_candidate, "position", Vector2(0, 89.0) if is_appeal else Vector2(0, 615.0), 0.2)
	await tween.finished

## 根据 [param is_appeal] 移动出战卡槽；[param appeal_time] 是动画耗时，单位秒。
func move_card_slot_battle(is_appeal: bool, appeal_time: float = 0.2) -> void:
	# 出战卡槽位移动画。
	var tween: Tween = create_tween()
	tween.tween_property(card_slot_battle, "position", Vector2(0, 0) if is_appeal else Vector2(0, -100.0), appeal_time)
	await tween.finished


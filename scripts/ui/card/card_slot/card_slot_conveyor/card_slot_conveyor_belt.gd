## 按统一引用的有序表或权重池生成传送带出战卡，使用后移除卡片。
extends PanelContainer
class_name CardSlotConveyorBelt

## 传送带齿轮动画节点。
@onready var conveyor_belt_gear: ConveyorBeltGear = $ConveyorBeltGear
## 新卡片的挂载区域。
@onready var new_card_area: Panel = $NewCardArea
## 控制新卡生成间隔的计时器。
@onready var create_new_card_timer: Timer = $CreateNewCardTimer
## 当前传送带中的卡片。
var curr_cards: Array[Card] = []

@export_group("传送带参数")
## 最大卡片数量，默认 10 张。
@export var num_card_max: int = 10
## 各卡片目标 x 坐标，间隔 50 像素。
var all_card_pos_x_target: Array[float] = []
## 卡片向左移动的速度，单位像素每秒。
@export var conveyor_velocity: float = 30
## 新卡生成的基础间隔，单位秒。
@export var create_new_card_cd: float = 5
## 统一引用的随机权重池。
@onready var card_random_pool: CardRandomPool = $CardRandomPool
## 生成序号到完整引用的覆盖表；未配置序号使用权重池。
var card_order: Dictionary[int, ResourceCardReference] = {}
## 从零开始累计的已生成卡片数量。
var all_num_card: int = 0
## 是否正在推进卡片和生成计时器。
var is_working: bool = false
## 关卡指定的生成速率倍率。
var create_new_card_speed: float
## 本关是否启用原版泳池传送带调节，默认关闭以保持已有白天和黑夜配置。
var _classic_pool_rules: bool = false
## 本关固定发卡间隔，0沿用原有规则；正数仅覆盖间隔，不覆盖权重调节。
var _fixed_card_interval:float = 0.0
## 本关是否在场上无坚果及高坚果时，将高坚果发卡替换为坚果，不检查传送带已有卡片。
var _tall_nut_fallback:bool = false
## 本关只读基础权重；每次临时生成调整表，不修改关卡共享资源。
var _classic_base_weights: Array[ResourceCardWeight] = []
## 上次发出的卡片身份；初始哨兵表示尚未发过卡。
var _last_classic_key: Vector3i = Vector3i(-1, -1, -1)
## 卡片消费后通知等待满槽的生成协程恢复。
signal signal_card_end

## 根据最大容量预先生成卡片目标位置。
func _ready() -> void:
	_init_card_position_x()

## 初始化零起点的传送带卡片目标 x 坐标。
func _init_card_position_x() -> void:
	# 槽位索引只控制布局，与内容编号无关。
	for index: int in range(num_card_max):
		all_card_pos_x_target.append(index * 50.0)

## 从 [param game_para] 获取统一有序卡、权重及倍率，初始化后保留首张卡。
func init_card_slot_conveyor_belt(game_para: ResourceLevelData) -> void:
	card_random_pool.init_card_random_pool(game_para.conveyor_weights)
	_classic_pool_rules = game_para.conveyor_classic_pool_rules
	_fixed_card_interval = game_para.conveyor_fixed_interval
	_tall_nut_fallback = game_para.conveyor_tall_nut_fallback
	_classic_base_weights = game_para.conveyor_weights
	_last_classic_key = Vector3i(-1, -1, -1)
	card_order = game_para.conveyor_order
	create_new_card_speed = game_para.create_new_card_speed
	create_new_card_cd /= create_new_card_speed
	if _fixed_card_interval > 0.0:
		create_new_card_cd = _fixed_card_interval
	create_new_card_timer.wait_time = create_new_card_cd
	await get_tree().process_frame
	_create_new_card()

## 按 [param delta] 秒推进传送带中的卡片位置。
func _process(delta: float) -> void:
	if not is_working:
		return
	# 卡片顺序决定其目标槽位。
	for index: int in curr_cards.size():
		if curr_cards[index].position.x > all_card_pos_x_target[index]:
			curr_cards[index].position.x -= delta * conveyor_velocity
		elif curr_cards[index].position.x < all_card_pos_x_target[index]:
			curr_cards[index].position.x = all_card_pos_x_target[index]

## [param card] 成功使用后移除并释放，再通知满槽等待者继续生成。
func card_use_end(card: Card) -> void:
	curr_cards.erase(card)
	card.queue_free()
	signal_card_end.emit()

## 计时器到期时尝试生成下一张卡。
func _on_create_new_card_timer_timeout() -> void:
	_create_new_card()

## 优先使用统一有序引用，缺省时按权重抽取；僵王和无效引用不生成出战卡。
func _create_new_card() -> void:
	if curr_cards.size() >= num_card_max:
		create_new_card_timer.stop()
		await signal_card_end
		create_new_card_timer.start()
	if _classic_pool_rules:
		_update_classic_interval()
		_update_classic_weights()
	# 有序表及随机池都返回相同引用类型，无需植物/僵尸分支。
	var reference: ResourceCardReference = card_order.get(all_num_card) if card_order.has(all_num_card) else card_random_pool.get_random_reference()
	if _tall_nut_fallback and reference != null and reference.card_type == ResourceCardReference.CardType.Plant \
		and reference.content_id == CharacterRegistry.PlantType.P024TallNut:
		# 只统计已经种在场上的植物，不检查带上卡片，也不修改共享引用。
		var wall_nut_count:int = int(Global.main_game.plant_cell_manager.curr_plant_num.get(CharacterRegistry.PlantType.P004WallNut, 0))
		var tall_nut_count:int = int(Global.main_game.plant_cell_manager.curr_plant_num.get(CharacterRegistry.PlantType.P024TallNut, 0))
		if wall_nut_count == 0 and tall_nut_count == 0:
			reference = ResourceCardReference.create(ResourceCardReference.CardType.Plant, CharacterRegistry.PlantType.P004WallNut, reference.is_imitater)
	if not AllCards.is_battle_card(reference) or reference.card_type == ResourceCardReference.CardType.ZombieBoss:
		push_error("CardSlotConveyorBelt：生成引用必须是已注册的植物或普通僵尸。")
		return
	# 卡片入树前已绑定完整引用和战斗交互上下文。
	var new_card: Card = AllCards.create_card(reference, Card.CardContext.Battle)
	if new_card == null:
		return
	new_card_area.add_child(new_card)
	# 基类入树时解析默认费用，传送带在之后设为免费卡。
	new_card.card_init_conveyor_belt()
	new_card.position = Vector2(new_card_area.size.x, 0)
	curr_cards.append(new_card)
	new_card.signal_card_use_end.connect(card_use_end)
	# 保留传送带原有的缩略图越界显示方式。
	var card_background: TextureRect = new_card.get_node("CardBg")
	card_background.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
	all_num_card += 1
	if _classic_pool_rules:
		_last_classic_key = reference.get_selection_key()
		if is_working:
			create_new_card_timer.start()


## 依据发卡前的带上卡数设置下一次间隔：0～4张4秒、5～6张4.25秒、7～8张5秒、9张起10秒。
func _update_classic_interval() -> void:
	if _fixed_card_interval > 0.0:
		create_new_card_timer.wait_time = _fixed_card_interval
		return
	# 原版使用百分之一秒计数，本项目直接使用游戏秒；满带暂停仍沿用原传送带流程。
	var count: int = curr_cards.size()
	create_new_card_timer.wait_time = 10.0 if count > 8 else (5.0 if count > 6 else (4.25 if count > 4 else 4.0))


## 按原版泳池规则构建本次临时权重：莲叶随场上及带上总数衰减，同类囤积和连续发卡抑制。
func _update_classic_weights() -> void:
	# 每次从基础表重新计算，不能累积修改上一轮结果。
	var adjusted: Array[ResourceCardWeight] = []
	# 只读的本关基础权重条目。
	for entry: ResourceCardWeight in _classic_base_weights:
		if entry == null or entry.card_reference == null or entry.weight <= 0:
			continue
		# 当前身份、带上同类数量及本次基础权重。
		var key: Vector3i = entry.card_reference.get_selection_key()
		var count_in_bank: int = 0
		var weight: int = entry.weight
		# 已发出但尚未使用的卡片，按完整身份区分。
		for card: Card in curr_cards:
			if is_instance_valid(card) and card.card_reference.get_selection_key() == key:
				count_in_bank += 1
		if entry.card_reference.card_type == ResourceCardReference.CardType.Plant \
			and entry.card_reference.content_id == CharacterRegistry.PlantType.P017LilyPad:
			# 莲叶总数达到18时基础权重降至1；低于18线性插值并按原整数权重截断。
			var total: int = int(Global.main_game.plant_cell_manager.curr_plant_num.get(CharacterRegistry.PlantType.P017LilyPad, 0)) + count_in_bank
			weight = int(lerpf(float(entry.weight), 1.0, clampf(float(total) / 18.0, 0.0, 1.0)))
		if _classic_base_weights.size() > 2:
			if count_in_bank >= 4:
				weight = 1
			elif count_in_bank >= 3:
				weight = 5
			elif key == _last_classic_key:
				weight = int(weight / 2.0)
		# 独立条目只引用原卡片身份，不修改其权重和修饰。
		var adjusted_entry: ResourceCardWeight = ResourceCardWeight.new()
		adjusted_entry.card_reference = entry.card_reference
		adjusted_entry.weight = weight
		adjusted.append(adjusted_entry)
	card_random_pool.init_card_random_pool(adjusted)

## 开始移动、齿轮动画和新卡计时。
func start_conveyor_belt() -> void:
	is_working = true
	conveyor_belt_gear.start_gear()
	create_new_card_timer.start()

## 停止移动、齿轮动画和新卡计时。
func stop_conveyor_belt() -> void:
	is_working = false
	conveyor_belt_gear.stop_gear()
	create_new_card_timer.stop()

## 根据 [param is_appeal] 显示或隐藏传送带，等待 0.2 秒移动完成。
func move_card_slot_conveyor_belt(is_appeal: bool) -> void:
	# 整个卡槽的位移动画。
	var tween: Tween = create_tween()
	tween.tween_property(self, "position:y", 0 if is_appeal else -100, 0.2)
	await tween.finished

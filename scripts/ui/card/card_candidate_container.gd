## 备选卡的占位背景，卡片移走后保留相同内容与费用预览。
extends Control
class_name CardCandidateContainer

## 与本容器关联的可选卡实例；选择时可移到出战卡槽。
var card: Card
## 与真实卡片保持一致的占位背景。
@onready var card_bg: TextureRect = $CardBg
## 显示真实卡片当前费用的占位标签。
@onready var cost: Label = $CardBg/Cost

## 子卡已完成初始化，复制其当前费用与静态缩略图到占位背景。
func _ready() -> void:
	# 卡已移入选卡槽时，由角色池原位的背景接收单独取消点击。
	mouse_filter = Control.MOUSE_FILTER_STOP
	cost.text = str(card.sun_cost)
	card_bg.texture = card.card_bg.texture
	# 占位预览与卡片互不共享节点，移动卡片不会带走背景。
	var static_preview: Node2D = AllCards.create_static_preview(card.card_reference)
	if static_preview != null:
		card_bg.add_child(static_preview)

## [param event] 点击角色池中已选择的卡牌占位时只取消该卡；真实卡仍在原位时由其按钮处理。
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed \
		and is_instance_valid(card) and card.is_choosed_pre_card \
		and card.card_context == Card.CardContext.Selection and is_instance_valid(Global.main_game) \
		and Global.main_game.main_game_progress in [MainGameManager.E_MainGameProgress.CHOOSE_CARD, MainGameManager.E_MainGameProgress.RE_CHOOSE_CARD]:
		card._on_button_pressed()
		accept_event()

## 入树前绑定 [param curr_card] 并设置返回位置，然后挂载子卡；占位不拥有卡牌身份。
func init_card_in_seed_chooser(curr_card: Card) -> void:
	card = curr_card
	curr_card.card_candidate_container = self
	add_child(curr_card)

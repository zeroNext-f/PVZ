extends Control
class_name CardSlotRoot

## 卡片
var curr_cards:Array[Card]
## 铲子
@onready var ui_shovel: UIShovel = %UIShovel

## 所有战斗模式共用的手套，快捷键与鼠标共用冷却检查。
@onready var ui_glove:UIBattleGlove = %UIBattleGlove

## 快捷键
@warning_ignore("unused_parameter")
func _unhandled_key_input(event):
	# 仅首次按下触发，长按键盘的自动重复不能反复开关时缓。
	if event.is_action_pressed("ShortcutKeys_SlowMotion", false):
		if is_instance_valid(Global.main_game):
			Global.main_game.toggle_slow_motion()
		get_viewport().set_input_as_handled()
		return
	if Input.is_action_just_pressed("ShortcutKeys_Glove"):
		if ui_glove.is_visible_in_tree():
			ui_glove._on_button_pressed()
		return
	## 铲子快捷键
	if Input.is_action_just_pressed("ShortcutKeys_Shovel"):
		if ui_shovel.visible:
			ui_shovel._on_button_pressed()
		return
	## 卡片快捷键
	for i in range(1,11):
		## 卡片快捷键
		if Input.is_action_just_pressed("ShortcutKeys_Card" + str(int(i))):
			## 0-9
			var card_i = i - 1
			if card_i < curr_cards.size():
				curr_cards[card_i]._on_button_pressed()
			else:
				return


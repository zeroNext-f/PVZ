## 冒险主页面中的白天入口只打开二级选关页，其他入口继续沿用原流程。
extends ChooseLevel

## 主页面现有白天按钮，保持原位置与存档编号不变。
@onready var day_entry:ChooseLevelButton = $AllPage/GridContainer/ChooseLevelButton
## 独立挂载的白天九关页面，不参与原主页面的关卡编号生成。
@onready var day_sublevels:Control = $DaySublevels
## 主页面共用标题，进入白天二级页时切换文字。
@onready var adventure_title:Label = $Label


## 初始化已配置的白天子关卡，空关卡继续保持占位，不参与旧主页面编号。
func _ready() -> void:
	super()
	day_sublevels.hide()
	# 第一关默认开放，此后仅在此前已配置关卡全部通关后开放下一关。
	var previous_completed:bool = true
	# 子关卡名称固定为 day_01 等，与其在场景中的排序无关，后续增加关卡不改变存档键。
	for node:Node in day_sublevels.get_node("GridContainer").get_children():
		# 当前九宫格中的关卡按钮；尚未配置的按钮不连接进入战斗信号。
		var level:ChooseLevelButton = node as ChooseLevelButton
		if level == null or level.is_placeholder or level.curr_level_data_game_para == null:
			continue
		level.curr_level_data_game_para.set_choose_level(game_mode, 0, level.curr_level_data_game_para.fixed_level_id)
		level.signal_choose_level_button.connect(_on_choose_level_button)
		# 当前独立子关卡的通关记录，不使用旧的白天整关记录代替。
		var level_state:Dictionary = Global.global_game_state.curr_all_level_state_data.get(level.curr_level_data_game_para.save_game_name, {})
		level.update_curr_level_button_state(level_state)
		if not previous_completed and not Global.config_service.open_all_level:
			level.lock_choose_level_button()
		previous_completed = previous_completed and bool(level_state.get("IsSuccess", false))


## [param choose_level_button] 白天按钮打开二级页，其他按钮仍按原配置进入战斗。
func _on_choose_level_button(choose_level_button:ChooseLevelButton):
	if choose_level_button == day_entry:
		all_page.hide()
		day_sublevels.show()
		adventure_title.text = "白 天"
		# 返回入口统一使用游戏原有主菜单按钮，避免键盘焦点停留在已隐藏的白天按钮。
		day_entry.texture_button.release_focus()
		return
	super(choose_level_button)

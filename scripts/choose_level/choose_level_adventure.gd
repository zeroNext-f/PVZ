## 冒险主页面保留原布局，白天与黑夜入口分别打开复用按钮的九关二级页。
extends ChooseLevel

## 原白天入口，沿用主页面编号。
@onready var day_entry:ChooseLevelButton = $AllPage/GridContainer/ChooseLevelButton
## 原黑夜入口，保留原按钮而不直接进入全局黑夜配置。
@onready var night_entry:ChooseLevelButton = $AllPage/GridContainer/ChooseLevelButton2
## 已有白天九关页面。
@onready var day_sublevels:Control = $DaySublevels
## 黑夜九关页面，独立固定存档编号night_01至night_09。
@onready var night_sublevels:Control = $NightSublevels
## 主页面共用标题。
@onready var adventure_title:Label = $Label

## 初始化两页固定编号、通关状态和顺序锁定，不参与原主页面自动编号。
func _ready() -> void:
	super()
	day_sublevels.hide()
	night_sublevels.hide()
	_init_sublevels(day_sublevels)
	_init_sublevels(night_sublevels)

## [param page] 二级九宫格；第一关开放，后续要求此前全部关卡通关，调试全开沿用原配置。
func _init_sublevels(page:Control) -> void:
	# 当前关卡之前是否全部通关。
	var previous_completed:bool = true
	# 复用的关卡按钮，顺序仅用于解锁，存档身份取资源固定编号。
	for node:Node in page.get_node("GridContainer").get_children():
		# 当前有效关卡，未配置占位不连接战斗入口。
		var level:ChooseLevelButton = node as ChooseLevelButton
		if level == null or level.is_placeholder or level.curr_level_data_game_para == null:
			continue
		level.curr_level_data_game_para.set_choose_level(game_mode, 0, level.curr_level_data_game_para.fixed_level_id)
		level.signal_choose_level_button.connect(_on_choose_level_button)
		# 独立子关卡记录，不沿用原整节点通关记录解锁全部九关。
		var level_state:Dictionary = Global.global_game_state.curr_all_level_state_data.get(level.curr_level_data_game_para.save_game_name, {})
		level.update_curr_level_button_state(level_state)
		if not previous_completed and not Global.config_service.open_all_level:
			level.lock_choose_level_button()
		previous_completed = previous_completed and bool(level_state.get("IsSuccess", false))

## [param choose_level_button] 主入口；[param curr_level_state_data] 原入口记录。
## 白天九关的通关键独立于旧白天入口，黑夜入口须同时兼容新白天完成记录。
func update_lock_level(choose_level_button:ChooseLevelButton, curr_level_state_data:Dictionary):
	if choose_level_button.name == "ChooseLevelButton2":
		# 固定白天末关的存档键，避免主页面旧编号一直未通关导致黑夜入口永久锁住。
		var day_final_key:String = str(game_mode) + "_0_day_09"
		# 旧黑夜入口已通关的玩家继续可访问，子关卡仍从自身记录顺序解锁。
		var day_final_state:Dictionary = Global.global_game_state.curr_all_level_state_data.get(day_final_key, {})
		if Global.config_service.open_all_level or curr_level_state_data.get("IsSuccess", false) or day_final_state.get("IsSuccess", false):
			return
		choose_level_button.lock_choose_level_button()
		return
	super(choose_level_button, curr_level_state_data)

## [param choose_level_button] 白天/黑夜主按钮只打开对应二级页，其余按钮复用原战斗入口。
func _on_choose_level_button(choose_level_button:ChooseLevelButton):
	if choose_level_button == day_entry or choose_level_button == night_entry:
		all_page.hide()
		day_sublevels.visible = choose_level_button == day_entry
		night_sublevels.visible = choose_level_button == night_entry
		adventure_title.text = "白 天" if choose_level_button == day_entry else "黑 夜"
		choose_level_button.texture_button.release_focus()
		return
	super(choose_level_button)

## 黑夜二级页返回时先回冒险主页面；其他页面保持原主菜单返回行为。
func back_start_menu():
	if night_sublevels.visible:
		night_sublevels.hide()
		all_page.show()
		adventure_title.text = "冒 险 模 式"
		return
	super()

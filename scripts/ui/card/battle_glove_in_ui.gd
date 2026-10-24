## 战斗工具栏手套，使用禅境花园原贴图；冷却只在成功搬运后开始。
extends TextureRect
class_name UIBattleGlove

## 每次成功移动后的冷却秒数，不受植物速度倍率影响。
const COOLDOWN_SECONDS:float = 15.0
## 工具图标，拿起工具时隐藏，退出手持时恢复。
@onready var icon:TextureRect = $Icon
## 点击区域。
@onready var button:Button = $Button
## 冷却数字。
@onready var cooldown_label:Label = $CooldownLabel
## 跟随鼠标的花园手套图标。
var cursor:Sprite2D
## 原生计时器随游戏暂停，选卡或切轮期间不消耗战斗冷却。
var cooldown_timer:Timer
## 当前是否处于手持状态。
var is_using:bool = false
## 卡槽进入战斗布局后才允许显示，避免传送带滑入期间在原点提前出现。
var toolbar_ready: bool = false


## 初始化工具点击信号、冷却计时器和独立前景鼠标图标。
func _ready() -> void:
	visible = false
	button.pressed.connect(_on_button_pressed)
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	add_child(cooldown_timer)
	cursor = Sprite2D.new()
	cursor.texture = icon.texture
	cursor.visible = false
	cursor.z_index = 100
	get_tree().current_scene.get_node("CanvasLayerTemp").add_child(cursor)


## 只在正式战斗显示，刷新冷却与鼠标图标。[param _delta] 为未使用的帧时长。
func _process(_delta:float) -> void:
	# 工具属于所有战斗模式，不依赖关卡是否开放铲子。
	var in_battle:bool = is_instance_valid(Global.main_game) \
		and Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME and toolbar_ready
	visible = in_battle
	cooldown_timer.paused = not in_battle
	button.disabled = not can_use()
	cooldown_label.text = str(ceili(cooldown_timer.time_left)) if not cooldown_timer.is_stopped() else ""
	icon.modulate = Color(0.45, 0.45, 0.45) if not cooldown_timer.is_stopped() else Color.WHITE
	if is_instance_valid(cursor):
		cursor.visible = in_battle and is_using
		# 前景层跟随视口，工具栏层不跟随；必须在鼠标图标自己的画布中读取坐标。
		cursor.global_position = cursor.get_global_mouse_position()


## 返回是否可以通过鼠标或 W 拿起工具，冷却期间不允许切换进入手套状态。
func can_use() -> bool:
	return toolbar_ready and is_instance_valid(cooldown_timer) and cooldown_timer.is_stopped() \
		and is_instance_valid(Global.main_game) \
		and Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME


## [param ready_for_battle] 卡槽入场动画与重挂载已完成；关闭时立即隐藏，位置和冷却进度不变。
func set_toolbar_ready(ready_for_battle: bool) -> void:
	toolbar_ready = ready_for_battle
	if not toolbar_ready:
		hide()
		if is_instance_valid(cursor):
			cursor.hide()


## 按钮与快捷键共用同一入口，避免快捷键绕过冷却。
func _on_button_pressed() -> void:
	if can_use():
		EventBus.push_event("main_game_click_glove")


## [param value] 是否正在使用手套，原工具栏图标随手持状态隐藏或恢复。
func set_using(value:bool) -> void:
	is_using = value
	icon.visible = not value
	if is_instance_valid(cursor):
		# 拿起当帧即定位，避免图标短暂显示在上一位置或画布原点。
		cursor.global_position = cursor.get_global_mouse_position()
		cursor.visible = value


## 仅成功迁移植物时调用，取消和无效落点不会消耗冷却。
func start_cooldown() -> void:
	cooldown_timer.start(COOLDOWN_SECONDS)


## 工具独立移除时同步清理前景鼠标图标。
func _exit_tree() -> void:
	if is_instance_valid(cursor):
		cursor.queue_free()

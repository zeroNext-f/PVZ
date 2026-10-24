extends Plant000Base
class_name Plant015IceShroom

## 最终引爆仍受睡眠等启用因素控制，落地释放使用组件的独立入口。
@onready var bomb_component: BombComponentIce = $BombComponent

## 正常新种植无条件释放一次并留场；展示、花园和存档恢复不重复触发出生技能。
func _ready() -> void:
	super()
	if character_init_type == E_CharacterInitType.IsNorm and is_instance_valid(Global.main_game) \
		and not plant_cell.is_restoring_plant_from_save:
		bomb_component.cast_entry_freeze()

## 空手点击本株时请求第二次冰冻；未启用的爆炸组件不响应，不消耗植物或卡牌。
## 返回是否成功释放；成功后死亡，is_bomb防止原亡语重复触发。
func activate_by_click() -> bool:
	if character_init_type != E_CharacterInitType.IsNorm or is_death or is_queued_for_deletion() \
		or not bomb_component.is_enabling or bomb_component.is_bomb \
		or not is_instance_valid(Global.main_game) \
		or Global.main_game.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME:
		return false
	bomb_component.bomb_once()
	character_death()
	return true

## 亡语
func death_language():
	bomb_component.judge_death_bomb()


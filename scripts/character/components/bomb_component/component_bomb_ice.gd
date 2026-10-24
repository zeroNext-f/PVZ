extends BombComponentBase
class_name BombComponentIce

@onready var bomb_effect: BombEffectBase = $BombEffect

@export var time_ice:float = 3
@export var time_decelerate: float = 5

## 落地释放独立的一次技能，不检查组件启用、不消耗is_bomb或最终引爆特效。
## 复制特效用于首次释放，原特效保留给后续点击或原亡语引爆。
func cast_entry_freeze() -> void:
	_play_bome_sfx()
	# 首次特效独立运行，避免原特效释放后第二次引爆引用已失效。
	var entry_effect: BombEffectBase = bomb_effect.duplicate() as BombEffectBase
	add_child(entry_effect)
	entry_effect.activate_bomb_effect()
	_bomb_all_enemy()

## 爆炸特效
func _start_bomb_fx():
	bomb_effect.activate_bomb_effect()

## 爆炸冰冻所有敌人
func _bomb_all_enemy():
	EventBus.push_event("ice_all_zombie", [time_ice, time_decelerate])

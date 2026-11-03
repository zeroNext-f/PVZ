extends BombComponentBase
class_name BombComponentJalapeno

## 辣椒实例提供所在行和世界坐标，用于整行伤害及最近火炬点燃。
var owner_plant:Plant000Base

func _ready() -> void:
	owner_plant = owner as Plant000Base

## 爆炸特效\冰道\梯子
func _start_bomb_fx():
	EventBus.push_event("jalapeno_bomb_effect", [owner_plant.row_col.x])

## 点燃同行最近一株火炬，再按本组件伤害对整行结算；保留冰道与梯子清除。
func _bomb_all_enemy():
	Global.main_game.plant_cell_manager.ignite_nearest_torch_in_lane(owner_plant)
	EventBus.push_event("jalapeno_bomb_lane_zombie", [owner_plant.row_col.x, bomb_value])
	## 销毁当前行道具[冰道和梯子]
	EventBus.push_event("jalapeno_bomb_item_lane", [owner_plant.row_col.x])


extends Plant000Base
class_name Plant016DoomShroom

@onready var bomb_component: BombComponentBase = %BombComponent

func ready_norm_signal_connect():
	super()
	# 引爆后改为生成本格墓碑，沿用墓碑占位、管理器登记及吞碑交互，不再创建坑洞。
	bomb_component.signal_bomb_once.connect(Global.main_game.plant_cell_manager.tomb_stone_manager.create_tombstone_at_cell.bind(plant_cell))


## 亡语
func death_language():
	bomb_component.judge_death_bomb()

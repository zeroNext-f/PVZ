extends Zombie000Base
class_name Zombie016Jackbox

@onready var bomb_component_jackbox: BombComponentJackbox = $BombComponentJackbox

@export_group("动画状态")
@export var is_pop:=false

## 撑杆落地召唤时直接进入开盒动画，不等待随机倒计时；普通自然出怪保持 false。
@export var spawn_with_open_box:bool = false

func ready_norm():
	super()
	## 罐子僵尸，直接爆炸
	if is_pot_zombie or spawn_with_open_box:
		_strigger_bomb()
	if spawn_with_open_box:
		# 留在落点播放完整开盒动画，期间不启动走路或啃食。
		move_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
		attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	bomb_component_jackbox.signal_trigger_bomb.connect(_strigger_bomb)
	hp_component.signal_hp_component_death.connect(bomb_component_jackbox.disable_component.bind(ComponentNormBase.E_IsEnableFactor.Death))

	signal_update_speed.connect(bomb_component_jackbox.owner_update_speed)


## 触发爆炸
func _strigger_bomb():
	is_pop = true
	bomb_component_jackbox.jack_bomb_timer.stop()
	SoundManager.play_character_SFX(&"boing")
	_stop_sfx_enter()

## 失去铁器道具
func loss_iron_item():
	super()
	bomb_component_jackbox.disable_component(ComponentNormBase.E_IsEnableFactor.Lose)
	_stop_sfx_enter()

func sfx_jack_suprise():
	SoundManager.play_character_SFX(&"jack_suprise")

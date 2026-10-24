## 正常出战橄榄球的动作路由，复用原版啃食/死亡与独立v4动作，展示仍使用原AnimationTree。
extends AnimComponentNorm
class_name AnimComponentFootball

## 原场景动画播放器，既有资源不替换。
@onready var _player:AnimationPlayer = $"../AnimationPlayer"
## 橄榄球所属角色，避免与其专属类形成脚本预加载环。
@onready var _football:Zombie000Base = owner
## 最新请求的动作，防止非循环死亡动作结束后被重新播放。
var _requested:StringName = &""
## 随机、寒冰、场外等共用因素乘积，不包含原版基础2倍。
var _speed_product:float = 1.0
## 清理车等强制停止动画后禁止路由重新启动播放器。
var _stopped:bool = false
## 慢走需恢复的手部贴图，原版啃食使用独立握拳/前臂贴图。
const WALK_TEXTURES:Dictionary = {
	"Zombie_football_leftarm_lower": preload("res://assets/reanim/Zombie_football_leftarm_lower.png"),
	"Zombie_football_leftarm_hand": preload("res://assets/reanim/Zombie_football_leftarm_hand.png"),
	"Zombie_football_rightarm_hand": preload("res://assets/reanim/zombie_football_rightarm_hand.png"),
}


## 保留原动画接口；只对正常出战关闭旧状态树，使用同一播放器播放新旧动作。
func _ready() -> void:
	super()
	if _football.character_init_type == Character000Base.E_CharacterInitType.IsNorm:
		animation_tree.active = false
		_player.animation_finished.connect(_on_animation_finished)


## [param _delta] 帧时间；死亡优先，冲刺期不会请求啃食，慢走期由原攻击状态切换。
func _process(_delta:float) -> void:
	if _stopped or _football.character_init_type != Character000Base.E_CharacterInitType.IsNorm:
		return
	if _football.is_death:
		_play(&"Zombie_football_death", 0.12)
		return
	if _football.football_launch_active:
		return
	# 阶段编号对应橄榄球的Charging/Impact/Walking，类间不互相预加载。
	var phase:int = int(_football.get("football_phase"))
	if phase == 0:
		_play(&"football/run", 0.0)
	elif phase == 1:
		_play(&"football/impact", 0.06)
	elif _football.is_attack:
		_play(&"Zombie_football_eat", 0.15)
	else:
		_play(&"football/slow", 0.15)


## [param animation_name] 播放动作；[param blend_seconds] 为切换混合时间。自定义动作已含制作时的快慢节奏。
func _play(animation_name:StringName, blend_seconds:float) -> void:
	if _requested == animation_name:
		return
	_requested = animation_name
	if String(animation_name).begins_with("football/"):
		# 只恢复三处啃食变体，不改头盔、掉手贴图或任何部件的死亡可见性。
		for node_name:String in WALK_TEXTURES:
			var sprite:Sprite2D = _football.get_node("Body/BodyCorrect/" + node_name) as Sprite2D
			sprite.texture = WALK_TEXTURES[node_name]
	_apply_player_speed()
	_player.play(animation_name, blend_seconds)


## 根据动作类型计算倍率：原版啃食/死亡保留场景基础速度，v4动作不再次乘2。
func _apply_player_speed() -> void:
	var base_speed:float = 1.0 if String(_requested).begins_with("football/") else animation_origin_speed
	_player.speed_scale = base_speed * _speed_product


## [param speed_factor_product] 继续服从随机、寒冰、冻结、黄油、顶飞和场外因素。
func owner_update_speed(speed_factor_product:float) -> void:
	_speed_product = speed_factor_product
	if _football.character_init_type != Character000Base.E_CharacterInitType.IsNorm:
		super(speed_factor_product)
	else:
		_apply_player_speed()


## [param speed_scale] 直接指定当前播放器倍率，兼容共用清除和演出接口。
func update_anim_speed_scale(speed_scale:float) -> void:
	if _football.character_init_type == Character000Base.E_CharacterInitType.IsNorm:
		_player.speed_scale = speed_scale
	else:
		super(speed_scale)


## 强制停止后不被_process重新启动。
func stop_anim() -> void:
	_stopped = true
	super()
	_player.stop(true)

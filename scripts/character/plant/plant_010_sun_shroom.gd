## 阳光菇：正常落地即生成八个25阳光，合计200，然后死亡；无周期生产或成长。
extends Plant000Base
class_name Plant010SunShroom

## 一次性生成的阳光数量，合计200。
const LANDING_SUN_COUNT:int = 8
## 每个阳光的价值。
const LANDING_SUN_VALUE:int = 25
## 阳光出生位置，沿用原角色的发光点。
@onready var marker_2d_create_sun:Marker2D = $Body/BodyCorrect/Marker2DCreateSun
## 本实例是否已支付落地阳光，防止重复回调或存档恢复重复领取。
var _landing_sun_paid:bool = false

## 正常出战入树后延迟到本帧初始化结束执行，预览、图鉴和花园不生产或死亡。
func ready_norm():
	super()
	_produce_landing_suns.call_deferred()

## 一次性落地效果；阳光与抛出补间挂在阳光实例上，不随植物死亡中断。
func _produce_landing_suns() -> void:
	if is_death or hp_component.is_death or is_queued_for_deletion() \
		or not is_instance_valid(Global.main_game):
		return
	if not _landing_sun_paid:
		_landing_sun_paid = true
		SoundManager.play_character_SFX("Throw1")
		# 八个独立阳光沿用已有抛出、收集与自动消失流程。
		for index:int in range(LANDING_SUN_COUNT):
			# 本次生成的 25 阳光，使用正式阳光场景和容器。
			var sun:Sun = SceneRegistry.SUN.instantiate()
			sun.init_sun(LANDING_SUN_VALUE, Global.main_game.suns.to_local(marker_2d_create_sun.global_position))
			Global.main_game.suns.add_child(sun)
			# 上抛再下落，复用原产光的 0.3+0.6 秒轨迹。
			var vertical_tween:Tween = sun.create_tween()
			vertical_tween.tween_property(sun, "position:y", -15.0, 0.3).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			vertical_tween.tween_property(sun, "position:y", 45.0, 0.6).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			sun.spawn_sun_tween = sun.create_tween()
			sun.spawn_sun_tween.set_parallel()
			sun.spawn_sun_tween.tween_subtween(vertical_tween)
			sun.spawn_sun_tween.tween_property(sun, "position:x", randf_range(-30.0, 30.0), 0.9).as_relative()
			sun.spawn_sun_tween.finished.connect(sun.on_sun_tween_finished)
	hp_component.Hp_loss_death()

## 保存一次性结算标记，避免初始化与过程存档恢复重叠时重复产出。
func gat_save_game_data_plant()->Dictionary:
	# 沿用本体血量、格子和睡眠等共用存档字段。
	var saved_data:Dictionary = super()
	saved_data["landing_sun_paid"] = _landing_sun_paid
	return saved_data

## [param saved_data] 已存植物数据；旧存档没有结算标记时视为未产出。
func load_game_data_plant(saved_data:Dictionary):
	super(saved_data)
	_landing_sun_paid = saved_data.get("landing_sun_paid", false)

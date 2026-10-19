## 全模式豌豆射手攻击：使用超能豌豆，每次攻击独立有四分之一概率四连发。
extends AttackComponentBulletBase
class_name AttackComponentAdventurePea

## 每次动画发射事件触发四连发的概率，取值为 0 到 1。
const BURST_CHANCE: float = 0.25
## 四连发的总弹数，包含立即发射的第一颗。
const BURST_COUNT: int = 4
## 正常角色速度下相邻子弹的间隔，单位为游戏秒。
const BURST_INTERVAL: float = 0.1
## 独立连射计时器，随角色速度调整并服从场景树暂停。
var _burst_timer: SpeedTimer
## 本轮连射尚未发射的弹数；死亡或组件禁用时清零。
var _remaining_bullets: int = 0


## 同步普通攻击周期与连射间隔；[param speed_product] 为角色速度因素乘积。
func owner_update_speed(speed_product: float):
	super(speed_product)
	if is_instance_valid(_burst_timer):
		_burst_timer.set_speed_scale(speed_product)


## 正常战斗的动画调用入口；所有模式每次攻击只抽取一次连射概率。
func _shoot_bullet():
	if not _can_continue_burst():
		return
	attack_bullet_type = BulletRegistry.BulletType.Bullet017SuperPea
	# 本次攻击总弹数；第一颗立即发射，剩余子弹按固定基础间隔排队。
	var shot_count: int = BURST_COUNT if randf() < BURST_CHANCE else 1
	_remaining_bullets = shot_count - 1
	super()
	if _remaining_bullets > 0:
		_ensure_burst_timer()
		_burst_timer.start_scaled(BURST_INTERVAL)


## 按需建立连射计时器，不改变原有攻击动画与射击冷却。
func _ensure_burst_timer() -> void:
	if is_instance_valid(_burst_timer):
		return
	_burst_timer = SpeedTimer.new()
	_burst_timer.name = "SuperPeaBurstTimer"
	_burst_timer.one_shot = true
	add_child(_burst_timer)
	_burst_timer.set_speed_scale(GlobalUtils.get_dic_product(owner.influence_speed_factors))
	_burst_timer.timeout.connect(_on_burst_timeout)


## 返回角色与本关卡是否仍允许完成本次连射；失去单个目标不取消已经触发的四连发。
func _can_continue_burst() -> bool:
	return is_enabling and is_instance_valid(owner) and not owner.is_death \
		and owner.character_init_type == Character000Base.E_CharacterInitType.IsNorm \
		and is_instance_valid(Global.main_game) \
		and Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME


## 按 [param is_enable_factor] 禁用组件时清除本轮连射，避免重新启用后补发旧子弹。
func disable_component(is_enable_factor: ComponentNormBase.E_IsEnableFactor):
	_remaining_bullets = 0
	if is_instance_valid(_burst_timer):
		_burst_timer.stop()
	super(is_enable_factor)


## 发射队列中的下一颗子弹；禁用、死亡或战斗结束后停止后续发射。
func _on_burst_timeout() -> void:
	if _remaining_bullets <= 0 or not _can_continue_burst():
		_remaining_bullets = 0
		return
	_remaining_bullets -= 1
	super._shoot_bullet()
	if _remaining_bullets > 0:
		_burst_timer.start_scaled(BURST_INTERVAL)

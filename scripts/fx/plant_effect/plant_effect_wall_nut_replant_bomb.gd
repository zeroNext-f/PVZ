## 坚果同格补种产生的独立灰烬爆炸，继承樱桃炸弹的伤害筛选与音画表现，不占种植位置。
extends Plant003CherryBomb

## 在下一个物理时机引爆；范围由爆炸组件即时形状查询获取，不依赖新区域的重叠缓存。
var _detonation_timer: Timer


## 初始化爆炸载体；不接受攻击，不播放樱桃种植后的等待动画，只释放其爆炸表现。
func ready_norm() -> void:
	super()
	hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	body.visible = false
	shadow.visible = false
	get_node("AnimationTree").active = false
	_detonation_timer = Timer.new()
	_detonation_timer.name = "ReplantDetonationTimer"
	_detonation_timer.one_shot = true
	_detonation_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_detonation_timer.wait_time = 0.001
	add_child(_detonation_timer)
	_detonation_timer.timeout.connect(_detonate)
	_detonation_timer.start()


## 仅结算一次 720 伤害爆炸；爆炸表现自行脱离载体播放，随后清除载体。
func _detonate() -> void:
	if is_death or is_queued_for_deletion():
		return
	bomb_component.bomb_once()
	character_death()

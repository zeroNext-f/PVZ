## 中体型读报：第一生命耗尽后破报，第二生命获得来源抗性并碾压。
extends Zombie000Base
class_name Zombie006Paper

@export_group("动画状态")
## 动画树以此标记进入无报纸分支。
@export var is_gasp:bool = false
## 两条生命各自的本体满血值。
const PAPER_BODY_HP:int = 270

## 正常出战只连接专属转阶段信号，不再使用旧破报攻击倍率。
func ready_norm_signal_connect():
	super()
	# 第一生命结束不触发基类真正死亡订阅者。
	var paper_hp:HpComponentPaper = hp_component as HpComponentPaper
	paper_hp.signal_first_life_lost.connect(_start_paper_reaction)

## [param _kind] 第一生命终结来源已保存；本体不高于89与报纸归零共用破报反应。
func _start_paper_reaction(_kind:int) -> void:
	attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsCharacter)
	hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	change_is_attack(false)
	# 本体先降至阈值也清除剩余报纸，本次伤害不向第二生命溢出。
	var paper_hp:HpComponentPaper = hp_component as HpComponentPaper
	paper_hp.curr_hp_armor2 = 0
	hp_stage_change_component.judge_body_change_armor(0, paper_hp.curr_hp, true, false)
	is_gasp = true
	SoundManager.play_character_SFX("Rarrgh")
	SoundManager.play_character_SFX("Rip")
	# 从任意持报动作直接进入反应，绕开普通死亡表现。
	var playback:AnimationNodeStateMachinePlayback = $AnimationTree.get("parameters/StateMachine/playback")
	playback.start("Zombie_paper_gasp")

## [param _delta] 帧秒数；按动画实际播放进度结束过渡，冻结会暂停反应。
func _process(_delta:float) -> void:
	if not is_instance_valid(hp_component):
		return
	# 只有两生命切换期间需要观察动画树。
	var paper_hp:HpComponentPaper = hp_component as HpComponentPaper
	if paper_hp.life_phase != HpComponentPaper.LifePhase.Reaction:
		return
	# 进入无报纸子树说明破报反应已经播完。
	var playback:AnimationNodeStateMachinePlayback = $AnimationTree.get("parameters/StateMachine/playback")
	if playback.get_current_node() == &"paper_gasp" and playback.get_fading_from_node() == &"":
		_start_second_life()

## 补满第二生命并恢复原本体掉手、掉头阈值，保留原实例异常状态与阵营。
func _start_second_life() -> void:
	# 专属组件保存两条生命和抗性，不重新创建僵尸。
	var paper_hp:HpComponentPaper = hp_component as HpComponentPaper
	paper_hp.life_phase = HpComponentPaper.LifePhase.Second
	paper_hp.max_hp = PAPER_BODY_HP
	paper_hp.max_hp_armor2 = 0
	paper_hp.death_hp = 89
	paper_hp.curr_hp = PAPER_BODY_HP
	hp_stage_change_component.boundary_value_hp.assign([179, 89])
	hp_stage_change_component.curr_hp_stage = -1
	# 保持冰车的正常、地面和低矮状态范围，专属检测器仅排除两种地刺。
	attack_component.detect_component.can_attack_plant_status = 13
	attack_component.detect_component.is_attack_ladder_plant = true
	hurt_box_component.enable_component(ComponentNormBase.E_IsEnableFactor.Character)
	move_component.update_move_factor(false, MoveComponent.E_MoveFactor.IsCharacter)
	attack_component.enable_component(ComponentNormBase.E_IsEnableFactor.Character)
	# 仅补入新增生命统计基数，不改变既有波间刷新条件或算法。
	if participates_natural_refresh and not is_hypno and is_instance_valid(Global.main_game):
		Global.main_game.zombie_manager.zombie_wave_manager.zombie_wave_refresh_manager.add_current_wave_health(curr_wave, PAPER_BODY_HP)

## [param attack_value] 爆炸伤害；[param is_cherry_bomb] 决定是否归为灰烬来源。
func be_bomb(attack_value:int, is_cherry_bomb:bool = false):
	# 第一生命耗尽只进入破报，第二生命才允许原灰烬死亡与删除表现。
	var paper_hp:HpComponentPaper = hp_component as HpComponentPaper
	paper_hp.lose_categorized_hp(attack_value, HpComponentPaper.DamageKind.Ash if is_cherry_bomb else HpComponentPaper.DamageKind.Normal, BulletRegistry.AttackMode.Penetration)
	if is_death:
		if is_cherry_bomb:
			charred_component.play_charred_anim()
		queue_free()

## 场外等管理性直接移除沿用原语义，必须先发送真正死亡通知，不能留下被释放的登记引用。
func character_death_disappear():
	is_can_death_language = false
	# 专属组件直接完成最终死亡，不进入第一生命的破报复活分支。
	var paper_hp:HpComponentPaper = hp_component as HpComponentPaper
	paper_hp.force_final_death()
	queue_free()

## [param lawn_mover] 原小推车；先完成最终死亡登记，再复用原碾压与淡出表现。
func be_mowered_run(lawn_mover:LawnMover):
	is_can_death_language = false
	# 小推车是原有强制清除，不让复活锁阻止其死亡信号。
	var paper_hp:HpComponentPaper = hp_component as HpComponentPaper
	paper_hp.force_final_death()
	super(lawn_mover)

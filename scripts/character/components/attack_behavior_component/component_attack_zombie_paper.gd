## 第一生命啃食，第二生命复用冰车碾压并完全排除地刺类。
extends AttackComponentZombieNorm
class_name AttackComponentZombiePaper

## 同级专用生命组件，决定当前攻击方式。
@onready var paper_hp:HpComponentPaper = %HpComponent

## [param delta] 物理帧秒数；第二生命不执行普通啃食扣血。
func _physics_process(delta:float) -> void:
	if paper_hp.life_phase == HpComponentPaper.LifePhase.First:
		super(delta)

## 第一生命停步啃食，第二生命不发送停步信号而直接碾压。
func attack_start():
	if paper_hp.life_phase == HpComponentPaper.LifePhase.First:
		super()
	elif paper_hp.life_phase == HpComponentPaper.LifePhase.Second:
		# 防止同格目标替换或旧缓存将地刺类送入扎胎反制。
		var target:Character000Base = detect_component.enemy_can_be_attacked
		if target is Plant022Caltrop or target is Plant047SpikeRock:
			return
		AttackComponentZombieZamboni.crush_detected_target(detect_component, owner)

## 仅第一生命接受旧啃食动画调用，过渡与第二生命没有啃食附加效果。
func attack_once():
	if paper_hp.life_phase == HpComponentPaper.LifePhase.First:
		super()

## 读报第二生命的碾压检测排除地刺、地刺王，不影响冰车或其他僵尸。
extends DetectComponent
class_name DetectComponentPaper

## 同级专用生命组件，第一生命仍使用原啃食检测规则。
@onready var paper_hp:HpComponentPaper = %HpComponent

## [param enemy] 当前碰撞目标；第二生命跳过地刺类，继续寻找其他合格目标。
func _judge_enemy_is_can_be_attack(enemy:Character000Base) -> bool:
	if paper_hp.life_phase == HpComponentPaper.LifePhase.Second \
		and (enemy is Plant022Caltrop or enemy is Plant047SpikeRock):
		return false
	return super(enemy)

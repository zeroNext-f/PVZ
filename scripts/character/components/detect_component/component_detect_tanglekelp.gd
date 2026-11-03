## 水草只主动抓取其他正常目标；潜水和海豚无论当前状态均不能作为主动主目标。
extends DetectComponent

## [param enemy] 范围内候选角色；先排除不能主动抓取的普通僵尸，再保留共用同行、阵营和受击窗口判断。
func _judge_enemy_is_can_be_attack(enemy: Character000Base) -> bool:
	if enemy is Zombie000Base and not GrapComponent.can_grab_target(enemy):
		return false
	return super._judge_enemy_is_can_be_attack(enemy)

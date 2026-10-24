## 读报专用两条生命；来源分类独立于防具伤害模式。
extends HpComponentZombie
class_name HpComponentPaper

## 致死来源；Crush 仅预留，现有倭瓜入口不接入。
enum DamageKind { Normal, Ash, Crush }
## 第一生命、破报过渡、第二生命。
enum LifePhase { First, Reaction, Second }
## 当前生命阶段。
var life_phase:LifePhase = LifePhase.First
## 第一生命记录的致死来源。
var lethal_damage_kind:DamageKind = DamageKind.Normal
## 当前伤害的来源上下文。
var _damage_kind:DamageKind = DamageKind.Normal
## 第二生命同类伤害只保留 10%。
const RESISTED_DAMAGE_RATIO:float = 0.1
## 第一生命耗尽，替代真正死亡；[param kind] 为致死来源。
signal signal_first_life_lost(kind:int)

## 第一生命由专属检查在本体不高于89或报纸归零时切换，禁用基类真正死亡信号。
func _ready() -> void:
	death_hp = -1
	super()

## [param value] 输入伤害；[param kind] 来源类别；[param mode] 原有防具结算模式。
func lose_categorized_hp(value:int, kind:DamageKind, mode:BulletRegistry.AttackMode) -> void:
	# 保存上下文，避免嵌套伤害信号污染下一次普通伤害。
	var previous_kind:DamageKind = _damage_kind
	_damage_kind = kind
	Hp_loss(value, mode, false, false)
	_damage_kind = previous_kind

## [param value] 已结算寒冰的伤害；第二生命同类来源乘 0.1，整数四舍五入。
func _resist_damage(value:int) -> int:
	if value > 0 and life_phase == LifePhase.Second and _damage_kind == lethal_damage_kind:
		return roundi(value * RESISTED_DAMAGE_RATIO)
	return value

## [param attack_value] 输入伤害；[param bullet_mode] 防具结算模式；[param apply_ice_bonus] 是否先结算寒冰。[br]
## [param is_drop_on_death]、[param is_drop_2] 控制掉落，[param trigger_be_attack_SFX] 控制音效。
func Hp_loss(attack_value:int, bullet_mode:BulletRegistry.AttackMode = BulletRegistry.AttackMode.Norm, is_drop_on_death=true, trigger_be_attack_SFX:=true, is_drop_2:=true, apply_ice_bonus:bool=true):
	if life_phase == LifePhase.Reaction or is_death or owner_character.is_death:
		return
	# 寒冰与抗性分别计算一次，父类不重复附加寒冰倍率。
	var damage:int = scale_ice_damage(attack_value) if apply_ice_bonus else attack_value
	damage = _resist_damage(damage)
	super(damage, bullet_mode, is_drop_on_death, trigger_be_attack_SFX, is_drop_2, false)
	_check_first_life()

## [param attack_value] 剧毒只扣本体，不附加寒冰；以普通来源参与第二生命抗性。
func lose_poison_body_hp(attack_value:int) -> void:
	if life_phase == LifePhase.Reaction:
		return
	super(_resist_damage(attack_value))
	_check_first_life()

## 第一生命本体不高于89或报纸归零时只转阶段，不发真正死亡或清场通知。
func _check_first_life() -> void:
	if life_phase == LifePhase.First and (curr_hp <= 89 or curr_hp_armor2 <= 0):
		lethal_damage_kind = _damage_kind
		life_phase = LifePhase.Reaction
		signal_first_life_lost.emit(lethal_damage_kind)

## 场外清理、小推车等原有强制移除不属于可复活伤害，直接完成真正死亡登记。
func force_final_death() -> void:
	if is_death or owner_character.is_death:
		return
	life_phase = LifePhase.Second
	death_hp = 89
	# 直接写入本体死亡，绕过伤害抗性与破报过渡锁，仍由生命组件发出唯一死亡信号。
	curr_hp = 0

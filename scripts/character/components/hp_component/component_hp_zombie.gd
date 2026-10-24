extends HpComponent
class_name HpComponentZombie
## 僵尸血量组件
@onready var progress_bar_hp_armor_2: ProgressBar = %ProgressBarHpArmor2
@onready var label_hp_armor_2: Label = %LabelHpArmor2
@onready var progress_bar_hp_armor_1: ProgressBar = %ProgressBarHpArmor1
@onready var label_hp_armor_1: Label = %LabelHpArmor1

@onready var armor_2_control: Control = %Armor2Control
@onready var armor_1_control: Control = %Armor1Control
@onready var hp_control: Control = %HpControl

@export_group("防具血量")
@export var max_hp_armor1:int
var curr_hp_armor1:int:
	set(value):
		value = max(value, 0)
		curr_hp_armor1 = value

		label_hp_armor_1.text = str(curr_hp_armor1)
		if max_hp_armor1 == 0:
			progress_bar_hp_armor_1.value = 0
		else:
			progress_bar_hp_armor_1.value = float(curr_hp_armor1) / max_hp_armor1

		if value == 0:
			armor_1_control.visible = false
			signal_armor1_death.emit()


@export var max_hp_armor2:int
var curr_hp_armor2:int:
	set(value):
		value = max(value, 0)
		curr_hp_armor2 = value

		## 血量ui显示
		label_hp_armor_2.text = str(curr_hp_armor2)
		if max_hp_armor2 == 0:
			progress_bar_hp_armor_2.value = 0
		else:
			progress_bar_hp_armor_2.value = float(curr_hp_armor2) / max_hp_armor2
		if value == 0:
			armor_2_control.visible = false
			signal_armor2_death.emit()

## 一类防具受击音效
@export var sfx_be_attack_armor1 := SoundManagerClass.TypeBeAttackSFX.Null
## 二类防具受击音效
@export var sfx_be_attack_armor2 := SoundManagerClass.TypeBeAttackSFX.Null

## 临界值状态（0为满血状态，每次到下一个状态 +1）
var curr_hp_stage:= 0
var curr_hp_stage_armor1:= 0
var curr_hp_stage_armor2:= 0

## 死亡后每4帧掉一次血
var num_frame := 0

signal signal_hp_armor1_loss(curr_hp_armor1:int, curr_hp:int, is_no_drop:bool)
signal signal_hp_armor2_loss(curr_hp_armor2:int, curr_hp:int, is_no_drop:bool)

## 一类防具死亡（掉落）信号
signal signal_armor1_death
## 二类防具死亡（掉落）信号
signal signal_armor2_death

## 僵尸掉血信号（只有僵尸使用）,参数为损失的血量值
signal signal_zombie_hp_loss(all_loss_hp:int)
## 正伤害分配与死亡判定之前通知特殊机制；不包含管理性移除或零伤害。
signal signal_before_damage

func _ready() -> void:
	super()
	self.curr_hp_armor1 = max_hp_armor1
	self.curr_hp_armor2 = max_hp_armor2

func _physics_process(delta: float) -> void:
	if owner_character.is_death and curr_hp != 0:
		num_frame = wrapi(num_frame + 1, 0, 4)
		if num_frame == 0:
			curr_hp -= max(int(delta * 50 * 4), 1)


func get_all_hp():
	return curr_hp_armor1 + curr_hp_armor2 + curr_hp


## [attack_value:int] 掉血的值
## [bullet_mode:AttackMode]: 伤害类型
## [is_drop_on_death:bool] 死亡时是否有掉落
## [trigger_be_attack_SFX:bool]:是否触发受击音效
## [is_drop_2:bool] 是否有掉落额外条件
## return bool: 返回是否死亡
## [param apply_ice_bonus] 正常伤害在防具分配前结算一次易伤；管理性移除不触发增伤。
func Hp_loss(attack_value:int, bullet_mode :BulletRegistry.AttackMode =BulletRegistry.AttackMode.Norm, is_drop_on_death=true, trigger_be_attack_SFX:=true, is_drop_2:=true, apply_ice_bonus:bool=true):
	if apply_ice_bonus and attack_value > 0 and not owner_character.is_death:
		signal_before_damage.emit()
	if apply_ice_bonus:
		attack_value = scale_ice_damage(attack_value)
	var ori_hp = get_all_hp()
	## 掉血标志, 1:本体 2:一类防具 4:二类防具
	var flag_loss:int = 0
	match bullet_mode:
		## 破甲豌豆不能绕过二类防具，但绕过一类防具；防具溢出沿用普通子弹规则。
		BulletRegistry.AttackMode.IgnoreArmor1:
			if curr_hp_armor2 > 0:
				# 二类防具扣血后的带符号值，用于计算仅一次的溢出伤害。
				var remaining_armor2:int = curr_hp_armor2 - attack_value
				curr_hp_armor2 = remaining_armor2
				flag_loss |= 4
				attack_value = maxi(-remaining_armor2, 0)
			if curr_hp > 0 and attack_value > 0:
				flag_loss |= 1
				curr_hp -= attack_value
		## 普通子弹
		BulletRegistry.AttackMode.Norm:
			# 如果有二类防具，先对二类防具掉血，若二类防具血量<0, 修改
			if curr_hp_armor2 > 0:
				var new_curr_hp_armor2 = curr_hp_armor2 - attack_value
				curr_hp_armor2 = new_curr_hp_armor2
				flag_loss |= 4
				if new_curr_hp_armor2 < 0:
					attack_value = -new_curr_hp_armor2
				else:
					attack_value = 0

			# 如果有一类防具
			if curr_hp_armor1 > 0 and attack_value > 0:
				var new_curr_hp_armor1 = curr_hp_armor1 - attack_value
				curr_hp_armor1 = new_curr_hp_armor1
				flag_loss |= 2
				if new_curr_hp_armor1 < 0:
					attack_value = -new_curr_hp_armor1
				else:
					attack_value = 0

			# 血量>0
			if curr_hp > 0 and attack_value > 0:
				flag_loss |= 1
				curr_hp -= attack_value


		## 穿透子弹,爆炸
		BulletRegistry.AttackMode.Penetration:
			# 如果有二类防具，先对二类防具掉血
			if curr_hp_armor2 > 0:
				var new_curr_hp_armor2 = curr_hp_armor2 - attack_value
				curr_hp_armor2 = new_curr_hp_armor2

				flag_loss |= 4

			# 如果有一类防具
			if curr_hp_armor1 > 0 and attack_value > 0:
				var new_curr_hp_armor1 = curr_hp_armor1 - attack_value
				curr_hp_armor1 = new_curr_hp_armor1
				flag_loss |= 2
				if new_curr_hp_armor1 < 0:
					attack_value = -new_curr_hp_armor1
				else:
					attack_value = 0

			# 血量>0
			if curr_hp > 0 and attack_value > 0:

				flag_loss |= 1
				curr_hp -= attack_value

		## 真实伤害子弹
		BulletRegistry.AttackMode.Real:
			# 如果有一类防具
			if curr_hp_armor1 > 0 and attack_value > 0:
				var new_curr_hp_armor1 = curr_hp_armor1 - attack_value
				curr_hp_armor1 = new_curr_hp_armor1
				flag_loss |= 2
				if new_curr_hp_armor1 < 0:
					attack_value = -new_curr_hp_armor1
				else:
					attack_value = 0

			# 血量>0
			if curr_hp > 0 and attack_value > 0:

				flag_loss |= 1
				curr_hp -= attack_value

		## 保龄球子弹
		BulletRegistry.AttackMode.BowlingFront:
			# 如果是正面
			# 如果有二类防具，先对二类防具掉血
			if curr_hp_armor2 > 0:

				# 如果为正面,无溢出伤害对二类防具造成400血量
				curr_hp_armor2 -= scale_ice_damage(400) if apply_ice_bonus else 400
				attack_value = 0
				flag_loss |= 4

			# 如果有一类防具
			if curr_hp_armor1 > 0 and attack_value > 0:
				## 对一类防具造成无溢出伤害800
				curr_hp_armor1 -= scale_ice_damage(800) if apply_ice_bonus else 800
				attack_value = 0
				flag_loss |= 2

			# 血量>0
			if curr_hp > 0 and attack_value > 0:
				#若有溢出伤害或没有防具 对僵尸本体造成1800伤害
				curr_hp -= scale_ice_damage(1800) if apply_ice_bonus else 1800
				flag_loss |= 1

		## 保龄球侧面子弹
		BulletRegistry.AttackMode.BowlingSide:

			#如果是正面
			# 如果有二类防具，先对二类防具掉血，若二类防具血量<0, 修改
			if curr_hp_armor2 > 0:
				#如果为侧面,二类防具造成1800血量， 溢出伤害1800
				curr_hp_armor2 -= scale_ice_damage(1800) if apply_ice_bonus else 1800
				attack_value = scale_ice_damage(1800) if apply_ice_bonus else 1800
				flag_loss |= 4
			# 如果有一类防具
			if curr_hp_armor1 > 0 and attack_value > 0:
				## 对一类防具造成无溢出伤害800
				curr_hp_armor1 -= scale_ice_damage(800) if apply_ice_bonus else 800
				attack_value = 0
				flag_loss |= 2

			# 血量>0
			if curr_hp > 0 and attack_value > 0:
				#若有溢出伤害或没有防具 对僵尸本体造成1800伤害
				curr_hp -= scale_ice_damage(1800) if apply_ice_bonus else 1800
				flag_loss |= 1

		## 锤子
		BulletRegistry.AttackMode.Hammer:
			# 如果有二类防具，无视二类防具,
			if curr_hp_armor2 > 0:
				pass
			# 如果有一类防具
			if curr_hp_armor1 > 0 and attack_value > 0:
				## 对一类防具造成无溢出伤害800
				curr_hp_armor1 -= scale_ice_damage(900) if apply_ice_bonus else 900
				attack_value = 0
				flag_loss |= 2

			# 血量>0 本体代码杀
			if curr_hp > 0 and attack_value > 0:
				#若有溢出伤害或没有防具 对僵尸本体造成伤害
				curr_hp -= curr_hp
				flag_loss |= 1


	var res_hp = get_all_hp()
	var loss_hp = ori_hp - res_hp

	var is_drop = not (owner.is_death and not is_drop_on_death) and is_drop_2

	## 组件发射掉血信号,僵尸发射僵尸掉血信号给僵尸管理器处理残半刷新
	signal_zombie_hp_loss.emit(loss_hp)
	if flag_loss & 1:
		signal_hp_loss.emit(curr_hp, is_drop)
		## 如果有受击音效并且触发受击音效
		if sfx_be_attack_body != SoundManager.TypeBeAttackSFX.Null and trigger_be_attack_SFX:
			SoundManager.play_be_attack_SFX(sfx_be_attack_body)

	if flag_loss & 2:
		signal_hp_armor1_loss.emit(curr_hp_armor1, curr_hp, is_drop)
		## 如果有受击音效并且触发受击音效
		if sfx_be_attack_armor1 != SoundManager.TypeBeAttackSFX.Null and trigger_be_attack_SFX:
			SoundManager.play_be_attack_SFX(sfx_be_attack_armor1)

	if flag_loss & 4:
		signal_hp_armor2_loss.emit(curr_hp_armor2, curr_hp, is_drop)
		## 如果有受击音效并且触发受击音效
		if sfx_be_attack_armor2 != SoundManager.TypeBeAttackSFX.Null and trigger_be_attack_SFX:
			SoundManager.play_be_attack_SFX(sfx_be_attack_armor2)

## 剧毒直接扣本体生命，绕过两类防具与寒冰易伤，保留原死亡、掉手掉头和刷新统计链路。[br]
## [param attack_value] 本次应扣本体生命，非正数或已死亡目标不处理。
func lose_poison_body_hp(attack_value:int) -> void:
	if attack_value <= 0 or is_death or owner_character.is_death or owner_character.is_queued_for_deletion():
		return
	# 扣血前本体生命，用于向自然波次刷新统计报告实际损失量。
	var previous_body_hp:int = curr_hp
	curr_hp -= attack_value
	signal_zombie_hp_loss.emit(previous_body_hp - curr_hp)
	signal_hp_loss.emit(curr_hp, true)


## 小僵尸大麻烦更新僵尸血量
func update_mini_zombie_hp():
	max_hp /= 2
	max_hp_armor1 /= 2
	max_hp_armor2 /= 2

	curr_hp = max_hp
	curr_hp_armor1 = max_hp_armor1
	curr_hp_armor2 = max_hp_armor2


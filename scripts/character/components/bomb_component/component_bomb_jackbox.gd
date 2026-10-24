extends BombComponentNorm
class_name BombComponentJackbox
## 小丑按爆炸瞬间阵营结算：敌方直接清除植物/魅惑僵尸，友方对敌方僵尸造成爆炸穿透伤害。

@onready var jack_bomb_timer: SpeedTimer = $JackBombTimer


## 早爆小丑概率
@export_range(0, 100, 1) var probability_early_bomb :int = 5
## 早爆小丑时间范围
@export var early_time_range:Vector2 = Vector2(4.4, 7.45)
## 晚爆小丑时间范围
@export var late_time_range:Vector2 = Vector2(13.22, 22.68)
## 小丑出生后爆炸时间
var wait_time_bomb :float= 0.0


## 小丑触发爆炸信号
signal signal_trigger_bomb

func _ready() -> void:
	owner = owner as Zombie000Base
	# 随机爆炸时长保持动作时间，已有速度与后续速度信号统一交给计时器。
	owner_update_speed(GlobalUtils.get_dic_product(owner.influence_speed_factors))
	## 如果出战角色
	if owner.character_init_type == Character000Base.E_CharacterInitType.IsNorm:
		var p = randi_range(1,100)
		## 早爆小丑
		if p <= probability_early_bomb:
			wait_time_bomb = randf_range(early_time_range.x, early_time_range.y)
		else:
			wait_time_bomb = randf_range(late_time_range.x, late_time_range.y)
		jack_bomb_timer.start_scaled(wait_time_bomb)

## 角色变速不重新抽取爆炸时间，冻结后从原有进度继续。
func owner_update_speed(speed_product:float):
	jack_bomb_timer.set_speed_scale(speed_product)

## 爆炸时间到,发射触发爆炸信号
func _on_jack_bomb_timer_timeout() -> void:
	signal_trigger_bomb.emit()

## 爆炸特效
func _start_bomb_fx():
	bomb_effect.activate_bomb_effect()

## 敌方清除与友方数值伤害分别筛选，复用普通爆炸即时形状查询，转换阵营后不等待重叠缓存刷新。
func _bomb_all_enemy():
	# 一次爆炸锁定来源阵营，不因结算目标引发的同步回调中途改用另一套攻击方式。
	var friendly:bool = (owner as Zombie000Base).is_hypno
	# 敌方：植物2、魅惑僵尸32、道具2048；友方：敌方僵尸4、攻击辅助框16。
	area_2d_bomb.collision_mask = 20 if friendly else 2082
	# 按角色去重，避免普通框及攻击辅助框让同一目标重复承受1800伤害。
	var seen_ids:Dictionary[int, bool] = {}
	# 弱引用快照允许前一个目标的死亡清理同步释放后续对象。
	var targets:Array[WeakRef] = []
	var pots:Array[WeakRef] = [] # 敌方小丑保留原有开罐行为，友方不处理罐子。
	# 即时查询使用原250×200形状，分页查询不限制目标总数。
	for area:Area2D in _query_current_bomb_areas():
		# 同一角色可拥有多个区域；在转换和读取属性前先检查有效性。
		var candidate:Variant = area.owner
		if not is_instance_valid(candidate) or seen_ids.has(candidate.get_instance_id()):
			continue
		if candidate is Character000Base and _is_jackbox_target(candidate, friendly):
			seen_ids[candidate.get_instance_id()] = true
			targets.append(weakref(candidate))
		elif not friendly and candidate is ScaryPot and absi(candidate.lane - owner.lane) <= 1:
			seen_ids[candidate.get_instance_id()] = true
			pots.append(weakref(candidate))
	# 每个合格角色最多结算一次，并在执行前重验阵营及存活状态。
	for reference:WeakRef in targets:
		# 先接收未转换引用，防止已释放对象在类型转换时触发错误。
		var value:Variant = reference.get_ref()
		if not is_instance_valid(value) or not _is_jackbox_target(value, friendly):
			continue
		# 已验证有效的伤害或清除目标。
		var character:Character000Base = value as Character000Base
		if not friendly:
			character.character_death_disappear()
		elif character is Zombie000Base:
			character.be_bomb(bomb_value, is_cherry_bomb)
		elif character is ZB000Base:
			character.be_attacked_bullet(bomb_value, BulletRegistry.AttackMode.Penetration, false, false)
	# 罐子沿用敌方爆炸开罐流程，友方从收集阶段起就排除。
	for reference:WeakRef in pots:
		# 原罐子可能已被角色死亡回调释放或排队清理。
		var pot:Variant = reference.get_ref()
		if is_instance_valid(pot) and not pot.is_queued_for_deletion():
			pot.open_pot_be_bomb()

## [param character] 当前范围内的候选角色；[param friendly] 为爆炸开始时锁定的小丑阵营。
## 友方沿用爆炸状态筛选及僵王受击窗口，敌方保留原植物清除并增加魅惑僵尸。
func _is_jackbox_target(character:Character000Base, friendly:bool) -> bool:
	if not is_instance_valid(character) or character == owner or character.is_death \
		or character.is_queued_for_deletion() or not character.is_inside_tree():
		return false
	if friendly:
		if character is Zombie000Base and character.is_hypno:
			return false
		return _can_bomb_character(character)
	return absi(character.lane - owner.lane) <= 1 \
		and (character is Plant000Base or (character is Zombie000Base and character.is_hypno))


## 禁用组件
func disable_component(is_enable_factor:E_IsEnableFactor):
	is_enable_factors[is_enable_factor] = false
	is_enabling = false
	jack_bomb_timer.stop()

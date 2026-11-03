## 烧灼状态表现与指定伤害后的后方灰烬连锁，不提供周期扣血、固定时限或独立秒杀判定。
extends RefCounted
class_name BurningState

## 每次溅射的基础灰烬伤害，后续仍经过防具、寒冰及专属抗性结算。
const SPLASH_DAMAGE:int = 20
## 烧灼特效的固定节点名，重复赋状态不重复叠加特效。
const EFFECT_NAME:StringName = &"BurningStatusEffect"
## 当前待结算的灰烬溅射事件；用队列取代递归，不限制同一僵尸再次实际受伤后的触发次数。
static var _pending_splashes:Array[Dictionary] = []
## 是否正在处理连锁；连锁内产生的新事件追加到队尾，不嵌套处理。
static var _processing_chain:bool = false

## [param character] 状态持有者；持续高亮和火焰仅用于存活正常出战的僵尸，不覆盖其他状态染色。
static func refresh_visual(character:Character000Base) -> void:
	if not is_instance_valid(character) or not is_instance_valid(character.body):
		return
	if not character.can_receive_abnormal_status() or not character.has_burning_placeholder or character.is_death:
		clear_visual(character)
		return
	if not (character is Zombie000Base or character is ZB000Base) \
		or character.character_init_type != Character000Base.E_CharacterInitType.IsNorm:
		return
	character.body.set_other_color(BodyCharacter.E_ChangeColors.BurningColor, Color(1.5, 1.5, 1.5))
	if character.has_node(NodePath(EFFECT_NAME)):
		return
	# 动态读取现有火焰子弹资源，只复制命中特效，不将模板子弹加入场景或计数。
	var fire_scene:PackedScene = load("res://scenes/bullet/bullet_006_pea_fire.tscn") as PackedScene
	var template:Node = fire_scene.instantiate()
	var effect:Node2D = template.get_node("BulletEffect").duplicate() as Node2D
	# 状态特效独立循环，移除原单次命中特效脚本，避免自动释放或访问原子弹owner。
	effect.set_script(null)
	effect.name = EFFECT_NAME
	effect.visible = true
	effect.position = Vector2(0, -20)
	effect.z_index = 5
	character.add_child(effect)
	# 循环使用同一套fire_done图像和轨道，独立副本不能改动所有火焰子弹的命中特效。
	var player:AnimationPlayer = effect.get_node("AnimationPlayer") as AnimationPlayer
	var animation:Animation = player.get_animation("fire_done").duplicate(true) as Animation
	animation.loop_mode = Animation.LOOP_LINEAR
	var library:AnimationLibrary = AnimationLibrary.new()
	library.add_animation(&"burning_loop", animation)
	for library_name:StringName in player.get_animation_library_list():
		player.remove_animation_library(library_name)
	player.add_animation_library(&"", library)
	player.play(&"burning_loop")
	template.free()

## [param character] 清除状态或死亡的持有者；只撤销烧灼自己的颜色和特效，不清除毒、寒冰或魅惑。
static func clear_visual(character:Character000Base) -> void:
	if not is_instance_valid(character):
		return
	if is_instance_valid(character.body):
		character.body.set_other_color(BodyCharacter.E_ChangeColors.BurningColor, Color.WHITE)
	# 死亡信号之前隐藏，避免queue_free延迟一帧仍显示在灰烬或复用身体上。
	var effect:Node2D = character.get_node_or_null(NodePath(EFFECT_NAME)) as Node2D
	if effect != null:
		effect.hide()
		# 同帧冰火互换时立即释放节点名，避免待删除旧特效阻止新烧灼创建自己的火焰表现。
		character.remove_child(effect)
		effect.queue_free()

## [param character] 即将承受指定火焰/灰烬伤害的角色；只对受击前已烧灼的存活僵尸记录快照。
## 返回包含受击前生命、行、朝向和位置的独立快照；无烧灼或不合格时返回空字典。
static func capture_hit(character:Character000Base) -> Dictionary:
	if not is_instance_valid(character) or character.is_death or character.is_queued_for_deletion() \
		or not character.can_receive_abnormal_status() or not character.has_burning_placeholder or not is_instance_valid(Global.main_game) \
		or not (character is Zombie000Base or character is ZB000Base):
		return {}
	# 优先使用普通僵尸真实行号，独立僵王按受击位置映射最近的一行。
	var lane:int = _get_lane(character)
	if lane < 0:
		return {}
	var cells:Array = Global.main_game.plant_cell_manager.all_plant_cells[lane]
	if cells.is_empty():
		return {}
	# 用场地实际相邻格中心的距离作为一格，不硬编码泳池/前院/屋顶的格距。
	var pitch:float = cells[0].size.x
	if cells.size() > 1:
		pitch = absf((cells[1].global_position.x + cells[1].size.x * 0.5) - (cells[0].global_position.x + cells[0].size.x * 0.5))
	return {"source":weakref(character), "hp_before":character.hp_component.get_all_hp(), "lane":lane,
		"x":character.global_position.x if character is Zombie000Base else character.hurt_box_component.global_position.x,
		"behind_direction":character.direction_x_root, "pitch":pitch}

## [param hit] 指定伤害结算前的快照；只有本体或防具总生命实际减少才触发，致死伤害仍可贡献本次连锁。
static func finish_hit(hit:Dictionary) -> void:
	if hit.is_empty():
		return
	# 弱引用可能已经失效，先验证再访问生命组件；正常死亡排队释放仍能完成本次触发。
	var source_reference:Variant = (hit["source"] as WeakRef).get_ref()
	if not is_instance_valid(source_reference) or source_reference.hp_component.get_all_hp() >= hit["hp_before"]:
		return
	_pending_splashes.append(hit)
	if _processing_chain:
		return
	_processing_chain = true
	# 允许任意多次符合条件的连锁；没有每只僵尸一次、层数或次数上限。
	while not _pending_splashes.is_empty():
		var splash:Dictionary = _pending_splashes.pop_front()
		_apply_splash(splash)
	_processing_chain = false

## [param splash] 已确认发生的受击事件；同行朝向相反的一格距离内所有存活僵尸均受20基础灰烬伤害。
## 普通敌方朝左前进时身后为右侧；魅惑反向后身后为左侧，不按阵营、体型或水下状态排除目标。
static func _apply_splash(splash:Dictionary) -> void:
	if not is_instance_valid(Global.main_game):
		return
	# 同一事件按角色快照处理一次，不按受击框数量重复命中；新的实际受伤仍可再次排队。
	var targets:Array = Global.main_game.zombie_manager.all_zombies_1d.duplicate()
	targets.append_array(Global.main_game.zombie_manager.get_living_bosses())
	for target_reference:Variant in targets:
		if not is_instance_valid(target_reference):
			continue
		var target:Character000Base = target_reference as Character000Base
		if target.is_death or target.is_queued_for_deletion() or _get_lane(target) != splash["lane"]:
			continue
		if not is_instance_valid(target.hurt_box_component) or not target.hurt_box_component.is_enabling:
			continue
		# 只以实际横向位置取身后一格距离，边界包含最远一格，不扩展到邻行或本体同点。
		var target_x:float = target.global_position.x if target is Zombie000Base else target.hurt_box_component.global_position.x
		var behind_distance:float = (target_x - float(splash["x"])) * float(splash["behind_direction"])
		if behind_distance <= 0.0 or behind_distance > float(splash["pitch"]):
			continue
		if target is Zombie000Base:
			target.be_bomb(SPLASH_DAMAGE, true)
		elif target is ZB000Base:
			target.be_bomb(SPLASH_DAMAGE, true)

## [param character] 普通僵尸或独立僵王；返回场地实际行，无法映射时返回-1。
static func _get_lane(character:Character000Base) -> int:
	# 当前场地行数组用于验证索引及独立僵王最近行映射。
	var rows:Array = Global.main_game.plant_cell_manager.all_plant_cells
	if character.lane >= 0 and character.lane < rows.size():
		return character.lane
	if not character is ZB000Base:
		return -1
	var best_lane:int = -1
	var best_distance:float = INF
	for row_index:int in range(rows.size()):
		if rows[row_index].is_empty():
			continue
		var cell:PlantCell = rows[row_index][0]
		var distance:float = absf(character.hurt_box_component.global_position.y - (cell.global_position.y + cell.size.y * 0.5))
		if distance < best_distance:
			best_distance = distance
			best_lane = row_index
	return best_lane

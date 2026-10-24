extends Character000Base
class_name Zombie000Base


@onready var attack_component: AttackComponentBase = %AttackComponent
@onready var hp_stage_change_component: HpStageChangeComponent = %HpStageChangeComponent
@onready var charred_component: CharredComponent = %CharredComponent
@onready var move_component: MoveComponent = %MoveComponent
@onready var swim_box_component: SwimBoxComponent = %SwimBoxComponent
@onready var drop_item_component: DropItemComponent = %DropItemComponent
## 灰烬表现已开始，供大嘴花等目标筛选排除正在化灰的僵尸，不随动画节点重挂而丢失。
var is_charred:bool = false
## 是否已受剧毒影响；首次施加后持续至死亡，重复施加不刷新、不叠加。
var is_poisoned:bool = false
## 烧灼状态空占位：供大喷菇识别与共享，不附加伤害、计时或音画效果。
var has_burning_placeholder:bool = false
## 是否正在被橄榄球顶飞；受击分类暂为气球同款IsSky，独立于原本阵营。
var football_launch_active:bool = false
## 顶飞前或期间其他机制请求的受击状态，落地后恢复。
var _football_restore_status:E_BeAttackStatusZombie = E_BeAttackStatusZombie.IsNorm
## 顶飞轨迹或被三叶草吹走的补间，重复顶飞时取消旧轨迹。
var _football_launch_tween:Tween
## 当前飞行起点、终点横坐标，重复顶飞从当前落点前再推三格。
var _football_launch_start_x:float = 0.0
## 当前顶飞的终点横坐标。
var _football_launch_end_x:float = 0.0
## 当前根节点抬升高度与重启轨迹时已有的抬升高度，影子反向抵消保持贴地。
var _football_launch_height:float = 0.0
## 重启顶飞时继承的原抬升高度。
var _football_launch_start_height:float = 0.0
## 顶飞期间暂停的跳跃补偿组件及其原始处理开关。
var _football_jump_component:Node
## 跳跃补偿组件原来的_process启用状态。
var _football_jump_was_processing:bool = false
## 已进入吹走清除流程的单位不再被另一只橄榄球救回。
var _football_blowing_away:bool = false
## 每次剧毒扣血间隔，单位为游戏秒；只随全局速度与暂停变化。
const POISON_TICK_SECONDS:float = 1.0
## 每秒扣除当前本体最大生命的比例，不包含一类或二类防具。
const POISON_BODY_HP_RATIO:float = 0.03

#region 僵尸类基础属性
@export var zombie_type:CharacterRegistry.ZombieType
## 僵尸基础属性参数，_ready初始化
@export_group("僵尸基础属性")
## 供战斗机制判断的体型分类；编号固定，不与图片尺寸或碰撞框大小自动关联。
enum BodySize {
	Small = 0, ## 小体型。
	Medium = 1, ## 中体型。
	Large = 2, ## 大体型。
}

## 当前僵尸的机制体型，默认小；后续角色可在继承场景中配置中或大，不随小僵尸模式缩放改变。
@export var zombie_body_size: BodySize = BodySize.Small

## 是否忽略梯子,即可以攻击梯子下的植物
@export var is_ignore_ladder:=false
## 是否为小僵尸大麻烦的小僵尸(速度翻倍,大小,血量减半)
var is_mini_zombie:= false
## 是否为罐子创建的僵尸
var is_pot_zombie:=false
## 是否正在从地下出现
var is_body_up_from_ground := false

@export_subgroup("僵尸铁器")
## 铁器种类
enum IronType{
	Null,		## 没有铁器
	IronArmor1,	## 一类铁器防具
	IronArmor2,	## 二类铁器防具
	IronItem,	## 铁器道具
}

## 僵尸铁器类型
@export var iron_type:IronType = IronType.Null
## 僵尸铁器节点
@export var iron_node:IronNode
@export_subgroup("僵尸初始化状态")
## 僵尸初始化状态（从1[is_norm] 开始，被攻击时是否能被攻击到的属性）
@export var init_be_attack_status :E_BeAttackStatusZombie = E_BeAttackStatusZombie.IsNorm
## 僵尸出生波次
var curr_wave:=-1
## 是否参与自然出怪的提前刷新数量统计；博士召唤及其衍生僵尸为 false，全场计数不受影响。
var participates_natural_refresh: bool = true
## 僵尸当前状态
var curr_be_attack_status:E_BeAttackStatusZombie=E_BeAttackStatusZombie.IsNorm:
	set(value):
		if football_launch_active and value != E_BeAttackStatusZombie.IsSky:
			_football_restore_status = value
			curr_be_attack_status = E_BeAttackStatusZombie.IsSky
		else:
			curr_be_attack_status = value
		signal_status_update.emit()

## 当前僵尸所在行，陆地、水池
var curr_zombie_row_type:CharacterRegistry.ZombieRowType=CharacterRegistry.ZombieRowType.Land
## 水路两栖僵尸当前行为水路时body变化
@export var body_change_on_pool:ResourceBodyChange

## 是否可以触发倭瓜位置判定，默认都为否，可以跳跃的僵尸跳跃组件跳跃后修改为否
@export var is_trigger_squash_pos_judge := false
## 是否可以高建国强行停止跳跃判定，默认都为否，可以跳跃的僵尸跳跃组件跳跃后修改为否
@export var is_trigger_tall_nut_stop_jump := false

## 状态更新信号
signal signal_status_update
## 行更新信号
signal signal_lane_update
#func _update_lane(new_lane):
	#lane = new_lane
	#signal_lane_update.emit()

## 僵尸掉血信号（只有僵尸使用）,参数为损失的血量值
signal signal_zombie_hp_loss(all_loss_hp:int, wave:int)

#endregion

#region 角色枚举
## 检测攻击时，根据状态判断是否可以攻击
enum E_BeAttackStatusZombie{
	IsNorm = 1,		## 正常
	IsJump = 2,		## 跳跃
	IsDownPool = 4,		## 水下
	IsSky = 8,			## 空中
	IsDownGround = 16,	## 地下
	IsJumpInPool = 32,	## 跳入泳池,该状态无法被高建国拦截
}

#endregion

#region 僵尸动画状态参数
@export_group("动画状态")
## 默认为移动状态,is_walk由多种状态控制
@export var is_walk := true
@export var is_attack := false:
	set(value):
		is_attack = value
		_judge_is_walk()
@export var is_swimming := false
##是否为珊瑚僵尸
var is_seaweed:=false
## 父类通用
#var is_death := false

## 被炸死
var is_bomb_death := false:
	set(value):
		is_bomb_death = value
		_judge_is_walk()

## is_walk由is_attack 和 is_bomb_death控制
func _judge_is_walk():
	is_walk = not is_attack and not is_bomb_death

#endregion

@export_group("入场音效")
@export var sfx_enter_name:StringName
## 入场音效
var sfx_enter:AudioStreamPlayer
var is_sfxing:=false
## 停止入场音效(死亡\失去小丑盒子)
func _stop_sfx_enter():
	if is_sfxing:
		sfx_enter.stop()

@export_group("其他")
@export_subgroup("黄油")
## 头的可能的节点路径,黄油糊脸使用,若路径都不对,新增一个对应的路径
var head1_path_candidate:Array[NodePath] = [
	"Body/BodyCorrect/Anim_head/Anim_head1",
	"Body/BodyCorrect/Anim_head1",
	"Body/BodyCorrect/Zombie_head",
	"Body/BodyCorrect/Head/Anim_head1",
	"Body/BodyCorrect/Zombie_catapult_driver_head",
]
## 头的节点
var head_node:Node2D
## 黄油节点,
var butter_splat:Node2D

## 僵尸初始化属性
enum E_ZInitAttr{
	CharacterInitType,	## 角色初始化类型（正常、展示）
	Lane,				## 僵尸行
	CurrZombieRowType,	## 僵尸所在行属性（水、陆地）
	CurrWave,			## 僵尸波次
	IsMiniZombie,		## 是否为小僵尸大麻烦的小僵尸
	IsPotZombie,		## 是否为罐子生成的僵尸，小丑瞬爆
	IsZombieMode,		## 是否为我是僵尸模式的僵尸，气球落地,撑杆食脑
	## 是否参与自然出怪提前刷新，子僵尸继承来源；默认 true 保留原有生成方式的行为。
	ParticipatesNaturalRefresh,
}

## 修改初始化状态，在添加到场景树之前调用
func init_zombie(zombie_init_para:Dictionary):
	self.character_init_type = zombie_init_para.get(E_ZInitAttr.CharacterInitType, E_CharacterInitType.IsNorm)
	self.is_mini_zombie = zombie_init_para.get(E_ZInitAttr.IsMiniZombie, false)
	# 入树前注入来源，供 ready 中的衍生生成和主场景登记使用。
	self.participates_natural_refresh = zombie_init_para.get(E_ZInitAttr.ParticipatesNaturalRefresh, true)
	match self.character_init_type:
		E_CharacterInitType.IsNorm:
			self.is_pot_zombie = zombie_init_para.get(E_ZInitAttr.IsPotZombie, false)
			self.is_zombie_mode = zombie_init_para.get(E_ZInitAttr.IsZombieMode, false)
			self.lane = zombie_init_para.get(E_ZInitAttr.Lane, -1)
			if zombie_init_para.has(E_ZInitAttr.CurrZombieRowType):
				self.curr_zombie_row_type = zombie_init_para[E_ZInitAttr.CurrZombieRowType]
			else:
				self.curr_zombie_row_type = Global.main_game.zombie_manager.all_zombie_rows[lane].zombie_row_type
			self.curr_wave = zombie_init_para.get(E_ZInitAttr.CurrWave, -1)


func _ready() -> void:
	if is_mini_zombie:
		update_mini_zombie()
	super()
	##INFO: 检测是否有头节点
	var is_have_head:=false
	for head1_path:NodePath in head1_path_candidate:
		if has_node(head1_path):
			head_node = get_node(head1_path)
			is_have_head = true
			break
	if not is_have_head:
		printerr(name, "没有获取头节点")

## 初始化正常出战角色
func ready_norm():
	super()
	var is_have_head:=false
	for head1_path:NodePath in head1_path_candidate:
		if has_node(head1_path):
			head_node = get_node(head1_path)
			is_have_head = true
			break
	if not is_have_head:
		printerr(name, "没有获取头节点")
	curr_be_attack_status = init_be_attack_status
	## 若生成位置在斜面中,生成时修正斜面位置
	if is_instance_valid(Global.main_game.main_game_slope):
		## 获取对应位置的斜面y相对位置
		var slope_y_first = Global.main_game.main_game_slope.get_all_slope_y(global_position.x)
		move_y_zombie(slope_y_first)
	## 僵尸普通攻击组件连接信号
	#if attack_component is AttackComponentZombieNorm:
		### 攻击组件是否攻击梯子下僵尸
		#attack_component.init_attack_component(is_ignore_ladder)
	## 攻击的检测组件更新是否可以攻击梯子下的植物，是否忽略梯子
	attack_component.detect_component.is_attack_ladder_plant = is_ignore_ladder
	## 两栖类僵尸在水路时变化
	if Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieRowType) == CharacterRegistry.ZombieRowType.Both:
		if body_change_on_pool != null:
			zombie_row_type_both_body_update()

	## 舞王僵尸会报错，当前帧最后调用
	call_deferred("judge_battlefield_update_speed")

## 两栖类僵尸body变化
func zombie_row_type_both_body_update():
	## 水路时body变化
	if curr_zombie_row_type == CharacterRegistry.ZombieRowType.Pool:
		for sprite_path in body_change_on_pool.sprite_appear:
			var sprite = get_node(sprite_path)
			sprite.visible = true

		for sprite_path in body_change_on_pool.sprite_disappear:
			var sprite = get_node(sprite_path)
			sprite.visible = false
	else:

		for sprite_path in body_change_on_pool.sprite_appear:
			var sprite = get_node(sprite_path)
			sprite.visible = false

		for sprite_path in body_change_on_pool.sprite_disappear:
			var sprite = get_node(sprite_path)
			sprite.visible = true

#region 宽屏下僵尸是否在战场外
## 判断是否在战场的计时器，每0.3秒判断一次
var judge_battlefield_timer:Timer
## 进入战场信号
signal signal_enter_battlefield

## 僵尸判断宽屏战场外移动加速
func judge_battlefield_update_speed():
	if global_position.x >= 800:
		## 初始化角色速度
		update_speed_factor(2, E_Influence_Speed_Factor.OutBattlefield)
		judge_battlefield_timer = Timer.new()
		judge_battlefield_timer.name = "judge_battlefield_timer"
		judge_battlefield_timer.wait_time = 0.3
		judge_battlefield_timer.one_shot = false
		judge_battlefield_timer.timeout.connect(_on_judge_battlefield_timer_timeout)
		add_child(judge_battlefield_timer)
		judge_battlefield_timer.start()
		## 等待进入战场
		await signal_enter_battlefield
		update_speed_factor(1, E_Influence_Speed_Factor.OutBattlefield)

func _on_judge_battlefield_timer_timeout():
	#print("判断一次是否进入战场")
	if global_position.x < 800:
		signal_enter_battlefield.emit()
		judge_battlefield_timer.queue_free()

#endregion

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	## 入场音效相关
	if not sfx_enter_name.is_empty():
		## 入场音效
		sfx_enter = SoundManager.play_character_SFX(sfx_enter_name)
		## 同一帧多次播放同一音效时不播放新音效
		if sfx_enter:
			is_sfxing = true
			sfx_enter.finished.connect(func():is_sfxing = false)
			hp_component.signal_hp_component_death.connect(_stop_sfx_enter)

	hp_component.signal_zombie_hp_loss.connect(func(hp_loss:int): signal_zombie_hp_loss.emit(hp_loss, curr_wave))
	## 角色死亡时禁用攻击组件
	hp_component.signal_hp_component_death.connect(attack_component.disable_component.bind(ComponentNormBase.E_IsEnableFactor.Death))
	## 攻击组件
	attack_component.signal_change_is_attack.connect(move_component.update_move_factor.bind(move_component.E_MoveFactor.IsAttack))
	attack_component.signal_change_is_attack.connect(change_is_attack)
	hurt_box_component = hurt_box_component as HurtBoxComponentZombie
	## 攻击时受击组件
	attack_component.signal_change_is_attack.connect(hurt_box_component.change_area_attack_appear)

	## 死亡时取消黄油
	hp_component.signal_hp_component_death.connect(death_stop_butter)

	## 血量状态变化组件
	hp_component.signal_hp_loss.connect(hp_stage_change_component.judge_body_change)
	## 防具血量状态变化组件
	hp_component.signal_hp_armor1_loss.connect(hp_stage_change_component.judge_body_change_armor.bind(true))
	hp_component.signal_hp_armor2_loss.connect(hp_stage_change_component.judge_body_change_armor.bind(false))

	## 当前动画结束时，移动组件改变移动状态
	anim_component.signal_animation_finished.connect(move_component._on_animation_finished)

	## 被魅惑信号
	signal_character_be_hypno.connect(hurt_box_component.owner_be_hypno)
	signal_character_be_hypno.connect(attack_component.owner_be_hypno)
	signal_character_be_hypno.connect(move_component._walking_start)

	## 游泳信号
	swim_box_component.signal_change_is_swimming.connect(change_is_swimming)

	## 铁器防具
	match iron_type:
		IronType.IronArmor1:
			hp_component.signal_armor1_death.connect(func():iron_type=IronType.Null)
		IronType.IronArmor2:
			hp_component.signal_armor2_death.connect(func():iron_type=IronType.Null)

	## 掉落战利品
	hp_component.signal_hp_component_death.connect(drop_item_component.drop_coin)
	hp_component.signal_hp_component_death.connect(drop_item_component.drop_garden_plant)

	## 移动僵尸本体y位置,修改对应检测层面节点位置
	move_component.signal_move_body_y.connect(move_y_zombie)

	## 对移动速度影响,只对速度移动模式生效
	signal_update_speed.connect(move_component.owner_update_speed)
	## 对攻击影响,
	signal_update_speed.connect(attack_component.owner_update_speed)

## 初始化展示角色
func ready_show():
	super()
	move_component.disable_component(ComponentNormBase.E_IsEnableFactor.InitType)

## 改变攻击状态攻击
func change_is_attack(value:bool):
	is_attack = value

## 更新移动方向修正(斜面时使用)
func update_move_dir_y_correct(move_dir_y_correct_slope:Vector2):
	#print("更新移动方向:", move_dir)
	move_component.move_dir_y_correct_slope = move_dir_y_correct_slope


## 角色移动y值(本体移动,同时修改检测层面的节点)
func move_y_zombie(move_y:float):
	position.y += move_y
	for n in node2d_detect_in_slope:
		n.position.y -= move_y

## 改变游泳状态,切换动画时0.2秒过度时间停止移动
func change_is_swimming(value:bool):
	is_swimming = value
	move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsSwimingChange)
	await get_tree().create_timer(0.2).timeout
	move_component.update_move_factor(false, MoveComponent.E_MoveFactor.IsSwimingChange)
	shadow.visible = not value

#region 僵尸受伤、死亡、
## 进入死亡时先移除残留一类防具，再发出死亡信号并进入原有掉头、受击关闭等流程。
func character_death():
	# 先标记逻辑死亡，防具移除回调不能再触发气球落地等存活状态行为。
	is_death = true
	finish_football_launch()
	if is_instance_valid(all_timer[E_TimerType.Poison]):
		all_timer[E_TimerType.Poison].stop()
	_remove_armor1_before_head_drop()
	super()
	hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Death)
	swim_box_component._on_owner_is_death()
	#attack_component.queue_free()


## 掉头前兜底清除一类防具；兼容绕过防具致死、正常破甲及换装生成的防具。[br]
## 已脱落的防具不重复生成掉落物；只处理一类防具，不修改二类防具或本体死亡阈值。
func _remove_armor1_before_head_drop() -> void:
	# 复用僵尸生命组件与阶段资源，保持防具血条、铁器标记、破损贴图及脱落表现一致。
	var zombie_hp: HpComponentZombie = hp_component as HpComponentZombie
	if zombie_hp == null or zombie_hp.max_hp_armor1 <= 0:
		return
	if zombie_hp.curr_hp_armor1 > 0:
		zombie_hp.curr_hp_armor1 = 0
	if is_instance_valid(hp_stage_change_component):
		# 即使血量先前已经清零，也要补齐可能尚未执行的防具脱落阶段；阶段组件会去重。
		hp_stage_change_component.judge_body_change_armor(0, zombie_hp.curr_hp, true, true)

## 僵尸死亡后逐渐透明，最后删除节点
func _fade_and_remove():
	var tween = create_tween()  # 自动创建并绑定Tween节点
	tween.tween_property(self, "modulate:a", 0.0, 1.0)  # 1秒内透明度降为0
	tween.tween_callback(queue_free)  # 动画完成后删除僵尸

## 死亡不消失(海草\TODO:小推车)
func character_death_not_disappear():
	hp_component.Hp_loss_death(false)

## 死亡直接消失
func character_death_disappear():
	is_death = true
	is_can_death_language = false
	hp_component.Hp_loss_death(false)
	queue_free()

## 施加独立剧毒状态；仅正常出战且存活的僵尸可接受，与其他异常状态共存。[br]
## 返回是否首次施加成功；重复施加直接返回false，不改变计时进度。
func be_poisoned() -> bool:
	if is_poisoned or is_death or hp_component.is_death or is_queued_for_deletion() \
		or character_init_type != E_CharacterInitType.IsNorm:
		return false
	is_poisoned = true
	body.set_other_color(BodyCharacter.E_ChangeColors.PoisonColor, Color(0.65, 1.0, 0.4))
	# 使用普通循环计时器，保持冻结、黄油及个体加速独立于中毒扣血。
	var poison_timer:Timer = Timer.new()
	poison_timer.wait_time = POISON_TICK_SECONDS
	poison_timer.timeout.connect(_on_poison_timer_timeout)
	all_timer[E_TimerType.Poison] = poison_timer
	add_child(poison_timer)
	poison_timer.start()
	return true


## 首次中毒一秒后开始结算；每次按当前本体最大生命的2%四舍五入，最低1点。
func _on_poison_timer_timeout() -> void:
	if not is_poisoned or is_death or hp_component.is_death or is_queued_for_deletion():
		all_timer[E_TimerType.Poison].stop()
		return
	settle_poison_damage_once()


## 对仍存活且已中毒的正常出战僵尸结算一次现有剧毒，不新建、停止或重启原跳伤计时器。
## 定时跳伤与胆小菇轮末追加跳伤共用本入口，保留防具绕过、寒冰不增伤及读报抗性。
func settle_poison_damage_once() -> void:
	if not is_poisoned or is_death or hp_component.is_death or is_queued_for_deletion() \
		or character_init_type != E_CharacterInitType.IsNorm:
		return
	# 专用本体扣血入口，不消耗防具、不触发寒冰增伤或普通受击加速机制。
	var zombie_hp:HpComponentZombie = hp_component as HpComponentZombie
	zombie_hp.lose_poison_body_hp(maxi(roundi(zombie_hp.max_hp * POISON_BODY_HP_RATIO), 1))


## 被小推车碾压
func be_mowered_run(lawn_mover:LawnMover):
	## 取消亡语
	is_can_death_language = false
	## 首先死亡无掉落
	hp_component.Hp_loss_death(false)
	## 禁用移动组件 停止移动
	move_component.disable_component(ComponentNormBase.E_IsEnableFactor.Death)
	## 停止动画
	anim_component.stop_anim()

	var zombie_death_bomb:ZombieDeathBomb = get_node_or_null("Body/ZombieDeathBomb")
	if zombie_death_bomb != null:
		zombie_death_bomb.activate_it()
	else:
		await be_mowered_run_anim_norm(lawn_mover)

	queue_free()



## 被小推车碾压动画(普通)
func be_mowered_run_anim_norm(lawn_mover:LawnMover):
	## 先掉落防具
	hp_component = hp_component as HpComponentZombie
	if hp_component.curr_hp_armor1 != 0:
		hp_stage_change_component.judge_body_change_armor(0, 0, true, true)
	if hp_component.curr_hp_armor2 != 0:
		hp_stage_change_component.judge_body_change_armor(0, 0, true, false)

	## 修改本体掉落物（手和头）
	var all_node_drop :Array[ZombieDropBase] = hp_stage_change_component.get_all_body_change()
	for node_drop in all_node_drop:
		node_drop.visible = false
		node_drop.reparent(self)

	## 身体被压扁
	var tween_be_mowered_run:Tween = create_tween()
	tween_be_mowered_run.set_parallel()
	tween_be_mowered_run.tween_property(body, "rotation_degrees", 90, 0.25)
	tween_be_mowered_run.tween_property(body, "scale", Vector2(0.5, 1), 0.25)

	await tween_be_mowered_run.finished
	body.visible = false

	## 掉落本体掉落物
	for node_drop in all_node_drop:
		node_drop.visible = true
		node_drop.acitvate_it_on_ground(lawn_mover.global_position.x)
		SoundManager.play_character_SFX("limbs_pop")
		await get_tree().create_timer(0.1).timeout


## 角色在泳池中死亡,泳池死亡动画调用
func in_water_death_start():
	var tween = create_tween()
	# 仅移动y轴，在1.5秒内下移200像素
	tween.tween_property(body, "position:y", body.position.y + 80, 2)
	#swim_box_component.in_water_death_start()

## 被水草缠住,
func be_grap_in_pool():
	attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.Death)
	anim_component.stop_anim()
	move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsDeath)

## 被炸弹炸
## 灰烬动画从角色本体摘出来,本体节点free,灰烬动画播放玩后删除
## is_cherry_bomb:bool = false ：是否灰烬炸弹(非土豆雷)
func be_bomb(attack_value:int, is_cherry_bomb:bool = false):
	is_can_death_language = false
	hp_component.Hp_loss(attack_value,BulletRegistry.AttackMode.Penetration, false, false)
	## 如果角色死亡
	if is_death:
		## 在在灰烬动画条件下
		if is_cherry_bomb and (not is_swimming or not curr_be_attack_status != E_BeAttackStatusZombie.IsDownGround):
			charred_component.play_charred_anim()
		queue_free()
	#await get_tree().process_frame
	set_deferred("is_can_death_language", true)

## 被大嘴花吃
func be_chomper_eat(attack_value:int):
	is_can_death_language = false
	hp_component.Hp_loss(attack_value,BulletRegistry.AttackMode.Penetration, false, false)
	if is_death:
		queue_free()
	#await get_tree().process_frame
	set_deferred("is_can_death_language", true)

## 被倭瓜压
func be_squash(attack_value:int=1800):
	is_can_death_language = false
	hp_component.Hp_loss(attack_value,BulletRegistry.AttackMode.Penetration, false, false)
	if is_death:
		queue_free()
	#await get_tree().process_frame
	set_deferred("is_can_death_language", true)

#endregion
## 铁器被吸走
## 非一类防具和非二类防具需重写该函数
func be_magnet_iron():
	match iron_type:
		IronType.IronArmor1:
			hp_component.Hp_loss(hp_component.curr_hp_armor1,BulletRegistry.AttackMode.Norm, false, false, true, false)
		IronType.IronArmor2:
			hp_component.Hp_loss(hp_component.curr_hp_armor2,BulletRegistry.AttackMode.Norm, false, false, true, false)
		IronType.IronItem:
			loss_iron_item()

## 失去铁器道具的影响,对应子类继承重写
func loss_iron_item():
	iron_node.visible = false
	iron_type = IronType.Null

## 被吹走,在空中的僵尸被三叶草吹时调用
func be_blow_away():
	if not football_launch_active or is_death:
		return
	finish_football_launch()
	_football_blowing_away = true
	curr_be_attack_status = E_BeAttackStatusZombie.IsSky
	move_component.update_move_factor(true, MoveComponent.E_MoveFactor.IsBlover)
	attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.FootballLaunch)
	# 与气球一致，向右吹离并走原直接清除链路。
	_football_launch_tween = create_tween()
	_football_launch_tween.tween_property(self, ^"position:x", position.x + 1000.0, 1.0)
	_football_launch_tween.tween_callback(character_death_disappear)


## 僵尸从墓碑出现
func zombie_up_from_tombstone(anim_multiply:float):
	update_speed_factor(0.0, Character000Base.E_Influence_Speed_Factor.HammerZombieSpeed)
	await zombie_up_from_ground(1/anim_multiply)
	## 从地下出来后恢复动画
	update_speed_factor(anim_multiply, Character000Base.E_Influence_Speed_Factor.HammerZombieSpeed)

## 从地下出来
func zombie_up_from_ground(up_time:float = 1.0):
	is_body_up_from_ground = true
	await body.zombie_body_up_from_ground(up_time)
	is_body_up_from_ground = false

## 跳跃被高坚果停止
func jump_be_stop(_plant:Plant000Base):
	pass


#region 黄油
## 黄油糊脸
##[butter_time:float]:黄油糊脸时间
func be_butter(butter_time:float=4):
	if not is_death:
		## 黄油节点
		if not is_instance_valid(butter_splat):
			butter_splat = SceneRegistry.BUTTER_SPLAT.instantiate()
			# 将精灵添加到当前场景中
			add_child(butter_splat)
		butter_splat.visible = true
		butter_splat.global_position = head_node.to_global(Vector2(20, 10))

		## 更新速度
		update_speed_factor(0.0, E_Influence_Speed_Factor.Butter)
		if not is_instance_valid(all_timer[E_TimerType.Butter]):
			all_timer[E_TimerType.Butter] = GlobalUtils.create_new_timer_once(self, _on_butter_timer_timeout)

		all_timer[E_TimerType.Butter].start(butter_time)

## 死亡时停止黄油
func death_stop_butter():
	if is_instance_valid(butter_splat):
		_on_butter_timer_timeout()

## 黄油时间计时器结束
func _on_butter_timer_timeout() -> void:
	update_speed_factor(1.0, E_Influence_Speed_Factor.Butter)
	butter_splat.visible = false
#endregion

#region 僵尸吃大蒜换行
func update_lane_on_eat_garlic():
	SoundManager.play_character_SFX("yuck")
	update_speed_factor(0.0, E_Influence_Speed_Factor.EatGarlic)
	await get_tree().create_timer(0.5, false).timeout
	update_speed_factor(1.0, E_Influence_Speed_Factor.EatGarlic)
	update_lane()


## 换行
func update_lane():
	## 可以换的行索引
	var can_update_zombie_row_i:Array[int] = []
	if lane != 0 and Global.main_game.zombie_manager.all_zombie_rows[lane-1].zombie_row_type == curr_zombie_row_type:
		can_update_zombie_row_i.append(lane-1)
	if lane != Global.main_game.zombie_manager.all_zombie_rows.size()-1 and Global.main_game.zombie_manager.all_zombie_rows[lane+1].zombie_row_type == curr_zombie_row_type:
		can_update_zombie_row_i.append(lane+1)

	var new_lane_i = can_update_zombie_row_i.pick_random()
	lane = new_lane_i
	signal_lane_update.emit()

	## 禁用攻击组件
	attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.Garlic)
	#GlobalUtils.child_node_change_parent(self, Global.main_game.zombie_manager.all_zombie_rows[lane])
	reparent(Global.main_game.zombie_manager.all_zombie_rows[lane])
	var tween:Tween = create_tween()
	tween.tween_property(self, ^"position:y", Global.main_game.zombie_manager.all_zombie_rows[lane].zombie_create_position.position.y, 1)
	tween.tween_callback(attack_component.enable_component.bind(ComponentNormBase.E_IsEnableFactor.Garlic))

#endregion


#region 梯子
## 梯子检测到僵尸时,僵尸爬过梯子
func start_climbing_ladder():
	move_component.start_ladder()

#endregion

#region 特殊场景状态
## 小僵尸大麻烦
func update_mini_zombie():
	random_speed_range *= 2
	## 舞王僵尸会改变符号,所有这么写
	scale = Vector2(
		0.5 * sign(scale.x),
		0.5 * sign(scale.y)
	)
	hp_component = hp_component as HpComponentZombie
	hp_component.update_mini_zombie_hp()
	hp_stage_change_component.update_mini_zombie_hp_stage_change()
	hurt_box_component.scale *= 2


## [param displacement] 沿世界x移动的距离；0.75秒内走低抛物线，不改变生命、阵营和行号。
## 正常出战且存活才可顶飞；重复顶飞续接当前高度，返回是否成功开始。
func start_football_launch(displacement:float) -> bool:
	if character_init_type != E_CharacterInitType.IsNorm or is_death or hp_component.is_death \
		or is_queued_for_deletion() or _football_blowing_away:
		return false
	if is_instance_valid(_football_launch_tween):
		_football_launch_tween.kill()
	if not football_launch_active:
		_football_restore_status = curr_be_attack_status
		football_launch_active = true
		_football_jump_component = get_node_or_null("JumpComponent")
		if is_instance_valid(_football_jump_component):
			_football_jump_was_processing = _football_jump_component.is_processing()
			_football_jump_component.set_process(false)
	_football_launch_start_x = global_position.x
	_football_launch_end_x = global_position.x + displacement
	_football_launch_start_height = _football_launch_height
	curr_be_attack_status = E_BeAttackStatusZombie.IsSky
	attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.FootballLaunch)
	move_component.update_move_factor(true, MoveComponent.E_MoveFactor.FootballLaunch)
	update_speed_factor(0.0, E_Influence_Speed_Factor.FootballLaunch)
	_football_launch_tween = create_tween()
	_football_launch_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_football_launch_tween.tween_method(_advance_football_launch, 0.0, 1.0, 0.75)
	_football_launch_tween.tween_callback(finish_football_launch)
	return true


## [param progress] 0～1的游戏时间进度；18像素峰高对应三格距离的低弧线。
func _advance_football_launch(progress:float) -> void:
	if not football_launch_active or is_death or is_queued_for_deletion():
		return
	# 横向位移独立于个体动作速度，保留全局暂停和倍速。
	var old_x:float = global_position.x
	var new_x:float = lerpf(_football_launch_start_x, _football_launch_end_x, progress)
	# 原地面基准可被换行等外部机制移动，逐次抵消已有抬升而不锁死y坐标。
	var ground_y:float = global_position.y + _football_launch_height
	var height:float = lerpf(_football_launch_start_height, 0.0, progress) + 72.0 * progress * (1.0 - progress)
	# 以世界高度保持影子贴地，兼容迷你模式的根节点缩放。
	var shadow_ground_y:float = shadow.global_position.y if is_instance_valid(shadow) else 0.0
	global_position = Vector2(new_x, ground_y - height)
	if is_instance_valid(shadow):
		shadow.global_position.y = shadow_ground_y
	_football_launch_height = height
	# 屋顶按真实横向位置同步身体与受击框的斜面高度，飞行高度由根节点统一提供。
	if is_instance_valid(Global.main_game) and is_instance_valid(Global.main_game.main_game_slope):
		var slope:MainGameSlope = Global.main_game.main_game_slope
		move_y_zombie(slope.get_all_slope_y(new_x) - slope.get_all_slope_y(old_x))


## 落地或死亡时清理自己的移动、攻击和速度因素；其他异常、气球和跳跃状态仍保留。
func finish_football_launch() -> void:
	if not football_launch_active:
		return
	if is_instance_valid(_football_launch_tween):
		_football_launch_tween.kill()
	football_launch_active = false
	# 根节点落地不应让原本贴地的影子再下沉一次。
	var shadow_ground_y:float = shadow.global_position.y if is_instance_valid(shadow) else 0.0
	global_position.y += _football_launch_height
	if is_instance_valid(shadow):
		shadow.global_position.y = shadow_ground_y
	_football_launch_height = 0.0
	_football_launch_start_height = 0.0
	curr_be_attack_status = _football_restore_status
	# 即使空中死亡也撤销动画暂停，允许原死亡动作接续。
	update_speed_factor(1.0, E_Influence_Speed_Factor.FootballLaunch)
	if not is_death and not hp_component.is_death:
		move_component.update_move_factor(false, MoveComponent.E_MoveFactor.FootballLaunch)
		move_component.update_previous_ground_global_x()
		attack_component.enable_component(ComponentNormBase.E_IsEnableFactor.FootballLaunch)
		if is_instance_valid(_football_jump_component):
			_football_jump_component.set_process(_football_jump_was_processing)


## [param time] 冻结时间；[param new_time_ice_end_decelerate] 其后减速时间。[br]
## 顶飞期间与气球共用语义：寒冰菇式冻结转成两段时长相加的减速，不追加冻结伤害。
func be_ice_freeze(time:float, new_time_ice_end_decelerate:float) -> void:
	if football_launch_active:
		be_ice_decelerate(time + new_time_ice_end_decelerate)
	else:
		super(time, new_time_ice_end_decelerate)

#endregion

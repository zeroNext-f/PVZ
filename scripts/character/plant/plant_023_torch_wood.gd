extends Plant000Base
class_name Plant023TorchWood

## 当前升级的子弹
var curr_bullet_up :Array[Bullet000Base] = []
## 子弹根节点
var bullets:Node2D
## 是否已被辣椒点燃，持续高亮并在允许亡语的死亡中留下辣椒；不改变子弹转换表。
var _is_ignited:bool = false
## 单次死亡最多安排一株辣椒，防止重复死亡回调重复生成。
var _death_jalapeno_scheduled:bool = false

## 返回是否首次被辣椒点燃；只有存活的正式出战火炬能点燃，重复命中不叠加亡语。
func ignite_by_jalapeno() -> bool:
	if character_init_type != E_CharacterInitType.IsNorm or is_death or is_queued_for_deletion() or _is_ignited:
		return false
	_is_ignited = true
	body.set_other_color(BodyCharacter.E_ChangeColors.TorchIgnitedColor, Color(1.5, 1.5, 1.5))
	return true

## 允许亡语的死亡在原格安排一株正常辣椒，实际创建交给仍存活的格子管理器，避免本株释放后协程丢失。
func death_language():
	if not is_can_death_language or not _is_ignited or _death_jalapeno_scheduled \
		or not is_instance_valid(plant_cell) or not is_instance_valid(Global.main_game):
		return
	_death_jalapeno_scheduled = true
	Global.main_game.plant_cell_manager.call_deferred("create_ignited_torch_death_jalapeno",
		weakref(plant_cell), get_instance_id(), is_zombie_mode)

## 返回普通植物存档并额外保留点燃资格，防止读档后丢失高亮与亡语。
func gat_save_game_data_plant() -> Dictionary:
	# 保存独立字典，沿用原血量、植物类型及模仿材质字段。
	var data:Dictionary = super()
	data["torch_is_ignited"] = _is_ignited
	return data

## [param data] 原植物存档；先恢复点燃再恢复血量，旧档缺少字段时保持未点燃。
func load_game_data_plant(data:Dictionary):
	if data.get("torch_is_ignited", false):
		ignite_by_jalapeno()
	super(data)

## 子弹升级数据
const bullet_upgrade_data = {
	BulletRegistry.BulletType.Bullet021TrackingPea: BulletRegistry.BulletType.Bullet022FireTrackingPea,
	BulletRegistry.BulletType.Bullet001Pea: BulletRegistry.BulletType.Bullet006PeaFire,
	# 超能豌豆过火保留独立身份，转换为80伤害的火焰超能豌豆。
	BulletRegistry.BulletType.Bullet017SuperPea: BulletRegistry.BulletType.Bullet020FireSuperPea,
	# 破甲豌豆过火仍跳过一类防具，使用火焰外观及原分裂流程。
	BulletRegistry.BulletType.Bullet018ArmorPiercingPea: BulletRegistry.BulletType.Bullet019FireArmorPiercingPea,
	BulletRegistry.BulletType.Bullet002PeaSnow: BulletRegistry.BulletType.Bullet001Pea,
}

func ready_norm() -> void:
	super()
	var main_game:MainGameManager = get_tree().current_scene
	bullets = main_game.bullets

## 子弹进入升级区域
func _on_area_2d_up_bullet_area_entered(area: Area2D) -> void:
	var bullet:Bullet000Base = area.owner
	if bullet.is_can_up and bullet.bullet_type in bullet_upgrade_data.keys():
		_up_bullet(bullet)

## 子弹离开当前区域
func _on_area_2d_up_bullet_area_exited(area: Area2D) -> void:
	var bullet:Bullet000Base = area.owner
	if bullet in curr_bullet_up:
		curr_bullet_up.erase(bullet)

## 升级子弹
func _up_bullet(curr_bullet:Bullet000Base):
	if curr_bullet not in curr_bullet_up:
		var new_bullet_up_scenes = Global.bullet_registry.get_bullet_scenes(bullet_upgrade_data[curr_bullet.bullet_type])
		var bullet_up :Bullet000Base = new_bullet_up_scenes.instantiate()
		bullet_up.init_bullet(curr_bullet.get_bullet_paras())
		# 追踪变体保留原目标、整理进度和贝塞尔轨迹，伤害由新场景固定为80。
		if curr_bullet is Bullet021TrackingPea and bullet_up is Bullet022FireTrackingPea:
			bullet_up.attack_value = 80
			bullet_up.restore_tracking_state_on_ready(curr_bullet.capture_tracking_state())
		# 分裂弹过火也保持禁止二次分裂及忽略原目标，不能因转换重置分裂代数。
		if curr_bullet is Bullet018ArmorPiercingPea and bullet_up is Bullet018ArmorPiercingPea:
			bullet_up.can_split = curr_bullet.can_split
			bullet_up.ignored_target_id = curr_bullet.ignored_target_id
		curr_bullet_up.append(bullet_up)
		bullets.call_deferred("add_child", bullet_up)
		curr_bullet.queue_free()

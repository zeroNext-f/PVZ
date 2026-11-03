## 海豚骑士按地面投影判断水陆，击飞的根节点抬升不能触发虚假离池。
extends SwimBoxComponentBaseSnorkle

## 最近接触的泳池区域，保留到区域释放，以便空中越界或落地时持续纠正状态。
var _pool_area: Area2D

## [param area] 实际泳池区域；记录引用后使用地面形状判断，不直接把空中接触当作入水。
func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.owner is Pool:
		_pool_area = area
		_refresh_ground_swimming()

## [param area] 退出的泳池区域；可能仅因击飞升高，不能直接切换为陆地。
func _on_area_2d_area_exited(area: Area2D) -> void:
	if area == _pool_area:
		_refresh_ground_swimming()

## [param _delta] 物理帧耗时；即使实际检测框仍在空中区域外，也持续跟踪地面水陆边界。
func _physics_process(_delta: float) -> void:
	_refresh_ground_swimming()

## 通过原检测形状及泳池形状直接相交，只抵消顶飞高度，保留原横向偏移和水陆边界。
func _refresh_ground_swimming() -> void:
	if owner_is_death or not is_instance_valid(_pool_area):
		return
	# 海豚当前实例与双方真实碰撞形状。
	var zombie: Zombie015Dolphinrider = owner as Zombie015Dolphinrider
	var detector: CollisionShape2D = $Area2D/CollisionShape2D
	var pool_shape: CollisionShape2D = _pool_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not is_instance_valid(zombie) or not is_instance_valid(pool_shape):
		return
	# 顶飞高度使用世界像素，与共用顶飞轨迹一致；受击状态仍由空中判定自身管理。
	var ground_transform: Transform2D = detector.global_transform
	ground_transform.origin.y += zombie._football_launch_height
	var swimming: bool = detector.shape.collide(ground_transform, pool_shape.shape, pool_shape.global_transform)
	if swimming == zombie.is_swimming:
		return
	if not swimming:
		appear_splash()
	signal_change_is_swimming.emit(swimming)

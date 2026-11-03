## 双子向日葵专用生产表现，保留公共周期与阳光抛出规则，仅交替生产个体。
extends CreateSunComponent
class_name CreateSunComponentTwin

## 左侧向日葵独有的花、脸、眨眼、茎叶；不包含两朵共享的底部叶片。
@export var left_parts: Array[CanvasItem] = []
## 右侧向日葵独有部件，与左侧分别控制modulate，不覆盖动画的self_modulate。
@export var right_parts: Array[CanvasItem] = []
## 两朵各自的产光位置，沿用公共组件的阳光抛落流程。
@export var left_origin: Marker2D
## 右侧花朵的产光位置。
@export var right_origin: Marker2D
## 下一次生产的头部，0为左、1为右，每轮翻转一次。
var next_head: int = 0

## 轮到的向日葵独立亮起0.5秒，产一颗阳光，再用0.5秒恢复；周期计时规则保持。
func create_sun() -> void:
	# 固定本次生产个体与位置，补间回调不受下一次轮换影响。
	var parts: Array[CanvasItem] = left_parts if next_head == 0 else right_parts
	var origin: Marker2D = left_origin if next_head == 0 else right_origin
	next_head = 1 - next_head
	# 只改变当前个体的亮度，公共Body继续承担受击、模仿者等独立表现。
	var tween: Tween = create_tween()
	tween.tween_method(_apply_head_color.bind(parts), Color.WHITE, Color(2, 2, 2), 0.5)
	tween.tween_callback(_spawn_head_sun.bind(origin))
	tween.tween_method(_apply_head_color.bind(parts), Color(2, 2, 2), Color.WHITE, 0.5)

## [param color] 本帧亮度；[param parts] 本次生产个体的独有部件，不修改另一朵或公共叶片。
func _apply_head_color(color: Color, parts: Array[CanvasItem]) -> void:
	# 当前个体中的一个有效部件。
	for part: CanvasItem in parts:
		if is_instance_valid(part):
			part.modulate = color

## [param origin] 当前产光个体的位置；沿用公共数量、价值、抛出与生产通知。
func _spawn_head_sun(origin: Marker2D) -> void:
	if not is_instance_valid(owner) or owner.is_death:
		return
	marker_2d_create_sun = origin
	_spawn_sun()

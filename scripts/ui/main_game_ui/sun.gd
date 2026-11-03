extends Node2D
class_name Sun

@export var sun_value := 25

## 阳光存在时间
@export var exist_time:float = 10.0
var collected := false  # 是否已被点击收集
## 生产阳光移动的tween
var spawn_sun_tween:Tween

func _ready() -> void:
	_sun_scale(sun_value)
	## 启动一个10秒定时器
	await get_tree().create_timer(exist_time, false).timeout

	# 如果还没被点击收集，自动销毁
	if not collected and is_inside_tree() and not is_queued_for_deletion():
		_start_fade_out()

func init_sun(curr_sun_value:int, pos:Vector2):
	sun_value = curr_sun_value
	position = pos

func _sun_scale(new_sun_value:int):
	var new_scale = new_sun_value/25.0
	scale = Vector2(new_scale,new_scale)


## 点击或自动收集阳光；离场、排队销毁或战场正在释放时忽略迟到回调，不再加阳光或启动动画。
func _on_button_pressed() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or collected \
		or not is_instance_valid(Global.main_game) or not Global.main_game.is_inside_tree() \
		or Global.main_game.is_queued_for_deletion():
		return
	if spawn_sun_tween:
		spawn_sun_tween.kill()

	if collected:
		return  # 防止重复点击

	collected = true  # 设置已被收集
	# 本次阳光飞向的局内计数器世界坐标。
	var target_position = Vector2()
	SoundManager.play_other_SFX("points")
	if is_instance_valid(Global.main_game):
		if is_instance_valid(Global.main_game.marker_2d_sun_target):
			## 出战卡槽在canvaslayer中，位置和摄像头位置有偏移
			target_position = Global.main_game.marker_2d_sun_target.global_position + Global.main_game.camera_2d.global_position
			#print(Global.main_game.marker_2d_sun_target.get_canvas_layer_node().get_final_transform())
		else:
			target_position = Global.main_game.marker_2d_sun_target_default.global_position

		EventBus.push_event("add_sun_value", [sun_value])

	# 绑定阳光节点的收集动画，节点释放时自动停止。
	var tween:Tween = create_tween()
	# 飞向阳光计数器，耗时0.3游戏秒。
	tween.tween_property(self, "global_position", target_position, 0.3).set_ease(Tween.EASE_OUT)
	$Button.queue_free()
	await tween.finished
	if not is_inside_tree() or is_queued_for_deletion():
		return
	## 到达位置，变透明
	tween = create_tween()
	tween.set_parallel()
	tween.tween_property(self, "modulate:a", 0, 0.5)
	await tween.finished
	queue_free()


## 未收集阳光到期后淡出；离场时不再创建动画，动画随阳光释放停止。
func _start_fade_out() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	# 绑定本阳光的到期淡出动画。
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)  # 🌫️ 1秒淡出
	tween.finished.connect(func():
		if not collected and is_instance_valid(self):
			self.queue_free()
	)

## 出生移动完成后的自动收集入口，忽略战场切换中已离树或排队释放的阳光。
func on_sun_tween_finished():
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if Global.config_service.auto_collect_sun:
		_on_button_pressed()

## 阳光离场时终止出生移动，避免迟到的完成信号继续触发自动收集。
func _exit_tree() -> void:
	if spawn_sun_tween:
		spawn_sun_tween.kill()

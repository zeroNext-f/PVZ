extends Plant000Base
class_name Plant011FumeShroom

@onready var attack_component: AttackComponentBulletBase = $AttackComponent
@onready var bullet_fx: Node2D = %Bullet_FX
var all_bullet_fx :Array[GPUParticles2D]
## 一次喷射后锁定，防止下一轮攻击或重复动画关键帧再次发射。
var _single_shot_fired:bool = false

func ready_norm():
	super()
	for p in bullet_fx.get_children():
		all_bullet_fx.append(p)

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(attack_component.owner_update_speed)
	attack_component.signal_shoot_bullet.connect(_on_single_shot)

## 发射信号先于子弹创建；延迟死亡，确保本次子弹完整初始化并脱离植物生命周期。
func _on_single_shot() -> void:
	if _single_shot_fired:
		return
	_single_shot_fired = true
	attack_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	_die_after_single_shot.call_deferred()

## 当前喷射的子弹已进入独立容器后，通过生命组件完成死亡。
func _die_after_single_shot() -> void:
	if not is_death and not hp_component.is_death:
		_detach_single_shot_fx()
		hp_component.Hp_loss_death()

## 喷雾特效脱离一次性植物，沿用原材质贴图并匹配720像素（约一整行）射程，不随植物删除而消失。
func _detach_single_shot_fx() -> void:
	if not is_instance_valid(bullet_fx) or not is_instance_valid(Global.main_game):
		return
	bullet_fx.reparent(Global.main_game.bullets, true)
	# 子弹射程720、速度720像素/秒，对应1秒粒子寿命；独立材质避免改动共享资源。
	for particles:GPUParticles2D in all_bullet_fx:
		particles.lifetime = 1.0
		if particles.process_material is ParticleProcessMaterial:
			# 本次喷雾自己的粒子材质，不保留原短程径向速度及速度限制曲线。
			var particle_material:ParticleProcessMaterial = particles.process_material.duplicate() as ParticleProcessMaterial
			particle_material.initial_velocity_min = 720.0
			particle_material.initial_velocity_max = 720.0
			particle_material.radial_velocity_min = 0.0
			particle_material.radial_velocity_max = 0.0
			particle_material.velocity_limit_curve = null
			particles.process_material = particle_material
		particles.emitting = true
		particles.restart()
	# 补间由独立特效节点持有，植物死亡不会取消停止发射和最终回收。
	var cleanup:Tween = bullet_fx.create_tween()
	cleanup.tween_interval(0.625)
	for particles:GPUParticles2D in all_bullet_fx:
		cleanup.tween_property(particles, "emitting", false, 0.0)
	cleanup.tween_interval(1.0)
	cleanup.tween_callback(bullet_fx.queue_free)


func _start_shoot():
	for gpu_particles_2d in all_bullet_fx:
		gpu_particles_2d.emitting = true

func _end_shoot():
	#print("结束")
	for gpu_particles_2d in all_bullet_fx:
		gpu_particles_2d.emitting = false


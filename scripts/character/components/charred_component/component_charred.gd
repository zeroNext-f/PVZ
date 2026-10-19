extends Node2D
class_name CharredComponent
## 灰烬组件

@onready var owner_character: Character000Base = owner

## 播放灰烬动画,将灰烬组件从角色本体中移动到角色父节点
func play_charred_anim():
	if is_instance_valid(owner_character) and owner_character is Zombie000Base:
		owner_character.is_charred = true
	#GlobalUtils.child_node_change_parent(self, owner_character.get_parent())
	reparent(owner_character.get_parent())
	visible = true



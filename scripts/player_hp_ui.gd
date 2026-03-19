extends Control
class_name PlayerHpUI

# 节点引用
@onready var heart_row: HBoxContainer = get_node_or_null("HeartRow")
@onready var heart_template: TextureRect = get_node_or_null("HeartRow/HeartTemplate")

# 血量显示配置
@export var max_hearts: int = 5               # 默认最多显示多少颗心
var _heart_nodes: Array[TextureRect] = []     # 当前实际管理的心节点列表


# 初始化
func _ready() -> void:
	if heart_row == null:
		push_error("PlayerHpUI：未找到 HeartRow 节点，请检查场景结构。")
		return

	if heart_template == null:
		push_error("PlayerHpUI：未找到 HeartTemplate 节点，请检查场景结构。")
		return

	_build_hearts(max_hearts)
	update_hp(max_hearts, max_hearts)


# 根据最大血量生成心节点
func _build_hearts(total_hearts: int) -> void:
	if heart_row == null or heart_template == null:
		return

	_heart_nodes.clear()

	heart_template.visible = true
	heart_template.name = "HeartTemplate"
	_heart_nodes.append(heart_template)

	if total_hearts <= 1:
		return

	for i in range(1, total_hearts):
		var new_heart: TextureRect = heart_template.duplicate() as TextureRect
		new_heart.name = "Heart_%d" % i
		heart_row.add_child(new_heart)
		_heart_nodes.append(new_heart)


# 刷新血量显示
func update_hp(current_hp: int, max_hp: int) -> void:
	if heart_row == null or heart_template == null:
		return

	if max_hp != _heart_nodes.size():
		_rebuild_all_hearts(max_hp)

	for i in range(_heart_nodes.size()):
		var heart := _heart_nodes[i]
		if heart != null:
			heart.visible = i < current_hp


# 当最大血量和当前心节点数量不一致时，彻底重建
func _rebuild_all_hearts(new_max_hp: int) -> void:
	if heart_row == null:
		push_error("PlayerHpUI：heart_row 为空，无法重建血量UI。")
		return

	if heart_template == null:
		push_error("PlayerHpUI：heart_template 为空，无法重建血量UI。")
		return

	for child in heart_row.get_children():
		if child != heart_template:
			child.queue_free()

	_heart_nodes.clear()
	heart_template.visible = true
	_heart_nodes.append(heart_template)

	if new_max_hp <= 1:
		return

	for i in range(1, new_max_hp):
		var new_heart: TextureRect = heart_template.duplicate() as TextureRect
		new_heart.name = "Heart_%d" % i
		heart_row.add_child(new_heart)
		_heart_nodes.append(new_heart)

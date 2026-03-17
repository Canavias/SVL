extends Control
class_name PlayerHpUI

# =========================
# 节点引用
# =========================
@onready var heart_row: HBoxContainer = $HeartRow
@onready var heart_template: TextureRect = $HeartRow/HeartTemplate

# =========================
# 血量显示配置
# =========================
@export var max_hearts: int = 5               # 默认最多显示多少颗心
var _heart_nodes: Array[TextureRect] = []     # 当前实际管理的心节点列表

# =========================
# 初始化
# 进入场景后自动生成心节点
# =========================
func _ready() -> void:
	_build_hearts(max_hearts)
	update_hp(max_hearts, max_hearts)

# =========================
# 根据最大血量生成心节点
# total_hearts: 需要生成的总心数
# =========================
func _build_hearts(total_hearts: int) -> void:
	# 先清空旧的缓存
	_heart_nodes.clear()

	# 先保留模板节点，后续复制它
	_heart_nodes.append(heart_template)

	# 如果 total_hearts <= 1，就不需要继续复制
	if total_hearts <= 1:
		return

	# 复制剩余的心节点
	for i in range(1, total_hearts):
		var new_heart: TextureRect = heart_template.duplicate() as TextureRect
		new_heart.name = "Heart_%d" % i
		heart_row.add_child(new_heart)
		_heart_nodes.append(new_heart)

# =========================
# 刷新血量显示
# current_hp: 当前血量
# max_hp: 最大血量
# 规则：
# - 前 current_hp 颗心显示
# - 后面的心隐藏
# =========================
func update_hp(current_hp: int, max_hp: int) -> void:
	# 如果最大血量变化了，且和当前节点数量不同，则重新构建
	if max_hp != _heart_nodes.size():
		_rebuild_all_hearts(max_hp)

	for i in range(_heart_nodes.size()):
		var heart := _heart_nodes[i]
		heart.visible = i < current_hp

# =========================
# 当最大血量和当前心节点数量不一致时，彻底重建
# =========================
func _rebuild_all_hearts(new_max_hp: int) -> void:
	# 删除 HeartRow 下面已有的所有子节点
	for child in heart_row.get_children():
		child.queue_free()

	# 等待节点队列删除完成前，不依赖旧节点
	_heart_nodes.clear()

	# 重新创建第一个模板心
	var new_template := heart_template.duplicate() as TextureRect
	new_template.name = "HeartTemplate"
	heart_row.add_child(new_template)
	heart_template = new_template

	# 再按新的数量构建
	_build_hearts(new_max_hp)

extends Node2D

@export var top_left_path: NodePath
@export var bottom_right_path: NodePath

@export var tile_top_left: Texture2D      # 左上角
@export var tile_top: Texture2D           # 上/下横向中段
@export var tile_top_right: Texture2D     # 右上角
@export var tile_side: Texture2D          # 左/右纵向中段
@export var tile_bottom_left: Texture2D   # 左下角
@export var tile_bottom_right: Texture2D  # 右下角

@export var fence_inset: float = 0.0      # 栅栏整体向内缩多少
@export var tile_overlap: float = 0.0     # 小块之间重叠多少，防止缝隙

@onready var ground: Sprite2D = $Ground
@onready var fence_top: Node2D = $FenceTop
@onready var fence_bottom: Node2D = $FenceBottom
@onready var fence_left: Node2D = $FenceLeft
@onready var fence_right: Node2D = $FenceRight

@onready var top_left_node: Node2D = get_node_or_null(top_left_path)
@onready var bottom_right_node: Node2D = get_node_or_null(bottom_right_path)

func _ready():
	if top_left_node == null:
		push_error("TopLeft 节点未找到")
		return

	if bottom_right_node == null:
		push_error("BottomRight 节点未找到")
		return

	_build_fence()

func _build_fence() -> void:
	_clear_fence_nodes()

	if not _check_textures():
		push_error("Map：栅栏贴图没有设置完整")
		return

	var left_x: float = top_left_node.global_position.x + fence_inset
	var top_y: float = top_left_node.global_position.y + fence_inset
	var right_x: float = bottom_right_node.global_position.x - fence_inset
	var bottom_y: float = bottom_right_node.global_position.y - fence_inset

	_build_top_fence(left_x, top_y, right_x)
	_build_bottom_fence(left_x, bottom_y, right_x)
	_build_left_fence(left_x, top_y, bottom_y)
	_build_right_fence(right_x, top_y, bottom_y)


func _build_top_fence(left_x: float, top_y: float, right_x: float) -> void:
	var corner_width: float = tile_top_left.get_width()
	var middle_width: float = tile_top.get_width() - tile_overlap

	# 左上角
	_add_tile(fence_top, tile_top_left, Vector2(left_x, top_y))

	# 中段
	var start_x: float = left_x + corner_width
	var end_x: float = right_x - tile_top_right.get_width()

	var current_x: float = start_x
	while current_x < end_x:
		_add_tile(fence_top, tile_top, Vector2(current_x, top_y))
		current_x += middle_width

	# 右上角
	_add_tile(fence_top, tile_top_right, Vector2(end_x, top_y))


func _build_bottom_fence(left_x: float, bottom_y: float, right_x: float) -> void:
	var y: float = bottom_y - tile_bottom_left.get_height()

	var corner_width: float = tile_bottom_left.get_width()
	var middle_width: float = tile_top.get_width() - tile_overlap

	# 左下角
	_add_tile(fence_bottom, tile_bottom_left, Vector2(left_x, y))

	# 中段
	var start_x: float = left_x + corner_width
	var end_x: float = right_x - tile_bottom_right.get_width()

	var current_x: float = start_x
	while current_x < end_x:
		_add_tile(fence_bottom, tile_top, Vector2(current_x, y))
		current_x += middle_width

	# 右下角
	_add_tile(fence_bottom, tile_bottom_right, Vector2(end_x, y))


func _build_left_fence(left_x: float, top_y: float, bottom_y: float) -> void:
	var start_y: float = top_y + tile_top_left.get_height()
	var end_y: float = bottom_y - tile_bottom_left.get_height()
	var middle_height: float = tile_side.get_height() - tile_overlap

	var current_y: float = start_y
	while current_y < end_y:
		_add_tile(fence_left, tile_side, Vector2(left_x, current_y))
		current_y += middle_height


func _build_right_fence(right_x: float, top_y: float, bottom_y: float) -> void:
	var x: float = right_x - tile_top_right.get_width()

	var start_y: float = top_y + tile_top_right.get_height()
	var end_y: float = bottom_y - tile_bottom_right.get_height()
	var middle_height: float = tile_side.get_height() - tile_overlap

	var current_y: float = start_y
	while current_y < end_y:
		_add_tile(fence_right, tile_side, Vector2(x, current_y))
		current_y += middle_height


func _add_tile(parent_node: Node2D, texture: Texture2D, pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = pos
	parent_node.add_child(sprite)


func _clear_fence_nodes() -> void:
	for node in fence_top.get_children():
		node.queue_free()

	for node in fence_bottom.get_children():
		node.queue_free()

	for node in fence_left.get_children():
		node.queue_free()

	for node in fence_right.get_children():
		node.queue_free()


func _check_textures() -> bool:
	return (
		tile_top_left != null
		and tile_top != null
		and tile_top_right != null
		and tile_side != null
		and tile_bottom_left != null
		and tile_bottom_right != null
	)

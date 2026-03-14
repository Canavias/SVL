extends Node2D
class_name ShadowCluster

# 场景引用
@export var shadow_area_scene: PackedScene   # 单个暗影块场景模板

# 区块参数
@export var tile_size: int = 64              # 网格尺寸/单块之间的间距
@export var center_bias_top_n: int = 4       # 候选点中优先从更靠近中心的前几个里随机选
@export var prefer_compact_shape: bool = true # 是否优先生成更紧凑的形状

# 区块数据
var grid_positions: Array[Vector2i] = []     # 当前区块内所有暗影单块的网格坐标


# 生成区块
func generate(tile_count: int) -> void:
	# 先清空旧数据，避免重复生成时叠加
	grid_positions.clear()

	# 清空旧的子节点，避免重复生成时叠加旧暗影块
	for child in get_children():
		child.queue_free()

	# 至少保证生成 1 个块
	tile_count = max(tile_count, 1)

	# 先计算连续的区块形状
	grid_positions = _generate_cluster_shape(tile_count)
	grid_positions = _normalize_positions(grid_positions)

	# 再根据网格坐标实例化暗影单块
	for grid_pos in grid_positions:
		var shadow_tile = shadow_area_scene.instantiate()
		add_child(shadow_tile)
		shadow_tile.position = Vector2i(grid_pos.x * tile_size, grid_pos.y * tile_size)


# 将区块网格坐标归一化到左上角，从 (0,0) 开始
func _normalize_positions(positions: Array[Vector2i]) -> Array[Vector2i]:
	if positions.is_empty():
		return positions

	var min_x: int = positions[0].x
	var min_y: int = positions[0].y

	for p in positions:
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)

	var normalized: Array[Vector2i] = []
	for p in positions:
		normalized.append(Vector2i(p.x - min_x, p.y - min_y))

	return normalized


# 生成一个“连续且尽量紧凑”的区块形状
func _generate_cluster_shape(tile_count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	# 第一个块固定从原点开始
	result.append(Vector2i.ZERO)

	# 不断从已有块的边缘扩展，直到达到目标数量
	while result.size() < tile_count:
		var candidates: Array[Vector2i] = _collect_candidates(result)

		# 理论上不会为空，保险处理
		if candidates.is_empty():
			break

		# 对候选点排序：
		# 1. 优先选择和已有块接触更多的点（更容易形成连续面状区域）
		# 2. 若接触数相同，则优先靠近中心，避免长成细长枝杈
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var a_neighbors := _count_neighbors(a, result)
			var b_neighbors := _count_neighbors(b, result)

			if prefer_compact_shape:
				if a_neighbors == b_neighbors:
					return a.length_squared() < b.length_squared()
				return a_neighbors > b_neighbors
			else:
				return a.length_squared() < b.length_squared()
		)

		# 不直接取第一个，而是从前几个“更合理”的候选里随机一个
		# 这样既保持随机性，也能保证形状整体更自然
		var pick_count: int = min(center_bias_top_n, candidates.size())
		var chosen: Vector2i = candidates[randi_range(0, pick_count - 1)]

		result.append(chosen)

	return result


# 收集当前区块所有可扩展的候选位置
func _collect_candidates(existing: Array[Vector2i]) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []

	# 四方向扩展
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	# 从每个已有块向四周找候选点
	for pos in existing:
		for dir in directions:
			var new_pos: Vector2i = pos + dir

			# 已存在的格子不能重复加入
			if new_pos in existing:
				continue

			# 候选列表里也不能重复
			if new_pos in candidates:
				continue

			candidates.append(new_pos)

	return candidates


# 统计一个候选点与现有区块有多少个相邻块
func _count_neighbors(pos: Vector2i, existing: Array[Vector2i]) -> int:
	var count: int = 0

	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	for dir in directions:
		if pos + dir in existing:
			count += 1

	return count


# 获取当前区块在“本地坐标系下”的包围盒（像素单位）
func get_bounds_in_pixels() -> Rect2:
	if grid_positions.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ZERO)

	var min_x: int = grid_positions[0].x
	var max_x: int = grid_positions[0].x
	var min_y: int = grid_positions[0].y
	var max_y: int = grid_positions[0].y

	for p in grid_positions:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)

	var rect_position := Vector2(min_x * tile_size, min_y * tile_size)
	var rect_size := Vector2(
		(max_x - min_x + 1) * tile_size,
		(max_y - min_y + 1) * tile_size
	)

	return Rect2(rect_position, rect_size)

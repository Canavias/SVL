extends Node2D
class_name ShadowSystem

# 场景引用
@export var shadow_cluster_scene: PackedScene   # 区块场景模板
@export var shadow_area_scene: PackedScene      # 单块场景模板

# 区块数量和大小规则
@export var cluster_count: int = 8              # 要生成的暗影区块总数
@export var min_tiles_per_cluster: int = 4      # 每个区块最少单块数
@export var max_tiles_per_cluster: int = 8      # 每个区块最多单块数
@export var max_single_tile_clusters: int = 0   # 最多允许多少个“单块区块”

# 地图范围参数
@export var map_width: float = 1920.0           # 地图宽度
@export var map_height: float = 1080.0          # 地图高度

# 区块摆放规则
@export var cluster_padding: float = 12.0       # 区块之间额外保留的间距
@export var max_place_try: int = 150            # 每个区块最多尝试摆放次数

# 调试参数
@export var print_debug_log: bool = false        # 是否打印调试日志

# 刷新参数
@export var enable_auto_refresh: bool = true    # 是否启用自动刷新
@export var refresh_interval: float = 5.0       # 每隔多少秒重新生成一次暗影区域

# 单块尺寸参数
@export var shadow_tile_size: int = 40          # 暗影单块统一尺寸，同时用于区块延伸步长

# 倒计时UI参数
@export var countdown_label_path: NodePath      # 倒计时文本Label节点路径
@export var countdown_prefix: String = " " # 倒计时文本前缀
@export var countdown_decimal_places: int = 1   # 倒计时保留的小数位数

# 运行状态
var _is_refreshing: bool = false                # 是否正在刷新暗影区域
var _refresh_timer: Timer = null                # 自动刷新的计时器
var _countdown_label: Label = null              # 倒计时UI文本节点


# 初始化
func _ready() -> void:
	# 获取倒计时UI节点
	_setup_countdown_label()

	# 先生成第一批暗影区块
	generate_shadow_clusters()

	# 启动自动刷新
	if enable_auto_refresh:
		_start_refresh_timer()
	else:
		_update_countdown_label_hidden()


# 每帧刷新倒计时UI
func _process(_delta: float) -> void:
	_update_countdown_label()


# 获取倒计时UI节点
func _setup_countdown_label() -> void:
	if countdown_label_path.is_empty():
		return

	_countdown_label = get_node_or_null(countdown_label_path) as Label

	if _countdown_label == null:
		push_warning("ShadowSystem: 未找到倒计时Label节点，请检查 countdown_label_path 是否设置正确。")
		return

	_countdown_label.visible = enable_auto_refresh
	_countdown_label.text = "%s--" % countdown_prefix


# 启动定时刷新
func _start_refresh_timer() -> void:
	# 如果已有计时器，先移除旧的，避免重复创建
	if _refresh_timer != null:
		_refresh_timer.queue_free()
		_refresh_timer = null

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = refresh_interval
	_refresh_timer.one_shot = false
	_refresh_timer.autostart = true
	add_child(_refresh_timer)
	_refresh_timer.timeout.connect(_on_refresh_timer_timeout)

	# 计时器启动后立即刷新一次UI
	_update_countdown_label()


# 生成所有暗影区块
func generate_shadow_clusters() -> void:
	if print_debug_log:
		print("=== generate_shadow_clusters start ===")

	var single_tile_cluster_count: int = 0   # 当前已经生成的单块区块数量
	var placed_rects: Array[Rect2] = []       # 记录已放置区块的世界包围盒

	# 循环生成多个区块
	for i in range(cluster_count):
		# 随机决定本次区块大小
		var tile_count: int = _roll_cluster_size()

		# 限制单块区块数量，避免地图上全是零散点
		if tile_count == 1:
			if single_tile_cluster_count >= max_single_tile_clusters:
				tile_count = randi_range(max(2, min_tiles_per_cluster), max_tiles_per_cluster)
			else:
				single_tile_cluster_count += 1

		if print_debug_log:
			print("cluster index = ", i, " tile_count = ", tile_count)

		# 实例化一个区块
		var cluster = shadow_cluster_scene.instantiate()
		add_child(cluster)

		# 将单块场景传给区块
		cluster.shadow_area_scene = shadow_area_scene
		cluster.tile_size = shadow_tile_size

		# 先在区块内部生成连续形状
		cluster.generate(tile_count)

		# 读取该区块的本地包围盒，用来判断是否会和其他区块碰撞
		var local_bounds: Rect2 = cluster.get_bounds_in_pixels()

		# 寻找一个合法的摆放位置
		var cluster_pos: Vector2 = _find_valid_cluster_position(local_bounds, placed_rects)

		# 如果没有找到合法位置，就删除这个区块并跳过
		if cluster_pos == Vector2.INF:
			if print_debug_log:
				print("cluster index = ", i, " place failed")
			cluster.queue_free()
			continue

		# 设置区块位置
		cluster.position = Vector2i(cluster_pos.x, cluster_pos.y)

		# 记录该区块放到世界中的真实包围盒
		var world_rect := Rect2(cluster_pos + local_bounds.position, local_bounds.size)
		placed_rects.append(world_rect)

		if print_debug_log:
			print("cluster index = ", i, " position = ", cluster_pos)
			print("cluster index = ", i, " world_rect = ", world_rect)

	if print_debug_log:
		print("=== generate_shadow_clusters end ===")


# 随机决定区块大小
func _roll_cluster_size() -> int:
	# 做一个更自然的分布：
	# - 少量单块
	# - 较多小中型区块
	# - 少量大型区块
	var r: float = randf()

	if min_tiles_per_cluster >= max_tiles_per_cluster:
		return min_tiles_per_cluster

	if r < 0.15:
		return clamp(1, min_tiles_per_cluster, max_tiles_per_cluster)
	elif r < 0.45:
		return randi_range(
			clamp(2, min_tiles_per_cluster, max_tiles_per_cluster),
			clamp(4, min_tiles_per_cluster, max_tiles_per_cluster)
		)
	elif r < 0.80:
		return randi_range(
			clamp(5, min_tiles_per_cluster, max_tiles_per_cluster),
			clamp(7, min_tiles_per_cluster, max_tiles_per_cluster)
		)
	else:
		return randi_range(
			clamp(8, min_tiles_per_cluster, max_tiles_per_cluster),
			max_tiles_per_cluster
		)


# 为区块寻找合适位置
func _find_valid_cluster_position(cluster_bounds: Rect2, placed_rects: Array[Rect2]) -> Vector2:
	# 如果地图范围比当前区块还小，直接失败
	if map_width < cluster_bounds.size.x or map_height < cluster_bounds.size.y:
		return Vector2.INF

	# 随机尝试多个候选位置
	for i in range(max_place_try):
		# 这里直接用左上角坐标系，而不是以中心为原点
		var candidate := Vector2(
			round(randf_range(0.0, map_width - cluster_bounds.size.x)),
			round(randf_range(0.0, map_height - cluster_bounds.size.y))
		)

		# 计算当前候选位置下，该区块在世界中的包围盒
		var test_rect := Rect2(candidate, cluster_bounds.size)

		# 检查是否与已放置区块重叠或过近
		var valid := true
		for rect in placed_rects:
			var expanded_rect := rect.grow(cluster_padding)
			if expanded_rect.intersects(test_rect):
				valid = false
				break

		if valid:
			return candidate

	# 找不到合法位置时，明确标记为失败
	return Vector2.INF


# 清除当前所有暗影区块
func clear_shadow_clusters() -> void:
	for child in get_children():
		if child is ShadowCluster:
			child.queue_free()


# 重新生成暗影区块
func refresh_shadow_clusters() -> void:
	# 防止定时器重复触发时重入
	if _is_refreshing:
		return

	_is_refreshing = true

	clear_shadow_clusters()

	# 等一帧，确保旧区块真正从场景树中移除
	await get_tree().process_frame

	generate_shadow_clusters()

	_is_refreshing = false

	# 刷新完成后，立即更新一次倒计时UI
	_update_countdown_label()


# 更新倒计时文本
func _update_countdown_label() -> void:
	if _countdown_label == null:
		return

	if not enable_auto_refresh:
		_countdown_label.visible = false
		return

	_countdown_label.visible = true

	if _refresh_timer == null:
		_countdown_label.text = "%s--" % countdown_prefix
		return

	var time_left: float = max(_refresh_timer.time_left, 0.0)
	var display_text := "%s%d" % [countdown_prefix, int(ceil(time_left))]
	_countdown_label.text = display_text


# 隐藏倒计时文本
func _update_countdown_label_hidden() -> void:
	if _countdown_label != null:
		_countdown_label.visible = false


# 定时器触发：重新生成暗影区块
func _on_refresh_timer_timeout() -> void:
	await refresh_shadow_clusters()

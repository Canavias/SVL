extends Camera2D
class_name PlayerCamera

# =========================
# 玩家引用
# =========================
@export var player_path: NodePath

# =========================
# 跟随参数
# normal_follow_speed：平时跟随速度
# dash_follow_speed：冲刺时跟随速度
# =========================
@export var normal_follow_speed: float = 4.5
@export var dash_follow_speed: float = 7.5

# =========================
# QTE 聚焦参数
# 注意：这里改成更大的值来收紧视野
# =========================
@export var normal_zoom: Vector2 = Vector2(1.15, 1.15)
@export var qte_zoom: Vector2 = Vector2(1.30, 1.30)
@export var zoom_lerp_speed: float = 5.0

# =========================
# 是否启用边界限制
# 这一轮先关闭，专门验证跟随是否正常
# =========================
@export var use_camera_limits: bool = false

# =========================
# 地图边界参数
# 后面要做边界时再启用
# =========================
@export var world_rect: Rect2 = Rect2(0.0, 0.0, 1920.0, 1080.0)

# =========================
# 内部运行变量
# =========================
var _player: Node2D = null
var _current_target_position: Vector2 = Vector2.ZERO

# =========================
# 初始化
# =========================
func _ready() -> void:
	make_current()
	zoom = normal_zoom

	if player_path != NodePath():
		_player = get_node_or_null(player_path) as Node2D

	if _player != null:
		global_position = _player.global_position
		_current_target_position = global_position

	_update_camera_limits()

# =========================
# 每帧更新
# =========================
func _process(delta: float) -> void:
	if _player == null:
		return

	var is_dashing: bool = _get_player_is_dashing()
	var is_in_qte: bool = _get_player_is_in_qte()

	_update_camera_follow(is_dashing, delta)
	_update_zoom(is_in_qte, delta)

# =========================
# 更新边界限制
# 这一轮先默认关闭
# =========================
func _update_camera_limits() -> void:
	limit_enabled = use_camera_limits

	if not use_camera_limits:
		return

	limit_left = int(world_rect.position.x)
	limit_top = int(world_rect.position.y)
	limit_right = int(world_rect.position.x + world_rect.size.x)
	limit_bottom = int(world_rect.position.y + world_rect.size.y)

# =========================
# 更新镜头跟随
# 平时轻微延迟，冲刺时更快
# =========================
func _update_camera_follow(is_dashing: bool, delta: float) -> void:
	var follow_speed: float = normal_follow_speed
	if is_dashing:
		follow_speed = dash_follow_speed

	_current_target_position = _current_target_position.lerp(_player.global_position, follow_speed * delta)
	global_position = _current_target_position

# =========================
# 更新镜头缩放
# QTE 时平滑聚焦
# =========================
func _update_zoom(is_in_qte: bool, delta: float) -> void:
	var target_zoom: Vector2 = normal_zoom

	if is_in_qte:
		target_zoom = qte_zoom

	zoom = zoom.lerp(target_zoom, zoom_lerp_speed * delta)

# =========================
# 读取玩家是否正在冲刺
# =========================
func _get_player_is_dashing() -> bool:
	if _player == null:
		return false

	if _player.has_method("is_dashing"):
		return _player.is_dashing()

	if "is_dashing_now" in _player:
		return _player.is_dashing_now

	return false

# =========================
# 读取玩家是否正在 QTE
# =========================
func _get_player_is_in_qte() -> bool:
	if _player == null:
		return false

	if _player.has_method("is_in_qte"):
		return _player.is_in_qte()

	if "is_in_qte_now" in _player:
		return _player.is_in_qte_now

	return false

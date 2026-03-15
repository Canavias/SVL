extends Node2D
class_name AttackSequence

# =========================
# 可调参数
# =========================
@export var lock_duration: float = 0.8              # 锁定持续时间
@export var warning_duration: float = 1.2           # 预警持续时间
@export var strike_duration: float = 0.2            # 攻击持续时间
@export var strike_radius: float = 64.0             # 攻击范围
@export var follow_speed: float = 180.0             # 追踪速度

@export var qte_open_ratio: float = 0.75            # 在预警阶段进行到多少比例时开启QTE（0~1）
@export var destroy_delay: float = 0.08             # 结算后稍微延迟销毁，方便观察日志

@export var warning_start_scale: Vector2 = Vector2(2.0, 2.0)   # 预警圈开始缩放
@export var warning_end_scale: Vector2 = Vector2(3.0, 3.0)     # 预警圈结束缩放
@export var warning_flash_speed: float = 10.0                  # 闪烁频率
@export var warning_start_color: Color = Color(1.0, 1.0, 0.3, 0.75) # 预警开始颜色
@export var warning_end_color: Color = Color(1.0, 0.1, 0.1, 1.0)    # 预警结束颜色

# =========================
# 内部状态
# 0 = 锁定
# 1 = 预警
# 2 = 攻击
# =========================
var _phase: int = 0
var _timer: float = 0.0
var _phase_total_time: float = 0.0
var _target: Player = null

# =========================
# QTE / 结算状态
# =========================
var _qte_opened: bool = false               # 本次攻击是否已经开启QTE
var _player_countered: bool = false         # 玩家是否成功完成QTE
var _resolved: bool = false                 # 本次攻击是否已经结算

# =========================
# 缓存节点引用
# =========================
@onready var lock_indicator: Sprite2D = $LockIndicator
@onready var warning_indicator: Sprite2D = $WarningIndicator
@onready var strike_area: Area2D = $StrikeArea

# =========================
# 初始化外部传入目标
# 由 WingEnemy 在实例化攻击后调用
# =========================
func setup(target: Player) -> void:
	_target = target

	if _target != null:
		global_position = _target.global_position

# =========================
# 攻击一生成即进入锁定状态
# =========================
func _ready() -> void:
	_enter_lock_phase()

# =========================
# 状态机总更新
# =========================
func _process(delta: float) -> void:
	if _resolved:
		return

	# 锁定阶段：持续追踪目标
	if _phase == 0 and _target != null:
		global_position = global_position.move_toward(_target.global_position, follow_speed * delta)

	# 预警阶段：更新视觉效果，并在后半段开启QTE
	if _phase == 1:
		_update_warning_visual()
		_try_open_qte_in_warning_phase()

	_timer -= delta
	if _timer > 0.0:
		return

	match _phase:
		0:
			_enter_warning_phase()
		1:
			_enter_strike_phase()
		2:
			_finish_and_free()

# =========================
# 锁定阶段
# =========================
func _enter_lock_phase() -> void:
	_phase = 0
	_timer = lock_duration
	_phase_total_time = lock_duration

	lock_indicator.visible = true
	warning_indicator.visible = false
	strike_area.monitoring = false

	_qte_opened = false
	_player_countered = false
	_resolved = false

	print("AttackSequence：进入锁定阶段")

# =========================
# 预警阶段
# =========================
func _enter_warning_phase() -> void:
	_phase = 1
	_timer = warning_duration
	_phase_total_time = warning_duration

	lock_indicator.visible = false
	warning_indicator.visible = true
	strike_area.monitoring = false

	warning_indicator.scale = warning_start_scale
	warning_indicator.modulate = warning_start_color

	print("AttackSequence：进入预警阶段")

# =========================
# 攻击阶段
# 到这里就正式结算这次攻击
# =========================
func _enter_strike_phase() -> void:
	_phase = 2
	_timer = strike_duration
	_phase_total_time = strike_duration

	lock_indicator.visible = false
	warning_indicator.visible = false
	strike_area.monitoring = true

	print("AttackSequence：进入攻击阶段，开始结算")

	_resolve_attack_once()

# =========================
# 在预警阶段后段开启QTE
# =========================
func _try_open_qte_in_warning_phase() -> void:
	if _qte_opened:
		return

	if _target == null:
		return

	if _phase_total_time <= 0.0:
		return

	var progress: float = 1.0 - (_timer / _phase_total_time)
	progress = clamp(progress, 0.0, 1.0)

	if progress >= qte_open_ratio:
		_qte_opened = true

		if _target.has_method("begin_qte"):
			_target.begin_qte(self)

		print("AttackSequence：QTE窗口开启")

# =========================
# 玩家QTE成功时，由 Player 回调
# =========================
func on_player_qte_success(player: Player) -> void:
	if _resolved:
		return

	if player != _target:
		return

	_player_countered = true
	print("AttackSequence：玩家QTE成功，本次攻击将被反击")

# =========================
# 只结算一次攻击
# =========================
func _resolve_attack_once() -> void:
	if _resolved:
		return

	_resolved = true

	# 进入攻击结算时，不再允许继续QTE输入
	if _target != null and _target.has_method("end_qte"):
		_target.end_qte()

	# QTE成功：进入反击分支
	if _player_countered:
		_on_counter_success()
		return

	# 没有目标则直接结束
	if _target == null:
		print("AttackSequence：没有目标，攻击结束")
		return

	# 还在范围内：正常命中
	if _is_target_inside_strike_range():
		print("AttackSequence：玩家未完成QTE，攻击命中")
		_target.try_take_light_damage()
	else:
		print("AttackSequence：玩家已离开攻击范围，本次攻击落空")

# =========================
# 反击成功分支
# 这一阶段先只打印，下一步再回传给敌人
# =========================
func _on_counter_success() -> void:
	print("AttackSequence：反击成功，本次攻击失效")

# =========================
# 判断目标是否在攻击范围内
# 目前保留你原本的圆形距离判定
# =========================
func _is_target_inside_strike_range() -> bool:
	if _target == null:
		return false

	var distance_to_target: float = global_position.distance_to(_target.global_position)
	return distance_to_target <= strike_radius

# =========================
# 预警表现更新
# =========================
func _update_warning_visual() -> void:
	if _phase_total_time <= 0.0:
		return

	var progress: float = 1.0 - (_timer / _phase_total_time)
	progress = clamp(progress, 0.0, 1.0)

	# 颜色渐变 + 缩放变化
	warning_indicator.modulate = warning_start_color.lerp(warning_end_color, progress)
	warning_indicator.scale = warning_start_scale.lerp(warning_end_scale, progress)

	# 闪烁逻辑（正弦波制造周期变化）
	var flash_value: float = sin(Time.get_ticks_msec() / 1000.0 * warning_flash_speed)
	warning_indicator.visible = flash_value > -0.4

# =========================
# 收尾并释放
# =========================
func _finish_and_free() -> void:
	await get_tree().create_timer(destroy_delay).timeout
	queue_free()

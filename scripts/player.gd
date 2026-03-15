# 继承和类名
extends CharacterBody2D
class_name Player

# =========================
# 可调参数
# =========================
@export var move_speed: float = 220.0           # 移动速度
@export var dash_speed: float = 420.0           # 冲刺速度
@export var dash_duration: float = 0.15         # 冲刺持续时间
@export var qte_invincible_duration: float = 0.35 # QTE成功后的无敌时长

# =========================
# 角色状态
# =========================
var is_dead: bool = false                       # 角色是否死亡
var is_in_shadow: bool = false                  # 角色是否处于暗影中
var is_invincible: bool = false                 # 角色是否处于无敌状态

# =========================
# 内部运行变量
# =========================
var _dash_timer: float = 0.0                    # 冲刺剩余时间
var _move_input: Vector2 = Vector2.ZERO         # 当前输入方向
var _shadow_overlap_count: int = 0              # 暗影重叠计数器
var _invincible_timer: float = 0.0              # 无敌剩余时间

# =========================
# QTE 运行变量
# =========================
var _qte_active: bool = false                   # 当前是否处于QTE输入窗口中
var _qte_success: bool = false                  # 本轮QTE是否成功
var _qte_index: int = 0                         # 当前已经输入到第几个按键
var _qte_sequence: Array[String] = ["qte_j", "qte_k", "qte_l"]  # 固定QTE序列
var _current_qte_attack: Node = null            # 当前是由哪个攻击触发的QTE，用于回传结果

# =========================
# 物理帧更新
# =========================
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_invincible(delta)
	_read_input()
	_update_qte_input()

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = _move_input * dash_speed
	else:
		velocity = _move_input * move_speed

	move_and_slide()

# =========================
# 读取移动/冲刺输入
# =========================
func _read_input() -> void:
	_move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if Input.is_action_just_pressed("dash"):
		_start_dash()

# =========================
# 更新无敌计时
# =========================
func _update_invincible(delta: float) -> void:
	if _invincible_timer > 0.0:
		_invincible_timer -= delta
		if _invincible_timer <= 0.0:
			_invincible_timer = 0.0
			is_invincible = false
			print("QTE无敌结束")

# =========================
# 冲刺逻辑
# =========================
func _start_dash() -> void:
	_dash_timer = dash_duration

# =========================
# 受伤逻辑
# =========================
func try_take_light_damage() -> void:
	if is_dead:
		return

	if is_invincible:
		print("玩家当前无敌，免疫本次强光伤害")
		return

	if is_in_shadow:
		print("玩家当前处于暗影中，免疫本次强光伤害")
		return

	die()

# =========================
# 死亡逻辑
# =========================
func die() -> void:
	is_dead = true
	queue_free()

# =========================
# 进入暗影状态
# =========================
func enter_shadow() -> void:
	_shadow_overlap_count += 1
	is_in_shadow = _shadow_overlap_count > 0
	print("enter_shadow -> overlap =", _shadow_overlap_count, " is_in_shadow =", is_in_shadow)

# =========================
# 退出暗影状态
# =========================
func exit_shadow() -> void:
	_shadow_overlap_count = max(_shadow_overlap_count - 1, 0)
	is_in_shadow = _shadow_overlap_count > 0
	print("exit_shadow -> overlap =", _shadow_overlap_count, " is_in_shadow =", is_in_shadow)

# =========================
# 开始QTE
# attack_node: 触发本次QTE的攻击节点，后续成功时要通知它
# =========================
func begin_qte(attack_node: Node) -> void:
	if is_dead:
		return

	_qte_active = true
	_qte_success = false
	_qte_index = 0
	_current_qte_attack = attack_node

	print("QTE开始！请输入顺序：J -> K -> L")

# =========================
# 结束QTE
# =========================
func end_qte() -> void:
	_qte_active = false
	_qte_index = 0
	_current_qte_attack = null
	print("QTE结束")

# =========================
# 当前QTE是否成功
# 给攻击结算时查询
# =========================
func has_qte_success() -> bool:
	return _qte_success

# =========================
# 消耗本轮QTE成功结果
# 用于攻击结算后读取一次并清空，避免重复生效
# =========================
func consume_qte_success() -> bool:
	var result := _qte_success
	_qte_success = false
	return result

# =========================
# 处理QTE输入
# 仅在QTE激活时检测
# =========================
func _update_qte_input() -> void:
	if not _qte_active:
		return

	var expected_action: String = _qte_sequence[_qte_index]

	# 如果当前应该按 J
	if expected_action == "qte_1" and Input.is_action_just_pressed("qte_j"):
		_accept_qte_input()
		return

	# 如果当前应该按 K
	if expected_action == "qte_2" and Input.is_action_just_pressed("qte_k"):
		_accept_qte_input()
		return

	# 如果当前应该按 L
	if expected_action == "qte_3" and Input.is_action_just_pressed("qte_l"):
		_accept_qte_input()
		return

	# 按错键则直接失败并结束
	if Input.is_action_just_pressed("qte_1") and expected_action != "qte_j":
		_fail_qte()
		return

	if Input.is_action_just_pressed("qte_2") and expected_action != "qte_k":
		_fail_qte()
		return

	if Input.is_action_just_pressed("qte_3") and expected_action != "qte_l":
		_fail_qte()
		return

# =========================
# 接受一次正确QTE输入
# =========================
func _accept_qte_input() -> void:
	_qte_index += 1
	print("QTE输入正确，当前进度：", _qte_index, "/", _qte_sequence.size())

	# 全部输入完成，判定成功
	if _qte_index >= _qte_sequence.size():
		_on_qte_success()

# =========================
# QTE成功
# =========================
func _on_qte_success() -> void:
	_qte_active = false
	_qte_success = true

	is_invincible = true
	_invincible_timer = qte_invincible_duration

	print("QTE成功！玩家进入短暂无敌，并准备反击")

	# 如果当前攻击节点存在，并且它实现了回调函数，就通知它
	if _current_qte_attack != null and _current_qte_attack.has_method("on_player_qte_success"):
		_current_qte_attack.on_player_qte_success(self)

# =========================
# QTE失败
# =========================
func _fail_qte() -> void:
	print("QTE失败：按键顺序错误")
	_qte_active = false
	_qte_success = false
	_qte_index = 0
	_current_qte_attack = null

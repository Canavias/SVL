extends CharacterBody2D
class_name Player

# =========================
# 可调参数
# =========================
@export var move_speed: float = 220.0                  # 移动速度
@export var dash_speed: float = 420.0                  # 冲刺速度
@export var dash_duration: float = 0.15                # 冲刺持续时间
@export var qte_invincible_duration: float = 0.35      # QTE成功后的无敌时间

# =========================
# 开发调试参数
# =========================
@export var debug_auto_qte_success: bool = false       # 开启后，QTE一开始就自动成功
@export var debug_one_key_qte_success: bool = true     # 开启后，按调试键可直接成功
@export var debug_allow_wrong_order: bool = false      # 开启后，不要求严格顺序，只要按过1/2/3即可

# =========================
# 角色状态
# =========================
var is_dead: bool = false
var is_in_shadow: bool = false
var is_invincible: bool = false

# =========================
# 内部运行变量
# =========================
var _dash_timer: float = 0.0
var _move_input: Vector2 = Vector2.ZERO
var _shadow_overlap_count: int = 0
var _invincible_timer: float = 0.0

# =========================
# QTE变量
# =========================
var _qte_active: bool = false                          # 当前是否处于QTE输入窗口
var _qte_success: bool = false                         # 本轮QTE是否成功
var _qte_index: int = 0                                # 当前输入到第几个键
var _qte_sequence: Array[String] = ["qte_1", "qte_2", "qte_3"]  # 当前QTE序列
var _current_qte_attack: Node = null                   # 当前触发QTE的攻击节点
var _qte_pressed_map := {                              # 非严格顺序模式下的按键记录
	"qte_1": false,
	"qte_2": false,
	"qte_3": false
}

# =========================
# UI引用
# =========================
var _qte_hint_ui: QTEHint = null

func _ready() -> void:
	_cache_qte_ui()

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
# 缓存QTE UI
# 默认从 Main/UI/QTEHint 获取
# =========================
func _cache_qte_ui() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	if scene.has_node("UI/QTEHint"):
		_qte_hint_ui = scene.get_node("UI/QTEHint") as QTEHint

# =========================
# 读取移动/冲刺输入
# =========================
func _read_input() -> void:
	_move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if Input.is_action_just_pressed("dash"):
		_start_dash()

# =========================
# 冲刺逻辑
# =========================
func _start_dash() -> void:
	_dash_timer = dash_duration

# =========================
# 更新无敌计时
# =========================
func _update_invincible(delta: float) -> void:
	if _invincible_timer > 0.0:
		_invincible_timer -= delta
		if _invincible_timer <= 0.0:
			_invincible_timer = 0.0
			is_invincible = false
			print("玩家无敌结束")

# =========================
# 开始QTE
# =========================
func begin_qte(attack_node: Node) -> void:
	if is_dead:
		return

	_qte_active = true
	_qte_success = false
	_qte_index = 0
	_current_qte_attack = attack_node

	_reset_qte_pressed_map()

	if _qte_hint_ui == null:
		_cache_qte_ui()

	if _qte_hint_ui != null:
		_qte_hint_ui.show_qte("1 2 3")

	print("QTE开始！当前输入序列：1 -> 2 -> 3")

	# 开发作弊：一开始就自动成功
	if debug_auto_qte_success:
		print("调试模式：自动QTE成功")
		_on_qte_success()

# =========================
# 结束QTE
# =========================
func end_qte() -> void:
	_qte_active = false
	_qte_index = 0
	_current_qte_attack = null

	_reset_qte_pressed_map()

	if _qte_hint_ui != null:
		_qte_hint_ui.hide_qte()

	print("QTE结束")

# =========================
# 受伤逻辑
# =========================
func try_take_light_damage() -> void:
	if is_dead:
		return

	if is_invincible:
		print("玩家无敌中，本次伤害无效")
		return

	if is_in_shadow:
		print("玩家位于暗影中，本次伤害无效")
		return

	die()

# =========================
# 死亡逻辑
# =========================
func die() -> void:
	is_dead = true
	queue_free()

# =========================
# 进入暗影
# =========================
func enter_shadow() -> void:
	_shadow_overlap_count += 1
	is_in_shadow = _shadow_overlap_count > 0
	print("enter_shadow -> overlap =", _shadow_overlap_count, " is_in_shadow =", is_in_shadow)

# =========================
# 退出暗影
# =========================
func exit_shadow() -> void:
	_shadow_overlap_count = max(_shadow_overlap_count - 1, 0)
	is_in_shadow = _shadow_overlap_count > 0
	print("exit_shadow -> overlap =", _shadow_overlap_count, " is_in_shadow =", is_in_shadow)

# =========================
# 处理QTE输入
# =========================
func _update_qte_input() -> void:
	if not _qte_active:
		return

	# 开发作弊：按一个调试键直接成功
	if debug_one_key_qte_success and Input.is_action_just_pressed("debug_qte_success"):
		print("调试模式：一键QTE成功")
		_on_qte_success()
		return

	if debug_allow_wrong_order:
		_update_qte_input_loose_mode()
	else:
		_update_qte_input_strict_mode()

# =========================
# 严格顺序模式
# 必须 1 -> 2 -> 3
# =========================
func _update_qte_input_strict_mode() -> void:
	var expected_action: String = _qte_sequence[_qte_index]

	if expected_action == "qte_1" and Input.is_action_just_pressed("qte_1"):
		_accept_qte_input()
		return

	if expected_action == "qte_2" and Input.is_action_just_pressed("qte_2"):
		_accept_qte_input()
		return

	if expected_action == "qte_3" and Input.is_action_just_pressed("qte_3"):
		_accept_qte_input()
		return

	if Input.is_action_just_pressed("qte_1") and expected_action != "qte_1":
		_fail_qte()
		return

	if Input.is_action_just_pressed("qte_2") and expected_action != "qte_2":
		_fail_qte()
		return

	if Input.is_action_just_pressed("qte_3") and expected_action != "qte_3":
		_fail_qte()
		return

# =========================
# 宽松模式
# 只要在窗口内按过 1 / 2 / 3 即可
# =========================
func _update_qte_input_loose_mode() -> void:
	if Input.is_action_just_pressed("qte_1"):
		_qte_pressed_map["qte_1"] = true

	if Input.is_action_just_pressed("qte_2"):
		_qte_pressed_map["qte_2"] = true

	if Input.is_action_just_pressed("qte_3"):
		_qte_pressed_map["qte_3"] = true

	if _qte_pressed_map["qte_1"] and _qte_pressed_map["qte_2"] and _qte_pressed_map["qte_3"]:
		print("宽松模式：已完成所有按键")
		_on_qte_success()

# =========================
# 接受一次正确输入
# =========================
func _accept_qte_input() -> void:
	_qte_index += 1
	print("QTE输入正确：", _qte_index, "/", _qte_sequence.size())

	if _qte_index >= _qte_sequence.size():
		_on_qte_success()

# =========================
# QTE成功
# =========================
func _on_qte_success() -> void:
	if not _qte_active:
		return

	_qte_active = false
	_qte_success = true

	is_invincible = true
	_invincible_timer = qte_invincible_duration

	if _qte_hint_ui != null:
		_qte_hint_ui.hide_qte()

	print("QTE成功！玩家进入短暂无敌，并准备反击")

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

	_reset_qte_pressed_map()

	if _qte_hint_ui != null:
		_qte_hint_ui.hide_qte()

# =========================
# 重置宽松模式的按键记录
# =========================
func _reset_qte_pressed_map() -> void:
	_qte_pressed_map["qte_1"] = false
	_qte_pressed_map["qte_2"] = false
	_qte_pressed_map["qte_3"] = false

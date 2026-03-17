extends CharacterBody2D
class_name Player

# =========================
# 可调参数
# =========================
@export var move_speed: float = 220.0                  # 普通移动速度
@export var dash_speed: float = 420.0                  # 冲刺速度
@export var dash_duration: float = 0.15                # 冲刺持续时间
@export var qte_invincible_duration: float = 0.35      # QTE成功后的短暂无敌时间

# =========================
# 血量参数
# =========================
@export var max_hp: int = 5                            # 玩家最大生命值
var current_hp: int = 5                                # 玩家当前生命值

# =========================
# 开发调试参数
# 保留功能，但移除多余输出
# =========================
@export var debug_auto_qte_success: bool = false       # 开启后，QTE开始即自动成功
@export var debug_one_key_qte_success: bool = true     # 开启后，按调试键可直接QTE成功
@export var debug_allow_wrong_order: bool = false      # 开启后，QTE不要求严格顺序

# =========================
# 角色状态
# =========================
var is_dead: bool = false                              # 是否已死亡
var is_in_shadow: bool = false                         # 是否处于暗影保护中
var is_invincible: bool = false                        # 是否处于无敌状态

# =========================
# 内部运行变量
# =========================
var _dash_timer: float = 0.0                           # 当前冲刺剩余时间
var _move_input: Vector2 = Vector2.ZERO                # 当前移动输入方向
var _shadow_overlap_count: int = 0                     # 与暗影区域的重叠计数
var _invincible_timer: float = 0.0                     # 当前无敌剩余时间

# =========================
# QTE变量
# =========================
var _qte_active: bool = false                          # 当前是否处于QTE输入窗口
var _qte_success: bool = false                         # 本轮QTE是否成功
var _qte_index: int = 0                                # 当前输入到第几个键
var _qte_sequence: Array[String] = ["qte_1", "qte_2", "qte_3"]  # 当前QTE目标序列
var _current_qte_attack: Node = null                   # 当前触发QTE的攻击节点

# 宽松模式下，记录三个按键是否已经按过
var _qte_pressed_map := {
	"qte_1": false,
	"qte_2": false,
	"qte_3": false
}

# =========================
# UI引用
# =========================
var _qte_hint_ui: QTEHint = null                       # QTE提示UI
var _player_hp_ui: PlayerHpUI = null                   # 玩家血量UI

# =========================
# 初始化
# 开局同步血量并缓存UI节点
# =========================
func _ready() -> void:
	current_hp = max_hp
	_cache_qte_ui()
	_cache_player_hp_ui()
	_refresh_hp_ui()

# =========================
# 物理帧更新
# 每帧处理：无敌计时、输入读取、QTE输入、移动
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
# 缓存QTE提示UI
# 按你当前场景结构，从 Main/UI/QTEHint 获取
# =========================
func _cache_qte_ui() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	if scene.has_node("UI/QTEHint"):
		_qte_hint_ui = scene.get_node("UI/QTEHint") as QTEHint

# =========================
# 缓存玩家血量UI
# 按你当前场景结构，从 Main/UI/PlayerHpUi 获取
# 注意节点名是 PlayerHpUi，不是 PlayerHpUI
# =========================
func _cache_player_hp_ui() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	if scene.has_node("UI/PlayerHpUi"):
		_player_hp_ui = scene.get_node("UI/PlayerHpUi") as PlayerHpUI

# =========================
# 刷新血量UI显示
# 当玩家血量变化时，通知UI更新显示
# =========================
func _refresh_hp_ui() -> void:
	if _player_hp_ui == null:
		_cache_player_hp_ui()

	if _player_hp_ui != null:
		_player_hp_ui.update_hp(current_hp, max_hp)

# =========================
# 读取移动和冲刺输入
# =========================
func _read_input() -> void:
	_move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if Input.is_action_just_pressed("dash"):
		_start_dash()

# =========================
# 开始冲刺
# =========================
func _start_dash() -> void:
	_dash_timer = dash_duration

# =========================
# 更新无敌计时器
# 到时后自动关闭无敌
# =========================
func _update_invincible(delta: float) -> void:
	if _invincible_timer > 0.0:
		_invincible_timer -= delta
		if _invincible_timer <= 0.0:
			_invincible_timer = 0.0
			is_invincible = false

# =========================
# 开始QTE
# attack_node: 本次攻击对应的攻击节点
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

	# 调试模式：QTE开始后立即成功
	if debug_auto_qte_success:
		_on_qte_success()

# =========================
# 结束QTE
# 无论成功或失败，结束时都要关闭输入窗口和提示
# =========================
func end_qte() -> void:
	_qte_active = false
	_qte_index = 0
	_current_qte_attack = null

	_reset_qte_pressed_map()

	if _qte_hint_ui != null:
		_qte_hint_ui.hide_qte()

# =========================
# 尝试受到光照伤害
# 只有在非死亡、非无敌、非暗影保护时才真正扣血
# =========================
func try_take_light_damage() -> void:
	if is_dead:
		return

	if is_invincible:
		return

	if is_in_shadow:
		return

	take_damage(1)

# =========================
# 实际扣血函数
# amount: 本次受到的伤害值
# =========================
func take_damage(amount: int) -> void:
	if is_dead:
		return

	if amount <= 0:
		return

	current_hp -= amount
	current_hp = max(current_hp, 0)

	_refresh_hp_ui()

	if current_hp <= 0:
		die()

# =========================
# 恢复生命值
# amount: 本次恢复的生命值
# 先预留给后续血包、回血奖励等功能使用
# =========================
func heal(amount: int) -> void:
	if is_dead:
		return

	if amount <= 0:
		return

	current_hp += amount
	current_hp = min(current_hp, max_hp)

	_refresh_hp_ui()

# =========================
# 死亡逻辑
# 当前先采用最简单的处理：直接移除玩家节点
# 后面可以再扩展死亡动画、结算界面等
# =========================
func die() -> void:
	if is_dead:
		return

	is_dead = true
	queue_free()

# =========================
# 进入暗影区域
# 使用重叠计数，避免多个暗影区域重叠时状态错误
# =========================
func enter_shadow() -> void:
	_shadow_overlap_count += 1
	is_in_shadow = _shadow_overlap_count > 0

# =========================
# 退出暗影区域
# 使用重叠计数，确保状态不会被提前清空
# =========================
func exit_shadow() -> void:
	_shadow_overlap_count = max(_shadow_overlap_count - 1, 0)
	is_in_shadow = _shadow_overlap_count > 0

# =========================
# 处理QTE输入
# 根据模式切换：严格顺序模式 / 宽松模式
# =========================
func _update_qte_input() -> void:
	if not _qte_active:
		return

	# 调试模式：按一个专用按键直接成功
	if debug_one_key_qte_success and Input.is_action_just_pressed("debug_qte_success"):
		_on_qte_success()
		return

	if debug_allow_wrong_order:
		_update_qte_input_loose_mode()
	else:
		_update_qte_input_strict_mode()

# =========================
# 严格顺序模式
# 必须按 1 -> 2 -> 3 的顺序完成
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
# 只要在窗口内按过 1 / 2 / 3 即可，不要求顺序
# =========================
func _update_qte_input_loose_mode() -> void:
	if Input.is_action_just_pressed("qte_1"):
		_qte_pressed_map["qte_1"] = true

	if Input.is_action_just_pressed("qte_2"):
		_qte_pressed_map["qte_2"] = true

	if Input.is_action_just_pressed("qte_3"):
		_qte_pressed_map["qte_3"] = true

	if _qte_pressed_map["qte_1"] and _qte_pressed_map["qte_2"] and _qte_pressed_map["qte_3"]:
		_on_qte_success()

# =========================
# 接受一次正确的QTE输入
# 当输入完整序列后，判定为成功
# =========================
func _accept_qte_input() -> void:
	_qte_index += 1

	if _qte_index >= _qte_sequence.size():
		_on_qte_success()

# =========================
# QTE成功
# 玩家获得短暂无敌，并通知当前攻击节点执行成功回调
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

	if _current_qte_attack != null and _current_qte_attack.has_method("on_player_qte_success"):
		_current_qte_attack.on_player_qte_success(self)

# =========================
# QTE失败
# 当前只做最基础处理：关闭QTE状态和提示
# 实际扣血仍由攻击结算阶段决定
# =========================
func _fail_qte() -> void:
	_qte_active = false
	_qte_success = false
	_qte_index = 0
	_current_qte_attack = null

	_reset_qte_pressed_map()

	if _qte_hint_ui != null:
		_qte_hint_ui.hide_qte()

# =========================
# 重置宽松模式下的按键记录
# =========================
func _reset_qte_pressed_map() -> void:
	_qte_pressed_map["qte_1"] = false
	_qte_pressed_map["qte_2"] = false
	_qte_pressed_map["qte_3"] = false

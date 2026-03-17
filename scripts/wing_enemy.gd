extends Node2D
class_name WingEnemy

# 导出参数
@export var target_path: NodePath                                      # 锁定的玩家节点
@export var attack_scene: PackedScene                                  # 生成的攻击场景
@export var attack_interval: float = 3.0                               # 攻击间隔
@export var max_hp: int = 10                                           # 最大血量
@export var counter_damage: int = 3                                    # QTE反击默认伤害

# 运行时变量
var current_hp: int = 0                                                # 当前血量
var is_dead: bool = false                                              # 是否死亡
var _target: Player = null                                             # 当前目标玩家
var _cooldown: float = 0.0                                             # 攻击冷却计时

# 信号
signal hp_changed(current_hp: int, max_hp: int)                        # 血量变化时发出
signal died(enemy: WingEnemy)                                          # 死亡时发出

# 初始化
func _ready() -> void:
	current_hp = max_hp

	if target_path != NodePath():
		_target = get_node(target_path) as Player

	_emit_hp_changed()

# 每帧处理
func _process(delta: float) -> void:
	if is_dead or _target == null or _target.is_dead:
		return

	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = attack_interval
		_start_attack()

# 发动攻击
func _start_attack() -> void:
	if attack_scene == null:
		return

	var attack = attack_scene.instantiate()
	get_tree().current_scene.get_node("AttackLayer").add_child(attack)

	if attack.has_method("setup"):
		attack.setup(self, _target)

# 通用受伤接口
func take_damage(damage: int) -> void:
	if is_dead or damage <= 0:
		return

	current_hp -= damage
	current_hp = max(current_hp, 0)

	print("WingEnemy 受到伤害：", damage, " 当前血量：", current_hp, "/", max_hp)
	_emit_hp_changed()

	if current_hp <= 0:
		die()

# QTE反击伤害
func take_counter_damage() -> void:
	take_damage(counter_damage)

# 死亡逻辑
func die() -> void:
	if is_dead:
		return

	is_dead = true
	print("WingEnemy 已死亡")

	died.emit(self)
	queue_free()

# 获取当前血量比例
func get_hp_ratio() -> float:
	if max_hp <= 0:
		return 0.0

	return float(current_hp) / float(max_hp)

# 发出血量变化信号
func _emit_hp_changed() -> void:
	hp_changed.emit(current_hp, max_hp)

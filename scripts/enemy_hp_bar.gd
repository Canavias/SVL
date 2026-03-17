extends Control
class_name EnemyHpBar

# 节点引用
@onready var hp_bar: ProgressBar = $HpBar                            # 敌人血条控件

# 当前绑定的敌人
var _enemy: WingEnemy = null                                         # 当前绑定的敌人对象

# 血条动画
var _hp_tween: Tween = null                                          # 当前血条补间动画
@export var hp_lerp_duration: float = 0.2                            # 血条变化时长

# 初始化
func _ready() -> void:
	visible = false

# 绑定敌人
func bind_enemy(enemy: WingEnemy) -> void:
	# 先断开旧敌人的信号
	if _enemy != null:
		if _enemy.hp_changed.is_connected(_on_enemy_hp_changed):
			_enemy.hp_changed.disconnect(_on_enemy_hp_changed)
		if _enemy.died.is_connected(_on_enemy_died):
			_enemy.died.disconnect(_on_enemy_died)

	_enemy = enemy

	if _enemy == null:
		visible = false
		return

	visible = true

	# 连接新敌人的信号
	if not _enemy.hp_changed.is_connected(_on_enemy_hp_changed):
		_enemy.hp_changed.connect(_on_enemy_hp_changed)

	if not _enemy.died.is_connected(_on_enemy_died):
		_enemy.died.connect(_on_enemy_died)

	# 初次绑定时直接同步
	_set_hp_immediately(_enemy.current_hp, _enemy.max_hp)

# 立即设置血条
func _set_hp_immediately(current_hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp

# 刷新血条显示
func _refresh_hp(current_hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp

	# 如果已有旧动画，先终止，避免连续受伤时动画冲突
	if _hp_tween != null:
		_hp_tween.kill()
		_hp_tween = null

	_hp_tween = create_tween()
	_hp_tween.tween_property(hp_bar, "value", current_hp, hp_lerp_duration)

# 敌人血量变化时刷新UI
func _on_enemy_hp_changed(current_hp: int, max_hp: int) -> void:
	_refresh_hp(current_hp, max_hp)

# 敌人死亡时隐藏血条
func _on_enemy_died(_dead_enemy: WingEnemy) -> void:
	visible = false

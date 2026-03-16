extends Node2D
class_name MainRoot

# =========================
# 节点引用
# 按你当前 Main 场景结构来取
# =========================
@onready var enemy: WingEnemy = $WingEnemy
@onready var enemy_hp_bar: EnemyHpBar = $UI/EnemyHpBar

# =========================
# 初始化
# =========================
func _ready() -> void:
	_bind_enemy_hp_bar()

# =========================
# 绑定敌人血条
# =========================
func _bind_enemy_hp_bar() -> void:
	if enemy_hp_bar == null:
		push_warning("Main：未找到 UI/EnemyHpBar")
		return

	if enemy == null:
		push_warning("Main：未找到 WingEnemy")
		enemy_hp_bar.bind_enemy(null)
		return

	enemy_hp_bar.bind_enemy(enemy)
	print("Main：已绑定敌人血条")

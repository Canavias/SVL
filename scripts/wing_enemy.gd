extends Node2D
class_name WingEnemy
# 导出变量
@export var target_path:NodePath       # 锁定的节点
@export var attack_scene:PackedScene   # 生成的攻击
@export var attack_interval:float=3.0  # 攻击的间隔
# 运行变量
var _target:Player=null  # 保存目标玩家引用
var _cooldown:float=0.0  # 攻击倒计时
# 寻找玩家
func _ready() -> void:
	if target_path != NodePath():
		_target = get_node(target_path) as Player
# 冷却（冷却归零时发动攻击，随后重置冷却）
func _process(delta: float) -> void:
	if _target == null:
		return
	
	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = attack_interval
		_start_attack()
# 攻击（实例化攻击场景并传入玩家当前位置）
func _start_attack() -> void:
	if attack_scene == null:
		return
		
	var attack = attack_scene.instantiate()
	get_tree().current_scene.get_node("AttackLayer").add_child(attack)
	attack.setup(_target)
		
	
	
	

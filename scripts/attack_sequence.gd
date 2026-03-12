# 继承和类名
extends Node2D
class_name AttackSequence
# 时间参数
@export var lock_duration:float=0.8     # 锁定持续时间
@export var warning_duration:float=1.2  # 预警持续时间
@export var strike_duration:float=0.2   # 攻击持续时间
@export var strike_radius: float = 64.0 # 攻击范围
# 内部状态
var _phase:int=0      # 当前所处阶段，0锁定1预警2攻击
var _timer:float=0.0  # 当前阶段剩余时间
var _target:Player    # 攻击锁定的玩家
# 缓存节点引用
@onready var lock_indicator:Sprite2D=$LockIndicator
@onready var warning_indicator:Sprite2D=$WarningIndicator
@onready var strike_area:Area2D=$StrikeArea
# 生成攻击时将被锁定的目标传入
func setup(target:Player) -> void:
	_target = target
# 攻击一生成即进入锁定状态
func _ready() -> void:
	_enter_lock_phase()
# 状态机（锁定->预警->攻击->释放内存）
func _process(delta:float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
		
	match _phase:
		0:
			_enter_warning_phase()
		1:
			_enter_strike_phase()
		2:
			queue_free()
# 锁定阶段
func _enter_lock_phase() -> void:
	_phase=0
	_timer=lock_duration
	
	lock_indicator.visible=true
	warning_indicator.visible=false
	strike_area.monitoring=false
# 预警阶段
func _enter_warning_phase() -> void:
	_phase=1
	_timer=warning_duration
	
	lock_indicator.visible=false
	warning_indicator.visible=true
	strike_area.monitoring=false
# 攻击阶段
func _enter_strike_phase() -> void:
	_phase = 2
	_timer = strike_duration

	lock_indicator.visible = false
	warning_indicator.visible = false
	strike_area.monitoring = true

	print("进入强光阶段")

	if _target == null:
		return

	var distance_to_target: float = global_position.distance_to(_target.global_position)
	print("攻击距离:", distance_to_target)

	if distance_to_target <= strike_radius:
		_target.try_take_light_damage()

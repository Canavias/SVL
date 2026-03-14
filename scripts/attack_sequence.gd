extends Node2D
class_name AttackSequence

@export var lock_duration:float=0.8     # 锁定持续时间
@export var warning_duration:float=1.2  # 预警持续时间
@export var strike_duration:float=0.2   # 攻击持续时间
@export var strike_radius:float=64.0    # 攻击范围
@export var follow_speed:float=180.0    # 追踪速度
@export var warning_start_scale:Vector2=Vector2(2.0,2.0) # 预警圈开始缩放
@export var warning_end_scale:Vector2=Vector2(3.0,3.0)   # 预警圈结束缩放
@export var warning_flash_speed:float=10.0 # 闪烁频率
@export var warning_start_color:Color=Color(1.0,1.0,0.3,0.75) # 预警开始颜色
@export var warning_end_color:Color=Color(1.0,0.1,0.1,1.0) # 预警结束颜色
# 内部状态
var _phase:int=0      # 当前所处阶段，0锁定1预警2攻击
var _timer:float=0.0  # 当前阶段剩余时间
var _target:Player    # 攻击锁定的玩家
var _phase_total_time:float=0.0 # 当前阶段开始时的总时长
# 缓存节点引用
@onready var lock_indicator:Sprite2D=$LockIndicator
@onready var warning_indicator:Sprite2D=$WarningIndicator
@onready var strike_area:Area2D=$StrikeArea
# 生成攻击时将被锁定的目标传入并持续追踪
func setup(target:Player) -> void:
	_target = target
	if _target != null:
		global_position=_target.global_position
# 攻击一生成即进入锁定状态
func _ready() -> void:
	_enter_lock_phase()
# 状态机（锁定->预警->攻击->释放内存）
func _process(delta:float) -> void:
	if _phase==0 and _target != null:
		global_position = global_position.move_toward(_target.global_position, follow_speed * delta)
	
	if _phase == 1:
		_update_warning_visual()
		
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
	_phase_total_time=lock_duration
	
	lock_indicator.visible=true
	warning_indicator.visible=false
	strike_area.monitoring=false
# 预警阶段
func _enter_warning_phase() -> void:
	_phase=1
	_timer=warning_duration	
	_phase_total_time=warning_duration
	
	lock_indicator.visible=false
	warning_indicator.visible=true
	strike_area.monitoring=false
	
	warning_indicator.scale=warning_start_scale
	warning_indicator.modulate=warning_start_color
# 攻击阶段
func _enter_strike_phase() -> void:
	_phase = 2
	_timer = strike_duration
	_phase_total_time=strike_duration

	lock_indicator.visible = false
	warning_indicator.visible = false
	strike_area.monitoring = true

	if _target == null:
		return

	var distance_to_target: float = global_position.distance_to(_target.global_position)

	if distance_to_target <= strike_radius:
		_target.try_take_light_damage()
func _update_warning_visual() -> void:
	# 防止除零
	if _phase_total_time<=0.0:
		return
	# 计算预警进度
	var progress:float=1.0-(_timer/_phase_total_time)
	progress=clamp(progress,0.0,1.0)
	# 颜色渐变+缩放改变（lerp线性插值）
	warning_indicator.modulate=warning_start_color.lerp(warning_end_color,progress)
	warning_indicator.scale=warning_start_scale.lerp(warning_end_scale,progress)
	# 闪烁逻辑（正弦波制造周期变化）
	var flash_value:float=sin(Time.get_ticks_msec()/1000.0*warning_flash_speed)
	warning_indicator.visible=flash_value>-0.4
	
	
	
	

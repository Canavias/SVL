# 继承和类名
extends CharacterBody2D
class_name Player
# 可调参数
@export var move_speed:float=220.0   # 移动速度
@export var dash_speed:float=420.0   # 冲刺速度
@export var dash_duration:float=0.15 # 冲刺时间 
# 角色状态
var is_dead:bool=false          #角色是否死亡
var is_in_shadow:bool=false     #角色是否处于阴影中
var is_invincible:bool=false    #角色是否处于无敌状态
# 内部运行变量
var _dash_timer:float=0.0             #冲刺剩余时间
var _move_input:Vector2=Vector2.ZERO  #当前输入方向
# 物理帧更新
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_read_input()
	if _dash_timer > 0.0: # 冲刺
		_dash_timer -= delta
		velocity = _move_input * dash_speed
	else:                # 移动
		velocity = _move_input * move_speed
	move_and_slide() # 执行
# 读取按键输入
func _read_input() -> void:
	_move_input = Input.get_vector("move_left","move_right","move_up","move_down")
	
	if Input.is_action_just_pressed("dash"):
		_start_dash()
# 冲刺逻辑
func _start_dash() -> void:
	_dash_timer = dash_duration
# 受伤逻辑
func try_take_light_damage() -> void:
	if is_dead:
		return
	if is_invincible:
		return
	if is_in_shadow:
		return
	die()
# 死亡逻辑
func die() -> void:
	is_dead = true
	queue_free()
# 暗影状态
func set_in_shadow(value: bool) -> void:
	is_in_shadow = value
	print("is_in_shadow=",is_in_shadow)
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	

extends Control
class_name QTEHint

# 节点引用
@onready var title_label: Label = $TitleLabel                          # 标题文本
@onready var keys_label: Label = $KeysLabel                            # 按键提示文本

# 可调参数
@export var blink_speed: float = 8.0                                   # 提示闪烁速度
@export var show_scale: Vector2 = Vector2(1.0, 1.0)                    # 默认显示缩放
@export var pulse_scale: Vector2 = Vector2(1.08, 1.08)                 # 脉冲时目标缩放

# 运行变量
var _showing: bool = false                                             # 当前是否正在显示

# 初始化
func _ready() -> void:
	visible = false
	scale = show_scale

# 显示QTE提示
func show_qte(display_text: String) -> void:
	title_label.text = "QTE!"
	keys_label.text = display_text

	visible = true
	_showing = true
	scale = pulse_scale
	modulate.a = 1.0

# 隐藏QTE提示
func hide_qte() -> void:
	visible = false
	_showing = false
	scale = show_scale
	modulate.a = 1.0

# 简单闪烁与轻微脉冲
func _process(_delta: float) -> void:
	if not _showing:
		return

	var t: float = Time.get_ticks_msec() / 1000.0
	var flash: float = 0.75 + 0.25 * sin(t * blink_speed)
	modulate.a = flash

	var pulse: float = 0.96 + 0.08 * abs(sin(t * blink_speed))
	scale = show_scale * pulse

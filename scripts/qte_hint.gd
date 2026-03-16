extends Control
class_name QTEHint

# =========================
# 节点引用
# =========================
@onready var title_label: Label = $TitleLabel
@onready var keys_label: Label = $KeysLabel

# =========================
# 可调参数
# =========================
@export var blink_speed: float = 8.0          # 提示闪烁速度
@export var show_scale: Vector2 = Vector2(1.0, 1.0)
@export var pulse_scale: Vector2 = Vector2(1.08, 1.08)

# =========================
# 运行变量
# =========================
var _showing: bool = false

func _ready() -> void:
	visible = false
	scale = show_scale

# =========================
# 显示QTE提示
# display_text: 用来显示按键序列，例如 "J K L" 或 "1 2 3"
# =========================
func show_qte(display_text: String) -> void:
	title_label.text = "QTE!"
	keys_label.text = display_text

	visible = true
	_showing = true
	scale = pulse_scale
	modulate.a = 1.0

# =========================
# 隐藏QTE提示
# =========================
func hide_qte() -> void:
	visible = false
	_showing = false
	scale = show_scale
	modulate.a = 1.0

# =========================
# 简单闪烁与轻微脉冲
# =========================
func _process(delta: float) -> void:
	if not _showing:
		return

	var t: float = Time.get_ticks_msec() / 1000.0
	var flash: float = 0.75 + 0.25 * sin(t * blink_speed)
	modulate.a = flash

	var pulse: float = 0.96 + 0.08 * abs(sin(t * blink_speed))
	scale = show_scale * pulse

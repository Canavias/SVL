extends Area2D
class_name ShadowArea

# 初始化
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# 进入区域
func _on_body_entered(body: Node) -> void:
	if body is Player:
		body.enter_shadow()

# 离开区域
func _on_body_exited(body: Node) -> void:
	if body is Player:
		body.exit_shadow()

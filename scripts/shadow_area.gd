# 继承和类名
extends Area2D
class_name ShadowArea

func _ready()  -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
# 进入区域
func _on_body_entered(body:Node) -> void:
	if body is Player:
		body.set_in_shadow(true)
		print("玩家进入暗影区")
# 离开区域
func _on_body_exited(body:Node) -> void:
	if body is Player:
		body.set_in_shadow(false)
		print("玩家离开暗影区")

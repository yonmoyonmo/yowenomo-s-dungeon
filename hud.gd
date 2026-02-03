extends Control

signal action_requested(action: String)

func _on_btn_forward_pressed():
	action_requested.emit("forward")

func _on_btn_back_pressed():
	action_requested.emit("back")

func _on_btn_left_pressed():
	action_requested.emit("left")

func _on_btn_right_pressed():
	action_requested.emit("right")

func _on_btn_turn_left_pressed():
	action_requested.emit("turn_left")

func _on_btn_turn_right_pressed():
	action_requested.emit("turn_right")

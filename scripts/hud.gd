extends Control

# HUD 버튼 입력을 게임 컨트롤러로 전달하는 중계 스크립트

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

func _on_btn_die_pressed():
	action_requested.emit("die")

func _on_btn_status_pressed():
	action_requested.emit("status")

func _on_btn_inventory_pressed():
	action_requested.emit("inventory")

func _on_btn_close_modal_pressed():
	action_requested.emit("close_modal")

func _on_btn_fight_pressed():
	action_requested.emit("fight")

func _on_btn_run_pressed():
	action_requested.emit("run")

extends Control

# 타이틀 씬 컨트롤러


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_button_1_pressed():
	# 타운으로 이동
	var err := get_tree().change_scene_to_file("res://scenes/Town.tscn")
	if err != OK:
		push_error("Failed to change scene: %s" % err)

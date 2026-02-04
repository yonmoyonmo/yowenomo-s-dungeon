extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_button_pressed():
	var err := get_tree().change_scene_to_file("res://scenes/Game.tscn")
	if err != OK:
		push_error("Failed to change scene: %s" % err)

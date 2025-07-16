extends SceneTree

func _init():
	call_deferred("_run")

func _run():
	change_scene_to_file("res://scenes/fine_tune.tscn")
	await create_timer(0.1).timeout
	print("Application started and idled")
	quit(0)

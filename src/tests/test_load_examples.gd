extends SceneTree

func _init():
	call_deferred("_run")

func _run():
	var res_root = ProjectSettings.globalize_path("res://")
	var example_dir = (res_root.path_join("..")).path_join("examples").simplify_path()
	var dir = DirAccess.open(example_dir)
	if dir == null:
		push_error("Failed to open examples directory")
		quit(1)
		return
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.get_extension().to_lower() == "json":
			var path = example_dir.path_join(file)
			var text = FileAccess.get_file_as_string(path)
			var parsed = JSON.parse_string(text)
			if typeof(parsed) != TYPE_DICTIONARY:
				push_error("Failed to load %s" % path)
				quit(1)
				dir.list_dir_end()
				return
		file = dir.get_next()
	dir.list_dir_end()
	print("Example projects loaded")
	quit(0)

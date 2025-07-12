extends SceneTree

const EXAMPLE_DIR := "res://../examples"

func _init():
	call_deferred("_run")

func _run():
	var dir = DirAccess.open(EXAMPLE_DIR)
	if dir == null:
		push_error("Failed to open examples directory")
		quit(1)
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.get_extension().to_lower() == "json":
			var path := "%s/%s" % [EXAMPLE_DIR, file]
			var text := FileAccess.get_file_as_string(path)
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

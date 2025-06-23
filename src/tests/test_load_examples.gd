extends SceneTree

const EXAMPLES := [
    "res://tests/test_projects/simple_project.json",
    "res://tests/test_projects/function_project.json"
]

func _init():
    call_deferred("_run")

func _run():
    for f in EXAMPLES:
        var text := FileAccess.get_file_as_string(f)
        var parsed = JSON.parse_string(text)
        if typeof(parsed) != TYPE_DICTIONARY:
            push_error("Failed to load %s" % f)
            quit(1)
            return
    print("Example projects loaded")
    quit(0)

extends VBoxContainer

@onready var GRADER_SCENE: PackedScene = load(get_script().resource_path.get_base_dir().path_join("grader_container.tscn"))

func _ready() -> void:
	pass

func _on_add_grader_button_pressed() -> void:
	var wrapper := MarginContainer.new()
	wrapper.layout_mode = 2
	wrapper.size_flags_vertical = 3
	wrapper.add_theme_constant_override("margin_left", 50)
	var inst := GRADER_SCENE.instantiate()
	wrapper.add_child(inst)
	inst.connect("tree_exited", Callable(wrapper, "queue_free"))
	$GradersContainer.add_child(wrapper)
	$GradersContainer.move_child($GradersContainer/AddGraderButton, -1)

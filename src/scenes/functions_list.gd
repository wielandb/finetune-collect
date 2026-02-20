extends ScrollContainer

@onready var available_function_scene = preload("res://scenes/available_function.tscn")
var _compact_layout_enabled = false

func set_compact_layout(enabled: bool) -> void:
	_compact_layout_enabled = enabled
	for function_container in $FunctionsListContainer.get_children():
		if function_container.is_in_group("available_function") and function_container.has_method("set_compact_layout"):
			function_container.set_compact_layout(enabled)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var ft_node = get_tree().get_root().get_node_or_null("FineTune")
	if ft_node != null and ft_node.has_method("is_compact_layout_enabled"):
		set_compact_layout(ft_node.is_compact_layout_enabled())
	else:
		set_compact_layout(false)

func to_var():
	var me = []
	for functionContainer in $FunctionsListContainer.get_children():
		if functionContainer.is_in_group("available_function"):
			me.append(functionContainer.to_var())
	return me

func from_var(data):
	# data -> FUNCTIONS -> [] function
	for f in data:
		var availableFunctionInstance = available_function_scene.instantiate()
		var addButton = $FunctionsListContainer/AddFunctionButton
		$FunctionsListContainer.add_child(availableFunctionInstance)
		if availableFunctionInstance.has_method("set_compact_layout"):
			availableFunctionInstance.set_compact_layout(_compact_layout_enabled)
		availableFunctionInstance.from_var(f)
		$FunctionsListContainer.move_child(addButton, -1)

func functions_list_to_gpt_available_tools_list():
	var definitions = self.to_var()
	var result := []
	for func_definition in definitions:
		# Skip any entries that have no name or no parameters
		if func_definition.get("name", "") == "":
			continue

		var function_name = func_definition["name"]
		var function_description = func_definition.get("description", "")

		# Build properties and required list
		var properties := {}
		var required_params := []

		for param_dict in func_definition["parameters"]:
			var param_name = param_dict["name"]
			required_params.append(param_name)

			# Deduce parameter type
			var param_type = "string"
			if param_dict.get("type", "").to_lower() == "number":
				param_type = "number"
			# You could add more conditionals if you have other types to handle

			# Start building the property for this parameter
			var property_definition := {
				"type": param_type,
				"description": param_dict.get("description", "")
			}

			# If it's an enum, add it
			if param_dict.get("isEnum", false):
				var enum_string = param_dict.get("enumOptions", "")
				if enum_string != "":
					# Split comma-separated string into an Array
					property_definition["enum"] = enum_string.split(",")

			# If it has limits, optionally append that info to the description
			#if param_dict.get("hasLimits", false):
			#	var minimum = param_dict.get("minimum", null)
			#	var maximum = param_dict.get("maximum", null)
			#	if minimum != null and maximum != null:
			#		property_definition["description"] += ", must be between %d and %d" % [minimum, maximum]

			properties[param_name] = property_definition

		# Build the final function object
		var openai_function := {
			"type": "function",
			"function": {
				"name": function_name,
				"description": function_description,
				"parameters": {
					"type": "object",
					"required": required_params,
					"properties": properties,
					"additionalProperties": false
				},
				"strict": true
			}
		}

		result.append(openai_function)
	print("OpenAI function definitions:")
	print(str(result))
	print("================")
	return result

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_add_function_button_pressed() -> void:
	var newInst = available_function_scene.instantiate()
	$FunctionsListContainer.add_child(newInst)
	if newInst.has_method("set_compact_layout"):
		newInst.set_compact_layout(_compact_layout_enabled)
	var newBtn = $FunctionsListContainer/AddFunctionButton
	$FunctionsListContainer.move_child(newBtn, -1)
	print(self.to_var())

func delete_all_functions_from_UI():
	for functionContainer in $FunctionsListContainer.get_children():
		if functionContainer.is_in_group("available_function"):
			functionContainer.queue_free()

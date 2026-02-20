extends SceneTree

var tests_run = 0
var tests_failed = 0

func assert_true(condition: bool, name: String) -> void:
	tests_run += 1
	if not condition:
		tests_failed += 1
		push_error("Assertion failed: " + name)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var root = VBoxContainer.new()
	get_root().add_child(root)
	var controller = load("res://scenes/schema_runtime/schema_form_controller.gd").new()
	controller.bind_form_root(root)
	var enum_values = []
	for i in range(12):
		enum_values.append("item_%02d" % i)
	var long_enum_value = "item_00_with_a_very_long_label_that_exceeds_forty_characters_for_ui"
	enum_values[0] = long_enum_value
	var schema = {
		"type": "string",
		"enum": enum_values
	}
	controller.load_schema(schema)
	await process_frame

	var filter_input = root.find_child("OptionFilterLineEdit", true, false)
	var option_buttons = root.find_children("*", "OptionButton", true, false)
	var choice = null
	if option_buttons.size() > 0:
		choice = option_buttons[0]
	assert_true(filter_input is LineEdit, "filter input rendered for enums with more than ten entries")
	assert_true(choice is OptionButton, "option button rendered")

	if filter_input is LineEdit and choice is OptionButton:
		assert_true(choice.item_count == enum_values.size(), "all enum entries visible before filtering")
		assert_true(choice.get_item_text(0) == long_enum_value, "dropdown entries keep full text and rely on control clipping")
		assert_true(choice.get_item_tooltip(0) == long_enum_value, "long enum labels keep full tooltip text")
		assert_true(choice.is_fit_to_longest_item() == false, "dropdown width is not expanded by longest entry")
		assert_true(choice.get_clip_text(), "dropdown clips text to current control width")
		assert_true(choice.get_text_overrun_behavior() == TextServer.OVERRUN_TRIM_ELLIPSIS, "dropdown uses ellipsis when text overflows")
		filter_input.text = "05"
		filter_input.emit_signal("text_changed", filter_input.text)
		await process_frame
		assert_true(choice.item_count == 1, "filter narrows option list on text change")
		assert_true(choice.get_item_text(0).find("05") != -1, "filtered option contains search text")
		choice.emit_signal("item_selected", 0)
		var parsed = JSON.parse_string(controller.get_value_as_json(false))
		assert_true(parsed == "item_05", "filtered selection maps to original enum value")
		filter_input.text = "item_1"
		filter_input.emit_signal("text_changed", filter_input.text)
		await process_frame
		assert_true(choice.item_count == 2, "typing updates visible options continuously")
		var parsed_after_auto_select = JSON.parse_string(controller.get_value_as_json(false))
		assert_true(parsed_after_auto_select == "item_10", "invalid filtered selection auto-selects first visible option")
		filter_input.text = "does_not_exist"
		filter_input.emit_signal("text_changed", filter_input.text)
		await process_frame
		assert_true(choice.item_count == 0, "no-match filter can clear all visible options")
		filter_input.text = "03"
		filter_input.emit_signal("text_changed", filter_input.text)
		await process_frame
		var parsed_after_empty_select = JSON.parse_string(controller.get_value_as_json(false))
		assert_true(parsed_after_empty_select == "item_03", "empty filtered selection auto-selects first visible option")
		filter_input.text = ""
		filter_input.emit_signal("text_changed", filter_input.text)
		await process_frame
		assert_true(choice.item_count == enum_values.size(), "clearing filter restores full option list")

	var small_root = VBoxContainer.new()
	get_root().add_child(small_root)
	var small_controller = load("res://scenes/schema_runtime/schema_form_controller.gd").new()
	small_controller.bind_form_root(small_root)
	var small_schema = {
		"type": "string",
		"enum": ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
	}
	small_controller.load_schema(small_schema)
	await process_frame
	var small_filter_input = small_root.find_child("OptionFilterLineEdit", true, false)
	assert_true(small_filter_input == null, "no filter input rendered for ten or fewer entries")

	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)

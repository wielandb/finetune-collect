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
	var schema = {
		"type": "string",
		"format": "date"
	}
	controller.load_schema(schema)

	var date_line_edit = root.find_child("DateLineEdit", true, false)
	var picker_button = root.find_child("DatePickerButton", true, false)
	var clear_button = root.find_child("DateClearButton", true, false)
	var picker_dialog = root.find_child("DatePickerDialog", true, false)
	var header_year_label = root.find_child("DatePickerHeaderYearLabel", true, false)
	var header_date_label = root.find_child("DatePickerHeaderDateLabel", true, false)
	var month_label = root.find_child("DatePickerMonthLabel", true, false)
	var calendar_grid = root.find_child("DatePickerCalendarGrid", true, false)
	var weekday_label_0 = root.find_child("DatePickerWeekdayLabel_0", true, false)
	var weekday_label_1 = root.find_child("DatePickerWeekdayLabel_1", true, false)
	var dialog_clear_button = root.find_child("DatePickerDialogClearButton", true, false)
	var cancel_button = root.find_child("DatePickerCancelButton", true, false)
	var set_button = root.find_child("DatePickerSetButton", true, false)

	assert_true(date_line_edit is LineEdit, "date line edit rendered")
	assert_true(picker_button is Button, "date picker button rendered")
	assert_true(clear_button is Button, "date clear button rendered")
	assert_true(picker_dialog is AcceptDialog, "date picker dialog rendered")
	assert_true(header_year_label is Label, "date picker header year rendered")
	assert_true(header_date_label is Label, "date picker header date rendered")
	assert_true(month_label is Label, "date picker month label rendered")
	assert_true(calendar_grid is GridContainer, "date picker calendar grid rendered")
	assert_true(weekday_label_0 is Label, "weekday label 0 rendered")
	assert_true(weekday_label_1 is Label, "weekday label 1 rendered")
	assert_true(dialog_clear_button is Button, "date picker dialog clear rendered")
	assert_true(cancel_button is Button, "date picker cancel rendered")
	assert_true(set_button is Button, "date picker set rendered")

	if date_line_edit is LineEdit and picker_button is Button and clear_button is Button and picker_dialog is AcceptDialog and header_year_label is Label and header_date_label is Label and month_label is Label and calendar_grid is GridContainer and weekday_label_0 is Label and weekday_label_1 is Label and dialog_clear_button is Button and cancel_button is Button and set_button is Button:
		assert_true(weekday_label_0.custom_minimum_size.x == weekday_label_1.custom_minimum_size.x, "weekday labels share aligned width")
		assert_true(weekday_label_0.text.length() >= 2, "weekday header labels use short abbreviations")
		date_line_edit.text = "2024-02-10"
		picker_button.emit_signal("pressed")
		assert_true(int(picker_dialog.get_meta("calendar_year", 0)) == 2024, "picker reads year from input")
		assert_true(int(picker_dialog.get_meta("calendar_month", 0)) == 2, "picker reads month from input")
		assert_true(int(picker_dialog.get_meta("calendar_day", 0)) == 10, "picker reads day from input")
		assert_true(header_date_label.text.find(", ") != -1, "header date includes comma after weekday")
		assert_true(header_date_label.text.find(". ") != -1, "header date includes dot after day number")
		assert_true(header_date_label.text.find("February") != -1 or header_date_label.text.find("Februar") != -1, "header date uses full month name")
		var prev_month_day_button = root.find_child("DateOtherMonthDayButtonPrev_31", true, false)
		assert_true(prev_month_day_button is Button, "previous month day button rendered")
		if prev_month_day_button is Button:
			prev_month_day_button.emit_signal("pressed")
		assert_true(int(picker_dialog.get_meta("calendar_year", 0)) == 2024, "selecting previous month day keeps year when expected")
		assert_true(int(picker_dialog.get_meta("calendar_month", 0)) == 1, "selecting previous month day switches month")
		assert_true(int(picker_dialog.get_meta("calendar_day", 0)) == 31, "selecting previous month day sets day")
		var day_button = root.find_child("DateDayButton_22", true, false)
		assert_true(day_button is Button, "calendar day button rendered")
		if day_button is Button:
			day_button.emit_signal("pressed")
		day_button = root.find_child("DateDayButton_22", true, false)
		if day_button is Button:
			day_button.emit_signal("pressed")
		var selected_value = JSON.parse_string(controller.get_value_as_json(false))
		assert_true(selected_value == "2024-01-22", "double click shortcut selects and sets day")
		assert_true(not picker_dialog.visible, "picker hides after double click set")

		controller.set_value_at_path([], "2024-02-21", false)
		date_line_edit.text = "2024-02-21"
		picker_button.emit_signal("pressed")
		var cancel_day_button = root.find_child("DateDayButton_22", true, false)
		if cancel_day_button is Button:
			cancel_day_button.emit_signal("pressed")
		cancel_button.emit_signal("pressed")
		var selected_after_cancel = JSON.parse_string(controller.get_value_as_json(false))
		assert_true(selected_after_cancel == "2024-02-21", "picker cancel keeps original value")
		assert_true(not picker_dialog.visible, "picker hides after cancel")

		clear_button.emit_signal("pressed")
		var selected_after_clear = JSON.parse_string(controller.get_value_as_json(false))
		assert_true(selected_after_clear == "", "inline clear empties value")

		date_line_edit.text = "2024-02-25"
		picker_button.emit_signal("pressed")
		dialog_clear_button.emit_signal("pressed")
		var selected_after_dialog_clear = JSON.parse_string(controller.get_value_as_json(false))
		assert_true(selected_after_dialog_clear == "", "dialog clear empties value")
		assert_true(not picker_dialog.visible, "picker hides after dialog clear")

	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)

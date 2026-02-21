extends SceneTree

var tests_run = 0
var tests_failed = 0

func _check(condition: bool, message: String) -> void:
	tests_run += 1
	if not condition:
		tests_failed += 1
		push_error(message)

func _set_window_size(width: int, height: int) -> void:
	var size = Vector2i(width, height)
	get_root().size = size
	DisplayServer.window_set_size(size)
	await process_frame
	await process_frame
	await create_timer(0.05).timeout

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var last_project_file = FileAccess.open("user://last_project.txt", FileAccess.WRITE)
	if last_project_file:
		last_project_file.store_string("")
		last_project_file.close()
	var last_project_data_file = FileAccess.open("user://last_project_data.json", FileAccess.WRITE)
	if last_project_data_file:
		last_project_data_file.store_string("")
		last_project_data_file.close()
	var last_project_state_file = FileAccess.open("user://last_project_state.json", FileAccess.WRITE)
	if last_project_state_file:
		last_project_state_file.store_string("")
		last_project_state_file.close()
	var scene = load("res://scenes/fine_tune.tscn").instantiate()
	get_root().add_child(scene)
	await create_timer(0.15).timeout
	var save_mode_btn = scene.get_node("VBoxContainer/SaveControls/SaveModeBtn")
	_check(not save_mode_btn.fit_to_longest_item, "save mode option button should not expand to the longest translated entry")

	await _set_window_size(360, 640)
	_check(scene.is_compact_layout_enabled(), "compact layout should be enabled for 360x640")
	var scale_for_360 = scene.get_compact_layout_scale_factor()
	_check(scene.get_node("Conversation").visible, "mobile start should show main conversation")
	_check(not scene.get_node("VBoxContainer").visible, "mobile start should hide sidebar list")
	_check(scene.get_node("CollapsedMenu").visible, "mobile start should show collapsed menu button")

	scene._on_expand_burger_btn_pressed()
	await process_frame
	_check(scene.get_node("VBoxContainer").visible, "mobile expand should show sidebar")
	_check(not scene.get_node("Conversation").visible, "mobile expand should hide main content")
	_check(not scene.get_node("CollapsedMenu").visible, "mobile expand should hide collapsed menu")

	scene._on_collapse_burger_btn_pressed()
	await process_frame
	_check(not scene.get_node("VBoxContainer").visible, "mobile collapse should hide sidebar again")
	_check(scene.get_node("Conversation").visible, "mobile collapse should show main content again")
	_check(scene.get_node("CollapsedMenu").visible, "mobile collapse should show collapsed menu button")

	await _set_window_size(1080, 1920)
	_check(scene.is_compact_layout_enabled(), "compact layout should be enabled for portrait aspect ratios independent of absolute pixels")
	var scale_for_1080 = scene.get_compact_layout_scale_factor()
	_check(scale_for_1080 >= 1.0 and scale_for_1080 <= 4.0, "mobile layout scale should stay in allowed range")
	_check(scale_for_1080 >= scale_for_360, "mobile layout scale should not shrink for wider portrait screens")

	await _set_window_size(1280, 720)
	_check(not scene.is_compact_layout_enabled(), "compact layout should be disabled for 1280x720")

	scene._on_collapse_burger_btn_pressed()
	await process_frame
	_check(not scene.get_node("VBoxContainer").visible, "desktop collapse should hide sidebar")
	_check(scene.get_node("Conversation").visible, "desktop collapse should keep main content visible")
	_check(scene.get_node("CollapsedMenu").visible, "desktop collapse should show collapsed menu")

	scene._on_expand_burger_btn_pressed()
	await process_frame
	_check(scene.get_node("VBoxContainer").visible, "desktop expand should restore sidebar")
	_check(scene.get_node("Conversation").visible, "desktop expand should keep main content visible")
	_check(not scene.get_node("CollapsedMenu").visible, "desktop expand should hide collapsed menu")

	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)

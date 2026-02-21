extends HBoxContainer

signal compact_layout_changed(enabled: bool)

const COMPACT_LAYOUT_MIN_ASPECT_RATIO = 1.3
const MOBILE_LAYOUT_REFERENCE_WIDTH = 360.0
const MOBILE_LAYOUT_COMFORT_MULTIPLIER = 1.3
const MOBILE_LAYOUT_MIN_SCALE = 1.0
const MOBILE_LAYOUT_MAX_SCALE = 4.0
const SAVE_ACTION_SAVE = 0
const SAVE_ACTION_SAVE_AS = 1
const PROJECT_STORAGE_MODE_LOCAL = 0
const PROJECT_STORAGE_MODE_CLOUD = 1
const AUTO_SAVE_MODE_OFF = 0
const AUTO_SAVE_MODE_EVERY_5_MIN = 1
const AUTO_SAVE_MODE_ON_CONVERSATION_SWITCH = 2
const FINETUNE_TYPE_SUPERVISED = 0
const FINETUNE_TYPE_DPO = 1
const FINETUNE_TYPE_REINFORCEMENT = 2
const JSONL_ENTRY_TYPE_UNKNOWN = -1

var FINETUNEDATA = {}
var FUNCTIONS = []
var CONVERSATIONS = {}
var GRADERS = []
var SCHEMAS = []
var SETTINGS = {
	"apikey": "",
	"useGlobalSystemMessage": false,
	"globalSystemMessage": "",
	"modelChoice": "gpt-4o",
	"availableModels": [],
	"schemaValidatorURL": "",
	"projectStorageMode": PROJECT_STORAGE_MODE_LOCAL,
	"projectCloudURL": "",
	"projectCloudKey": "",
	"projectCloudName": "",
	"autoSaveMode": AUTO_SAVE_MODE_OFF
}

var RUNTIME = {"filepath": ""}

# File used to remember the last opened project across sessions
const LAST_PROJECT_PATH_FILE = "user://last_project.txt"
const LAST_PROJECT_DATA_FILE = "user://last_project_data.json"
const LAST_PROJECT_STATE_FILE = "user://last_project_state.json"
const LAST_PROJECT_SOURCE_NONE = "none"
const LAST_PROJECT_SOURCE_LOCAL = "local"
const LAST_PROJECT_SOURCE_CLOUD = "cloud"
const UNSAVED_CHOICE_SAVE = 0
const UNSAVED_CHOICE_DONT_SAVE = 1
const UNSAVED_CHOICE_CANCEL = 2
const PRE_ACTION_SAVE_FAILED = 0
const PRE_ACTION_SAVE_SUCCESS = 1
const PRE_ACTION_SAVE_WAITING_FOR_DIALOG = 2
const ACTION_KIND_NEW_FINE_TUNE = "new_fine_tune"
const ACTION_KIND_LOAD_LOCAL_PATH = "load_local_path"
const ACTION_KIND_LOAD_CLOUD = "load_cloud"
const ACTION_KIND_LOAD_WEB_JSON = "load_web_json"

var CURRENT_EDITED_CONVO_IX = "FtC1"
var _compact_layout_enabled = false
var _desktop_sidebar_collapsed = false
var _compact_sidebar_visible = false
var _schemas_list_default_min_size = Vector2(0, 0)
var _desktop_content_scale_factor = 1.0
var _mobile_content_scale_factor = 1.0
var _is_applying_content_scale = false
var _autosave_in_progress = false
var _save_in_progress = false
var _default_settings_template = {}
var _last_clean_project_snapshot_json = ""
var _pending_destructive_action = {}
var _save_dialog_for_unsaved_guard_active = false
var _test_unsaved_choice_override = -1

var file_access_web = FileAccessWeb.new()
var EXPORT_BTN_ORIG_TEXT = ""
# FINETUNEDATA = 
# { functions: [],
#   settings: {
#     "use_global_system_message": true,
#     "global_system_message": "You are a helpful assistant!",
#
#	},
#   conversations: [CONVERSATION1],

# CONVERSATION1 = { 

func getRandomConvoID(length: int) -> String:
	var ascii_letters_and_digits = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	while true:
		var result = ""
		for i in range(length):
			result += ascii_letters_and_digits[randi() % ascii_letters_and_digits.length()]
		if result not in CONVERSATIONS:
			return result
	return "----" # We will never get here but Godot needs it to be happy

func selectionStringToIndex(node, string):
	# Takes a node and a string that matches one of the options and returns its index
	# Checks both item text and tooltip so it works with custom display names
	for i in range(node.item_count):
		if node.get_item_text(i) == string or node.get_item_tooltip(i) == string:
			return i
	return -1

func getallnodes(node):
	var nodeCollection = []
	for N in node.get_children():
		if N.get_child_count() > 0:
			print("["+N.get_name()+"]")
			getallnodes(N)
		else:
			nodeCollection.append(N)
	return nodeCollection

func _default_last_project_state() -> Dictionary:
	return {
		"source": LAST_PROJECT_SOURCE_NONE,
		"path": "",
		"cloudURL": "",
		"cloudKey": "",
		"cloudName": ""
	}

func _save_last_project_state(state: Dictionary) -> void:
	var merged_state = _default_last_project_state()
	for key in state.keys():
		merged_state[key] = state[key]
	var file = FileAccess.open(LAST_PROJECT_STATE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(merged_state))
		file.close()

func _load_last_project_state() -> Dictionary:
	var default_state = _default_last_project_state()
	if not FileAccess.file_exists(LAST_PROJECT_STATE_FILE):
		return default_state
	var state_text = FileAccess.get_file_as_string(LAST_PROJECT_STATE_FILE).strip_edges()
	if state_text == "":
		return default_state
	var parsed_state = JSON.parse_string(state_text)
	if typeof(parsed_state) != TYPE_DICTIONARY:
		return default_state
	for key in default_state.keys():
		if not parsed_state.has(key):
			parsed_state[key] = default_state[key]
	return parsed_state

# Store the given path so it can be loaded on the next start
func save_last_project_path(path: String) -> void:
	var file = FileAccess.open(LAST_PROJECT_PATH_FILE, FileAccess.WRITE)
	if file:
		file.store_string(path)
		file.close()

# Store raw project data for platforms where the file path can't be accessed
func save_last_project_data(json_data: String) -> void:
	var file = FileAccess.open(LAST_PROJECT_DATA_FILE, FileAccess.WRITE)
	if file:
		file.store_string(json_data)
		file.close()

func _remember_last_open_local(path: String, json_data: String) -> void:
	save_last_project_path(path)
	save_last_project_data(json_data)
	_save_last_project_state({
		"source": LAST_PROJECT_SOURCE_LOCAL,
		"path": path,
		"cloudURL": "",
		"cloudKey": "",
		"cloudName": ""
	})

func _remember_last_open_cloud(json_data: String) -> void:
	var cloud_url = str(SETTINGS.get("projectCloudURL", "")).strip_edges()
	var cloud_key = str(SETTINGS.get("projectCloudKey", "")).strip_edges()
	var cloud_name = str(SETTINGS.get("projectCloudName", "")).strip_edges()
	save_last_project_path("")
	save_last_project_data(json_data)
	_save_last_project_state({
		"source": LAST_PROJECT_SOURCE_CLOUD,
		"path": "",
		"cloudURL": cloud_url,
		"cloudKey": cloud_key,
		"cloudName": cloud_name
	})

func _clear_last_project_memory() -> void:
	save_last_project_path("")
	save_last_project_data("")
	_save_last_project_state({"source": LAST_PROJECT_SOURCE_NONE})

# Retrieve the stored project path if available
func get_last_project_path() -> String:
	if FileAccess.file_exists(LAST_PROJECT_PATH_FILE):
		var file = FileAccess.open(LAST_PROJECT_PATH_FILE, FileAccess.READ)
		if file:
			var txt = file.get_as_text()
			file.close()
			return txt.strip_edges()
	return ""

func _is_project_json_text(json_text_data: String) -> bool:
	if json_text_data.strip_edges() == "":
		return false
	var parsed = JSON.parse_string(json_text_data)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	return parsed.has("functions") and parsed.has("conversations") and parsed.has("settings")

func _capture_current_project_snapshot_json() -> String:
	_collect_current_state_for_save()
	return make_save_json_data()

func _mark_project_clean_from_current_state() -> void:
	_last_clean_project_snapshot_json = _capture_current_project_snapshot_json()

func _has_unsaved_changes() -> bool:
	if _last_clean_project_snapshot_json == "":
		return false
	var current_snapshot = _capture_current_project_snapshot_json()
	return current_snapshot != _last_clean_project_snapshot_json

# Load project data stored as snapshot fallback
func load_last_project_data() -> bool:
	if not FileAccess.file_exists(LAST_PROJECT_DATA_FILE):
		return false
	var data = FileAccess.get_file_as_string(LAST_PROJECT_DATA_FILE)
	if data.strip_edges() == "":
		return false
	if not _is_project_json_text(data):
		return false
	load_from_json_data(data)
	RUNTIME["filepath"] = ""
	return true

func _load_project_from_local_path(path: String, remember_last_open: bool = true) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var path_lower = path.to_lower()
	if path_lower.ends_with(".json"):
		load_from_json(path)
	elif path_lower.ends_with(".ftproj"):
		load_from_binary(path)
	else:
		return false
	RUNTIME["filepath"] = path
	var snapshot = _capture_current_project_snapshot_json()
	_last_clean_project_snapshot_json = snapshot
	if remember_last_open:
		_remember_last_open_local(path, snapshot)
	return true

func _load_project_from_web_json(json_text_data: String, remember_last_open: bool = true) -> bool:
	if not _is_project_json_text(json_text_data):
		return false
	load_from_json_data(json_text_data)
	RUNTIME["filepath"] = ""
	var snapshot = _capture_current_project_snapshot_json()
	_last_clean_project_snapshot_json = snapshot
	if remember_last_open:
		_remember_last_open_local("", snapshot)
	return true

func _apply_cloud_state_from_last_project_state(state: Dictionary) -> void:
	if SETTINGS.size() == 0:
		return
	var updated_settings = SETTINGS.duplicate(true)
	updated_settings["projectStorageMode"] = PROJECT_STORAGE_MODE_CLOUD
	updated_settings["projectCloudURL"] = str(state.get("cloudURL", ""))
	updated_settings["projectCloudKey"] = str(state.get("cloudKey", ""))
	updated_settings["projectCloudName"] = str(state.get("cloudName", ""))
	SETTINGS = updated_settings
	$Conversation/Settings/ConversationSettings.from_var(SETTINGS)
	_sync_save_load_ui_for_storage_mode()
	_configure_autosave()

func _restore_from_legacy_last_project() -> bool:
	var last_path = get_last_project_path()
	if last_path != "" and FileAccess.file_exists(last_path):
		if _load_project_from_local_path(last_path):
			return true
	if load_last_project_data():
		_mark_project_clean_from_current_state()
		return true
	return false

# Attempt to load the previously opened project
func load_last_project_on_start() -> void:
	var state = _load_last_project_state()
	var source = str(state.get("source", LAST_PROJECT_SOURCE_NONE))
	if source == LAST_PROJECT_SOURCE_LOCAL:
		var local_path = str(state.get("path", "")).strip_edges()
		if local_path != "" and _load_project_from_local_path(local_path):
			return
		if load_last_project_data():
			_mark_project_clean_from_current_state()
			return
	elif source == LAST_PROJECT_SOURCE_CLOUD:
		_apply_cloud_state_from_last_project_state(state)
		var cloud_loaded = await _load_project_from_cloud()
		if cloud_loaded:
			return
		_reset_project_to_defaults(false)
		return
	_restore_from_legacy_last_project()

func is_compact_layout_enabled() -> bool:
	return _compact_layout_enabled

func get_compact_layout_scale_factor() -> float:
	if _compact_layout_enabled:
		return _mobile_content_scale_factor
	return _desktop_content_scale_factor

func _get_layout_window_size() -> Vector2:
	var native_size = DisplayServer.window_get_size()
	if native_size.x > 0 and native_size.y > 0:
		return Vector2(native_size.x, native_size.y)
	return get_viewport_rect().size

func _compute_should_use_compact_layout(viewport_size: Vector2) -> bool:
	if viewport_size.x <= 0:
		return false
	var aspect_ratio = viewport_size.y / viewport_size.x
	return aspect_ratio >= COMPACT_LAYOUT_MIN_ASPECT_RATIO

func _compute_mobile_layout_scale(viewport_size: Vector2) -> float:
	if viewport_size.x <= 0:
		return 1.0
	var screen_scale = DisplayServer.screen_get_scale()
	if screen_scale <= 0.0:
		screen_scale = 1.0
	var logical_width = viewport_size.x / screen_scale
	var width_scale = (logical_width / MOBILE_LAYOUT_REFERENCE_WIDTH) * MOBILE_LAYOUT_COMFORT_MULTIPLIER
	return clampf(width_scale, MOBILE_LAYOUT_MIN_SCALE, MOBILE_LAYOUT_MAX_SCALE)

func _apply_content_scale_for_layout(compact_enabled: bool, viewport_size: Vector2) -> void:
	var target_scale = _desktop_content_scale_factor
	if compact_enabled:
		target_scale = _compute_mobile_layout_scale(viewport_size)
		_mobile_content_scale_factor = target_scale
	else:
		_mobile_content_scale_factor = 1.0
	if _is_applying_content_scale:
		return
	var root_window = get_tree().root
	if not is_equal_approx(root_window.content_scale_factor, target_scale):
		_is_applying_content_scale = true
		root_window.content_scale_factor = target_scale
		_is_applying_content_scale = false

func _set_sidebar_and_main_visibility(sidebar_visible: bool, collapsed_menu_visible: bool, conversation_visible: bool) -> void:
	$VBoxContainer.visible = sidebar_visible
	$CollapsedMenu.visible = collapsed_menu_visible
	$Conversation.visible = conversation_visible

func _apply_desktop_sidebar_state() -> void:
	if _desktop_sidebar_collapsed:
		_set_sidebar_and_main_visibility(false, true, true)
	else:
		_set_sidebar_and_main_visibility(true, false, true)

func _apply_compact_sidebar_state() -> void:
	if _compact_sidebar_visible:
		_set_sidebar_and_main_visibility(true, false, false)
	else:
		_set_sidebar_and_main_visibility(false, true, true)

func _apply_compact_layout_to_node(node: Node) -> void:
	if node != self and node.has_method("set_compact_layout"):
		node.call("set_compact_layout", _compact_layout_enabled)
	for child in node.get_children():
		_apply_compact_layout_to_node(child)

func _apply_compact_layout_to_ui() -> void:
	_apply_compact_layout_to_node(self)

func _apply_compact_layout_state(force_mobile_main: bool = false) -> void:
	var viewport_size = _get_layout_window_size()
	var should_enable_compact = _compute_should_use_compact_layout(viewport_size)
	_apply_content_scale_for_layout(should_enable_compact, viewport_size)
	if _compact_layout_enabled == should_enable_compact and not force_mobile_main:
		return
	var previous_state = _compact_layout_enabled
	_compact_layout_enabled = should_enable_compact
	if _compact_layout_enabled:
		if force_mobile_main or not previous_state:
			_compact_sidebar_visible = false
		_apply_compact_sidebar_state()
		if $Conversation/Schemas/SchemasList != null:
			$Conversation/Schemas/SchemasList.custom_minimum_size.x = 0
	else:
		_apply_desktop_sidebar_state()
		if $Conversation/Schemas/SchemasList != null:
			$Conversation/Schemas/SchemasList.custom_minimum_size.x = _schemas_list_default_min_size.x
	compact_layout_changed.emit(_compact_layout_enabled)
	_apply_compact_layout_to_ui()

func _on_viewport_size_changed() -> void:
	_apply_compact_layout_state(false)

func _is_cloud_storage_enabled() -> bool:
	return int(SETTINGS.get("projectStorageMode", PROJECT_STORAGE_MODE_LOCAL)) == PROJECT_STORAGE_MODE_CLOUD

func _is_http_url(text: String) -> bool:
	var lower_text = text.strip_edges().to_lower()
	return lower_text.begins_with("http://") or lower_text.begins_with("https://")

func _set_test_unsaved_choice_override(choice: int) -> void:
	_test_unsaved_choice_override = choice

func request_load_project_from_path_with_unsaved_guard(path: String) -> void:
	await _request_destructive_action({
		"kind": ACTION_KIND_LOAD_LOCAL_PATH,
		"path": path
	})

func request_load_project_from_web_json_with_unsaved_guard(json_text_data: String) -> void:
	await _request_destructive_action({
		"kind": ACTION_KIND_LOAD_WEB_JSON,
		"jsonData": json_text_data
	})

func _request_destructive_action(action: Dictionary) -> void:
	if _has_unsaved_changes():
		_pending_destructive_action = action.duplicate(true)
		await _show_unsaved_changes_dialog()
		return
	await _execute_destructive_action(action)

func _execute_destructive_action(action: Dictionary) -> void:
	var action_kind = str(action.get("kind", ""))
	match action_kind:
		ACTION_KIND_NEW_FINE_TUNE:
			_reset_project_to_defaults(true)
		ACTION_KIND_LOAD_LOCAL_PATH:
			var path = str(action.get("path", "")).strip_edges()
			if path != "":
				_load_project_from_local_path(path)
		ACTION_KIND_LOAD_CLOUD:
			update_settings_internal()
			await _load_project_from_cloud()
		ACTION_KIND_LOAD_WEB_JSON:
			var json_text_data = str(action.get("jsonData", ""))
			_load_project_from_web_json(json_text_data)

func _show_unsaved_changes_dialog() -> void:
	if _pending_destructive_action.size() == 0:
		return
	if _test_unsaved_choice_override != -1:
		var choice = _test_unsaved_choice_override
		_test_unsaved_choice_override = -1
		await _handle_unsaved_choice(choice)
		return
	if DisplayServer.get_name().to_lower() == "headless":
		await _handle_unsaved_choice(UNSAVED_CHOICE_CANCEL)
		return
	var dialog = ConfirmationDialog.new()
	dialog.title = tr("FINETUNE_UNSAVED_DIALOG_TITLE")
	dialog.dialog_text = tr("FINETUNE_UNSAVED_DIALOG_TEXT")
	dialog.get_ok_button().text = tr("FINETUNE_UNSAVED_DIALOG_SAVE")
	dialog.get_cancel_button().text = tr("FINETUNE_UNSAVED_DIALOG_CANCEL")
	var dont_save_button = dialog.add_button(tr("FINETUNE_UNSAVED_DIALOG_DONT_SAVE"), false, "dont_save")
	add_child(dialog)
	dialog.confirmed.connect(_on_unsaved_dialog_save_confirmed.bind(dialog))
	dialog.canceled.connect(_on_unsaved_dialog_cancelled.bind(dialog))
	dialog.close_requested.connect(_on_unsaved_dialog_cancelled.bind(dialog))
	dont_save_button.pressed.connect(_on_unsaved_dialog_dont_save_pressed.bind(dialog))
	dialog.popup_centered(Vector2i(640, 220))

func _on_unsaved_dialog_save_confirmed(dialog: ConfirmationDialog) -> void:
	dialog.queue_free()
	await _handle_unsaved_choice(UNSAVED_CHOICE_SAVE)

func _on_unsaved_dialog_dont_save_pressed(dialog: ConfirmationDialog) -> void:
	dialog.queue_free()
	await _handle_unsaved_choice(UNSAVED_CHOICE_DONT_SAVE)

func _on_unsaved_dialog_cancelled(dialog: ConfirmationDialog) -> void:
	dialog.queue_free()
	await _handle_unsaved_choice(UNSAVED_CHOICE_CANCEL)

func _handle_unsaved_choice(choice: int) -> void:
	if _pending_destructive_action.size() == 0:
		return
	if choice == UNSAVED_CHOICE_SAVE:
		var save_result = await _save_before_destructive_action()
		if save_result == PRE_ACTION_SAVE_SUCCESS:
			var action = _pending_destructive_action.duplicate(true)
			_pending_destructive_action = {}
			await _execute_destructive_action(action)
		elif save_result == PRE_ACTION_SAVE_FAILED:
			_pending_destructive_action = {}
		return
	if choice == UNSAVED_CHOICE_DONT_SAVE:
		var action = _pending_destructive_action.duplicate(true)
		_pending_destructive_action = {}
		await _execute_destructive_action(action)
		return
	_pending_destructive_action = {}

func _save_before_destructive_action() -> int:
	if _save_in_progress:
		return PRE_ACTION_SAVE_FAILED
	_save_in_progress = true
	_collect_current_state_for_save()
	var save_result = PRE_ACTION_SAVE_FAILED
	if _is_cloud_storage_enabled():
		if await _save_project_to_cloud():
			save_result = PRE_ACTION_SAVE_SUCCESS
	else:
		if RUNTIME["filepath"] != "":
			if _save_local_for_platform(SAVE_ACTION_SAVE, false):
				save_result = PRE_ACTION_SAVE_SUCCESS
		else:
			_save_dialog_for_unsaved_guard_active = true
			$VBoxContainer/SaveControls/SaveBtn/SaveFileDialog.visible = true
			save_result = PRE_ACTION_SAVE_WAITING_FOR_DIALOG
	_save_in_progress = false
	return save_result

func _reset_project_to_defaults(clear_last_project_memory: bool = true) -> void:
	RUNTIME["filepath"] = ""
	FINETUNEDATA = {}
	FUNCTIONS = []
	CONVERSATIONS = {}
	GRADERS = []
	SCHEMAS = []
	$Conversation/Messages/MessagesList.delete_all_messages_from_UI()
	$Conversation/Functions/FunctionsList.delete_all_functions_from_UI()
	$Conversation/Graders/GradersList.from_var([])
	$Conversation/Schemas/SchemasList.from_var([])
	if _default_settings_template.size() > 0:
		SETTINGS = _default_settings_template.duplicate(true)
	else:
		update_settings_internal()
		SETTINGS = SETTINGS.duplicate(true)
		_default_settings_template = SETTINGS.duplicate(true)
	$Conversation/Settings/ConversationSettings.from_var(SETTINGS)
	_sync_save_load_ui_for_storage_mode()
	_configure_autosave()
	_on_button_pressed()
	refresh_conversations_list()
	if $VBoxContainer/ConversationsList.item_count > 0:
		$VBoxContainer/ConversationsList.select(0)
		_on_item_list_item_selected(0, false)
	if clear_last_project_memory:
		_clear_last_project_memory()
	_mark_project_clean_from_current_state()

func _sync_save_load_ui_for_storage_mode() -> void:
	var save_btn = $VBoxContainer/SaveControls/SaveBtn
	var load_btn = $VBoxContainer/LoadBtn
	if _is_cloud_storage_enabled():
		save_btn.text = tr("FINETUNE_SAVE_CLOUD")
		load_btn.text = tr("FINETUNE_LOAD_CLOUD")
	else:
		save_btn.text = tr("FINETUNE_SAVE")
		load_btn.text = tr("FINETUNE_LOAD")
	var save_mode_btn = $VBoxContainer/SaveControls/SaveModeBtn
	save_mode_btn.clear()
	save_mode_btn.fit_to_longest_item = false
	save_mode_btn.clip_text = true
	save_mode_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	save_mode_btn.add_item(tr("GENERIC_SAVE"), SAVE_ACTION_SAVE)
	if not _is_cloud_storage_enabled():
		save_mode_btn.add_item(tr("GENERIC_SAVE_AS"), SAVE_ACTION_SAVE_AS)
	save_mode_btn.select(-1)
	save_mode_btn.disabled = false

func _setup_save_mode_option_button() -> void:
	var save_mode_btn = $VBoxContainer/SaveControls/SaveModeBtn
	if not save_mode_btn.is_connected("item_selected", Callable(self, "_on_save_mode_btn_item_selected")):
		save_mode_btn.item_selected.connect(_on_save_mode_btn_item_selected)
	_sync_save_load_ui_for_storage_mode()

func _on_save_mode_btn_item_selected(index: int) -> void:
	var save_mode_btn = $VBoxContainer/SaveControls/SaveModeBtn
	var selected_action = save_mode_btn.get_item_id(index)
	await _run_selected_save_action(selected_action)
	save_mode_btn.select(-1)

func _collect_current_state_for_save() -> void:
	save_current_conversation()
	update_functions_internal()
	update_settings_internal()
	update_graders_internal()
	update_schemas_internal()

func _save_local_for_platform(selected_action: int, allow_save_as_dialog: bool) -> bool:
	match OS.get_name():
		"Windows", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD", "Android","macOS":
			if selected_action == SAVE_ACTION_SAVE_AS:
				if allow_save_as_dialog:
					$VBoxContainer/SaveControls/SaveBtn/SaveFileDialog.visible = true
				return false
			else:
				if not _save_to_current_path():
					if allow_save_as_dialog:
						$VBoxContainer/SaveControls/SaveBtn/SaveFileDialog.visible = true
					return false
				refresh_conversations_list()
				var json_save_data = make_save_json_data()
				_last_clean_project_snapshot_json = json_save_data
				_remember_last_open_local(str(RUNTIME.get("filepath", "")), json_save_data)
				return true
		"Web":
			var json_save_data = make_save_json_data()
			_last_clean_project_snapshot_json = json_save_data
			_remember_last_open_local("", json_save_data)
			var byte_array = json_save_data.to_utf8_buffer()
			JavaScriptBridge.download_buffer(byte_array, "fine_tune_project.json", "text/plain")
			return true
	return false

func _cloud_request(action: String, payload: Dictionary) -> Dictionary:
	var cloud_url = str(SETTINGS.get("projectCloudURL", "")).strip_edges()
	if cloud_url == "":
		return {"ok": false, "error": "Missing projectCloudURL"}
	var request_payload = payload.duplicate(true)
	request_payload["action"] = action
	var http = HTTPRequest.new()
	add_child(http)
	var headers = PackedStringArray()
	headers.append("Content-Type: application/json")
	var err = http.request(cloud_url, headers, HTTPClient.METHOD_POST, JSON.stringify(request_payload))
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "HTTP request failed to start"}
	var response = await http.request_completed
	http.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "Network error", "result": int(response[0])}
	var response_code = int(response[1])
	var body_text = response[3].get_string_from_utf8().strip_edges()
	var parsed = JSON.parse_string(body_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		parsed = {"ok": false, "error": body_text}
	parsed["http_code"] = response_code
	return parsed

func _find_non_url_images() -> Array:
	var invalid_entries = []
	for convo_key in CONVERSATIONS.keys():
		var convo = CONVERSATIONS[convo_key]
		for i in range(convo.size()):
			var msg = convo[i]
			if msg.get("type", "") == "Image":
				var image_content = str(msg.get("imageContent", "")).strip_edges()
				if image_content != "" and not _is_http_url(image_content):
					invalid_entries.append({"conversation": str(convo_key), "messageIndex": i})
	return invalid_entries

func _save_project_to_cloud() -> bool:
	var cloud_key = str(SETTINGS.get("projectCloudKey", "")).strip_edges()
	var project_name = str(SETTINGS.get("projectCloudName", "")).strip_edges()
	if cloud_key == "" or project_name == "":
		push_error("Cloud save aborted: Missing cloud key or project name.")
		return false
	await convert_base64_images_in_all_conversations()
	var non_url_images = _find_non_url_images()
	if non_url_images.size() > 0:
		push_error("Cloud save aborted: Found image content that is not an URL.")
		print(non_url_images)
		return false
	var project_json_text = make_save_json_data()
	var project_data = JSON.parse_string(project_json_text)
	if typeof(project_data) != TYPE_DICTIONARY:
		push_error("Cloud save aborted: Could not serialize project data.")
		return false
	var payload = {
		"key": cloud_key,
		"project": project_name,
		"data": project_data
	}
	var response = await _cloud_request("save", payload)
	if int(response.get("http_code", 0)) != 200:
		push_error("Cloud save failed with HTTP code " + str(response.get("http_code", 0)))
		return false
	if not bool(response.get("ok", false)):
		push_error("Cloud save failed: " + str(response.get("error", "unknown error")))
		return false
	print("Cloud save successful for project " + project_name)
	_last_clean_project_snapshot_json = project_json_text
	_remember_last_open_cloud(project_json_text)
	return true

func _load_project_from_cloud() -> bool:
	var cloud_key = str(SETTINGS.get("projectCloudKey", "")).strip_edges()
	var project_name = str(SETTINGS.get("projectCloudName", "")).strip_edges()
	if cloud_key == "" or project_name == "":
		push_error("Cloud load aborted: Missing cloud key or project name.")
		return false
	var payload = {
		"key": cloud_key,
		"project": project_name
	}
	var response = await _cloud_request("load", payload)
	if int(response.get("http_code", 0)) != 200:
		push_error("Cloud load failed with HTTP code " + str(response.get("http_code", 0)))
		return false
	if not bool(response.get("ok", false)):
		push_error("Cloud load failed: " + str(response.get("error", "unknown error")))
		return false
	var data = response.get("data", null)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Cloud load failed: Invalid data payload.")
		return false
	var json_text_data = JSON.stringify(data, "\t", false)
	load_from_json_data(json_text_data)
	RUNTIME["filepath"] = ""
	var snapshot = _capture_current_project_snapshot_json()
	_last_clean_project_snapshot_json = snapshot
	_remember_last_open_cloud(snapshot)
	return true

func _configure_autosave() -> void:
	var mode = int(SETTINGS.get("autoSaveMode", AUTO_SAVE_MODE_OFF))
	var timer = $AutoSaveTimer
	timer.stop()
	if mode == AUTO_SAVE_MODE_EVERY_5_MIN:
		timer.wait_time = 300.0
		timer.start()

func _run_autosave(trigger: String) -> void:
	if _autosave_in_progress or _save_in_progress:
		return
	var mode = int(SETTINGS.get("autoSaveMode", AUTO_SAVE_MODE_OFF))
	if mode == AUTO_SAVE_MODE_OFF:
		return
	if trigger == "conversation_switch" and mode != AUTO_SAVE_MODE_ON_CONVERSATION_SWITCH:
		return
	if trigger == "timer" and mode != AUTO_SAVE_MODE_EVERY_5_MIN:
		return
	_autosave_in_progress = true
	_save_in_progress = true
	_collect_current_state_for_save()
	if _is_cloud_storage_enabled():
		await _save_project_to_cloud()
	else:
		if RUNTIME["filepath"] == "":
			print("Autosave skipped (local mode without filepath).")
		else:
			_save_local_for_platform(SAVE_ACTION_SAVE, false)
	_save_in_progress = false
	_autosave_in_progress = false

func _on_auto_save_timer_timeout() -> void:
	_run_autosave("timer")

func _run_selected_save_action(selected_action: int) -> bool:
	if _save_in_progress:
		return false
	_save_in_progress = true
	_collect_current_state_for_save()
	var save_success = false
	if _is_cloud_storage_enabled():
		save_success = await _save_project_to_cloud()
	else:
		save_success = _save_local_for_platform(selected_action, true)
	_save_in_progress = false
	return save_success

func _save_to_current_path() -> bool:
	if RUNTIME["filepath"] == "":
		return false
	save_as_appropriate_from_path(RUNTIME["filepath"])
	var messages_list_container = $Conversation/Messages/MessagesList/MessagesListContainer
	if messages_list_container.get_child_count() > 0:
		var first_message_container = messages_list_container.get_child(0)
		if first_message_container.is_in_group("message") and SETTINGS.get("countTokensWhen") == 0:
			first_message_container._do_token_calculation_update()
	return true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_on_button_pressed()
	refresh_conversations_list()
	_on_item_list_item_selected(0)
	delete_conversation("FtC1") # A janky workaround for the startup sequence
	refresh_conversations_list()
	_on_item_list_item_selected(0)
	file_access_web.loaded.connect(_on_file_loaded)
	file_access_web.progress.connect(_on_upload_progress)
	var save_file_dialog = $VBoxContainer/SaveControls/SaveBtn/SaveFileDialog
	if not save_file_dialog.is_connected("canceled", Callable(self, "_on_save_file_dialog_canceled")):
		save_file_dialog.canceled.connect(_on_save_file_dialog_canceled)
	update_settings_internal()
	_default_settings_template = SETTINGS.duplicate(true)
	await load_last_project_on_start()
	_setup_save_mode_option_button()
	_configure_autosave()
	if _last_clean_project_snapshot_json == "":
		_mark_project_clean_from_current_state()
	
	var tab_bar = $Conversation.get_tab_bar()
	tab_bar.set_tab_title(0, tr("Messages"))
	tab_bar.set_tab_title(1, tr("Functions"))
	tab_bar.set_tab_title(2, tr("Settings"))
	$Exporter.export_progress.connect(_on_export_progress)
	EXPORT_BTN_ORIG_TEXT = $VBoxContainer/ExportBtn.text
	_schemas_list_default_min_size = $Conversation/Schemas/SchemasList.custom_minimum_size
	_desktop_content_scale_factor = get_tree().root.content_scale_factor
	_mobile_content_scale_factor = 1.0
	if not get_viewport().is_connected("size_changed", Callable(self, "_on_viewport_size_changed")):
		get_viewport().connect("size_changed", Callable(self, "_on_viewport_size_changed"))
	_apply_compact_layout_state(true)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_released("save"):
		_run_selected_save_action(SAVE_ACTION_SAVE)
	if Input.is_action_just_released("load"):
		_on_load_btn_pressed()
	if Input.is_action_just_released("ui_paste"):
		var clipboard_content = DisplayServer.clipboard_get()
		var is_cb_json = $Conversation/Settings/ConversationSettings.validate_is_json(clipboard_content)
		if is_cb_json:
			print("War JSON")
			var ftcmsglist = conversation_from_openai_message_json(clipboard_content)
			for ftmsg in ftcmsglist:
				$Conversation/Messages/MessagesList.add_message(ftmsg)
	#	if RUNTIME["filepath"] == "":
	#		$VBoxContainer/SaveControls/SaveBtn/SaveFileDialog.visible = true
	#	else:
	#		save_as_appropriate_from_path(RUNTIME["filepath"])


func _on_save_btn_pressed() -> void:
	await _run_selected_save_action(SAVE_ACTION_SAVE)

func _on_new_fine_tune_btn_pressed() -> void:
	await _request_destructive_action({"kind": ACTION_KIND_NEW_FINE_TUNE})

func update_functions_internal():
	FUNCTIONS = $Conversation/Functions/FunctionsList.to_var()

func update_settings_internal():
	SETTINGS = $Conversation/Settings/ConversationSettings.to_var()
	print("Settings: ")

	print(SETTINGS)
	_sync_save_load_ui_for_storage_mode()
	_configure_autosave()
func update_graders_internal():
	GRADERS = $Conversation/Graders/GradersList.to_var()

func update_schemas_internal():
	SCHEMAS = $Conversation/Schemas/SchemasList.to_var()
	update_available_schemas_in_UI_global()
func get_available_schema_names():
	var tmpNames = []
	for s in SCHEMAS:
		var name = s.get("name", "")
		if name != "":
			tmpNames.append(name)
	return tmpNames

func update_available_schemas_in_UI_global():
	for node in get_tree().get_nodes_in_group("UI_needs_schema_list"):
		var selected_text := ""
		if node.selected != -1:
			selected_text = node.get_item_text(node.selected)
		node.clear()
		node.add_item(tr("ONLY_JSON_NO_SCHEMA"))
		for s in get_available_schema_names():
			node.add_item(s)
		if selected_text != "":
			var idx := -1
			for i in range(node.item_count):
				if node.get_item_text(i) == selected_text:
					idx = i
					break
			node.select(idx)
		else:
			node.select(0)
func get_available_function_names():
	var tmpNames = []
	for f in FUNCTIONS:
		tmpNames.append(f["name"])
	return tmpNames
	
func get_available_parameter_names_for_function(fname: String):
	update_functions_internal()
	var tmpParameterNames = []
	for f in FUNCTIONS:
		if f["name"] == fname:
			for p in f["parameters"]:
				tmpParameterNames.append(p["name"])
	return tmpParameterNames

func update_available_functions_in_UI_global():
	print("Updating UI...")
	for node in get_tree().get_nodes_in_group("UI_needs_function_list"):
		print("Found a UI element that needs Updating")
		node.clear()
		for f in get_available_function_names():
			node.add_item(f)

func _on_item_list_item_selected(index: int, save_before_switch = true) -> void:
	if index < 0 or index >= $VBoxContainer/ConversationsList.item_count:
		return
	var next_conversation_ix = str($VBoxContainer/ConversationsList.get_item_tooltip(index))
	var switched_conversation = next_conversation_ix != CURRENT_EDITED_CONVO_IX
	update_functions_internal()
	print("Available Function Names:")
	print(get_available_function_names())
	print("Functions: ")
	print(FUNCTIONS)
	update_available_functions_in_UI_global()
	if save_before_switch:
		save_current_conversation()
		if switched_conversation:
			_run_autosave("conversation_switch")
	# Alle Nachrichten loeschen
	for message in $Conversation/Messages/MessagesList/MessagesListContainer.get_children():
		if message.is_in_group("message"):
			message.queue_free()
	# Und die neuen aus der Convo laden
	CURRENT_EDITED_CONVO_IX = next_conversation_ix
	# Create conversation if it does not exist
	print("IX:")
	print(CURRENT_EDITED_CONVO_IX)
	DisplayServer.window_set_title("finetune-collect - Current conversation: " + CURRENT_EDITED_CONVO_IX)
	$Conversation/Messages/MessagesList.from_var(CONVERSATIONS[str(CURRENT_EDITED_CONVO_IX)])
	$Conversation/Graders/GradersList.update_from_last_message()

func save_current_conversation_to_conversations_at_index(ix: int):
	# THERE SHOULD BE NO REASON TO USE THIS FUNCTION
	CONVERSATIONS[ix] = $Conversation/Messages/MessagesList.to_var()

func save_current_conversation():
	CONVERSATIONS[CURRENT_EDITED_CONVO_IX] = $Conversation/Messages/MessagesList.to_var()

func _on_load_btn_pressed() -> void:
	update_settings_internal()
	if _is_cloud_storage_enabled():
		await _request_destructive_action({"kind": ACTION_KIND_LOAD_CLOUD})
		return
	match OS.get_name():
		"Windows", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD", "Android","macOS":
			$VBoxContainer/LoadBtn/FileDialog.visible = true
		"Web":
			file_access_web.open(".json")

func _on_file_loaded(file_name: String, file_type: String, base64_data: String) -> void:
	# A finetune project file was loaded via web
	var json_text_data = Marshalls.base64_to_utf8(base64_data)
	await request_load_project_from_web_json_with_unsaved_guard(json_text_data)
	
	
func _on_upload_progress(current_bytes: int, total_bytes: int) -> void:
	pass

func is_function_parameter_required(function_name, parameter_name):
	print("Performing parameter required check!")
	for function in FUNCTIONS:
		if function["name"] == function_name:
			for parameter in function["parameters"]:
				if parameter["name"] == parameter_name:
					print("Paramter required check:")
					print(parameter)
					return parameter["isRequired"]
	print("is_function_parameter_required could not find parameter " + str(parameter_name) + " for function " + function_name + ". I mean, I will be returning false, but are you sure everythings alright?")
	return false

func is_function_parameter_enum(function_name, parameter_name):
	for function in FUNCTIONS:
		if function["name"] == function_name:
			for parameter in function["parameters"]:
				if parameter["name"] == parameter_name:
					if parameter["isEnum"]:
						return true
	return false
	
func get_function_parameter_enums(function_name, parameter_name):
	for function in FUNCTIONS:
		if function["name"] == function_name:
			for parameter in function["parameters"]:
				if parameter["name"] == parameter_name:
					if parameter["isEnum"]:
						return str(parameter["enumOptions"]).split(",", false)
	return []

func get_function_parameter_type(function_name, parameter_name):
	for function in FUNCTIONS:
		if function["name"] == function_name:
			for parameter in function["parameters"]:
				if parameter["name"] == parameter_name:
					return parameter["type"]
	return "None"

func get_function_definition(function_name):
	for function in FUNCTIONS:
		if function["name"] == function_name:
			return function
	return {}

func get_parameter_def(function_name, parameter_name):
	for function in FUNCTIONS:
		if function["name"] == function_name:
			for parameter in function["parameters"]:
				if parameter["name"] == parameter_name:
					return parameter
	return {}

## Functions to check if invalid definitions exist

func exists_function_without_name():
	for function in FUNCTIONS:
		if function["name"] == "":
			return true
	return false

func exists_function_without_description():
	for function in FUNCTIONS:
		if function["description"] == "":
			return true
	return false

func exists_parameter_without_name():
	for function in FUNCTIONS:
			for parameter in function["parameters"]:
				if parameter["name"] == "":
					return true

func exists_parameter_without_description():
	for function in FUNCTIONS:
			for parameter in function["parameters"]:
				if parameter["description"] == "":
					return true

## -- End of functions to check if invalid definitions exist

func check_is_conversation_problematic(idx: String):
	var thisconvo = CONVERSATIONS[idx]
	var finetunetype = SETTINGS.get("finetuneType", 0)
	if finetunetype == 1:
		# DPO: First message user, second message assistant (with meta message 3 messages)
		var metamessageoffset = 0
		if thisconvo[0]["role"] == "meta" or thisconvo[0]["type"] == "meta":
			metamessageoffset = 1
		if len(thisconvo) != 2 + metamessageoffset:
			return true
		if len(thisconvo) >= 1 + metamessageoffset:
			if thisconvo[0 + metamessageoffset]["role"] != "user":
				return true
		if len(thisconvo) >= 2 + metamessageoffset:
			if thisconvo[1 + metamessageoffset]["role"] != "assistant":
				return true
		if thisconvo[0 + metamessageoffset]["textContent"] == "":
			return true
		if thisconvo[1 + metamessageoffset]["preferredTextContent"] == "" or thisconvo[1 + metamessageoffset]["unpreferredTextContent"] == "":
			return true
		return false
	elif finetunetype == 2:
		# Check that the last message is assistant and JSON or Function Call
		if thisconvo[-1]["role"] != "assistant":
			return true
		if thisconvo[-1]["type"] != "Function Call" and thisconvo[-1]["type"] != "JSON":
			return true
	# Check if at least two messages exist
	if len(thisconvo) < 2:
		return true
	# Check if all text messages contain non-empty text content
	for m in thisconvo:
		if m["type"] == "Text" and m["textContent"] == "":
			return true
	# Check if all image messages contain non-empty image content
	for m in thisconvo:
		if m["type"] == "Image" and m["imageContent"] == "":
			return true
	# Check if all function call messages contain non-empty functionNames
	for m in thisconvo:
		if m["type"] == "Function Call" and m["functionName"] == "":
			return true
	# Check if at least one message is from the assistant
	var hasAssistantMessage = false
	for m in thisconvo:
		if m["role"] == "assistant":
			hasAssistantMessage = true
	if not hasAssistantMessage:
		return true
	return false
	
func check_is_conversation_ready(idx: String) -> bool:
	var thisconvo = CONVERSATIONS[idx]
	for m in thisconvo:
		if m["type"] == "meta" and m.get("metaData", {}).get("ready", false) == true:
			return true
	return false

func _on_file_dialog_file_selected(path: String) -> void:
	await request_load_project_from_path_with_unsaved_guard(path)
	


func get_conversation_name_or_false(idx):
	var this_convo = CONVERSATIONS[idx]
	for msg in this_convo:
		if msg.get("type", "Text") == "meta":
			if msg.get("metaData", {}).get("conversationName", "") != "":
				return msg.get("metaData", {}).get("conversationName", "")
	return false

func refresh_conversations_list():
	$VBoxContainer/ConversationsList.clear()
	var numberIx = -1
	for i in CONVERSATIONS.keys():
		numberIx += 1
		var conversation_name = i
		if get_conversation_name_or_false(i):
			conversation_name = get_conversation_name_or_false(i)
		if check_is_conversation_problematic(i):
			$VBoxContainer/ConversationsList.add_item(str(conversation_name), load("res://icons/forum-remove-custom.png"))
		else:
			if check_is_conversation_ready(i):
				$VBoxContainer/ConversationsList.add_item(str(conversation_name), load("res://icons/forum-check.png"))
			else:
				$VBoxContainer/ConversationsList.add_item(str(conversation_name), load("res://icons/forum-custom.png"))
		$VBoxContainer/ConversationsList.set_item_tooltip(numberIx, i)

func _on_conversation_tab_changed(tab: int) -> void:
	save_current_conversation()
	update_functions_internal()
	update_settings_internal()
	update_graders_internal()
	update_schemas_internal()


func create_new_conversation(msgs=[]):
	# Generate a new ConvoID
	var newID = getRandomConvoID(4)
	CONVERSATIONS[newID] = msgs
	# Update everything that needs to be updated
	refresh_conversations_list()
	return newID

func append_to_conversation(convoid, msg={}):
	if convoid in CONVERSATIONS:
		CONVERSATIONS[convoid].append(msg)
	else:
		print("Error: No such conversation" + str(convoid))

func _on_button_pressed() -> void:
	# Create conversation if it does not exist
	var finetunetype = SETTINGS.get("finetuneType", 0)
	if finetunetype == 0:
		create_new_conversation(
			[
				{"role": "meta", "type": "meta"}
			]
		)
	elif finetunetype == 1:
		# DPO: There is only one kind of conversation we can have here, so we can also just poulate it
		create_new_conversation([
			{ "role": "user", "type": "Text", "textContent": "", "unpreferredTextContent": "", "preferredTextContent": "", "imageContent": "", "imageDetail": 0, "functionName": "", "functionParameters": [], "functionResults": "", "functionUsePreText": ""},
			{ "role": "assistant", "type": "Text", "textContent": "", "unpreferredTextContent": "", "preferredTextContent": "", "imageContent": "", "imageDetail": 0, "functionName": "", "functionParameters": [], "functionResults": "", "functionUsePreText": ""}
			]
		)
	elif finetunetype == 2:
		create_new_conversation(
			[
				{"role": "meta", "type": "meta"}
			]
		)
	print(CONVERSATIONS)
	

func save_to_binary(filename):
	FINETUNEDATA = {}
	FINETUNEDATA["functions"] = FUNCTIONS
	FINETUNEDATA["conversations"] = CONVERSATIONS
	FINETUNEDATA["settings"] = SETTINGS
	FINETUNEDATA["graders"] = GRADERS
	FINETUNEDATA["schemas"] = SCHEMAS
	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file:
		file.store_var(FINETUNEDATA)
		file.close()
	else:
		print("file open failed")
	
func load_from_binary(filename):
	if FileAccess.file_exists(filename):
		print("save file found")
		var file = FileAccess.open(filename, FileAccess.READ)
		FINETUNEDATA = file.get_var()
		file.close()
		FUNCTIONS = FINETUNEDATA["functions"]
		CONVERSATIONS = FINETUNEDATA["conversations"]
		SETTINGS = FINETUNEDATA["settings"]
		GRADERS = FINETUNEDATA.get("graders", [])
		SCHEMAS = FINETUNEDATA.get("schemas", [])
		for i in CONVERSATIONS.keys():
			CURRENT_EDITED_CONVO_IX = str(i)
			$Conversation/Functions/FunctionsList.delete_all_functions_from_UI()
			$Conversation/Messages/MessagesList.delete_all_messages_from_UI()
			$Conversation/Functions/FunctionsList.from_var(FUNCTIONS)
			$Conversation/Settings/ConversationSettings.from_var(SETTINGS)
			_sync_save_load_ui_for_storage_mode()
			_configure_autosave()
			$Conversation/Graders/GradersList.from_var(GRADERS)
			$Conversation/Schemas/SchemasList.from_var(SCHEMAS)
			$Conversation/Messages/MessagesList.from_var(CONVERSATIONS[CURRENT_EDITED_CONVO_IX])
			refresh_conversations_list()
			var selected_index = selectionStringToIndex($VBoxContainer/ConversationsList, CURRENT_EDITED_CONVO_IX)
			$VBoxContainer/ConversationsList.select(selected_index)
			_on_item_list_item_selected(selected_index, false)
			call_deferred("_convert_base64_images_after_load")
	else:
		print("file not found")

func load_from_json_data(jsondata: String):
	var json_as_dict = JSON.parse_string(jsondata)
	print(json_as_dict)
	# Unload all UI
	$Conversation/Functions/FunctionsList.delete_all_functions_from_UI()
	$Conversation/Messages/MessagesList.delete_all_messages_from_UI()
	FINETUNEDATA = json_as_dict
	FUNCTIONS = FINETUNEDATA["functions"]
	CONVERSATIONS = FINETUNEDATA["conversations"]
	SETTINGS = FINETUNEDATA["settings"]
	GRADERS = FINETUNEDATA.get("graders", [])
	SCHEMAS = FINETUNEDATA.get("schemas", [])
	for i in CONVERSATIONS.keys():
		CURRENT_EDITED_CONVO_IX = str(i)
	$Conversation/Settings/ConversationSettings.from_var(SETTINGS)
	_sync_save_load_ui_for_storage_mode()
	_configure_autosave()
	$Conversation/Functions/FunctionsList.from_var(FUNCTIONS)
	$Conversation/Graders/GradersList.from_var(GRADERS)
	$Conversation/Schemas/SchemasList.from_var(SCHEMAS)
	$Conversation/Messages/MessagesList.from_var(CONVERSATIONS[CURRENT_EDITED_CONVO_IX])
	refresh_conversations_list()
	var selected_index = selectionStringToIndex($VBoxContainer/ConversationsList, CURRENT_EDITED_CONVO_IX)
	if selected_index == -1:
		selected_index = len(CONVERSATIONS) - 1 
	$VBoxContainer/ConversationsList.select(selected_index)
	_on_item_list_item_selected(selected_index, false)
	call_deferred("_convert_base64_images_after_load")

func make_save_json_data():
	FINETUNEDATA = {}
	FINETUNEDATA["functions"] = FUNCTIONS
	FINETUNEDATA["conversations"] = CONVERSATIONS
	FINETUNEDATA["settings"] = SETTINGS
	FINETUNEDATA["graders"] = GRADERS
	FINETUNEDATA["schemas"] = SCHEMAS
	var jsonstr = JSON.stringify(FINETUNEDATA, "\t", false)
	return jsonstr

func save_to_json(filename):
	var file = FileAccess.open(filename, FileAccess.WRITE)
	var jsonstr = make_save_json_data()
	file.store_string(jsonstr)
	file.close()
	
func load_from_json(filename):
	# loads from a given file name
	var json_as_text = FileAccess.get_file_as_string(filename)
	load_from_json_data(json_as_text)

func import_finetune_jsonl_file(path: String) -> Dictionary:
	var report = {
		"detected_type": JSONL_ENTRY_TYPE_UNKNOWN,
		"imported": 0,
		"skipped": 0,
		"errors": [],
		"created_ids": [],
		"source_label": path.get_file(),
		"line_total": 0
	}
	if not FileAccess.file_exists(path):
		report["skipped"] = 1
		report["errors"].append("File not found: " + path)
		_show_jsonl_import_report(report)
		return report
	var jsonl_text = FileAccess.get_file_as_string(path)
	report = import_finetune_jsonl_text(jsonl_text, path.get_file())
	_show_jsonl_import_report(report)
	return report

func import_finetune_jsonl_text(jsonl_text: String, source_label: String) -> Dictionary:
	if source_label.strip_edges() == "":
		source_label = "jsonl"
	var report = {
		"detected_type": JSONL_ENTRY_TYPE_UNKNOWN,
		"imported": 0,
		"skipped": 0,
		"errors": [],
		"created_ids": [],
		"source_label": source_label,
		"line_total": 0
	}
	save_current_conversation()
	update_functions_internal()
	var lines = jsonl_text.split("\n")
	report["line_total"] = lines.size()
	var detected_type = JSONL_ENTRY_TYPE_UNKNOWN
	for i in range(lines.size()):
		var line_no = i + 1
		var line_text = lines[i].strip_edges()
		if line_text == "":
			continue
		var json = JSON.new()
		var parse_err = json.parse(line_text)
		if parse_err != OK:
			report["skipped"] += 1
			report["errors"].append("Line %d: Invalid JSON (%s)." % [line_no, json.get_error_message()])
			continue
		var entry = json.data
		if typeof(entry) != TYPE_DICTIONARY:
			report["skipped"] += 1
			report["errors"].append("Line %d: JSON entry is not an object." % line_no)
			continue
		var entry_type = _detect_jsonl_entry_type(entry)
		if entry_type == JSONL_ENTRY_TYPE_UNKNOWN:
			report["skipped"] += 1
			report["errors"].append("Line %d: Unknown fine-tuning JSONL entry shape." % line_no)
			continue
		if detected_type == JSONL_ENTRY_TYPE_UNKNOWN:
			detected_type = entry_type
			report["detected_type"] = detected_type
			_set_finetune_type_for_import(detected_type)
		elif entry_type != detected_type:
			report["skipped"] += 1
			report["errors"].append(
				"Line %d: Mixed fine-tuning type skipped (detected %s, expected %s)." % [
					line_no,
					_detected_type_to_label(entry_type),
					_detected_type_to_label(detected_type)
				]
			)
			continue
		_import_tools_from_jsonl_entry(entry, detected_type)
		var conversion_result = _convert_jsonl_entry_to_conversation(entry, detected_type, line_no, source_label)
		for warning_text in conversion_result.get("errors", []):
			report["errors"].append(warning_text)
		if not conversion_result.get("ok", false):
			report["skipped"] += 1
			continue
		var conversation_messages = conversion_result.get("conversation", [])
		if not (conversation_messages is Array) or conversation_messages.size() == 0:
			report["skipped"] += 1
			report["errors"].append("Line %d: Converted conversation is empty." % line_no)
			continue
		var created_id = create_new_conversation(conversation_messages)
		report["created_ids"].append(created_id)
		report["imported"] += 1
	update_functions_internal()
	update_settings_internal()
	if report["created_ids"].size() > 0:
		var last_created_id = report["created_ids"][report["created_ids"].size() - 1]
		_select_conversation_by_id(last_created_id)
	call_deferred("_convert_base64_images_after_load")
	return report

func _set_finetune_type_for_import(finetune_type: int) -> void:
	SETTINGS["finetuneType"] = finetune_type
	$Conversation/Settings/ConversationSettings.from_var(SETTINGS)
	update_settings_internal()

func _detect_jsonl_entry_type(entry: Dictionary) -> int:
	var looks_like_dpo = entry.has("input") and entry.has("preferred_output") and entry.has("non_preferred_output")
	if looks_like_dpo:
		return FINETUNE_TYPE_DPO
	if not entry.has("messages"):
		return JSONL_ENTRY_TYPE_UNKNOWN
	if entry.has("reference_json") \
	or entry.has("reference_answer") \
	or entry.has("do_function_call") \
	or entry.has("ideal_function_call_data"):
		return FINETUNE_TYPE_REINFORCEMENT
	for key in entry.keys():
		if key != "messages" and key != "tools":
			return FINETUNE_TYPE_REINFORCEMENT
	return FINETUNE_TYPE_SUPERVISED

func _detected_type_to_label(detected_type: int) -> String:
	match detected_type:
		FINETUNE_TYPE_SUPERVISED:
			return "SFT"
		FINETUNE_TYPE_DPO:
			return "DPO"
		FINETUNE_TYPE_REINFORCEMENT:
			return "RFT"
	return "Unknown"

func _make_ft_message_template(role: String, msg_type: String) -> Dictionary:
	return {
		"role": role,
		"type": msg_type,
		"textContent": "",
		"unpreferredTextContent": "",
		"preferredTextContent": "",
		"imageContent": "",
		"imageDetail": 0,
		"functionName": "",
		"functionParameters": [],
		"functionResults": "",
		"functionUsePreText": "",
		"userName": "",
		"jsonSchemaValue": "{}",
		"audioData": "",
		"audioTranscript": "",
		"audioFiletype": "",
		"fileMessageData": "",
		"fileMessageName": ""
	}

func _make_meta_message(conversation_name: String) -> Dictionary:
	var msg = _make_ft_message_template("meta", "meta")
	msg["metaData"] = {
		"ready": false,
		"conversationName": conversation_name,
		"notes": ""
	}
	return msg

func _make_text_message(role: String, text: String, user_name: String = "") -> Dictionary:
	var msg = _make_ft_message_template(role, "Text")
	msg["textContent"] = text
	msg["userName"] = user_name
	return msg

func _make_json_message(role: String, json_text: String) -> Dictionary:
	var msg = _make_ft_message_template(role, "JSON")
	msg["jsonSchemaValue"] = json_text
	return msg

func _extract_first_text_from_message_array(messages: Array, role_hint: String = "") -> String:
	for msg in messages:
		if msg is Dictionary:
			if role_hint == "" or msg.get("role", "") == role_hint:
				var text = _extract_text_from_msg(msg)
				if text != "":
					return text
	for msg in messages:
		if msg is Dictionary:
			return _extract_text_from_msg(msg)
	return ""

func _extract_rft_extra_fields(entry: Dictionary) -> Dictionary:
	var reserved_keys = {
		"messages": true,
		"tools": true,
		"reference_json": true,
		"reference_answer": true,
		"do_function_call": true,
		"ideal_function_call_data": true
	}
	var extras = {}
	for key in entry.keys():
		if not reserved_keys.has(key):
			extras[key] = entry[key]
	return extras

func _convert_jsonl_entry_to_conversation(entry: Dictionary, detected_type: int, line_no: int, source_label: String) -> Dictionary:
	var result = {
		"ok": false,
		"conversation": [],
		"errors": []
	}
	var conversation_name = "%s L%d" % [source_label, line_no]
	var conversation = [_make_meta_message(conversation_name)]
	match detected_type:
		FINETUNE_TYPE_SUPERVISED:
			var messages = entry.get("messages", [])
			if messages is Array:
				var converted_messages = conversation_from_openai_message_json(messages)
				for msg in converted_messages:
					conversation.append(msg)
			else:
				result["errors"].append("Line %d: SFT entry has no valid messages array." % line_no)
				result["conversation"] = []
				return result
		FINETUNE_TYPE_DPO:
			var input_entry = entry.get("input", {})
			if not (input_entry is Dictionary):
				result["errors"].append("Line %d: DPO entry input is missing or invalid." % line_no)
				result["conversation"] = []
				return result
			var input_messages = input_entry.get("messages", [])
			if input_messages is Array:
				var converted_input_messages = conversation_from_openai_message_json(input_messages)
				for msg in converted_input_messages:
					conversation.append(msg)
			else:
				result["errors"].append("Line %d: DPO input has no valid messages array." % line_no)
				result["conversation"] = []
				return result
			var preferred_messages = entry.get("preferred_output", [])
			var non_preferred_messages = entry.get("non_preferred_output", [])
			var preferred_text = ""
			var non_preferred_text = ""
			if preferred_messages is Array:
				preferred_text = _extract_first_text_from_message_array(preferred_messages, "assistant")
			if non_preferred_messages is Array:
				non_preferred_text = _extract_first_text_from_message_array(non_preferred_messages, "assistant")
			var dpo_assistant = _make_text_message("assistant", preferred_text)
			dpo_assistant["preferredTextContent"] = preferred_text
			dpo_assistant["unpreferredTextContent"] = non_preferred_text
			conversation.append(dpo_assistant)
		FINETUNE_TYPE_REINFORCEMENT:
			var rft_messages = entry.get("messages", [])
			if rft_messages is Array:
				var converted_rft_messages = conversation_from_openai_message_json(rft_messages)
				for msg in converted_rft_messages:
					conversation.append(msg)
			else:
				result["errors"].append("Line %d: RFT entry has no valid messages array." % line_no)
				result["conversation"] = []
				return result
			if entry.get("do_function_call", false):
				var ideal_call_data = entry.get("ideal_function_call_data", {})
				if ideal_call_data is Dictionary:
					var function_name = str(ideal_call_data.get("name", ""))
					if function_name != "":
						var arguments_dict = {}
						var raw_arguments = ideal_call_data.get("arguments", {})
						if raw_arguments is Dictionary:
							arguments_dict = raw_arguments
						elif raw_arguments is String:
							var parsed_args = JSON.parse_string(raw_arguments)
							if parsed_args is Dictionary:
								arguments_dict = parsed_args
						var pretext = str(ideal_call_data.get("functionUsePreText", ""))
						conversation.append(_create_ft_function_call_msg(function_name, arguments_dict, "", pretext))
					else:
						result["errors"].append("Line %d: RFT ideal_function_call_data has no function name." % line_no)
				else:
					result["errors"].append("Line %d: RFT ideal_function_call_data is invalid." % line_no)
			if entry.has("reference_json"):
				conversation.append(_make_json_message("assistant", JSON.stringify(entry.get("reference_json", {}))))
			if entry.has("reference_answer"):
				conversation.append(_make_text_message("assistant", str(entry.get("reference_answer", ""))))
			var extra_fields = _extract_rft_extra_fields(entry)
			if extra_fields.size() > 0:
				conversation.append(_make_json_message("assistant", JSON.stringify(extra_fields)))
		_:
			result["errors"].append("Line %d: Unsupported fine-tuning type." % line_no)
			result["conversation"] = []
			return result
	if conversation.size() < 2:
		result["errors"].append("Line %d: Conversation has too few messages after conversion." % line_no)
		result["conversation"] = conversation
		return result
	result["ok"] = true
	result["conversation"] = conversation
	return result

func _import_tools_from_jsonl_entry(entry: Dictionary, detected_type: int) -> void:
	var tools = []
	if detected_type == FINETUNE_TYPE_DPO:
		var dpo_input = entry.get("input", {})
		if dpo_input is Dictionary:
			var dpo_tools = dpo_input.get("tools", [])
			if dpo_tools is Array:
				tools = dpo_tools
	else:
		var top_level_tools = entry.get("tools", [])
		if top_level_tools is Array:
			tools = top_level_tools
	for tool in tools:
		if tool is Dictionary:
			_ensure_function_from_openai_tool(tool)

func _normalize_openai_param_type(raw_type) -> String:
	if raw_type is String:
		return raw_type.to_lower()
	if raw_type is Array:
		for t in raw_type:
			if t is String and t.to_lower() != "null":
				return t.to_lower()
		for t in raw_type:
			if t is String:
				return t.to_lower()
	return "string"

func _append_function_definition_to_ui(new_func_def: Dictionary) -> void:
	var func_scene = load("res://scenes/available_function.tscn")
	var func_instance = func_scene.instantiate()
	if func_instance.has_method("set_compact_layout"):
		func_instance.set_compact_layout(_compact_layout_enabled)
	func_instance.from_var(new_func_def)
	var list_container = $Conversation/Functions/FunctionsList/FunctionsListContainer
	list_container.add_child(func_instance)
	var add_btn = list_container.get_node("AddFunctionButton")
	list_container.move_child(add_btn, -1)
	update_functions_internal()
	update_available_functions_in_UI_global()

func _ensure_function_from_openai_tool(tool: Dictionary) -> void:
	if tool.get("type", "") != "function":
		return
	var function_data = tool.get("function", {})
	if not (function_data is Dictionary):
		return
	var function_name = str(function_data.get("name", "")).strip_edges()
	if function_name == "":
		return
	update_functions_internal()
	for existing in FUNCTIONS:
		if existing.get("name", "") == function_name:
			return
	var parameters_schema = function_data.get("parameters", {})
	var properties = {}
	var required_parameters = []
	if parameters_schema is Dictionary:
		var raw_properties = parameters_schema.get("properties", {})
		if raw_properties is Dictionary:
			properties = raw_properties
		var raw_required = parameters_schema.get("required", [])
		if raw_required is Array:
			required_parameters = raw_required
	var parameter_defs = []
	for parameter_name in properties.keys():
		var parameter_schema = properties[parameter_name]
		if not (parameter_schema is Dictionary):
			continue
		var normalized_type = _normalize_openai_param_type(parameter_schema.get("type", "string"))
		var ft_parameter_type = "String"
		if normalized_type == "number" or normalized_type == "integer":
			ft_parameter_type = "Number"
		var is_required = required_parameters.has(parameter_name)
		var is_enum = false
		var enum_options = ""
		var raw_enum = parameter_schema.get("enum", [])
		if raw_enum is Array and raw_enum.size() > 0:
			is_enum = true
			var enum_text_values = []
			for enum_value in raw_enum:
				enum_text_values.append(str(enum_value))
			enum_options = ",".join(enum_text_values)
		var has_limits = parameter_schema.has("minimum") or parameter_schema.has("maximum")
		var minimum = 0
		var maximum = 0
		if parameter_schema.has("minimum"):
			minimum = float(parameter_schema["minimum"])
		if parameter_schema.has("maximum"):
			maximum = float(parameter_schema["maximum"])
		parameter_defs.append({
			"type": ft_parameter_type,
			"name": str(parameter_name),
			"description": str(parameter_schema.get("description", "")),
			"minimum": minimum,
			"maximum": maximum,
			"isEnum": is_enum,
			"hasLimits": has_limits and ft_parameter_type == "Number",
			"enumOptions": enum_options,
			"isRequired": is_required
		})
	var new_function_definition = {
		"name": function_name,
		"description": str(function_data.get("description", "")),
		"parameters": parameter_defs,
		"functionExecutionEnabled": false,
		"functionExecutionExecutable": "",
		"functionExecutionArgumentsString": ""
	}
	_append_function_definition_to_ui(new_function_definition)

func _select_conversation_by_id(convo_id: String) -> void:
	var selected_index = selectionStringToIndex($VBoxContainer/ConversationsList, convo_id)
	if selected_index < 0:
		return
	$VBoxContainer/ConversationsList.select(selected_index)
	_on_item_list_item_selected(selected_index, false)

func _show_jsonl_import_report(report: Dictionary) -> void:
	var lines = []
	lines.append(tr("FINETUNE_JSONL_IMPORT_REPORT_TITLE"))
	lines.append(tr("FINETUNE_JSONL_IMPORT_REPORT_SOURCE") % str(report.get("source_label", "")))
	lines.append(tr("FINETUNE_JSONL_IMPORT_REPORT_IMPORTED") % int(report.get("imported", 0)))
	lines.append(tr("FINETUNE_JSONL_IMPORT_REPORT_SKIPPED") % int(report.get("skipped", 0)))
	lines.append(tr("FINETUNE_JSONL_IMPORT_REPORT_DETECTED_TYPE") % _detected_type_to_label(int(report.get("detected_type", JSONL_ENTRY_TYPE_UNKNOWN))))
	var errors = report.get("errors", [])
	if errors is Array and errors.size() > 0:
		lines.append("")
		lines.append(tr("FINETUNE_JSONL_IMPORT_REPORT_DETAILS"))
		var max_errors_to_show = min(20, errors.size())
		for i in range(max_errors_to_show):
			lines.append("- " + str(errors[i]))
		if errors.size() > max_errors_to_show:
			lines.append(tr("FINETUNE_JSONL_IMPORT_REPORT_MORE") % int(errors.size() - max_errors_to_show))
	var dialog_text = "\n".join(lines)
	print(dialog_text)
	if not is_inside_tree():
		return
	if DisplayServer.get_name().to_lower() == "headless":
		return
	var dialog = AcceptDialog.new()
	dialog.title = tr("FINETUNE_JSONL_IMPORT_DIALOG_TITLE")
	dialog.dialog_text = dialog_text
	add_child(dialog)
	dialog.confirmed.connect(Callable(dialog, "queue_free"))
	dialog.close_requested.connect(Callable(dialog, "queue_free"))
	dialog.popup_centered(Vector2i(760, 460))

func save_as_appropriate_from_path(path):
	var path_lower = path.to_lower()
	if path_lower.ends_with(".json"):
		save_to_json(path)
	elif path_lower.ends_with(".ftproj"):
		save_to_binary(path)
	else:
		print("Konnte nicht speichern, da unbekanntes format")

func load_from_appropriate_from_path(path):
	var path_lower = path.to_lower()
	if path_lower.ends_with(".json"):
		load_from_json(path)
	elif path_lower.ends_with(".ftproj"):
		load_from_binary(path)
	else:
		print("Konnte nicht laden, da unbekanntes format")


func _on_save_file_dialog_file_selected(path: String) -> void:
	if _is_cloud_storage_enabled():
		var cloud_saved = await _save_project_to_cloud()
		if _save_dialog_for_unsaved_guard_active:
			_save_dialog_for_unsaved_guard_active = false
			if cloud_saved and _pending_destructive_action.size() > 0:
				var cloud_action = _pending_destructive_action.duplicate(true)
				_pending_destructive_action = {}
				await _execute_destructive_action(cloud_action)
			else:
				_pending_destructive_action = {}
		return
	save_current_conversation()
	update_functions_internal()
	update_settings_internal()
	update_graders_internal()
	update_schemas_internal()
	var save_success = false
	var path_lower = path.to_lower()
	if path_lower.ends_with(".json"):
		save_to_json(path)
		save_success = true
	elif path_lower.ends_with(".ftproj"):
		save_to_binary(path)
		save_success = true
	if save_success:
		RUNTIME["filepath"] = path
		var snapshot = make_save_json_data()
		_last_clean_project_snapshot_json = snapshot
		_remember_last_open_local(path, snapshot)
	if _save_dialog_for_unsaved_guard_active:
		_save_dialog_for_unsaved_guard_active = false
		if save_success and _pending_destructive_action.size() > 0:
			var action = _pending_destructive_action.duplicate(true)
			_pending_destructive_action = {}
			await _execute_destructive_action(action)
		else:
			_pending_destructive_action = {}

func _on_save_file_dialog_canceled() -> void:
	if _save_dialog_for_unsaved_guard_active:
		_save_dialog_for_unsaved_guard_active = false
		_pending_destructive_action = {}

func delete_conversation(ixStr: String):
	CONVERSATIONS.erase(ixStr)
	# If we were currently editing this conversation, unload it
	if CURRENT_EDITED_CONVO_IX == ixStr:
		for message in $Conversation/Messages/MessagesList/MessagesListContainer.get_children():
			if message.is_in_group("message"):
				message.queue_free()
		# Select a random conversation that we will now be editing
		for c in CONVERSATIONS.keys():
			CURRENT_EDITED_CONVO_IX = c
			$Conversation/Messages/MessagesList.from_var(CONVERSATIONS[CURRENT_EDITED_CONVO_IX])
			refresh_conversations_list()
			$VBoxContainer/ConversationsList.select(selectionStringToIndex($VBoxContainer/ConversationsList, CURRENT_EDITED_CONVO_IX))
			break
	refresh_conversations_list()
	print(CONVERSATIONS)

func get_ItemList_selected_Item_index(node: ItemList) -> int:
	for i in range(node.item_count):
		if node.is_selected(i):
			return i
	return -1

func _on_conversations_list_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == 4194312:
			# Go through every entry and check if it is selected
			for i in range($VBoxContainer/ConversationsList.item_count):
				if $VBoxContainer/ConversationsList.is_selected(i):
					delete_conversation($VBoxContainer/ConversationsList.get_item_tooltip(get_ItemList_selected_Item_index($VBoxContainer/ConversationsList)))
		if event.pressed and Input.is_key_pressed(KEY_CTRL) and event.keycode == KEY_D:
			for i in range($VBoxContainer/ConversationsList.item_count):
				if $VBoxContainer/ConversationsList.is_selected(i):
					var newConvoID = getRandomConvoID(4)
					var origConvoID = $VBoxContainer/ConversationsList.get_item_text(get_ItemList_selected_Item_index($VBoxContainer/ConversationsList))
					CONVERSATIONS[newConvoID] = CONVERSATIONS[origConvoID]
					refresh_conversations_list()
					

func _on_collapse_burger_btn_pressed() -> void:
	if _compact_layout_enabled:
		_compact_sidebar_visible = false
		_apply_compact_sidebar_state()
		return
	_desktop_sidebar_collapsed = true
	_apply_desktop_sidebar_state()

func _on_expand_burger_btn_pressed() -> void:
	if _compact_layout_enabled:
		_compact_sidebar_visible = true
		_apply_compact_sidebar_state()
		return
	_desktop_sidebar_collapsed = false
	_apply_desktop_sidebar_state()

func create_jsonl_data_for_file():
	var EFINETUNEDATA = {} # EFINETUNEDATA -> ExportFinetuneData (so that we don't remove anything from the save file on export)
	EFINETUNEDATA["functions"] = FUNCTIONS.duplicate(true)
	var allconversations = CONVERSATIONS.duplicate(true)
	var unproblematicconversations = {}
	# Check all conversations and only add unproblematic ones
	# Check what the settings say about what to export
	var whatToExport = SETTINGS.get("exportConvo", 0)
	# 0 -> only unproblematic, 1 -> only ready, 2 -> all
	for convokey in allconversations:
		if whatToExport == 0:
			if not check_is_conversation_problematic(convokey):
				unproblematicconversations[convokey] = CONVERSATIONS[convokey]
		elif whatToExport == 1:
			if not check_is_conversation_problematic(convokey) and check_is_conversation_ready(convokey):
				unproblematicconversations[convokey] = CONVERSATIONS[convokey]
		elif whatToExport == 2:
			unproblematicconversations[convokey] = CONVERSATIONS[convokey]
	EFINETUNEDATA["conversations"] = unproblematicconversations
	EFINETUNEDATA["settings"] = SETTINGS.duplicate(true)
	var complete_jsonl_string = ""
	match SETTINGS.get("finetuneType", 0):
		0:
			complete_jsonl_string = await $Exporter.convert_fine_tuning_data(EFINETUNEDATA)
		1:
			complete_jsonl_string = await $Exporter.convert_dpo_data(EFINETUNEDATA)
		2:
			complete_jsonl_string = await $Exporter.convert_rft_data(EFINETUNEDATA)
	return complete_jsonl_string

func _start_export_progress():
	EXPORT_BTN_ORIG_TEXT = $VBoxContainer/ExportBtn.text
	$VBoxContainer/ExportBtn.disabled = true
	$VBoxContainer/ExportBtn.text = tr("FINETUNE_EXPORTING")


func _end_export_progress():
	$VBoxContainer/ExportBtn.disabled = false
	$VBoxContainer/ExportBtn.text = EXPORT_BTN_ORIG_TEXT


func _on_export_progress(current: int, total: int, text: String = "") -> void:
	var base_text = tr("FINETUNE_EXPORTING")
	if text != "":
		base_text += " " + text
	$VBoxContainer/ExportBtn.text = "%s %d/%d" % [base_text, current, total]


func _on_export_btn_pressed() -> void:
	# If we are on the web, different things need to happen
	match OS.get_name():
		"Windows", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD", "Android","macOS":
			$VBoxContainer/ExportBtn/ExportFileDialog.visible = true
		"Web":
			_start_export_progress()
			# When we are on web, we need to download the file directly
			var complete_jsonl_string = await create_jsonl_data_for_file()
			_end_export_progress()
			var byte_array = complete_jsonl_string.to_utf8_buffer()
			JavaScriptBridge.download_buffer(byte_array, "fine_tune.jsonl", "text/plain")
	

func _on_export_file_dialog_file_selected(path: String) -> void:
	_start_export_progress()
	var complete_jsonl_string = await create_jsonl_data_for_file()
	_end_export_progress()
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(complete_jsonl_string)
	file.close()


func isImageURL(url: String) -> bool:
	# Return false if the URL is empty or only whitespace.
	if url.strip_edges() == "":
		return false

	# Define valid URL schemes. Adjust this list if you need to allow other schemes.
	var valid_schemes = ["http://", "https://"]

	# Convert the URL to lowercase for case-insensitive comparisons.
	var lower_url = url.to_lower()

	# Check if the URL begins with one of the valid schemes.
	var scheme_valid = false
	for scheme in valid_schemes:
		if lower_url.begins_with(scheme):
			scheme_valid = true
			break
	if not scheme_valid:
		return false

	# Remove any query parameters or fragment identifiers.
	var cleaned_url = lower_url.split("?")[0].split("#")[0]

	# Finally, check if the cleaned URL ends with a valid image extension.
	return cleaned_url.ends_with(".png") or cleaned_url.ends_with(".jpg") or cleaned_url.ends_with(".jpeg")

# This function uses the above isJpgOrPngURL() to check if the URL is valid,
# and if so, returns "png" if the URL ends with .png or "jpg" if it ends with .jpg.
# Otherwise, it returns an empty string.
func getImageType(url: String) -> String:
	# Use our helper function to ensure the URL is valid.
	if not isImageURL(url):
		return ""
	
	# Convert to lowercase and remove any query or fragment parts.
	var lower_url = url.to_lower()
	var base_url = lower_url.split("?")[0].split("#")[0]
	
	if base_url.ends_with(".png"):
		return "png"
	elif base_url.ends_with(".jpg"):
		return "jpg"
	elif base_url.ends_with(".jpeg"):
		return "jpeg"
	else:
		return ""


func get_number_of_images_for_conversation(convoIx):
	var image_count = 0
	for message in CONVERSATIONS[convoIx]:
		if message["type"] == "Image":
			image_count += 1
	return image_count

func get_number_of_images_total():
	var image_count = 0
	for convoIx in CONVERSATIONS:
		image_count += get_number_of_images_for_conversation(convoIx)
	return image_count

func get_ext_from_base64(b64: String) -> String:
	var raw = Marshalls.base64_to_raw(b64)
	if raw.size() >= 3 and raw[0] == 0xFF and raw[1] == 0xD8 and raw[2] == 0xFF:
		return "jpg"
	if raw.size() >= 8 and raw[0] == 0x89 and raw[1] == 0x50 and raw[2] == 0x4E and raw[3] == 0x47:
		return "png"
	return "jpg"

func _upload_base64_image_get_url(b64: String, upload_url: String, upload_key: String) -> String:
	var data_str = b64
	if data_str.begins_with("http://") or data_str.begins_with("https://"):
		return data_str
	var http = HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray()
	headers.append("Content-Type: application/json")
	var ext = get_ext_from_base64(data_str)
	var payload = {"key": upload_key, "image": data_str, "ext": ext}
	var err = http.request(upload_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		http.queue_free()
		return b64
	var resp = await http.request_completed
	http.queue_free()
	if resp[1] == 200:
		return resp[3].get_string_from_utf8().strip_edges()
	return b64

func convert_base64_images_in_all_conversations() -> void:
	var upload_enabled = SETTINGS.get("imageUploadSetting", 0)
	var upload_url = SETTINGS.get("imageUploadServerURL", "")
	var upload_key = SETTINGS.get("imageUploadServerKey", "")
	if upload_enabled != 1 or upload_url == "" or upload_key == "":
		return
	for convo_key in CONVERSATIONS.keys():
		var convo = CONVERSATIONS[convo_key]
		for i in range(convo.size()):
			var msg = convo[i]
			if msg.get("type", "") == "Image":
				var img_data = msg.get("imageContent", "")
				if img_data != "" and not _is_http_url(str(img_data)):
					var url = await _upload_base64_image_get_url(img_data, upload_url, upload_key)
					CONVERSATIONS[convo_key][i]["imageContent"] = url

func _convert_base64_images_after_load() -> void:
	await convert_base64_images_in_all_conversations()

# Helper to create a Finetune-Collect function call message and ensure the
# function definition exists in the global FUNCTIONS array.
func _create_ft_function_call_msg(function_name: String, arguments_dict: Dictionary, function_result: String, pretext: String) -> Dictionary:
	update_functions_internal()
	var param_list := []
	for arg_name in arguments_dict.keys():
					var val = arguments_dict[arg_name]
					var entry = {
									"name": str(arg_name),
									"isUsed": true,
									"parameterValueText": "",
									"parameterValueChoice": "",
									"parameterValueNumber": 0
					}
					match typeof(val):
									TYPE_INT, TYPE_FLOAT:
													entry["parameterValueNumber"] = val
									_:
													entry["parameterValueText"] = str(val)
					param_list.append(entry)

	var fn_exists = false
	for f in FUNCTIONS:
					if f.get("name", "") == function_name:
									fn_exists = true
									break
	if !fn_exists:
					var param_defs := []
					for arg_name in arguments_dict.keys():
									var v = arguments_dict[arg_name]
									var p_type = "Number" if (typeof(v) in [TYPE_INT, TYPE_FLOAT]) else "String"
									param_defs.append({
													"type": p_type,
													"name": str(arg_name),
													"description": "",
													"minimum": 0,
													"maximum": 0,
													"isEnum": false,
													"hasLimits": false,
													"enumOptions": "",
													"isRequired": true
									})
					var new_func_def = {
									"name": function_name,
									"description": "",
									"parameters": param_defs,
									"functionExecutionEnabled": false,
									"functionExecutionExecutable": "",
									"functionExecutionArgumentsString": ""
					}
					var func_scene = load("res://scenes/available_function.tscn")
					var func_instance = func_scene.instantiate()
					if func_instance.has_method("set_compact_layout"):
						func_instance.set_compact_layout(_compact_layout_enabled)
					func_instance.from_var(new_func_def)
					var list_container = $Conversation/Functions/FunctionsList/FunctionsListContainer
					list_container.add_child(func_instance)
					var add_btn = list_container.get_node("AddFunctionButton")
					list_container.move_child(add_btn, -1)
					update_functions_internal()
					update_available_functions_in_UI_global()
	return {
			"role": "assistant",
			"type": "Function Call",
			"textContent": "",
			"unpreferredTextContent": "",
			"preferredTextContent": "",
			"imageContent": "",
			"imageDetail": 0,
			"functionName": function_name,
			"functionParameters": param_list,
			"functionResults": function_result,
			"functionUsePreText": pretext
	}

# Extract text content from an OpenAI message which may contain either a string
# or an array with text parts.
func _extract_text_from_msg(msg: Dictionary) -> String:
		var text := ""
		if msg.has("content"):
						var content = msg["content"]
						if content is String:
										text = content
						elif content is Array:
										for p in content:
														if p is String:
																		text += p
														elif typeof(p) == TYPE_DICTIONARY:
																		if p.get("type", "") == "text":
																						text += p.get("text", "")
																		elif p.has("text"):
																						text += p["text"]
						elif content is Dictionary:
										text = content.get("text", "")
		return text

# Simple JSON validity check used when importing OpenAI messages
func _validate_is_json(testtext) -> bool:
	if testtext == "":
			return false
	var json = JSON.new()
	var err = json.parse(testtext)
	if err == OK:
			return true
	return false

func conversation_from_openai_message_json(oaimsgjson):
	# Accept both a JSON string or an already parsed array
	if typeof(oaimsgjson) == TYPE_STRING:
		var parsed = JSON.parse_string(oaimsgjson)
		if parsed is Dictionary and parsed.has("messages"):
			oaimsgjson = parsed["messages"]
		else:
			oaimsgjson = parsed
	if typeof(oaimsgjson) != TYPE_ARRAY:
		return []
	# Filter to dictionary entries only. This avoids mutating while iterating.
	var messages = []
	for msg in oaimsgjson:
		if msg is Dictionary:
			messages.append(msg)
	var NEWCONVO = []
	var image_detail_map = {"high": 0, "low": 1, "auto": 2}
	var i = 0
	while i < messages.size():
		var msg = messages[i]
		var role = msg.get("role", "")
		var msg_type = msg.get("type", "")
		if role == "system" or role == "developer":
			var sys_text = _extract_text_from_msg(msg)
			NEWCONVO.append({
				"role": "system",
				"type": "Text",
				"textContent": sys_text,
				"unpreferredTextContent": "",
				"preferredTextContent": "",
				"imageContent": "",
				"imageDetail": 0,
				"functionName": "",
				"functionParameters": [],
				"functionResults": "",
				"functionUsePreText": ""
			})
		elif role == "user":
			var content = msg.get("content")
			if content is Array:
				for piece in content:
					if piece is Dictionary and piece.get("type", "") == "text":
						NEWCONVO.append({
							"role": "user",
							"type": "Text",
							"textContent": piece.get("text", ""),
							"unpreferredTextContent": "",
							"preferredTextContent": "",
							"imageContent": "",
							"imageDetail": 0,
							"functionName": "",
							"functionParameters": [],
							"functionResults": "",
							"functionUsePreText": "",
							"userName": msg.get("name", "")
						})
					elif piece is Dictionary and piece.get("type", "") == "image_url":
						var url = piece["image_url"].get("url", "")
						var detail = image_detail_map.get(piece["image_url"].get("detail", "high"), 0)
						if url.begins_with("data:image/jpeg;base64,"):
							url = url.replace("data:image/jpeg;base64,", "")
						elif url.begins_with("data:image/png;base64,"):
							url = url.replace("data:image/png;base64,", "")
						NEWCONVO.append({
							"role": "user",
							"type": "Image",
							"textContent": "",
							"unpreferredTextContent": "",
							"preferredTextContent": "",
							"imageContent": url,
							"imageDetail": detail,
							"functionName": "",
							"functionParameters": [],
							"functionResults": "",
							"functionUsePreText": "",
							"userName": msg.get("name", "")
						})
					elif piece is String:
						NEWCONVO.append({
							"role": "user",
							"type": "Text",
							"textContent": piece,
							"unpreferredTextContent": "",
							"preferredTextContent": "",
							"imageContent": "",
							"imageDetail": 0,
							"functionName": "",
							"functionParameters": [],
							"functionResults": "",
							"functionUsePreText": "",
							"userName": msg.get("name", "")
						})
					else:
						var text = _extract_text_from_msg(msg)
						NEWCONVO.append({
							"role": "user",
							"type": "Text",
							"textContent": text,
							"unpreferredTextContent": "",
							"preferredTextContent": "",
							"imageContent": "",
							"imageDetail": 0,
							"functionName": "",
							"functionParameters": [],
							"functionResults": "",
							"functionUsePreText": "",
							"userName": msg.get("name", "")
						})
			else:
				var text = _extract_text_from_msg(msg)
				if text != "":
					NEWCONVO.append({
						"role": "user",
						"type": "Text",
						"textContent": text,
						"unpreferredTextContent": "",
						"preferredTextContent": "",
						"imageContent": "",
						"imageDetail": 0,
						"functionName": "",
						"functionParameters": [],
						"functionResults": "",
						"functionUsePreText": "",
						"userName": msg.get("name", "")
					})
		elif msg_type == "function_call":
			var call_id = msg.get("call_id", msg.get("id", ""))
			var function_name = msg.get("name", "")
			var arguments_json = msg.get("arguments", "{}")
			var arguments_dict = JSON.parse_string(arguments_json)
			if arguments_dict == null:
				arguments_dict = {}
			var function_result = ""
			if i + 1 < messages.size():
				var next_msg = messages[i + 1]
				if next_msg.get("type", "") == "function_call_output" and next_msg.get("call_id", "") == call_id:
					function_result = next_msg.get("output", "")
					i += 1
			var pretext = ""
			if NEWCONVO.size() > 0:
				var last_msg = NEWCONVO[-1]
				if last_msg.get("role", "") == "assistant" and last_msg.get("type", "") == "Text":
					pretext = last_msg.get("textContent", "")
					NEWCONVO.pop_back()
			NEWCONVO.append(_create_ft_function_call_msg(function_name, arguments_dict, function_result, pretext))
		elif role == "assistant":
			if msg.has("tool_calls") and msg["tool_calls"] and msg["tool_calls"].size() > 0:
				var call = msg["tool_calls"][0]
				var call_id = call.get("id", "")
				var function_name = call["function"].get("name", "")
				var arguments_json = call["function"].get("arguments", "{}")
				var arguments_dict = JSON.parse_string(arguments_json)
				if arguments_dict == null:
					arguments_dict = {}
				var function_result = ""
				if i + 1 < messages.size():
					var nxt = messages[i + 1]
					if nxt.get("role", "") == "tool" and nxt.get("tool_call_id", "") == call_id:
						function_result = _extract_text_from_msg(nxt)
						i += 1
				var pretext = _extract_text_from_msg(msg)
				NEWCONVO.append(_create_ft_function_call_msg(function_name, arguments_dict, function_result, pretext))
			elif msg.has("function_call") and msg["function_call"]:
				var fc = msg["function_call"]
				var function_name = fc.get("name", "")
				var arguments_json = fc.get("arguments", "{}")
				var arguments_dict = JSON.parse_string(arguments_json)
				if arguments_dict == null:
					arguments_dict = {}
				var function_result = ""
				if i + 1 < messages.size():
					var nxt2 = messages[i + 1]
					if nxt2.get("role", "") in ["function", "tool"] and nxt2.get("name", "") == function_name:
						if nxt2.get("role", "") == "tool":
							function_result = _extract_text_from_msg(nxt2)
						else:
							function_result = nxt2.get("content", "")
						i += 1
				var pretext = _extract_text_from_msg(msg)
				NEWCONVO.append(_create_ft_function_call_msg(function_name, arguments_dict, function_result, pretext))
			elif i + 1 < messages.size() and messages[i + 1].get("type", "") == "function_call":
				var fcmsg = messages[i + 1]
				var call_id2 = fcmsg.get("call_id", fcmsg.get("id", ""))
				var fname2 = fcmsg.get("name", "")
				var ajson2 = fcmsg.get("arguments", "{}")
				var adict2 = JSON.parse_string(ajson2)
				if adict2 == null:
					adict2 = {}
				var result2 = ""
				if i + 2 < messages.size():
					var outm = messages[i + 2]
					if outm.get("type", "") == "function_call_output" and outm.get("call_id", "") == call_id2:
						result2 = outm.get("output", "")
						i += 1
						i += 1
					else:
						i += 1
				else:
					i += 1
				var pretext2 = _extract_text_from_msg(msg)
				NEWCONVO.append(_create_ft_function_call_msg(fname2, adict2, result2, pretext2))
				i += 1
				continue
			else:
				var a_text = _extract_text_from_msg(msg)
				if _validate_is_json(a_text):
					NEWCONVO.append({
						"role": "assistant",
						"type": "JSON",
						"textContent": "",
						"unpreferredTextContent": "",
						"preferredTextContent": "",
						"imageContent": "",
						"imageDetail": 0,
						"functionName": "",
						"functionParameters": [],
						"functionResults": "",
						"functionUsePreText": "",
						"jsonSchemaValue": a_text
					})
				else:
					NEWCONVO.append({
						"role": "assistant",
						"type": "Text",
						"textContent": a_text,
						"unpreferredTextContent": "",
						"preferredTextContent": "",
						"imageContent": "",
						"imageDetail": 0,
						"functionName": "",
						"functionParameters": [],
						"functionResults": "",
						"functionUsePreText": ""
					})
		i += 1

	return NEWCONVO
func get_schema_by_name(name: String):
	for s in SCHEMAS:
		if s.get("name", "") == name:
			return s.get("schema", null)
	return null

func get_sanitized_schema_by_name(name: String):
	for s in SCHEMAS:
		if s.get("name", "") == name:
			return s.get("sanitizedSchema", null)
	return null


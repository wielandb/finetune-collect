extends HBoxContainer

signal compact_layout_changed(enabled: bool)

const COMPACT_LAYOUT_MIN_ASPECT_RATIO = 1.3
const MOBILE_LAYOUT_REFERENCE_WIDTH = 360.0
const MOBILE_LAYOUT_COMFORT_MULTIPLIER = 1.3
const MOBILE_LAYOUT_MIN_SCALE = 1.0
const MOBILE_LAYOUT_MAX_SCALE = 4.0
const SAVE_ACTION_SAVE_LOCAL = 0
const SAVE_ACTION_SAVE_LOCAL_AS = 1
const SAVE_ACTION_SAVE_CLOUD = 2
const SAVE_ACTION_SAVE_CLOUD_AS = 3
const LOAD_ACTION_FROM_FILE = 0
const LOAD_ACTION_FROM_CLOUD = 1
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
var CONVERSATION_ORDER = []
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
const SAVE_BUTTON_DEFAULT_ICON = preload("res://icons/save.png")
const SAVE_BUTTON_SUCCESS_ICON = preload("res://icons/content-save-check-custom.png")
const SAVE_BUTTON_SUCCESS_ICON_DURATION_SECONDS = 4.0

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
var _test_cloud_dialog_response_queue = []
var _test_cloud_request_response_queue = []
var _save_success_icon_feedback_id = 0
var _save_success_icon_feedback_duration_seconds = SAVE_BUTTON_SUCCESS_ICON_DURATION_SECONDS
var _suppress_message_update_events = false

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
	# Match tooltip (stable ID) first, then fallback to visible text.
	var wanted_value = str(string)
	for i in range(node.item_count):
		if str(node.get_item_tooltip(i)) == wanted_value:
			return i
	for i in range(node.item_count):
		if str(node.get_item_text(i)) == wanted_value:
			return i
	return -1

func _is_meta_message(message_data) -> bool:
	if not (message_data is Dictionary):
		return false
	return str(message_data.get("type", "")) == "meta" or str(message_data.get("role", "")) == "meta"

func _normalize_meta_message(message_data: Dictionary, fallback_name: String = "") -> Dictionary:
	var normalized_message = message_data.duplicate(true)
	normalized_message["role"] = "meta"
	normalized_message["type"] = "meta"
	var meta_data = normalized_message.get("metaData", {})
	if not (meta_data is Dictionary):
		meta_data = {}
	if not meta_data.has("ready"):
		meta_data["ready"] = false
	if not meta_data.has("conversationName"):
		meta_data["conversationName"] = fallback_name
	if not meta_data.has("notes"):
		meta_data["notes"] = ""
	normalized_message["metaData"] = meta_data
	return normalized_message

func _ensure_conversation_meta_message(messages_data, fallback_name: String = "") -> Array:
	var normalized_messages = []
	if messages_data is Array:
		normalized_messages = messages_data.duplicate(true)
	var meta_index = -1
	for i in range(normalized_messages.size()):
		if _is_meta_message(normalized_messages[i]):
			meta_index = i
			break
	if meta_index == -1:
		normalized_messages.insert(0, _make_meta_message(fallback_name))
		return normalized_messages
	var normalized_meta = _normalize_meta_message(normalized_messages[meta_index], fallback_name)
	if meta_index == 0:
		normalized_messages[0] = normalized_meta
		return normalized_messages
	normalized_messages.remove_at(meta_index)
	normalized_messages.insert(0, normalized_meta)
	return normalized_messages

func _normalize_all_conversations_with_meta() -> void:
	for convo_id in CONVERSATIONS.keys():
		CONVERSATIONS[convo_id] = _ensure_conversation_meta_message(CONVERSATIONS[convo_id])

func _sync_conversation_order() -> void:
	var normalized_order = []
	var seen = {}
	for raw_id in CONVERSATION_ORDER:
		var convo_id = str(raw_id).strip_edges()
		if convo_id == "":
			continue
		if seen.has(convo_id):
			continue
		if CONVERSATIONS.has(convo_id):
			normalized_order.append(convo_id)
			seen[convo_id] = true
	for raw_id in CONVERSATIONS.keys():
		var convo_id = str(raw_id).strip_edges()
		if convo_id == "":
			continue
		if seen.has(convo_id):
			continue
		normalized_order.append(convo_id)
		seen[convo_id] = true
	CONVERSATION_ORDER = normalized_order

func _extract_loaded_conversations(raw_conversations) -> Dictionary:
	var loaded_conversations = {}
	if raw_conversations is Dictionary:
		for raw_id in raw_conversations.keys():
			var convo_id = str(raw_id).strip_edges()
			if convo_id == "":
				continue
			var convo_messages = raw_conversations[raw_id]
			loaded_conversations[convo_id] = _ensure_conversation_meta_message(convo_messages)
	elif raw_conversations is Array:
		for raw_entry in raw_conversations:
			if not (raw_entry is Dictionary):
				continue
			var convo_id = str(raw_entry.get("id", "")).strip_edges()
			if convo_id == "":
				convo_id = getRandomConvoID(4)
			while loaded_conversations.has(convo_id):
				convo_id = getRandomConvoID(4)
			var convo_messages = raw_entry.get("messages", [])
			loaded_conversations[convo_id] = _ensure_conversation_meta_message(convo_messages)
	return loaded_conversations

func _apply_loaded_conversations(raw_conversations, raw_order) -> void:
	CONVERSATIONS = _extract_loaded_conversations(raw_conversations)
	_normalize_all_conversations_with_meta()
	CONVERSATION_ORDER = []
	if raw_order is Array:
		for raw_id in raw_order:
			var convo_id = str(raw_id).strip_edges()
			if convo_id == "":
				continue
			if not CONVERSATIONS.has(convo_id):
				continue
			if CONVERSATION_ORDER.has(convo_id):
				continue
			CONVERSATION_ORDER.append(convo_id)
	_sync_conversation_order()

func _set_current_conversation_after_load() -> void:
	if CONVERSATION_ORDER.size() == 0:
		CURRENT_EDITED_CONVO_IX = ""
		return
	CURRENT_EDITED_CONVO_IX = str(CONVERSATION_ORDER[CONVERSATION_ORDER.size() - 1])

func _set_message_update_suppressed(suppressed: bool) -> void:
	_suppress_message_update_events = suppressed

func is_message_update_suppressed() -> bool:
	return _suppress_message_update_events

func _extract_conversation_order_from_json_text(json_text_data: String) -> Array:
	var conversations_key_index = json_text_data.find("\"conversations\"")
	if conversations_key_index == -1:
		return []
	var object_start_index = json_text_data.find("{", conversations_key_index)
	if object_start_index == -1:
		return []
	var extracted_order = []
	var depth = 1
	var i = object_start_index + 1
	var in_string = false
	var escaped = false
	var expect_key = true
	while i < json_text_data.length() and depth > 0:
		var ch = json_text_data.substr(i, 1)
		if in_string:
			if escaped:
				escaped = false
			elif ch == "\\":
				escaped = true
			elif ch == "\"":
				in_string = false
			i += 1
			continue
		if ch == "\"":
			if depth == 1 and expect_key:
				var key_start = i + 1
				var key_end = key_start
				var key_escape = false
				while key_end < json_text_data.length():
					var key_char = json_text_data.substr(key_end, 1)
					if key_escape:
						key_escape = false
					elif key_char == "\\":
						key_escape = true
					elif key_char == "\"":
						break
					key_end += 1
				if key_end >= json_text_data.length():
					break
				var key_text = json_text_data.substr(key_start, key_end - key_start)
				if key_text != "" and not extracted_order.has(key_text):
					extracted_order.append(key_text)
				i = key_end + 1
				expect_key = false
				continue
			in_string = true
			escaped = false
			i += 1
			continue
		if ch == "{":
			depth += 1
		elif ch == "}":
			depth -= 1
		elif ch == "," and depth == 1:
			expect_key = true
		i += 1
	return extracted_order

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
		"cloudName": "",
		"imageUploadSetting": 0,
		"imageUploadServerURL": "",
		"imageUploadServerKey": ""
	}

func _build_last_project_upload_state_from_settings() -> Dictionary:
	return {
		"imageUploadSetting": int(SETTINGS.get("imageUploadSetting", 0)),
		"imageUploadServerURL": str(SETTINGS.get("imageUploadServerURL", "")).strip_edges(),
		"imageUploadServerKey": str(SETTINGS.get("imageUploadServerKey", "")).strip_edges()
	}

func _merge_last_project_upload_state(state: Dictionary) -> Dictionary:
	var merged_state = state.duplicate(true)
	var upload_state = _build_last_project_upload_state_from_settings()
	for key in upload_state.keys():
		merged_state[key] = upload_state[key]
	return merged_state

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
	_save_last_project_state(_merge_last_project_upload_state({
		"source": LAST_PROJECT_SOURCE_LOCAL,
		"path": path,
		"cloudURL": "",
		"cloudKey": "",
		"cloudName": ""
	}))

func _remember_last_open_cloud(json_data: String) -> void:
	var cloud_url = str(SETTINGS.get("projectCloudURL", "")).strip_edges()
	var cloud_key = str(SETTINGS.get("projectCloudKey", "")).strip_edges()
	var cloud_name = str(SETTINGS.get("projectCloudName", "")).strip_edges()
	save_last_project_path("")
	save_last_project_data(json_data)
	_save_last_project_state(_merge_last_project_upload_state({
		"source": LAST_PROJECT_SOURCE_CLOUD,
		"path": "",
		"cloudURL": cloud_url,
		"cloudKey": cloud_key,
		"cloudName": cloud_name
	}))

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
	var restored_upload_setting = int(state.get("imageUploadSetting", 1))
	if restored_upload_setting != 1:
		restored_upload_setting = 1
	updated_settings["imageUploadSetting"] = restored_upload_setting
	updated_settings["imageUploadServerURL"] = str(state.get("imageUploadServerURL", updated_settings.get("imageUploadServerURL", ""))).strip_edges()
	updated_settings["imageUploadServerKey"] = str(state.get("imageUploadServerKey", updated_settings.get("imageUploadServerKey", ""))).strip_edges()
	SETTINGS = updated_settings
	$Conversation/Settings/ConversationSettings.from_var(SETTINGS)
	_sync_save_load_ui_for_storage_mode()
	_configure_autosave()

func _restore_from_legacy_last_project() -> bool:
	var last_path = get_last_project_path()
	if last_path != "" and FileAccess.file_exists(last_path):
		if _load_project_from_local_path(last_path):
			_set_project_storage_mode(PROJECT_STORAGE_MODE_LOCAL)
			return true
	if load_last_project_data():
		_set_project_storage_mode(PROJECT_STORAGE_MODE_LOCAL)
		_mark_project_clean_from_current_state()
		return true
	return false

# Attempt to load the previously opened project
func load_last_project_on_start() -> void:
	# Startup defaults should always be local/file unless cloud state is explicitly restored.
	_set_project_storage_mode(PROJECT_STORAGE_MODE_LOCAL)
	var state = _load_last_project_state()
	var source = str(state.get("source", LAST_PROJECT_SOURCE_NONE))
	if source == LAST_PROJECT_SOURCE_LOCAL:
		var local_path = str(state.get("path", "")).strip_edges()
		if local_path != "" and _load_project_from_local_path(local_path):
			_set_project_storage_mode(PROJECT_STORAGE_MODE_LOCAL)
			return
		if load_last_project_data():
			_set_project_storage_mode(PROJECT_STORAGE_MODE_LOCAL)
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

func _queue_test_cloud_dialog_response(response: Dictionary) -> void:
	_test_cloud_dialog_response_queue.append(response.duplicate(true))

func _queue_test_cloud_request_response(response: Dictionary) -> void:
	_test_cloud_request_response_queue.append(response.duplicate(true))

func _get_default_save_action() -> int:
	if _is_cloud_storage_enabled():
		return SAVE_ACTION_SAVE_CLOUD
	return SAVE_ACTION_SAVE_LOCAL

func _get_default_load_action() -> int:
	if _is_cloud_storage_enabled():
		return LOAD_ACTION_FROM_CLOUD
	return LOAD_ACTION_FROM_FILE

func _configure_action_option_button(option_button: OptionButton) -> void:
	option_button.fit_to_longest_item = false
	option_button.clip_text = true
	option_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _set_project_storage_mode(mode: int) -> void:
	SETTINGS["projectStorageMode"] = mode
	var settings_ui = $Conversation/Settings/ConversationSettings
	var mode_button = settings_ui.get_node_or_null("VBoxContainer/ProjectStorageModeContainer/ProjectStorageModeOptionButton")
	if mode_button is OptionButton:
		mode_button.select(mode)
	if settings_ui.has_method("_apply_project_storage_mode_ui"):
		settings_ui.call("_apply_project_storage_mode_ui")
	_sync_save_load_ui_for_storage_mode()
	_configure_autosave()

func _apply_cloud_target_settings(url: String, key: String, project_id: String) -> void:
	var cloud_url = url.strip_edges()
	var cloud_key = key.strip_edges()
	var cloud_project_id = project_id.strip_edges()
	SETTINGS["projectCloudURL"] = cloud_url
	SETTINGS["projectCloudKey"] = cloud_key
	SETTINGS["projectCloudName"] = cloud_project_id
	var settings_ui = $Conversation/Settings/ConversationSettings
	var cloud_url_edit = settings_ui.get_node_or_null("VBoxContainer/ProjectCloudURLContainer/ProjectCloudURLEdit")
	if cloud_url_edit is LineEdit:
		cloud_url_edit.text = cloud_url
	var cloud_key_edit = settings_ui.get_node_or_null("VBoxContainer/ProjectCloudKeyContainer/ProjectCloudKeyEdit")
	if cloud_key_edit is LineEdit:
		cloud_key_edit.text = cloud_key
	var cloud_name_edit = settings_ui.get_node_or_null("VBoxContainer/ProjectCloudNameContainer/ProjectCloudNameEdit")
	if cloud_name_edit is LineEdit:
		cloud_name_edit.text = cloud_project_id

func _build_cloud_target_prefill() -> Dictionary:
	return {
		"url": str(SETTINGS.get("projectCloudURL", "")).strip_edges(),
		"key": str(SETTINGS.get("projectCloudKey", "")).strip_edges(),
		"project_id": str(SETTINGS.get("projectCloudName", "")).strip_edges()
	}

func _prepare_cloud_target_for_save(force_prompt: bool) -> bool:
	var prefill = _build_cloud_target_prefill()
	var should_prompt = force_prompt or str(prefill.get("project_id", "")) == ""
	if not should_prompt:
		return true
	var response = await _request_cloud_target_dialog("save", prefill)
	if not bool(response.get("confirmed", false)):
		return false
	_apply_cloud_target_settings(
		str(response.get("url", "")),
		str(response.get("key", "")),
		str(response.get("project_id", ""))
	)
	return true

func _prepare_cloud_target_for_load() -> bool:
	var response = await _request_cloud_target_dialog("load", _build_cloud_target_prefill())
	if not bool(response.get("confirmed", false)):
		return false
	_apply_cloud_target_settings(
		str(response.get("url", "")),
		str(response.get("key", "")),
		str(response.get("project_id", ""))
	)
	return true

func _request_cloud_target_dialog(context: String, prefill: Dictionary) -> Dictionary:
	if _test_cloud_dialog_response_queue.size() > 0:
		var queued = _test_cloud_dialog_response_queue.pop_front()
		if typeof(queued) == TYPE_DICTIONARY:
			return {
				"confirmed": bool(queued.get("confirmed", false)),
				"url": str(queued.get("url", prefill.get("url", ""))).strip_edges(),
				"key": str(queued.get("key", prefill.get("key", ""))).strip_edges(),
				"project_id": str(queued.get("project_id", prefill.get("project_id", ""))).strip_edges()
			}
	if DisplayServer.get_name().to_lower() == "headless":
		return {
			"confirmed": false,
			"url": str(prefill.get("url", "")).strip_edges(),
			"key": str(prefill.get("key", "")).strip_edges(),
			"project_id": str(prefill.get("project_id", "")).strip_edges()
		}
	var dialog = ConfirmationDialog.new()
	var is_load_dialog = context == "load"
	if is_load_dialog:
		dialog.title = tr("FINETUNE_CLOUD_DIALOG_TITLE_LOAD")
		dialog.get_ok_button().text = tr("FINETUNE_CLOUD_DIALOG_CONFIRM_LOAD")
	else:
		dialog.title = tr("FINETUNE_CLOUD_DIALOG_TITLE_SAVE")
		dialog.get_ok_button().text = tr("FINETUNE_CLOUD_DIALOG_CONFIRM_SAVE")
	dialog.get_cancel_button().text = tr("GENERIC_CANCEL")
	add_child(dialog)
	var form = GridContainer.new()
	form.columns = 2
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog.add_child(form)
	var url_label = Label.new()
	url_label.text = tr("FINETUNE_CLOUD_DIALOG_URL")
	form.add_child(url_label)
	var url_edit = LineEdit.new()
	url_edit.text = str(prefill.get("url", ""))
	url_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(url_edit)
	var key_label = Label.new()
	key_label.text = tr("FINETUNE_CLOUD_DIALOG_API_KEY")
	form.add_child(key_label)
	var key_edit = LineEdit.new()
	key_edit.text = str(prefill.get("key", ""))
	key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_edit.secret = true
	form.add_child(key_edit)
	var project_id_label = Label.new()
	project_id_label.text = tr("FINETUNE_CLOUD_DIALOG_PROJECT_ID")
	form.add_child(project_id_label)
	var project_id_edit = LineEdit.new()
	project_id_edit.text = str(prefill.get("project_id", ""))
	project_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(project_id_edit)
	var state = {
		"done": false,
		"confirmed": false
	}
	dialog.confirmed.connect(func() -> void:
		state["done"] = true
		state["confirmed"] = true
	)
	var on_cancel = func() -> void:
		if bool(state.get("done", false)):
			return
		state["done"] = true
	dialog.canceled.connect(on_cancel)
	dialog.close_requested.connect(on_cancel)
	dialog.popup_centered(Vector2i(700, 280))
	while not bool(state.get("done", false)):
		await get_tree().process_frame
	var result = {
		"confirmed": bool(state.get("confirmed", false)),
		"url": str(prefill.get("url", "")).strip_edges(),
		"key": str(prefill.get("key", "")).strip_edges(),
		"project_id": str(prefill.get("project_id", "")).strip_edges()
	}
	if bool(state.get("confirmed", false)):
		result["url"] = url_edit.text.strip_edges()
		result["key"] = key_edit.text.strip_edges()
		result["project_id"] = project_id_edit.text.strip_edges()
	dialog.queue_free()
	return result

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
			_set_project_storage_mode(PROJECT_STORAGE_MODE_CLOUD)
			save_result = PRE_ACTION_SAVE_SUCCESS
	else:
		if RUNTIME["filepath"] != "":
			if _save_local_for_platform(SAVE_ACTION_SAVE_LOCAL, false):
				_set_project_storage_mode(PROJECT_STORAGE_MODE_LOCAL)
				save_result = PRE_ACTION_SAVE_SUCCESS
		else:
			_save_dialog_for_unsaved_guard_active = true
			$VBoxContainer/SaveControls/SaveBtn/SaveFileDialog.visible = true
			save_result = PRE_ACTION_SAVE_WAITING_FOR_DIALOG
	_save_in_progress = false
	if save_result == PRE_ACTION_SAVE_SUCCESS:
		_show_save_success_icon_feedback()
	return save_result

func _reset_project_to_defaults(clear_last_project_memory: bool = true) -> void:
	RUNTIME["filepath"] = ""
	FINETUNEDATA = {}
	FUNCTIONS = []
	CONVERSATIONS = {}
	CONVERSATION_ORDER = []
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
	var load_btn = $VBoxContainer/LoadControls/LoadBtn
	if _is_cloud_storage_enabled():
		save_btn.text = tr("FINETUNE_SAVE_CLOUD")
		load_btn.text = tr("FINETUNE_LOAD_CLOUD")
	else:
		save_btn.text = tr("FINETUNE_SAVE")
		load_btn.text = tr("FINETUNE_LOAD")
	var save_mode_btn = $VBoxContainer/SaveControls/SaveModeBtn
	save_mode_btn.clear()
	_configure_action_option_button(save_mode_btn)
	save_mode_btn.add_item(tr("GENERIC_SAVE"), SAVE_ACTION_SAVE_LOCAL)
	save_mode_btn.add_item(tr("GENERIC_SAVE_AS"), SAVE_ACTION_SAVE_LOCAL_AS)
	save_mode_btn.add_item(tr("FINETUNE_SAVE_CLOUD"), SAVE_ACTION_SAVE_CLOUD)
	save_mode_btn.add_item(tr("FINETUNE_SAVE_CLOUD_AS"), SAVE_ACTION_SAVE_CLOUD_AS)
	save_mode_btn.select(-1)
	save_mode_btn.disabled = false
	var load_mode_btn = $VBoxContainer/LoadControls/LoadModeBtn
	load_mode_btn.clear()
	_configure_action_option_button(load_mode_btn)
	load_mode_btn.add_item(tr("FINETUNE_LOAD_FROM_FILE"), LOAD_ACTION_FROM_FILE)
	load_mode_btn.add_item(tr("FINETUNE_LOAD_FROM_CLOUD"), LOAD_ACTION_FROM_CLOUD)
	load_mode_btn.select(-1)
	load_mode_btn.disabled = false

func _show_save_success_icon_feedback() -> void:
	if not is_inside_tree():
		return
	var save_btn = get_node_or_null("VBoxContainer/SaveControls/SaveBtn")
	if not (save_btn is Button):
		return
	_save_success_icon_feedback_id += 1
	var current_feedback_id = _save_success_icon_feedback_id
	save_btn.icon = SAVE_BUTTON_SUCCESS_ICON
	var wait_duration = float(_save_success_icon_feedback_duration_seconds)
	if wait_duration < 0.01:
		wait_duration = 0.01
	await get_tree().create_timer(wait_duration).timeout
	if not is_inside_tree():
		return
	if current_feedback_id != _save_success_icon_feedback_id:
		return
	save_btn.icon = SAVE_BUTTON_DEFAULT_ICON

func _setup_save_mode_option_button() -> void:
	var save_mode_btn = $VBoxContainer/SaveControls/SaveModeBtn
	if not save_mode_btn.is_connected("item_selected", Callable(self, "_on_save_mode_btn_item_selected")):
		save_mode_btn.item_selected.connect(_on_save_mode_btn_item_selected)
	_sync_save_load_ui_for_storage_mode()

func _setup_load_mode_option_button() -> void:
	var load_mode_btn = $VBoxContainer/LoadControls/LoadModeBtn
	if not load_mode_btn.is_connected("item_selected", Callable(self, "_on_load_mode_btn_item_selected")):
		load_mode_btn.item_selected.connect(_on_load_mode_btn_item_selected)

func _on_save_mode_btn_item_selected(index: int) -> void:
	var save_mode_btn = $VBoxContainer/SaveControls/SaveModeBtn
	var selected_action = save_mode_btn.get_item_id(index)
	await _run_selected_save_action(selected_action)
	save_mode_btn.select(-1)

func _on_load_mode_btn_item_selected(index: int) -> void:
	var load_mode_btn = $VBoxContainer/LoadControls/LoadModeBtn
	var selected_action = load_mode_btn.get_item_id(index)
	await _run_selected_load_action(selected_action)
	load_mode_btn.select(-1)

func _collect_current_state_for_save() -> void:
	save_current_conversation()
	update_functions_internal()
	update_settings_internal()
	update_graders_internal()
	update_schemas_internal()

func _save_local_for_platform(selected_action: int, allow_save_as_dialog: bool) -> bool:
	match OS.get_name():
		"Windows", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD", "Android","macOS":
			if selected_action == SAVE_ACTION_SAVE_LOCAL_AS:
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
	if _test_cloud_request_response_queue.size() > 0:
		var queued = _test_cloud_request_response_queue.pop_front()
		if typeof(queued) == TYPE_DICTIONARY:
			return queued.duplicate(true)
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
	var save_success = false
	if _is_cloud_storage_enabled():
		save_success = await _save_project_to_cloud()
	else:
		if RUNTIME["filepath"] == "":
			print("Autosave skipped (local mode without filepath).")
		else:
			save_success = _save_local_for_platform(SAVE_ACTION_SAVE_LOCAL, false)
	if save_success:
		_show_save_success_icon_feedback()
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
	match selected_action:
		SAVE_ACTION_SAVE_LOCAL:
			save_success = _save_local_for_platform(SAVE_ACTION_SAVE_LOCAL, true)
			if save_success:
				_set_project_storage_mode(PROJECT_STORAGE_MODE_LOCAL)
		SAVE_ACTION_SAVE_LOCAL_AS:
			save_success = _save_local_for_platform(SAVE_ACTION_SAVE_LOCAL_AS, true)
		SAVE_ACTION_SAVE_CLOUD:
			if await _prepare_cloud_target_for_save(false):
				save_success = await _save_project_to_cloud()
				if save_success:
					_set_project_storage_mode(PROJECT_STORAGE_MODE_CLOUD)
		SAVE_ACTION_SAVE_CLOUD_AS:
			if await _prepare_cloud_target_for_save(true):
				save_success = await _save_project_to_cloud()
				if save_success:
					_set_project_storage_mode(PROJECT_STORAGE_MODE_CLOUD)
	_save_in_progress = false
	if save_success:
		_show_save_success_icon_feedback()
	return save_success

func _run_selected_load_action(selected_action: int) -> bool:
	update_settings_internal()
	match selected_action:
		LOAD_ACTION_FROM_CLOUD:
			if not await _prepare_cloud_target_for_load():
				return false
			await _request_destructive_action({"kind": ACTION_KIND_LOAD_CLOUD})
			return true
		LOAD_ACTION_FROM_FILE:
			match OS.get_name():
				"Windows", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD", "Android","macOS":
					$VBoxContainer/LoadControls/LoadBtn/FileDialog.visible = true
				"Web":
					file_access_web.open(".json")
			return true
	return false

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
	_setup_load_mode_option_button()
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
		_run_selected_save_action(_get_default_save_action())
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
	await _run_selected_save_action(_get_default_save_action())

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
	var previous_suppress_state = _suppress_message_update_events
	_set_message_update_suppressed(true)
	for message in $Conversation/Messages/MessagesList/MessagesListContainer.get_children():
		if message.is_in_group("message"):
			message.queue_free()
	CURRENT_EDITED_CONVO_IX = next_conversation_ix
	print("IX:")
	print(CURRENT_EDITED_CONVO_IX)
	DisplayServer.window_set_title("finetune-collect - Current conversation: " + CURRENT_EDITED_CONVO_IX)
	if not CONVERSATIONS.has(CURRENT_EDITED_CONVO_IX):
		CONVERSATIONS[CURRENT_EDITED_CONVO_IX] = _ensure_conversation_meta_message([])
		if not CONVERSATION_ORDER.has(CURRENT_EDITED_CONVO_IX):
			CONVERSATION_ORDER.append(CURRENT_EDITED_CONVO_IX)
		_sync_conversation_order()
	CONVERSATIONS[str(CURRENT_EDITED_CONVO_IX)] = _ensure_conversation_meta_message(CONVERSATIONS[str(CURRENT_EDITED_CONVO_IX)])
	$Conversation/Messages/MessagesList.from_var(CONVERSATIONS[str(CURRENT_EDITED_CONVO_IX)])
	_set_message_update_suppressed(previous_suppress_state)
	$Conversation/Graders/GradersList.update_from_last_message()

func save_current_conversation_to_conversations_at_index(ix: int):
	# THERE SHOULD BE NO REASON TO USE THIS FUNCTION
	var convo_id = str(ix)
	if convo_id == "":
		return
	CONVERSATIONS[convo_id] = _ensure_conversation_meta_message($Conversation/Messages/MessagesList.to_var())
	if not CONVERSATION_ORDER.has(convo_id):
		CONVERSATION_ORDER.append(convo_id)
	_sync_conversation_order()

func save_current_conversation():
	if CURRENT_EDITED_CONVO_IX == "":
		return
	CONVERSATIONS[CURRENT_EDITED_CONVO_IX] = _ensure_conversation_meta_message($Conversation/Messages/MessagesList.to_var())
	if not CONVERSATION_ORDER.has(CURRENT_EDITED_CONVO_IX):
		CONVERSATION_ORDER.append(CURRENT_EDITED_CONVO_IX)
	_sync_conversation_order()

func _on_load_btn_pressed() -> void:
	await _run_selected_load_action(_get_default_load_action())

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
	if not (thisconvo is Array):
		return true
	if thisconvo.size() == 0:
		return true
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
	_sync_conversation_order()
	$VBoxContainer/ConversationsList.clear()
	var numberIx = -1
	for i in CONVERSATION_ORDER:
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


func create_new_conversation(msgs: Array = []):
	# Generate a new ConvoID
	var newID = getRandomConvoID(4)
	CONVERSATIONS[newID] = _ensure_conversation_meta_message(msgs)
	CONVERSATION_ORDER.append(newID)
	_sync_conversation_order()
	# Update everything that needs to be updated
	refresh_conversations_list()
	return newID

func _duplicate_conversation_by_id(source_convo_id: String) -> String:
	var source_id = str(source_convo_id).strip_edges()
	if source_id == "":
		return ""
	if not CONVERSATIONS.has(source_id):
		return ""
	var new_convo_id = getRandomConvoID(4)
	var source_messages = CONVERSATIONS[source_id]
	if source_messages is Array:
		CONVERSATIONS[new_convo_id] = _ensure_conversation_meta_message(source_messages)
	else:
		CONVERSATIONS[new_convo_id] = _ensure_conversation_meta_message([])
	CONVERSATION_ORDER.append(new_convo_id)
	_sync_conversation_order()
	refresh_conversations_list()
	return new_convo_id

func append_to_conversation(convoid, msg={}):
	if convoid in CONVERSATIONS:
		CONVERSATIONS[convoid] = _ensure_conversation_meta_message(CONVERSATIONS[convoid])
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
	_sync_conversation_order()
	FINETUNEDATA = {}
	FINETUNEDATA["functions"] = FUNCTIONS
	FINETUNEDATA["conversations"] = CONVERSATIONS
	FINETUNEDATA["conversationOrder"] = CONVERSATION_ORDER
	FINETUNEDATA["settings"] = SETTINGS
	FINETUNEDATA["graders"] = GRADERS
	FINETUNEDATA["schemas"] = SCHEMAS
	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file:
		file.store_var(FINETUNEDATA)
		file.close()
	else:
		print("file open failed")

func _apply_loaded_project_data(loaded_data: Dictionary, conversation_order_override: Array = []) -> void:
	$Conversation/Functions/FunctionsList.delete_all_functions_from_UI()
	$Conversation/Messages/MessagesList.delete_all_messages_from_UI()
	FINETUNEDATA = loaded_data
	var loaded_functions = FINETUNEDATA.get("functions", [])
	if loaded_functions is Array:
		FUNCTIONS = loaded_functions
	else:
		FUNCTIONS = []
	var loaded_settings = FINETUNEDATA.get("settings", {})
	if loaded_settings is Dictionary:
		SETTINGS = loaded_settings
	else:
		SETTINGS = {}
	var loaded_graders = FINETUNEDATA.get("graders", [])
	if loaded_graders is Array:
		GRADERS = loaded_graders
	else:
		GRADERS = []
	var loaded_schemas = FINETUNEDATA.get("schemas", [])
	if loaded_schemas is Array:
		SCHEMAS = loaded_schemas
	else:
		SCHEMAS = []
	var loaded_conversation_order = FINETUNEDATA.get("conversationOrder", [])
	if conversation_order_override.size() > 0:
		loaded_conversation_order = conversation_order_override
	_apply_loaded_conversations(FINETUNEDATA.get("conversations", {}), loaded_conversation_order)
	_set_current_conversation_after_load()
	$Conversation/Settings/ConversationSettings.from_var(SETTINGS)
	_sync_save_load_ui_for_storage_mode()
	_configure_autosave()
	$Conversation/Functions/FunctionsList.from_var(FUNCTIONS)
	$Conversation/Graders/GradersList.from_var(GRADERS)
	$Conversation/Schemas/SchemasList.from_var(SCHEMAS)
	refresh_conversations_list()
	var selected_index = selectionStringToIndex($VBoxContainer/ConversationsList, CURRENT_EDITED_CONVO_IX)
	if selected_index >= 0:
		$VBoxContainer/ConversationsList.select(selected_index)
		_on_item_list_item_selected(selected_index, false)
	else:
		$Conversation/Messages/MessagesList.delete_all_messages_from_UI()
	call_deferred("_convert_base64_images_after_load")
	
func load_from_binary(filename):
	if not FileAccess.file_exists(filename):
		print("file not found")
		return
	print("save file found")
	var file = FileAccess.open(filename, FileAccess.READ)
	var loaded_data = file.get_var()
	file.close()
	if not (loaded_data is Dictionary):
		push_error("Could not load binary project: Invalid project data.")
		return
	_apply_loaded_project_data(loaded_data)

func load_from_json_data(jsondata: String):
	var json_as_dict = JSON.parse_string(jsondata)
	print(json_as_dict)
	if not (json_as_dict is Dictionary):
		push_error("Could not load JSON project: Invalid project data.")
		return
	var conversation_order_override = []
	if not json_as_dict.has("conversationOrder"):
		conversation_order_override = _extract_conversation_order_from_json_text(jsondata)
	else:
		var loaded_order = json_as_dict.get("conversationOrder", [])
		if loaded_order is Array and loaded_order.size() == 0:
			conversation_order_override = _extract_conversation_order_from_json_text(jsondata)
	_apply_loaded_project_data(json_as_dict, conversation_order_override)

func make_save_json_data():
	_sync_conversation_order()
	FINETUNEDATA = {}
	FINETUNEDATA["functions"] = FUNCTIONS
	FINETUNEDATA["conversations"] = CONVERSATIONS
	FINETUNEDATA["conversationOrder"] = CONVERSATION_ORDER
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
		_set_project_storage_mode(PROJECT_STORAGE_MODE_LOCAL)
		_show_save_success_icon_feedback()
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
	CONVERSATION_ORDER.erase(ixStr)
	_sync_conversation_order()
	# If we were currently editing this conversation, unload it
	if CURRENT_EDITED_CONVO_IX == ixStr:
		for message in $Conversation/Messages/MessagesList/MessagesListContainer.get_children():
			if message.is_in_group("message"):
				message.queue_free()
		if CONVERSATION_ORDER.size() > 0:
			CURRENT_EDITED_CONVO_IX = str(CONVERSATION_ORDER[0])
			$Conversation/Messages/MessagesList.from_var(CONVERSATIONS[CURRENT_EDITED_CONVO_IX])
		else:
			CURRENT_EDITED_CONVO_IX = ""
	refresh_conversations_list()
	if CURRENT_EDITED_CONVO_IX != "":
		var selected_index = selectionStringToIndex($VBoxContainer/ConversationsList, CURRENT_EDITED_CONVO_IX)
		if selected_index >= 0:
			$VBoxContainer/ConversationsList.select(selected_index)
	print(CONVERSATIONS)

func get_ItemList_selected_Item_index(node: ItemList) -> int:
	for i in range(node.item_count):
		if node.is_selected(i):
			return i
	return -1

func _on_conversations_list_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == 4194312:
			var selected_index = get_ItemList_selected_Item_index($VBoxContainer/ConversationsList)
			if selected_index >= 0:
				var convo_id = str($VBoxContainer/ConversationsList.get_item_tooltip(selected_index))
				delete_conversation(convo_id)
		if event.pressed and Input.is_key_pressed(KEY_CTRL) and event.keycode == KEY_D:
			var selected_index = get_ItemList_selected_Item_index($VBoxContainer/ConversationsList)
			if selected_index >= 0:
				var source_id = str($VBoxContainer/ConversationsList.get_item_tooltip(selected_index))
				var duplicated_id = _duplicate_conversation_by_id(source_id)
				if duplicated_id != "":
					var duplicated_index = selectionStringToIndex($VBoxContainer/ConversationsList, duplicated_id)
					if duplicated_index >= 0:
						$VBoxContainer/ConversationsList.select(duplicated_index)
					

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
	_sync_conversation_order()
	for convokey in CONVERSATION_ORDER:
		if not allconversations.has(convokey):
			continue
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

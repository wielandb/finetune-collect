extends SceneTree

var tests_run = 0
var tests_failed = 0

func _check(condition: bool, message: String) -> void:
	tests_run += 1
	if not condition:
		tests_failed += 1
		push_error(message)

func _clear_last_project_files() -> void:
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

func _create_scene():
	var scene = load("res://scenes/fine_tune.tscn").instantiate()
	get_root().add_child(scene)
	await create_timer(0.3).timeout
	return scene

func _destroy_scene(scene) -> void:
	if scene != null:
		scene.queue_free()
		await process_frame
		await process_frame

func _set_conversation_display_name(scene, convo_id: String, display_name: String) -> void:
	if not scene.CONVERSATIONS.has(convo_id):
		return
	var messages = scene.CONVERSATIONS[convo_id]
	if not (messages is Array):
		messages = []
	var meta_index = -1
	for i in range(messages.size()):
		var msg = messages[i]
		if msg is Dictionary and str(msg.get("type", "")) == "meta":
			meta_index = i
			break
	if meta_index == -1:
		messages.insert(0, {
			"role": "meta",
			"type": "meta",
			"metaData": {
				"ready": false,
				"conversationName": display_name,
				"notes": ""
			}
		})
	else:
		var meta_message = messages[meta_index]
		var meta_data = meta_message.get("metaData", {})
		if not (meta_data is Dictionary):
			meta_data = {}
		meta_data["conversationName"] = display_name
		if not meta_data.has("ready"):
			meta_data["ready"] = false
		if not meta_data.has("notes"):
			meta_data["notes"] = ""
		meta_message["metaData"] = meta_data
		messages[meta_index] = meta_message
	scene.CONVERSATIONS[convo_id] = messages

func _set_conversation_ready(scene, convo_id: String, ready: bool) -> void:
	if not scene.CONVERSATIONS.has(convo_id):
		return
	var messages = scene.CONVERSATIONS[convo_id]
	if not (messages is Array):
		return
	for i in range(messages.size()):
		var msg = messages[i]
		if msg is Dictionary and str(msg.get("type", "")) == "meta":
			var meta_data = msg.get("metaData", {})
			if not (meta_data is Dictionary):
				meta_data = {}
			meta_data["ready"] = ready
			if not meta_data.has("conversationName"):
				meta_data["conversationName"] = ""
			if not meta_data.has("notes"):
				meta_data["notes"] = ""
			msg["metaData"] = meta_data
			messages[i] = msg
			scene.CONVERSATIONS[convo_id] = messages
			return

func _get_conversation_meta_data(scene, convo_id: String) -> Dictionary:
	if not scene.CONVERSATIONS.has(convo_id):
		return {}
	var messages = scene.CONVERSATIONS[convo_id]
	if not (messages is Array):
		return {}
	for msg in messages:
		if msg is Dictionary and str(msg.get("type", "")) == "meta":
			var meta_data = msg.get("metaData", {})
			if meta_data is Dictionary:
				return meta_data
	return {}

func _conversation_has_meta(scene, convo_id: String) -> bool:
	if not scene.CONVERSATIONS.has(convo_id):
		return false
	var messages = scene.CONVERSATIONS[convo_id]
	if not (messages is Array) or messages.size() == 0:
		return false
	var first_message = messages[0]
	if not (first_message is Dictionary):
		return false
	return str(first_message.get("type", "")) == "meta" and str(first_message.get("role", "")) == "meta"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_clear_last_project_files()
	var scene = await _create_scene()
	var id_a = scene.create_new_conversation([
		{"role": "meta", "type": "meta", "metaData": {"ready": false, "conversationName": "Order A", "notes": ""}}
	])
	var id_b = scene.create_new_conversation([
		{"role": "meta", "type": "meta", "metaData": {"ready": false, "conversationName": "Order B", "notes": ""}}
	])
	var id_c = scene.create_new_conversation([
		{"role": "meta", "type": "meta", "metaData": {"ready": false, "conversationName": "Order C", "notes": ""}}
	])
	var id_without_meta = scene.create_new_conversation([
		{"role": "user", "type": "Text", "textContent": "no meta initially"}
	])
	_check(_conversation_has_meta(scene, id_without_meta), "new conversations should auto-insert a meta message at index 0")
	scene.refresh_conversations_list()
	var order = scene.CONVERSATION_ORDER.duplicate()
	_check(order.size() >= 4, "conversation order should contain all created conversations")
	if order.size() >= 4:
		_check(str(order[order.size() - 4]) == id_a, "first created conversation should keep insertion order")
		_check(str(order[order.size() - 3]) == id_b, "second created conversation should keep insertion order")
		_check(str(order[order.size() - 2]) == id_c, "third created conversation should keep insertion order")
		_check(str(order[order.size() - 1]) == id_without_meta, "new conversations should append at the bottom")
	var list_node = scene.get_node("VBoxContainer/ConversationsList")
	_check(list_node.item_count == order.size(), "sidebar count should match conversation order count")
	if list_node.item_count > 0:
		_check(str(list_node.get_item_tooltip(list_node.item_count - 1)) == str(order[order.size() - 1]), "last sidebar entry should match last ordered conversation")

	var snapshot = scene.make_save_json_data()
	var parsed_snapshot = JSON.parse_string(snapshot)
	_check(parsed_snapshot is Dictionary, "saved snapshot should be a dictionary")
	if parsed_snapshot is Dictionary:
		_check(parsed_snapshot.has("conversationOrder"), "saved snapshot should include conversation order")
		var saved_order = parsed_snapshot.get("conversationOrder", [])
		_check(saved_order is Array, "conversationOrder should be an array")
		if saved_order is Array:
			_check(saved_order.size() == order.size(), "saved order size should match runtime order")
			for i in range(min(saved_order.size(), order.size())):
				_check(str(saved_order[i]) == str(order[i]), "saved order should preserve runtime insertion order")

	_clear_last_project_files()
	var restored_scene = await _create_scene()
	restored_scene.load_from_json_data(snapshot)
	var restored_order = restored_scene.CONVERSATION_ORDER
	var restored_list_node = restored_scene.get_node("VBoxContainer/ConversationsList")
	_check(restored_order.size() == order.size(), "restored order size should match saved order")
	_check(restored_list_node.item_count == restored_order.size(), "restored sidebar should match restored order size")
	for i in range(min(restored_order.size(), order.size())):
		_check(str(restored_order[i]) == str(order[i]), "restored order should keep saved order")
		_check(str(restored_list_node.get_item_tooltip(i)) == str(restored_order[i]), "restored sidebar entry should use ordered conversation id")

	if restored_order.size() >= 2:
		var first_id = str(restored_order[0])
		var second_id = str(restored_order[1])
		_set_conversation_display_name(restored_scene, first_id, second_id)
		restored_scene.refresh_conversations_list()
		var selected_index_for_second_id = restored_scene.selectionStringToIndex(restored_list_node, second_id)
		_check(selected_index_for_second_id >= 0, "selection by id should return an index")
		if selected_index_for_second_id >= 0:
			_check(str(restored_list_node.get_item_tooltip(selected_index_for_second_id)) == second_id, "selection by id should resolve tooltip id, not conflicting display text")

		_set_conversation_display_name(restored_scene, first_id, "Ready Source")
		_set_conversation_display_name(restored_scene, second_id, "Ready Target")
		_set_conversation_ready(restored_scene, first_id, true)
		_set_conversation_ready(restored_scene, second_id, false)
		restored_scene.refresh_conversations_list()
		var first_index = restored_scene.selectionStringToIndex(restored_list_node, first_id)
		var second_index = restored_scene.selectionStringToIndex(restored_list_node, second_id)
		_check(first_index >= 0 and second_index >= 0, "both conversations should be selectable by id before switch test")
		if first_index >= 0 and second_index >= 0:
			restored_scene._on_item_list_item_selected(first_index, false)
			restored_scene._on_item_list_item_selected(second_index)
			var second_meta_after_switch = _get_conversation_meta_data(restored_scene, second_id)
			_check(str(second_meta_after_switch.get("conversationName", "")) == "Ready Target", "switching should not overwrite selected conversation name with previous one")
			_check(bool(second_meta_after_switch.get("ready", false)) == false, "switching should not overwrite selected conversation ready flag with previous one")

		_set_conversation_display_name(restored_scene, first_id, "Source Name")
		var duplicated_id = restored_scene._duplicate_conversation_by_id(first_id)
		_check(duplicated_id != "", "duplicating a valid conversation should return a new id")
		if duplicated_id != "":
			_check(str(restored_scene.CONVERSATION_ORDER[restored_scene.CONVERSATION_ORDER.size() - 1]) == duplicated_id, "duplicated conversation should append at bottom")
			_set_conversation_display_name(restored_scene, duplicated_id, "Duplicated Name")
			_check(restored_scene.get_conversation_name_or_false(first_id) == "Source Name", "duplicated conversation should not mutate source conversation name")

	if restored_order.size() >= 2:
		var target_id = str(restored_order[restored_order.size() - 1])
		var helper_id = str(restored_order[restored_order.size() - 2])
		restored_scene.CONVERSATIONS[target_id] = [
			{"role": "user", "type": "Text", "textContent": "manually stripped meta"}
		]
		restored_scene.refresh_conversations_list()
		restored_scene._select_conversation_by_id(helper_id)
		restored_scene._select_conversation_by_id(target_id)
		_check(_conversation_has_meta(restored_scene, target_id), "switching to a conversation should repair missing meta message")
		var repaired_meta = _get_conversation_meta_data(restored_scene, target_id)
		_check(repaired_meta.has("ready"), "repaired meta should include ready flag")
		_check(repaired_meta.has("conversationName"), "repaired meta should include conversationName")
		_check(repaired_meta.has("notes"), "repaired meta should include notes")

	await _destroy_scene(scene)
	await _destroy_scene(restored_scene)
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)

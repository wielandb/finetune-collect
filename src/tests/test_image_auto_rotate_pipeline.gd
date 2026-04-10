extends SceneTree

const ImageOrientationUtils = preload("res://image_orientation_utils.gd")

var tests_run = 0
var tests_failed = 0

func _check(condition: bool, message: String) -> void:
	tests_run += 1
	if not condition:
		tests_failed += 1
		push_error(message)

func _assert_eq(actual, expected, message: String) -> void:
	_check(actual == expected, "%s | expected=%s actual=%s" % [message, str(expected), str(actual)])

func _assert_true(condition: bool, message: String) -> void:
	_check(condition, message)

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
	_clear_last_project_files()
	var scene = load("res://scenes/fine_tune.tscn").instantiate()
	get_root().add_child(scene)
	await create_timer(0.35).timeout
	return scene

func _destroy_scene(scene) -> void:
	if scene != null:
		scene.queue_free()
		await process_frame
		await process_frame

func _build_exif_orientation_segment(orientation: int) -> PackedByteArray:
	var clamped_orientation = clampi(int(orientation), 1, 8)
	var segment_data = PackedByteArray([
		0x45, 0x78, 0x69, 0x66, 0x00, 0x00,
		0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00,
		0x01, 0x00,
		0x12, 0x01, 0x03, 0x00,
		0x01, 0x00, 0x00, 0x00,
		0x01, 0x00, 0x00, 0x00,
		0x00, 0x00, 0x00, 0x00
	])
	segment_data[24] = clamped_orientation & 0xFF
	segment_data[25] = (clamped_orientation >> 8) & 0xFF
	var segment = PackedByteArray([0xFF, 0xE1, 0x00, 0x22])
	segment.append_array(segment_data)
	return segment

func _inject_exif_orientation_into_jpeg(raw_jpg: PackedByteArray, orientation: int) -> PackedByteArray:
	if raw_jpg.size() < 2:
		return raw_jpg
	if raw_jpg[0] != 0xFF or raw_jpg[1] != 0xD8:
		return raw_jpg
	var oriented_jpg = PackedByteArray([0xFF, 0xD8])
	oriented_jpg.append_array(_build_exif_orientation_segment(orientation))
	for i in range(2, raw_jpg.size()):
		oriented_jpg.append(raw_jpg[i])
	return oriented_jpg

func _make_jpg_base64(width: int, height: int) -> String:
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.7, 0.4, 1.0))
	return Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.92))

func _make_exif_orientation_jpg_base64(width: int, height: int, orientation: int) -> String:
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			if x < int(width / 2):
				image.set_pixel(x, y, Color(0.9, 0.2, 0.2, 1.0))
			else:
				image.set_pixel(x, y, Color(0.2, 0.2, 0.9, 1.0))
	var raw_jpg = image.save_jpg_to_buffer(0.92)
	var oriented_raw_jpg = _inject_exif_orientation_into_jpeg(raw_jpg, orientation)
	return Marshalls.raw_to_base64(oriented_raw_jpg)

func _decode_base64_size(base64_data: String) -> Vector2i:
	var payload = ImageOrientationUtils.base64_payload_from_data_uri(base64_data)
	var raw = Marshalls.base64_to_raw(payload)
	var format_hint = ImageOrientationUtils.detect_image_format_from_raw(raw)
	var image = ImageOrientationUtils.decode_image_from_buffer(raw, format_hint, "")
	if image == null:
		return Vector2i.ZERO
	return Vector2i(image.get_width(), image.get_height())

func _base_project_data_with_single_image(image_content: String, auto_rotate_mode: int, upload_mode: int, upload_url: String = "", upload_key: String = "") -> Dictionary:
	return {
		"functions": [],
		"conversations": {
			"Conv1": [
				{"role": "meta", "type": "meta"},
				{"role": "user", "type": "Image", "imageContent": image_content, "imageDetail": 0}
			]
		},
		"conversationOrder": ["Conv1"],
		"settings": {
			"useGlobalSystemMessage": false,
			"globalSystemMessage": "",
			"apikey": "",
			"apiBaseURL": "https://api.openai.com/v1",
			"modelChoice": "gpt-4o",
			"availableModels": [],
			"includeFunctions": 0,
			"finetuneType": 0,
			"exportImagesHow": 0,
			"useUserNames": false,
			"schemaEditorURL": "",
			"schemaValidatorURL": "",
			"projectStorageMode": 0,
			"projectCloudURL": "",
			"projectCloudKey": "",
			"projectCloudName": "",
			"autoSaveMode": 0,
			"imageUploadSetting": upload_mode,
			"imageAutoRotateSetting": auto_rotate_mode,
			"imageUploadServerURL": upload_url,
			"imageUploadServerKey": upload_key,
			"tokenCounterPath": "",
			"exportConvos": 0,
			"countTokensWhen": 0,
			"tokenCounts": "{}",
			"countTokensModel": 0
		},
		"graders": [],
		"schemas": []
	}

func _test_pixel_rotate_backfills_existing_base64_after_load() -> void:
	var scene = await _create_scene()
	var source_b64 = _make_exif_orientation_jpg_base64(11, 4, 6)
	var project_data = _base_project_data_with_single_image(source_b64, 2, 0)
	scene.load_from_json_data(JSON.stringify(project_data))
	await process_frame
	await process_frame
	await process_frame
	var updated_b64 = str(scene.CONVERSATIONS["Conv1"][1].get("imageContent", ""))
	_assert_true(updated_b64 != source_b64, "Backfill should rotate and rewrite existing base64 payload on load in pixel-rotate mode")
	var updated_size = _decode_base64_size(updated_b64)
	_assert_eq(updated_size.x, 4, "Backfilled base64 width should be rotated")
	_assert_eq(updated_size.y, 11, "Backfilled base64 height should be rotated")
	await _destroy_scene(scene)

func _test_pixel_rotate_happens_before_upload_for_base64_payload() -> void:
	var scene = await _create_scene()
	scene.SETTINGS["imageAutoRotateSetting"] = 2
	scene.SETTINGS["imageUploadSetting"] = 1
	scene.SETTINGS["imageUploadServerURL"] = "https://upload.test/image-upload.php"
	scene.SETTINGS["imageUploadServerKey"] = "upload_key"
	scene._reset_test_image_upload_call_count()
	scene._queue_test_image_upload_response("")
	var source_b64 = _make_exif_orientation_jpg_base64(10, 3, 6)
	scene.CONVERSATIONS["ConvRotate"] = [
		{"role": "meta", "type": "meta"},
		{"role": "user", "type": "Image", "imageContent": source_b64, "imageDetail": 0}
	]
	scene.CONVERSATION_ORDER.append("ConvRotate")
	await scene.convert_base64_images_in_conversation("ConvRotate")
	var result_b64 = str(scene.CONVERSATIONS["ConvRotate"][1].get("imageContent", ""))
	_assert_eq(scene._get_test_image_upload_call_count(), 1, "Pixel-rotate base64 should still execute upload path")
	_assert_true(result_b64 != source_b64, "Pixel rotation must happen before upload (echoed payload should already be rotated)")
	var result_size = _decode_base64_size(result_b64)
	_assert_eq(result_size.x, 3, "Uploaded payload width should reflect rotated pixels")
	_assert_eq(result_size.y, 10, "Uploaded payload height should reflect rotated pixels")
	await _destroy_scene(scene)

func _test_url_path_downloads_rotates_uploads_and_replaces_url() -> void:
	var scene = await _create_scene()
	scene.SETTINGS["imageAutoRotateSetting"] = 2
	scene.SETTINGS["imageUploadSetting"] = 1
	scene.SETTINGS["imageUploadServerURL"] = "https://upload.test/image-upload.php"
	scene.SETTINGS["imageUploadServerKey"] = "upload_key"
	scene._reset_test_image_upload_call_count()
	scene._clear_test_image_download_responses()
	var source_url = "https://source.test/oriented.jpg"
	var oriented_jpg_b64 = _make_exif_orientation_jpg_base64(9, 4, 6)
	scene._set_test_image_download_response(source_url, oriented_jpg_b64, "image/jpeg", "jpg")
	scene._queue_test_image_upload_response("https://upload.test/rotated.jpg")
	scene.CONVERSATIONS["ConvUrlRotate"] = [
		{"role": "meta", "type": "meta"},
		{"role": "user", "type": "Image", "imageContent": source_url, "imageDetail": 0}
	]
	scene.CONVERSATION_ORDER.append("ConvUrlRotate")
	await scene.convert_base64_images_in_conversation("ConvUrlRotate")
	var result_url = str(scene.CONVERSATIONS["ConvUrlRotate"][1].get("imageContent", ""))
	_assert_eq(scene._get_test_image_upload_call_count(), 1, "URL image with needed EXIF correction should be uploaded once")
	_assert_eq(result_url, "https://upload.test/rotated.jpg", "URL image should be replaced by uploaded rotated URL")
	await _destroy_scene(scene)

func _test_url_path_skips_reupload_when_no_rotation_needed() -> void:
	var scene = await _create_scene()
	scene.SETTINGS["imageAutoRotateSetting"] = 2
	scene.SETTINGS["imageUploadSetting"] = 1
	scene.SETTINGS["imageUploadServerURL"] = "https://upload.test/image-upload.php"
	scene.SETTINGS["imageUploadServerKey"] = "upload_key"
	scene._reset_test_image_upload_call_count()
	scene._clear_test_image_download_responses()
	var source_url = "https://source.test/already-correct.jpg"
	var no_exif_rotation_b64 = _make_jpg_base64(8, 5)
	scene._set_test_image_download_response(source_url, no_exif_rotation_b64, "image/jpeg", "jpg")
	scene._queue_test_image_upload_response("https://upload.test/should-not-be-used.jpg")
	scene.CONVERSATIONS["ConvUrlNoRotate"] = [
		{"role": "meta", "type": "meta"},
		{"role": "user", "type": "Image", "imageContent": source_url, "imageDetail": 0}
	]
	scene.CONVERSATION_ORDER.append("ConvUrlNoRotate")
	await scene.convert_base64_images_in_conversation("ConvUrlNoRotate")
	var result_url = str(scene.CONVERSATIONS["ConvUrlNoRotate"][1].get("imageContent", ""))
	_assert_eq(scene._get_test_image_upload_call_count(), 0, "URL image without needed EXIF correction should not trigger re-upload")
	_assert_eq(result_url, source_url, "URL image without needed EXIF correction should keep original URL")
	await _destroy_scene(scene)

func _test_url_path_upload_failure_keeps_original_url() -> void:
	var scene = await _create_scene()
	scene.SETTINGS["imageAutoRotateSetting"] = 2
	scene.SETTINGS["imageUploadSetting"] = 1
	scene.SETTINGS["imageUploadServerURL"] = "https://upload.test/image-upload.php"
	scene.SETTINGS["imageUploadServerKey"] = "upload_key"
	scene._reset_test_image_upload_call_count()
	scene._clear_test_image_download_responses()
	var source_url = "https://source.test/oriented-fallback.jpg"
	var oriented_jpg_b64 = _make_exif_orientation_jpg_base64(9, 4, 6)
	scene._set_test_image_download_response(source_url, oriented_jpg_b64, "image/jpeg", "jpg")
	scene._queue_test_image_upload_response("")
	scene.CONVERSATIONS["ConvUrlFallback"] = [
		{"role": "meta", "type": "meta"},
		{"role": "user", "type": "Image", "imageContent": source_url, "imageDetail": 0}
	]
	scene.CONVERSATION_ORDER.append("ConvUrlFallback")
	await scene.convert_base64_images_in_conversation("ConvUrlFallback")
	var result_url = str(scene.CONVERSATIONS["ConvUrlFallback"][1].get("imageContent", ""))
	_assert_eq(scene._get_test_image_upload_call_count(), 1, "URL image should still attempt upload when EXIF correction is needed")
	_assert_eq(result_url, source_url, "URL image should keep original URL when rotate-upload fails")
	await _destroy_scene(scene)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_pixel_rotate_backfills_existing_base64_after_load()
	await _test_pixel_rotate_happens_before_upload_for_base64_payload()
	await _test_url_path_downloads_rotates_uploads_and_replaces_url()
	await _test_url_path_skips_reupload_when_no_rotation_needed()
	await _test_url_path_upload_failure_keeps_original_url()
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)

extends SceneTree

class FineTuneStub:
	extends Node
	var SETTINGS = {"imageAutoRotateSetting": 0}
	func is_compact_layout_enabled() -> bool:
		return false
	func get_available_function_names() -> Array:
		return []

var tests_run = 0
var tests_failed = 0
var _fine_tune_stub = null

func assert_eq(actual, expected, name: String = "") -> void:
	tests_run += 1
	if actual != expected:
		tests_failed += 1
		push_error("Assertion failed %s: expected %s got %s" % [name, str(expected), str(actual)])

func assert_true(condition: bool, name: String = "") -> void:
	tests_run += 1
	if not condition:
		tests_failed += 1
		push_error("Assertion failed %s: expected true got false" % name)

func _make_png_base64(width: int, height: int) -> String:
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.6, 0.8, 1.0))
	return Marshalls.raw_to_base64(image.save_png_to_buffer())

func _make_jpg_base64(width: int, height: int) -> String:
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.8, 0.3, 0.2, 1.0))
	return Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.9))

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

func _make_exif_orientation_jpg_base64(width: int, height: int, orientation: int) -> String:
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			if x < int(width / 2):
				image.set_pixel(x, y, Color(0.95, 0.2, 0.15, 1.0))
			else:
				image.set_pixel(x, y, Color(0.15, 0.3, 0.95, 1.0))
	var raw_jpg = image.save_jpg_to_buffer(0.92)
	var oriented_jpg = _inject_exif_orientation_into_jpeg(raw_jpg, orientation)
	return Marshalls.raw_to_base64(oriented_jpg)

func _set_auto_rotate_mode(mode: int) -> void:
	if _fine_tune_stub == null or not is_instance_valid(_fine_tune_stub):
		_fine_tune_stub = FineTuneStub.new()
		_fine_tune_stub.name = "FineTune"
		get_root().add_child(_fine_tune_stub)
	_fine_tune_stub.SETTINGS["imageAutoRotateSetting"] = int(mode)

func _new_message_node():
	var scene = load("res://scenes/message.tscn")
	var node = scene.instantiate()
	get_root().add_child(node)
	await process_frame
	return node

func test_png_base64_is_rendered() -> void:
	var node = await _new_message_node()
	var texture_rect = node.get_node("ImageMessageContainer/TextureRect")
	var png_b64 = _make_png_base64(7, 5)
	node.base64_to_image(texture_rect, png_b64)
	assert_true(texture_rect.texture != null, "png texture exists")
	assert_eq(texture_rect.texture.get_width(), 7, "png width")
	assert_eq(texture_rect.texture.get_height(), 5, "png height")
	node.queue_free()

func test_jpg_base64_is_rendered() -> void:
	var node = await _new_message_node()
	var texture_rect = node.get_node("ImageMessageContainer/TextureRect")
	var jpg_b64 = _make_jpg_base64(9, 6)
	node.base64_to_image(texture_rect, jpg_b64)
	assert_true(texture_rect.texture != null, "jpg texture exists")
	assert_eq(texture_rect.texture.get_width(), 9, "jpg width")
	assert_eq(texture_rect.texture.get_height(), 6, "jpg height")
	node.queue_free()

func test_data_uri_base64_is_rendered() -> void:
	var node = await _new_message_node()
	var texture_rect = node.get_node("ImageMessageContainer/TextureRect")
	var png_b64 = _make_png_base64(11, 4)
	var data_uri = "data:image/png;base64," + png_b64
	node.base64_to_image(texture_rect, data_uri)
	assert_true(texture_rect.texture != null, "data uri texture exists")
	assert_eq(texture_rect.texture.get_width(), 11, "data uri width")
	assert_eq(texture_rect.texture.get_height(), 4, "data uri height")
	node.queue_free()

func test_http_url_without_extension_is_accepted() -> void:
	var node = await _new_message_node()
	assert_true(node.isImageURL("https://example.com/image"), "url without extension")
	assert_true(node.isImageURL("https://example.com/image?size=large"), "url with query without extension")
	node.queue_free()

func test_local_file_import_sets_texture_and_base64() -> void:
	var node = await _new_message_node()
	var image = Image.create(8, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.1, 0.9, 0.1, 1.0))
	var temp_path = "user://tmp_message_import_test.png"
	assert_eq(image.save_png(temp_path), OK, "save temp png")
	node._on_file_dialog_file_selected(temp_path)
	var texture_rect = node.get_node("ImageMessageContainer/TextureRect")
	var base64_edit = node.get_node("ImageMessageContainer/ImageInputRow/Base64ImageEdit")
	assert_true(texture_rect.texture != null, "local import texture exists")
	assert_true(base64_edit.text.length() > 0, "local import base64 exists")
	var abs_path = ProjectSettings.globalize_path(temp_path)
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(abs_path)
	node.queue_free()

func test_upload_spinner_is_toggled_during_upload_status() -> void:
	var node = await _new_message_node()
	var spinner = node.get_node("ImageMessageContainer/ImageInputRow/UploadSpinner")
	assert_true(not spinner.visible, "spinner hidden by default")
	node._begin_image_upload_status()
	assert_true(spinner.visible, "spinner visible while upload is pending")
	node._end_image_upload_status()
	assert_true(not spinner.visible, "spinner hidden after upload finished")
	node.queue_free()

func test_exif_orientation_mode_none_keeps_pixel_layout() -> void:
	_set_auto_rotate_mode(0)
	var node = await _new_message_node()
	var texture_rect = node.get_node("ImageMessageContainer/TextureRect")
	var jpg_b64 = _make_exif_orientation_jpg_base64(12, 4, 6)
	node.base64_to_image(texture_rect, jpg_b64)
	assert_true(texture_rect.texture != null, "mode none texture exists")
	assert_eq(texture_rect.texture.get_width(), 12, "mode none width unchanged")
	assert_eq(texture_rect.texture.get_height(), 4, "mode none height unchanged")
	node.queue_free()

func test_exif_orientation_mode_display_only_rotates_preview_without_mutation() -> void:
	_set_auto_rotate_mode(1)
	var node = await _new_message_node()
	var texture_rect = node.get_node("ImageMessageContainer/TextureRect")
	var jpg_b64 = _make_exif_orientation_jpg_base64(10, 3, 6)
	node.base64_to_image(texture_rect, jpg_b64)
	assert_true(texture_rect.texture != null, "mode display-only texture exists")
	assert_eq(texture_rect.texture.get_width(), 3, "mode display-only width rotated")
	assert_eq(texture_rect.texture.get_height(), 10, "mode display-only height rotated")
	var processed = node._process_base64_image_for_mode(jpg_b64, "jpg", "")
	assert_true(processed.get("ok", false), "mode display-only processing succeeds")
	assert_true(processed.get("orientation_applied", false), "mode display-only applies orientation")
	assert_true(not processed.get("changed", false), "mode display-only does not mutate payload")
	assert_eq(str(processed.get("payload", "")), jpg_b64, "mode display-only payload unchanged")
	node.queue_free()

func test_exif_orientation_mode_pixel_rotate_mutates_payload() -> void:
	_set_auto_rotate_mode(2)
	var node = await _new_message_node()
	var texture_rect = node.get_node("ImageMessageContainer/TextureRect")
	var jpg_b64 = _make_exif_orientation_jpg_base64(9, 4, 6)
	var processed = node._process_base64_image_for_mode(jpg_b64, "jpg", "")
	assert_true(processed.get("ok", false), "mode pixel-rotate processing succeeds")
	assert_true(processed.get("orientation_applied", false), "mode pixel-rotate applies orientation")
	assert_true(processed.get("changed", false), "mode pixel-rotate mutates payload")
	var rotated_payload = str(processed.get("payload", ""))
	assert_true(rotated_payload != "", "mode pixel-rotate returns payload")
	assert_true(rotated_payload != jpg_b64, "mode pixel-rotate payload differs")
	node.base64_to_image(texture_rect, rotated_payload)
	assert_true(texture_rect.texture != null, "mode pixel-rotate texture exists")
	assert_eq(texture_rect.texture.get_width(), 4, "mode pixel-rotate width rotated")
	assert_eq(texture_rect.texture.get_height(), 9, "mode pixel-rotate height rotated")
	node.queue_free()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_set_auto_rotate_mode(0)
	await test_png_base64_is_rendered()
	await test_jpg_base64_is_rendered()
	await test_data_uri_base64_is_rendered()
	await test_http_url_without_extension_is_accepted()
	await test_local_file_import_sets_texture_and_base64()
	await test_upload_spinner_is_toggled_during_upload_status()
	await test_exif_orientation_mode_none_keeps_pixel_layout()
	await test_exif_orientation_mode_display_only_rotates_preview_without_mutation()
	await test_exif_orientation_mode_pixel_rotate_mutates_payload()
	if _fine_tune_stub != null and is_instance_valid(_fine_tune_stub):
		_fine_tune_stub.queue_free()
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)

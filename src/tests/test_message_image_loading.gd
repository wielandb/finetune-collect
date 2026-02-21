extends SceneTree

var tests_run = 0
var tests_failed = 0

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

func _new_message_node():
	var scene = load("res://scenes/message.tscn")
	var node = scene.instantiate()
	get_root().add_child(node)
	return node

func test_png_base64_is_rendered() -> void:
	var node = _new_message_node()
	var texture_rect = node.get_node("ImageMessageContainer/TextureRect")
	var png_b64 = _make_png_base64(7, 5)
	node.base64_to_image(texture_rect, png_b64)
	assert_true(texture_rect.texture != null, "png texture exists")
	assert_eq(texture_rect.texture.get_width(), 7, "png width")
	assert_eq(texture_rect.texture.get_height(), 5, "png height")
	node.queue_free()

func test_jpg_base64_is_rendered() -> void:
	var node = _new_message_node()
	var texture_rect = node.get_node("ImageMessageContainer/TextureRect")
	var jpg_b64 = _make_jpg_base64(9, 6)
	node.base64_to_image(texture_rect, jpg_b64)
	assert_true(texture_rect.texture != null, "jpg texture exists")
	assert_eq(texture_rect.texture.get_width(), 9, "jpg width")
	assert_eq(texture_rect.texture.get_height(), 6, "jpg height")
	node.queue_free()

func test_data_uri_base64_is_rendered() -> void:
	var node = _new_message_node()
	var texture_rect = node.get_node("ImageMessageContainer/TextureRect")
	var png_b64 = _make_png_base64(11, 4)
	var data_uri = "data:image/png;base64," + png_b64
	node.base64_to_image(texture_rect, data_uri)
	assert_true(texture_rect.texture != null, "data uri texture exists")
	assert_eq(texture_rect.texture.get_width(), 11, "data uri width")
	assert_eq(texture_rect.texture.get_height(), 4, "data uri height")
	node.queue_free()

func test_http_url_without_extension_is_accepted() -> void:
	var node = _new_message_node()
	assert_true(node.isImageURL("https://example.com/image"), "url without extension")
	assert_true(node.isImageURL("https://example.com/image?size=large"), "url with query without extension")
	node.queue_free()

func test_local_file_import_sets_texture_and_base64() -> void:
	var node = _new_message_node()
	var image = Image.create(8, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.1, 0.9, 0.1, 1.0))
	var temp_path = "user://tmp_message_import_test.png"
	assert_eq(image.save_png(temp_path), OK, "save temp png")
	node._on_file_dialog_file_selected(temp_path)
	var texture_rect = node.get_node("ImageMessageContainer/TextureRect")
	var base64_edit = node.get_node("ImageMessageContainer/Base64ImageEdit")
	assert_true(texture_rect.texture != null, "local import texture exists")
	assert_true(base64_edit.text.length() > 0, "local import base64 exists")
	var abs_path = ProjectSettings.globalize_path(temp_path)
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(abs_path)
	node.queue_free()

func _init() -> void:
	test_png_base64_is_rendered()
	test_jpg_base64_is_rendered()
	test_data_uri_base64_is_rendered()
	test_http_url_without_extension_is_accepted()
	test_local_file_import_sets_texture_and_base64()
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)

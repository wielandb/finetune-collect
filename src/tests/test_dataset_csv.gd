extends SceneTree

var tests_run = 0
var tests_failed = 0

func assert_eq(actual, expected, name = ""):
	tests_run += 1
	if actual != expected:
		tests_failed += 1
		push_error("Assertion failed %s: expected %s got %s" % [name, str(expected), str(actual)])

func _init():
	var FineTune = load("res://scenes/fine_tune.gd")
	var ft = FineTune.new()
	ft.SETTINGS = {"useGlobalSystemMessage": false}

	assert_eq(ft._next_role_for_dataset_import("meta"), "system", "next role from meta")
	assert_eq(ft._next_role_for_dataset_import("system"), "user", "next role from system")
	assert_eq(ft._next_role_for_dataset_import("user"), "assistant", "next role from user")
	assert_eq(ft._next_role_for_dataset_import("assistant"), "user", "next role from assistant")

	ft.SETTINGS["useGlobalSystemMessage"] = true
	assert_eq(ft._next_role_for_dataset_import("meta"), "user", "next role from meta with global system message")

	var image_cell = JSON.stringify({"type": "input_image", "image_url": "https://example.com/image.png"})
	assert_eq(ft._extract_dataset_image_content_from_cell(image_cell), "https://example.com/image.png", "extract image_url from input_image payload")
	assert_eq(ft._extract_dataset_image_content_from_cell("https://example.com/image.png"), "https://example.com/image.png", "extract direct image url")

	var image_msg = ft._dataset_cell_to_message(image_cell, "user", 0)
	assert_eq(image_msg.get("type", ""), "Image", "dataset user image type")
	assert_eq(image_msg.get("imageContent", ""), "https://example.com/image.png", "dataset user image content")

	var data_url_msg = ft._dataset_cell_to_message("data:image/png;base64,AAAA", "user", 0)
	assert_eq(data_url_msg.get("type", ""), "Image", "dataset data url type")
	assert_eq(data_url_msg.get("imageContent", ""), "AAAA", "dataset data url normalized")

	var assistant_json_msg = ft._dataset_cell_to_message("{\"ok\":true}", "assistant", 0)
	assert_eq(assistant_json_msg.get("type", ""), "JSON", "assistant json detection")
	assert_eq(assistant_json_msg.get("jsonSchemaValue", ""), "{\"ok\":true}", "assistant json payload")

	var assistant_image_cell_msg = ft._dataset_cell_to_message(image_cell, "assistant", 0)
	assert_eq(assistant_image_cell_msg.get("type", ""), "Text", "assistant image-like cell remains text")

	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)

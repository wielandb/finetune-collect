extends SceneTree

class DummyFineTune:
	extends Node
	var SETTINGS = {"exportImagesHow": 0}
	func update_settings_internal():
		pass

func _init():
	call_deferred("_run")

func _run():
	var ft = DummyFineTune.new()
	ft.name = "FineTune"
	get_root().add_child(ft)
	var exporter = load("res://scenes/exporter.gd").new()
	get_root().add_child(exporter)
	var msg_url = {
		"type": "Image",
		"role": "user",
		"imageContent": "http://example.com/test.png",
		"imageDetail": 0
	}
	var res_url = await exporter.convert_message_to_openai_format(msg_url)
	var url = res_url.get("content", [])[0].get("image_url", {}).get("url", "")
	assert(url == "http://example.com/test.png")

	var b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg=="
	var msg_b64 = {
		"type": "Image",
		"role": "user",
		"imageContent": b64,
		"imageDetail": 0
	}
	var res_b64 = await exporter.convert_message_to_openai_format(msg_b64)
	var url_b64 = res_b64.get("content", [])[0].get("image_url", {}).get("url", "")
	assert(url_b64.begins_with("data:image/"))
	print("Image export respects 'as given'")
	quit(0)

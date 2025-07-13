extends SceneTree

class ExporterStub:
	extends "res://scenes/exporter.gd"
	func getSettings():
		return {"includeFunctions": 0, "exportImagesHow": 0}

func _init():
	var Exporter = load("res://tests/exporter_stub.gd")
	var ex = Exporter.new()
	var text = FileAccess.get_file_as_string("res://tests/test_projects/image_url_project.json")
	var data = JSON.parse_string(text)
	var jsonl = await ex.convert_fine_tuning_data(data)
	var obj = JSON.parse_string(jsonl.strip_edges())
	if obj["messages"][0]["content"][0]["image_url"]["url"] == "http://example.com/image-upload.php?image=foo.jpg":
		print("Export test passed")
		quit(0)
	else:
		push_error("Export failed")
		quit(1)

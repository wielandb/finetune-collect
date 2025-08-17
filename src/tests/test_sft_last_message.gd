extends SceneTree

class DummyFineTune:
	extends Node
	var SETTINGS = {}
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
	var ftdata = {
		"functions": [],
		"settings": {},
		"conversations": {
			"c1": [
				{"role": "system", "type": "Text", "textContent": "sys"},
				{"role": "user", "type": "Text", "textContent": "Hi"},
				{"role": "assistant", "type": "Text", "textContent": "Hello"}
			]
		}
	}
	var result = await exporter.convert_fine_tuning_data(ftdata)
	var lines = result.strip_edges().split("\n")
	var parsed = JSON.parse_string(lines[0])
	var msgs = parsed.get("messages", [])
	assert(msgs.size() == 3)
	assert(msgs[0].get("role", "") == "system")
	assert(msgs[msgs.size() - 1].get("role", "") == "assistant")
	print("SFT export keeps system and assistant messages")
	quit(0)

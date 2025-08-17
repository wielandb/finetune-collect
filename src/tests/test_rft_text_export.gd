extends SceneTree

class DummyFineTune:
	extends Node
	var SETTINGS = {"includeFunctions": 0}
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
				{"role": "user", "type": "Text", "textContent": "Hi"},
				{"role": "assistant", "type": "Text", "textContent": "Hello"}
			],
			"c2": [
				{"role": "user", "type": "Text", "textContent": "Add"},
				{
					"role": "assistant",
					"type": "Function Call",
					"functionName": "add",
					"functionUsePreText": "",
					"functionParameters": [
						{"name": "a", "isUsed": true, "parameterValueChoice": "", "parameterValueText": "2", "parameterValueNumber": 0},
						{"name": "b", "isUsed": true, "parameterValueChoice": "", "parameterValueText": "3", "parameterValueNumber": 0}
					],
					"functionResults": ""
				}
			],
			"c3": [
				{"role": "user", "type": "Text", "textContent": "Schema"},
				{"role": "assistant", "type": "JSON", "jsonSchemaValue": "{\"foo\": \"bar\"}"}
			]
		}
	}
	var result = await exporter.convert_rft_data(ftdata)
	var lines = result.strip_edges().split("\n")
	var parsed1 = JSON.parse_string(lines[0])
	assert(parsed1.get("reference_answer", "") == "Hello")
	assert(parsed1.get("do_function_call", true) == false)
	var parsed2 = JSON.parse_string(lines[1])
	assert(parsed2.get("do_function_call", false))
	assert(parsed2.get("ideal_function_call_data", {}).get("name", "") == "add")
	var parsed3 = JSON.parse_string(lines[2])
	assert(parsed3.get("reference_json", {}).get("foo", "") == "bar")
	assert(parsed3.get("do_function_call", true) == false)
	print("RFT export variants ok")
	quit(0)

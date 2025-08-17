extends SceneTree

class DummyFT:
	extends Node
	var SETTINGS = {"finetuneType": 0, "useUserNames": false, "tokenCounts": "{}"}
	func get_available_function_names():
		return []
	func get_available_parameter_names_for_function(name):
		return []

func _init():
	call_deferred("_run")

func _run():
	var ft = DummyFT.new()
	ft.name = "FineTune"
	get_root().add_child(ft)
	var msg = load("res://scenes/message.tscn").instantiate()
	get_root().add_child(msg)
	await create_timer(0).timeout
	msg.from_var({"role": "assistant", "type": "JSON Schema"})
	var data = msg.to_var()
	assert(data["type"] == "JSON")
	print("Legacy JSON Schema message type converted")
	quit(0)


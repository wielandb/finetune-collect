extends SceneTree

func _init():
	call_deferred("_run")

func _run():
	var exporter = load("res://scenes/exporter.gd").new()
	var msgs = [
		{'role': 'developer', 'content': 'a'},
		{'role': 'developer', 'content': 'b'},
		{'role': 'system', 'content': 'c'},
		{'role': 'user', 'content': 'd'},
		{'role': 'system', 'content': 'e'},
	]
	exporter.enforce_single_developer_message(msgs)
	assert(msgs[0]['role'] == 'developer')
	assert(msgs[1]['role'] == 'user')
	assert(msgs[2]['role'] == 'user')
	assert(msgs[3]['role'] == 'user')
	assert(msgs[4]['role'] == 'user')
	print("RFT developer limit enforced")
	quit(0)

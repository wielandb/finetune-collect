extends SceneTree

var tests_run := 0
var tests_failed := 0

func assert_eq(a, b, name := ""):
	tests_run += 1
	if a != b:
		tests_failed += 1
		push_error("Assertion failed %s: expected %s got %s" % [name, str(b), str(a)])

func test_text_message():
	var Scene = load("res://scenes/message.tscn")
	var node = Scene.instantiate()
	node.from_var({"role":"assistant","type":"Text","textContent":"Hello"})
	var sample = node.to_model_output_sample()
	assert_eq(sample.get("sample_text", ""), "Hello", "sample_text")
	assert_eq(sample.get("tool_calls", []).size(), 0, "no tool calls")
	node.queue_free()

func test_function_call():
	var Scene = load("res://scenes/message.tscn")
	var node = Scene.instantiate()
	node.from_var({
		"role":"assistant",
		"type":"Function Call",
		"functionName":"add",
		"functionUsePreText":"",
		"functionParameters":[{"name":"a","isUsed":true,"parameterValueChoice":"","parameterValueText":"2","parameterValueNumber":0}],
		"functionResults":""
	})
	var sample = node.to_model_output_sample()
	assert_eq(sample.get("tool_calls", []).size(), 1, "tool call size")
	assert_eq(sample.get("tool_calls", [])[0]["function"]["name"], "add", "function name")
	var args = JSON.parse_string(sample.get("tool_calls", [])[0]["function"]["arguments"])
	assert_eq(args.get("a", ""), "2", "argument a")
	node.queue_free()

func test_json_schema():
	var Scene = load("res://scenes/message.tscn")
	var node = Scene.instantiate()
	node.from_var({
		"role":"assistant",
		"type":"JSON Schema",
		"jsonSchemaValue":"{\"foo\":\"bar\"}"
	})
	var sample = node.to_model_output_sample()
	assert_eq(sample.get("output_json", {}).get("foo", ""), "bar", "output_json")
	node.queue_free()

func _init():
	test_text_message()
	test_function_call()
	test_json_schema()
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)

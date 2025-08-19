extends SceneTree


var tests_run := 0
var tests_failed := 0

func assert_eq(a, b, name := ""):
	tests_run += 1
	if a != b:
		tests_failed += 1
		push_error("Assertion failed %s: expected %s got %s" % [name, str(b), str(a)])


# Basic save and load using FileAccess to ensure the engine can store data
func test_save_and_load_var():
	var path = "user://tmp_save.bin"
	var data = {"a": 1, "b": 2}
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_var(data)
	file.close()
	var file_r = FileAccess.open(path, FileAccess.READ)
	var loaded = file_r.get_var()
	file_r.close()
	assert_eq(loaded["a"], 1, "saved var a")
	assert_eq(loaded["b"], 2, "saved var b")

func test_convert_functions():
	var Exporter = load("res://scenes/exporter.gd")
	var ex = Exporter.new()
	var param = {"name":"age","type":"Integer","description":"Age","isRequired":true}
	var p_out = ex.convert_parameter_to_openai_format(param)
	assert_eq(p_out["type"], "integer", "convert_parameter_to_openai_format type")
	assert_eq(p_out["description"], "Age", "convert_parameter_to_openai_format description")
	var funcdef = {"name":"test","description":"desc","parameters":[param]}
	var f_out = ex.convert_function_to_openai_format(funcdef)
	assert_eq(f_out["function"]["name"], "test", "convert_function_to_openai_format name")
	assert_eq(f_out["function"]["parameters"]["properties"]["age"]["type"], "integer", "convert_function param type")
	assert_eq(f_out["function"]["parameters"]["required"][0], "age", "convert_function required")

func test_parameter_value_helpers():
	var Exporter = load("res://scenes/exporter.gd")
	var ex = Exporter.new()
	var arr = [
		{"name":"p1","parameterValueChoice":"choice","parameterValueText":"","parameterValueNumber":0},
		{"name":"p2","parameterValueChoice":"","parameterValueText":"text","parameterValueNumber":0},
		{"name":"p3","parameterValueChoice":"","parameterValueText":"","parameterValueNumber":42}
	]
	var res = ex.get_parameter_values_from_function_parameter_dict(arr)
	assert_eq(res["p1"], "choice", "param value choice")
	assert_eq(res["p2"], "text", "param value text")
	assert_eq(res["p3"], 42, "param value number")

func test_create_conversation_parts():
	var Exporter = load("res://scenes/exporter.gd")
	var ex = Exporter.new()
	var convo = [
		{"role":"user","type":"Text","textContent":"hi"},
		{"role":"assistant","type":"Function Call","functionName":"foo","functionParameters":[]},
		{"role":"assistant","type":"Function Call","functionName":"bar","functionParameters":[]}
	]
	var parts = ex.create_conversation_parts(convo)
	assert_eq(parts.size(), 1, "conversation parts size")
	assert_eq(parts[0].size(), 2, "conversation part length")
	assert_eq(parts[0][0]["role"], "user", "conversation part role")

func test_image_utils():
	var Exporter = load("res://scenes/exporter.gd")
	var ex = Exporter.new()
	assert_eq(ex.isImageURL("http://example.com/img.png"), true, "isImageURL valid")
	assert_eq(ex.isImageURL("invalid"), false, "isImageURL invalid")
	assert_eq(ex.getImageType("https://example.com/pic.jpg?x=1"), "jpg", "getImageType jpg")
	assert_eq(ex.isImageURL("https://example.com/pic.jpeg"), true, "isImageURL jpeg")
	assert_eq(ex.getImageType("https://example.com/pic.jpeg"), "jpeg", "getImageType jpeg")
	assert_eq(ex.getImageType("https://example.com/pic.png"), "png", "getImageType png")


func test_convert_text_message():
	var Exporter = load("res://scenes/exporter.gd")
	var ex = Exporter.new()
	var msg = {"role":"user","type":"Text","textContent":"hello"}
	var conv = ex.convert_message_to_openai_format(msg)
	assert_eq(conv["role"], "user", "convert_message role")
	assert_eq(conv["content"], "hello", "convert_message content")

func test_convert_functions_list():
	var Exporter = load("res://scenes/exporter.gd")
	var ex = Exporter.new()
	var f1 = {"name":"f1","description":"","parameters":[]}
	var f2 = {"name":"f2","description":"","parameters":[]}
	var res = ex.convert_functions_to_openai_format([f1, f2], ["f2"])
	assert_eq(res.size(), 1, "convert_functions_to_openai_format size")
	assert_eq(res[0]["function"]["name"], "f2", "convert_functions_to_openai_format name")

func test_convert_conversation_function_call() -> void:
	var Exporter = load("res://scenes/exporter.gd")
	var ex = Exporter.new()
	var convo = [
		{"role":"user","type":"Text","textContent":"hi"},
		{"role":"assistant","type":"Function Call","functionName":"foo","functionParameters":[{"name":"a","isUsed":true,"parameterValueChoice":"1","parameterValueText":""}],"functionResults":"ok","functionUsePreText":""}
	]
	var result = await ex.convert_conversation_to_openai_format(convo)
	assert_eq(result.size(), 3, "convert_conversation size")
	assert_eq(result[1]["role"], "assistant", "function call role")
	assert_eq(result[1].has("tool_calls"), true, "function call tool_calls")
	assert_eq(result[2]["role"], "tool", "tool response role")

func test_message_class():
	var Message = load("res://addons/openai_api/Scripts/Message.gd")
	var msg = Message.new()
	msg.set_role("assistant")
	msg.add_text_content("hello")
	msg.add_image_content("https://example.com/img.png", "auto")
	msg.add_function_call("1", "foo", {"bar":"baz"})
	var d = msg.get_as_dict()
	assert_eq(d["role"], "assistant", "message role")
	assert_eq(d["content"].size(), 2, "message content size")
	assert_eq(d["content"][0]["type"], "text", "message text type")
	assert_eq(d["tool_calls"].size(), 1, "message tool calls size")
	assert_eq(d["tool_calls"][0]["function"]["name"], "foo", "function call name")

func test_message_ui_text_roundtrip():
	var Scene = load("res://scenes/message.tscn")
	var node = Scene.instantiate()
	node.from_openai_message({"role":"user","content":"hi"})
	var out = node.to_openai_message()
	assert_eq(out.get("content", ""), "hi", "ui text roundtrip")
	assert_eq(out.get("role", ""), "user", "ui text role")
	node.queue_free()

func test_message_ui_image_roundtrip():
	var Scene = load("res://scenes/message.tscn")
	var node = Scene.instantiate()
	node.from_openai_message({"role":"assistant","content":[{"type":"image_url","image_url":{"url":"http://example.com/pic.png","detail":"auto"}}]})
	var out = node.to_openai_message()
	assert_eq(out.get("role", ""), "assistant", "ui image role")
	assert_eq(out.get("content", [])[0]["image_url"]["url"], "http://example.com/pic.png", "ui image url")
	assert_eq(out.get("content", [])[0]["image_url"]["detail"], "auto", "ui image detail")
	node.queue_free()

func _init():
	test_save_and_load_var()
	test_convert_functions()
	test_parameter_value_helpers()
	test_create_conversation_parts()
	test_image_utils()
	test_convert_text_message()
	test_convert_functions_list()
	await test_convert_conversation_function_call()
	test_message_class()
	test_message_ui_text_roundtrip()
	test_message_ui_image_roundtrip()
	print("Tests run: %d, Failures: %d" % [tests_run, tests_failed])
	quit(tests_failed)

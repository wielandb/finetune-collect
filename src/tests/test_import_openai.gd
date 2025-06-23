extends SceneTree

var FUNCTIONS = []

func _create_ft_function_call_msg(function_name: String, arguments_dict: Dictionary, function_result: String, pretext: String) -> Dictionary:
    var param_list := []
    for arg_name in arguments_dict.keys():
        var val = arguments_dict[arg_name]
        var entry = {
            "name": str(arg_name),
            "isUsed": true,
            "parameterValueText": "",
            "parameterValueChoice": "",
            "parameterValueNumber": 0
        }
        match typeof(val):
            TYPE_INT, TYPE_FLOAT:
                entry["parameterValueNumber"] = val
            _:
                entry["parameterValueText"] = str(val)
        param_list.append(entry)

    var fn_exists := false
    for f in FUNCTIONS:
        if f.get("name", "") == function_name:
            fn_exists = true
            break
    if !fn_exists:
        var param_defs := []
        for arg_name in arguments_dict.keys():
            var v = arguments_dict[arg_name]
            var p_type = "Number" if typeof(v) in [TYPE_INT, TYPE_FLOAT] else "String"
            param_defs.append({
                "type": p_type,
                "name": str(arg_name),
                "description": "",
                "minimum": 0,
                "maximum": 0,
                "isEnum": false,
                "hasLimits": false,
                "enumOptions": "",
                "isRequired": true
            })
        FUNCTIONS.append({
            "name": function_name,
            "description": "",
            "parameters": param_defs,
            "functionExecutionEnabled": false,
            "functionExecutionExecutable": "",
            "functionExecutionArgumentsString": ""
        })

    return {
        "role": "assistant",
        "type": "Function Call",
        "textContent": "",
        "unpreferredTextContent": "",
        "preferredTextContent": "",
        "imageContent": "",
        "imageDetail": 0,
        "functionName": function_name,
        "functionParameters": param_list,
        "functionResults": function_result,
        "functionUsePreText": pretext
    }

func _extract_text_from_msg(msg: Dictionary) -> String:
    var text := ""
    if msg.has("content"):
        if msg["content"] is String:
            text = msg["content"]
        elif msg["content"] is Array:
            for p in msg["content"]:
                if p.get("type", "") == "text" or p.get("type", "") == "output_text":
                    text += p.get("text", "")
    return text

func _validate_is_json(testtext) -> bool:
    if testtext == "":
        return false
    var json = JSON.new()
    var err = json.parse(testtext)
    return err == OK

func conversation_from_openai_message_json(oaimsgjson):
    if typeof(oaimsgjson) == TYPE_STRING:
        var parsed = JSON.parse_string(oaimsgjson)
        if parsed is Dictionary and parsed.has("messages"):
            oaimsgjson = parsed["messages"]
        else:
            oaimsgjson = parsed
    if typeof(oaimsgjson) != TYPE_ARRAY:
        return []

    var NEWCONVO = []
    var image_detail_map = {"high": 0, "low": 1, "auto": 2}
    var i := 0
    while i < oaimsgjson.size():
        var msg = oaimsgjson[i]
        var role = msg.get("role", "")
        var msg_type = msg.get("type", "")

        if role == "system" or role == "developer":
            NEWCONVO.append({
                "role": "assistant",
                "type": "Text",
                "textContent": msg.get("content", ""),
                "unpreferredTextContent": "",
                "preferredTextContent": "",
                "imageContent": "",
                "imageDetail": 0,
                "functionName": "",
                "functionParameters": [],
                "functionResults": "",
                "functionUsePreText": ""
            })
        elif role == "user":
            var content = msg.get("content")
            if content is Array:
                for piece in content:
                    if piece.get("type", "") == "text":
                        NEWCONVO.append({
                            "role": "user",
                            "type": "Text",
                            "textContent": piece.get("text", ""),
                            "unpreferredTextContent": "",
                            "preferredTextContent": "",
                            "imageContent": "",
                            "imageDetail": 0,
                            "functionName": "",
                            "functionParameters": [],
                            "functionResults": "",
                            "functionUsePreText": "",
                            "userName": msg.get("name", "")
                        })
                    elif piece.get("type", "") == "image_url":
                        var url = piece["image_url"].get("url", "")
                        var detail = image_detail_map.get(piece["image_url"].get("detail", "high"), 0)
                        if url.begins_with("data:image/jpeg;base64,"):
                            url = url.replace("data:image/jpeg;base64,", "")
                        NEWCONVO.append({
                            "role": "user",
                            "type": "Image",
                            "textContent": "",
                            "unpreferredTextContent": "",
                            "preferredTextContent": "",
                            "imageContent": url,
                            "imageDetail": detail,
                            "functionName": "",
                            "functionParameters": [],
                            "functionResults": "",
                            "functionUsePreText": "",
                            "userName": msg.get("name", "")
                        })
            else:
                NEWCONVO.append({
                    "role": "user",
                    "type": "Text",
                    "textContent": msg.get("content", ""),
                    "unpreferredTextContent": "",
                    "preferredTextContent": "",
                    "imageContent": "",
                    "imageDetail": 0,
                    "functionName": "",
                    "functionParameters": [],
                    "functionResults": "",
                    "functionUsePreText": "",
                    "userName": msg.get("name", "")
                })
        elif msg_type == "function_call":
            var call_id = msg.get("call_id", msg.get("id", ""))
            var function_name = msg.get("name", "")
            var arguments_json = msg.get("arguments", "{}")
            var arguments_dict = JSON.parse_string(arguments_json)
            if arguments_dict == null:
                arguments_dict = {}

            var function_result = ""
            if i + 1 < oaimsgjson.size():
                var next_msg = oaimsgjson[i + 1]
                if next_msg.get("type", "") == "function_call_output" and next_msg.get("call_id", "") == call_id:
                    function_result = next_msg.get("output", "")
                    i += 1

            var pretext := ""
            if NEWCONVO.size() > 0:
                var last_msg = NEWCONVO[-1]
                if last_msg.get("role", "") == "assistant" and last_msg.get("type", "") == "Text":
                    pretext = last_msg.get("textContent", "")
                    NEWCONVO.pop_back()

            NEWCONVO.append(_create_ft_function_call_msg(function_name, arguments_dict, function_result, pretext))
        elif role == "assistant":
            if msg.has("tool_calls") and msg["tool_calls"].size() > 0:
                var call = msg["tool_calls"][0]
                var call_id = call.get("id", "")
                var function_name = call["function"].get("name", "")
                var arguments_json = call["function"].get("arguments", "{}")
                var arguments_dict = JSON.parse_string(arguments_json)
                if arguments_dict == null:
                    arguments_dict = {}

                var function_result = ""
                if i + 1 < oaimsgjson.size():
                    var nxt = oaimsgjson[i + 1]
                    if nxt.get("role", "") == "tool" and nxt.get("tool_call_id", "") == call_id:
                        function_result = _extract_text_from_msg(nxt)
                        i += 1

                var pretext := _extract_text_from_msg(msg)
                NEWCONVO.append(_create_ft_function_call_msg(function_name, arguments_dict, function_result, pretext))
            elif msg.has("function_call"):
                var fc = msg["function_call"]
                var function_name = fc.get("name", "")
                var arguments_json = fc.get("arguments", "{}")
                var arguments_dict = JSON.parse_string(arguments_json)
                if arguments_dict == null:
                    arguments_dict = {}

                var function_result = ""
                if i + 1 < oaimsgjson.size():
                    var nxt2 = oaimsgjson[i + 1]
                    if nxt2.get("role", "") in ["function", "tool"] and nxt2.get("name", "") == function_name:
                        if nxt2.get("role", "") == "tool":
                            function_result = _extract_text_from_msg(nxt2)
                        else:
                            function_result = nxt2.get("content", "")
                        i += 1

                var pretext := _extract_text_from_msg(msg)
                NEWCONVO.append(_create_ft_function_call_msg(function_name, arguments_dict, function_result, pretext))
            elif i + 1 < oaimsgjson.size() and oaimsgjson[i + 1].get("type", "") == "function_call":
                var fcmsg = oaimsgjson[i + 1]
                var call_id2 = fcmsg.get("call_id", fcmsg.get("id", ""))
                var fname2 = fcmsg.get("name", "")
                var ajson2 = fcmsg.get("arguments", "{}")
                var adict2 = JSON.parse_string(ajson2)
                if adict2 == null:
                    adict2 = {}

                var result2 = ""
                if i + 2 < oaimsgjson.size():
                    var outm = oaimsgjson[i + 2]
                    if outm.get("type", "") == "function_call_output" and outm.get("call_id", "") == call_id2:
                        result2 = outm.get("output", "")
                        i += 1
                        i += 1
                    else:
                        i += 1
                else:
                    i += 1

                var pretext2 := _extract_text_from_msg(msg)
                NEWCONVO.append(_create_ft_function_call_msg(fname2, adict2, result2, pretext2))
                i += 1
                continue
            else:
                var a_text := _extract_text_from_msg(msg)
                if _validate_is_json(a_text):
                    NEWCONVO.append({
                        "role": "assistant",
                        "type": "JSON Schema",
                        "textContent": "",
                        "unpreferredTextContent": "",
                        "preferredTextContent": "",
                        "imageContent": "",
                        "imageDetail": 0,
                        "functionName": "",
                        "functionParameters": [],
                        "functionResults": "",
                        "functionUsePreText": "",
                        "jsonSchemaValue": a_text
                    })
                else:
                    NEWCONVO.append({
                        "role": "assistant",
                        "type": "Text",
                        "textContent": a_text,
                        "unpreferredTextContent": "",
                        "preferredTextContent": "",
                        "imageContent": "",
                        "imageDetail": 0,
                        "functionName": "",
                        "functionParameters": [],
                        "functionResults": "",
                        "functionUsePreText": ""
                    })
        i += 1
    return NEWCONVO

func _test_basic():
    FUNCTIONS.clear()
    var msgs = [
        {"role":"developer","content":"system msg"},
        {"role":"user","content":[
            {"type":"text","text":"Hi"},
            {"type":"image_url","image_url":{"url":"data:image/jpeg;base64,abcd","detail":"high"}}
        ]},
        {"role":"assistant","content":"{\"foo\":1}"}
    ]
    var result = conversation_from_openai_message_json(msgs)
    print(result)
    assert(result.size() == 4)
    assert(result[0]["role"] == "assistant" and result[0]["type"] == "Text")
    assert(result[1]["type"] == "Text" and result[2]["type"] == "Image")
    assert(result[3]["type"] == "JSON Schema")

func _test_function_call():
    FUNCTIONS.clear()
    var msgs = [
        {"role":"user","content":"Call weather"},
        {"type":"function_call","id":"1","name":"weather_forecast","arguments":"{\"location\":\"SF\"}"},
        {"type":"function_call_output","call_id":"1","output":"{\"temp\":20}"},
        {"role":"assistant","content":[{"type":"output_text","text":"It is 20"}]}
    ]
    var result = conversation_from_openai_message_json(msgs)
    assert(result.size() == 3)
    var fc = result[1]
    assert(fc["type"] == "Function Call")
    assert(FUNCTIONS.size() == 1 and FUNCTIONS[0]["name"] == "weather_forecast")

func _init():
    _test_basic()
    _test_function_call()
    print("All tests passed")
    quit()

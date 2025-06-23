extends SceneTree

func _extract_text_from_msg(msg: Dictionary) -> String:
    var text := ""
    if msg.has("content"):
        if msg["content"] is String:
            text = msg["content"]
        elif msg["content"] is Array:
            for p in msg["content"]:
                if p.get("type", "") == "text":
                    text += p.get("text", "")
    return text

func conversation_from_openai_message_json(oaimsgjson):
    if typeof(oaimsgjson) == TYPE_STRING:
        oaimsgjson = JSON.parse_string(oaimsgjson)
    if typeof(oaimsgjson) != TYPE_ARRAY:
        return []
    var convo = []
    for msg in oaimsgjson:
        var text = _extract_text_from_msg(msg)
        convo.append({
            "role": msg.get("role", ""),
            "type": "Text",
            "textContent": text
        })
    return convo

func _init():
    var input_json = [
        {"role": "system", "content": [{"type": "text", "text": "Hello"}]},
        {"role": "user", "content": "Hi"}
    ]
    var result = conversation_from_openai_message_json(input_json)
    var ok = result.size() == 2 and result[0].get("textContent", "") == "Hello"
    if ok:
        print("Import successful")
        quit(0)
    else:
        push_error("Conversation import failed")
        quit(1)

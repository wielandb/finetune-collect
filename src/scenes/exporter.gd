extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func url_to_base64(url: String):
	var httpreqObj = $HTTPRequest
	httpreqObj.request(url)
	var response = await httpreqObj.request_completed
	var body = response[3]
	var base_64_data = Marshalls.raw_to_base64(body)
	return base_64_data
	

func filter_function_map_only_keep_array(function_map, keep_functions_name_array):
	var function_map_tmp = function_map
	for key in function_map_tmp:
		if key not in keep_functions_name_array:
			function_map_tmp.erase(key)
	return function_map_tmp
	
func get_all_functions_used_in_conversation(convoIx):
	var conversations = get_node("/root/FineTune").CONVERSATIONS
	var listOfFunctionNamesUsedInThisConvo = []
	for message in conversations[convoIx]:
		if message['type'] == 'Function Call':
			listOfFunctionNamesUsedInThisConvo.append(message['functionName'])
	return listOfFunctionNamesUsedInThisConvo

func get_all_functions_used_globally():
	var conversations = get_node("/root/FineTune").CONVERSATIONS
	var listOfFunctionNamesUsed = []
	for convoIx in conversations: 
		for message in conversations[convoIx]:
			if message['type'] == 'Function Call':
				listOfFunctionNamesUsed.append(message['functionName'])
	return listOfFunctionNamesUsed

func getRandomID(length: int) -> String:
	var ascii_letters_and_digits = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var result = ""
	for i in range(length):
		result += ascii_letters_and_digits[randi() % ascii_letters_and_digits.length()]
	return result

func getSettings():
	get_node("/root/FineTune").update_settings_internal()
	return get_node("/root/FineTune").SETTINGS

func convert_parameter_to_openai_format(param):
	#Convert a parameter from the source format to OpenAI function parameter format.
	var param_type_map = {
		'String': 'string',
		'Integer': 'integer',
		'Number': 'number',
		'Boolean': 'boolean'		
	}
	var converted_param = {
		'type': param_type_map.get(param['type'], 'string'),
		'description': param.get('description', '')
	}
	# Handle enum options
	if param.get('isEnum', false) and param.get('enumOptions'):
		converted_param['enum'] = param['enumOptions'].split(',')
	return converted_param
	
func convert_function_to_openai_format(funcdef):
	# Convert a function from the source format to OpenAI function format.
	var converted_function = {
		'type': 'function',
		'function': {
			'name': funcdef['name'],
			'description': funcdef.get('description', ''),
			'parameters': {
				'type': 'object',
				'properties': {},
				'required': []
			}
		}
	}
	for param in funcdef['parameters']:
		var param_name = param['name']
		var converted_param = convert_parameter_to_openai_format(param)
		
		converted_function['function']['parameters']['properties'][param_name] = converted_param
		
		# Add to required parameters if isRequired is True
		if param.get('isRequired', false):
			converted_function['function']['parameters']['required'].append(param_name)
	return converted_function
	
func convert_message_to_openai_format(message, function_map=null):
	# Convert a message from the source format to OpenAI message format.
	# Handles text, image, and function call messages.
	print("Converting message of type...")
	print(message['type'])
	var tool_call = {}
	var image_detail_map = {
		0: "high",
		1: "low",
		2: "auto"
	}
	# Text message
	if message['type'] == 'Text':
		var toAddDict ={
			'role': message['role'],
			'content': message['textContent']
		}
		if message.get("userName", "") != "":
			toAddDict["name"] = message.get("userName", "")
		return toAddDict
	# Image message
	elif message['type'] == 'Image':
		var image_url_data = ""
		if getSettings().get('exportImagesHow', 0) == 0:
			if isImageURL(message['imageContent']):
				image_url_data = message['imageContent']
			else:
				# TODO: Get if it is really a jpeg or a png we are laoding
				image_url_data = "data:image/jpeg;base64," + message['imageContent']
		elif getSettings().get('exportImagesHow', 0) == 1:
			var imageurl = message['imageContent'] 
			var base64_data = await url_to_base64(imageurl)
			match getImageType(imageurl):
				"png":
					image_url_data = "data:image/png;base64," + base64_data
				"jpeg", "jpg":
					image_url_data = "data:image/jpeg;base64," + base64_data
				"":
					push_error("Invalid file type")
		return {
			'role': message['role'],
			'content': [
				{
					'type': 'image_url',
					'image_url': {
						'url': image_url_data,
						'detail': image_detail_map[int(message.get("imageDetail", 0))]
					}
				}
			]
		}
	# Function Call message
	elif message['type'] == 'Function Call':
		# Prepare function call
		var function_name = message['functionName']
		var function_parameters = {}
		
		# If there is a function pre-execution message, set it as content
		var preFunctionText = null
		if message["functionUsePreText"] != "":
			preFunctionText = message["functionUsePreText"]
		# Convert parameters
		for param in message['functionParameters']:
			if param['isUsed']:
				# Use choice if available, otherwise text
				var value = param['parameterValueChoice'] or param['parameterValueText']
				function_parameters[param['name']] = value
		var tool_call_id = getRandomID(3)
		# Prepare tool call
		tool_call = {
			'role': 'assistant',
			'content': preFunctionText,
			'tool_calls': [{
				'id': str(tool_call_id),
				'type': 'function',
				'function': {
					'name': function_name,
					'arguments': JSON.stringify(function_parameters)
				}
			}]
		}
		# If function result exists, add tool response
		if message['functionResults']:
			var tool_response = {
					'role': 'tool',
					'tool_call_id': str(tool_call_id),
					'content': message['functionResults']
			}
			return [tool_call, tool_response]
		return tool_call
	elif message['type'] == 'JSON Schema':
		var toAddDict = {
			'role': message['role'],
			'content': message['jsonSchemaValue']
		}
		return toAddDict
	elif message['type'] == 'Audio':
		var toAddDict = {
			'role': message['role'],
			'content': [
				{
					'type': 'input_audio',
					'input_audio': {
						'format': message['audioFiletype'],
						'data': message['audioData']
					}
				}
			]
		}
		return toAddDict
	elif message['type'] == "PDF File":
		var toAddDict = {
			'role': message['role'],
			'content': [
					{
						'type': 'file',
						'file': {
							'filename': message['fileMessageName'],
							'file_data': 'data:application/pdf;base64,' + message['fileMessageData']
						}
					}
				]
			}
		return toAddDict
	return null

func convert_conversation_to_openai_format(conversation, function_map=null):
	# Convert an entire conversation to OpenAI format.
	# :param conversation: List of messages in source format
	# :param function_map: Optional map of function definitions
	# :return: List of converted messages with optional system message
	var converted_messages = []
	for message in conversation:
		var converted = await convert_message_to_openai_format(message, function_map)
		if converted == null:
			continue
		# Handle cases where a single function message might return multiple messages
		if converted is Array:
			converted_messages += converted
		elif converted:
			converted_messages.append(converted)
	return converted_messages

func convert_functions_to_openai_format(functions, onlykeep=null):
	# Convert list of functions to OpenAI tools format.
	var tmp = []
	for funcDef in functions:
		if not onlykeep or funcDef["name"] in onlykeep:
			tmp.append(convert_function_to_openai_format(funcDef))
	return tmp

func get_parameter_values_from_function_parameter_dict(fpdict):
	var parametersAndValues = {}
	for fp in fpdict:
		if fp["parameterValueChoice"] != "":
			parametersAndValues[fp['name']] = fp["parameterValueChoice"]
		elif fp["parameterValueText"] != "":
			parametersAndValues[fp['name']] = fp["parameterValueText"]
		else:
			parametersAndValues[fp['name']] = fp["parameterValueNumber"]
	return parametersAndValues

func create_conversation_parts(conversation: Array) -> Array:
	# Return full prefixes up to each non-final assistant Function Call
	var parts: Array = []
	var count: int = conversation.size()
	for i in range(count):
		var msg = conversation[i]
		if msg['role'] == 'assistant' and msg['type'] == 'Function Call' and i < count - 1:
			# build prefix through this call
			var prefix: Array = []
			for j in range(i + 1):
				prefix.append(conversation[j])
			parts.append(prefix)
	return parts

func convert_rft_data(ftdata):
	var jsonl_file_string = ""
	# ftdata -> the project file structure
	### Needs to be converted from scripts
	## function_map = {func['name']: func for func in data.get('functions', [])}
	var function_map = {}
	for funcDef in ftdata.get('functions', []):
		function_map[funcDef["name"]] = funcDef
	var tools = convert_functions_to_openai_format(ftdata.get('functions', []))
	var system_message = null
	if ftdata['settings'].get('useGlobalSystemMessage', false):
		system_message = ftdata['settings'].get('globalSystemMessage', '')
	# Expand conversations: include original and mid-call prefixes
	if ftdata['settings'].get('doRFTExportConversationSplits', 0) == 0:
		var original = ftdata['conversations'].duplicate(true)
		var expanded = {}
		for conversation_key in original:
			# keep full original
			expanded[conversation_key] = original[conversation_key]
			var splits = create_conversation_parts(original[conversation_key])
			print("Found " + str(splits.size()) + " mid-call splits for " + conversation_key)
			for i in range(splits.size()):
				var part_key = conversation_key + "-" + str(i)
				expanded[part_key] = splits[i]
		# replace conversations map with expanded version
		ftdata['conversations'] = expanded
	## End of convo expanding
	print("Expanded conversations:")
	print(ftdata['conversations'])
	for conversation_key in ftdata['conversations']:
		var conversation = ftdata['conversations'][conversation_key].duplicate(true)
		# For reinforcement fine tuning, we need to remove the last assistant message/function call, because we need to convert it to "correct data"
		var last_message = conversation.pop_back()
		# We need to check if the message we got is assistant + either JSON Schema or function call
		if last_message['role'] != "assistant":
			print("Invalid role in last message in conversation " + conversation_key + ", skipping...")
			print("Last message:")
			print(last_message)
			continue
		if last_message['type'] != "JSON Schema" and last_message['type'] != "Function Call":
			print("Invalid type in last message in conversation " + conversation_key + ", skipping...")
			continue
		var correct_data = {}
		if last_message['type'] == "JSON Schema":
			# Get the value, parse it and put it into correct data, append empty function data...
			correct_data = JSON.parse_string(last_message['jsonSchemaValue'])
			correct_data['ideal_function_call_data'] = []
			correct_data['do_function_call'] = false
		elif last_message['type'] == "Function Call":
			correct_data['do_function_call'] = true
			correct_data['ideal_function_call_data'] = {
				"name": last_message["functionName"],
				"arguments": get_parameter_values_from_function_parameter_dict(last_message["functionParameters"]),
				"functionUsePreText": last_message["functionUsePreText"]
			}
		else:
			print("Something went very wrong...")
			continue
			
		
		var processed_conversation = []
		if system_message:
				processed_conversation.append({
					'role': 'system', 
					'content': system_message
				})
		# Convert conversation
		processed_conversation += await convert_conversation_to_openai_format(conversation, function_map)
		# Write to JSONL, optionally including tools
		var output_entry = correct_data
		output_entry['messages'] = processed_conversation
		# Only add tools if there are function calls in the conversation
		# TODO: Do as the settings say
		var function_handle_setting = getSettings().get("includeFunctions", 0)
		if function_handle_setting == 0:
			# Always include all
			tools = convert_functions_to_openai_format(ftdata.get('functions', []))
			if tools.size() > 0:
				output_entry['tools'] = tools
		elif function_handle_setting == 1:
			# Only include ones used in the conversation
			tools = convert_functions_to_openai_format(ftdata.get('functions', []), get_all_functions_used_in_conversation(conversation_key))
			if tools.size() > 0:
				output_entry['tools'] = tools
		elif function_handle_setting == 2:
			tools = convert_functions_to_openai_format(ftdata.get('functions', []), get_all_functions_used_globally())
			if tools.size() > 0:
				output_entry['tools'] = tools
		elif function_handle_setting == 3:
			for msg in processed_conversation:
				if msg.get('tool_calls', false) and tools.size() > 0:
					output_entry['tools'] = tools
					break
		else:
			tools = convert_functions_to_openai_format(ftdata.get('functions', []))
			if tools.size() > 0:
				output_entry['tools'] = tools
		jsonl_file_string += JSON.stringify(output_entry) + "\n"
	return jsonl_file_string

func convert_dpo_data(ftdata):
	var jsonl_file_string = ""
	var conversations = ftdata.get("conversations", {})
	
	for convo_key in conversations:
		var conversation = conversations[convo_key]
		
		# We only train on one-turn conversations where:
		#   - there are exactly 2 messages (user -> assistant)
		#   - the user message is type Text
		#   - the assistant message is type Text
		#   - the assistant has both preferredTextContent and unpreferredTextContent non-empty
		if conversation.size() == 2:
			var user_message = conversation[0]
			var assistant_message = conversation[1]
			
			if user_message.get("role", "") == "user" \
			and assistant_message.get("role", "") == "assistant" \
			and user_message.get("type", "") == "Text" \
			and assistant_message.get("type", "") == "Text":
				
				var preferred_text = assistant_message.get("preferredTextContent", "")
				var unpreferred_text = assistant_message.get("unpreferredTextContent", "")
				
				if preferred_text != "" and unpreferred_text != "":
					var user_text = user_message.get("textContent", "")
					
					# Build the JSON object according to the DPO schema
					var dpo_entry = {
						"input": {
							"messages": [
								{
									"role": "user",
									"content": user_text
								}
							],
							"tools": [],
							"parallel_tool_calls": true
						},
						"preferred_output": [
							{
								"role": "assistant",
								"content": preferred_text
							}
						],
						"non_preferred_output": [
							{
								"role": "assistant",
								"content": unpreferred_text
							}
						]
					}
					
					# Append serialized data (one JSON object per line)
					jsonl_file_string += JSON.stringify(dpo_entry) + "\n"
	
	return jsonl_file_string

func convert_fine_tuning_data(ftdata):
	var jsonl_file_string = ""
	# ftdata -> the project file structure
	### Needs to be converted from scripts
	## function_map = {func['name']: func for func in data.get('functions', [])}
	var function_map = {}
	for funcDef in ftdata.get('functions', []):
		function_map[funcDef["name"]] = funcDef
	var tools = convert_functions_to_openai_format(ftdata.get('functions', []))
	var system_message = null
	if ftdata['settings'].get('useGlobalSystemMessage', false):
		system_message = ftdata['settings'].get('globalSystemMessage', '')
	for conversation_key in ftdata['conversations']:
		var conversation = ftdata['conversations'][conversation_key]
		var processed_conversation = []
		if system_message:
				processed_conversation.append({
					'role': 'system', 
					'content': system_message
				})
		# Convert conversation
		processed_conversation += await convert_conversation_to_openai_format(conversation, function_map)
		# Write to JSONL, optionally including tools
		var output_entry = {
			'messages': processed_conversation
		}
		# Only add tools if there are function calls in the conversation
		# TODO: Do as the settings say
		var function_handle_setting = getSettings().get("includeFunctions", 0)
		if function_handle_setting == 0:
			# Always include all
			tools = convert_functions_to_openai_format(ftdata.get('functions', []))
			if tools.size() > 0:
				output_entry['tools'] = tools
		elif function_handle_setting == 1:
			# Only include ones used in the conversation
			tools = convert_functions_to_openai_format(ftdata.get('functions', []), get_all_functions_used_in_conversation(conversation_key))
			if tools.size() > 0:
				output_entry['tools'] = tools
		elif function_handle_setting == 2:
			tools = convert_functions_to_openai_format(ftdata.get('functions', []), get_all_functions_used_globally())
			if tools.size() > 0:
				output_entry['tools'] = tools
		elif function_handle_setting == 3:
			for msg in processed_conversation:
				if msg.get('tool_calls', false) and tools.size() > 0:
					output_entry['tools'] = tools
					break
		else:
			tools = convert_functions_to_openai_format(ftdata.get('functions', []))
			if tools.size() > 0:
				output_entry['tools'] = tools
		jsonl_file_string += JSON.stringify(output_entry) + "\n"
	return jsonl_file_string


func isImageURL(url: String) -> bool:
	# Return false if the URL is empty or only whitespace.
	if url.strip_edges() == "":
		return false

	# Define valid URL schemes. Adjust this list if you need to allow other schemes.
	var valid_schemes = ["http://", "https://"]

	# Convert the URL to lowercase for case-insensitive comparisons.
	var lower_url = url.to_lower()

	# Check if the URL begins with one of the valid schemes.
	var scheme_valid = false
	for scheme in valid_schemes:
		if lower_url.begins_with(scheme):
			scheme_valid = true
			break
	if not scheme_valid:
		return false

	# Remove any query parameters or fragment identifiers.
	var cleaned_url = lower_url.split("?")[0].split("#")[0]

	# Finally, check if the cleaned URL ends with a valid image extension.
	return cleaned_url.ends_with(".png") or cleaned_url.ends_with(".jpg")

# This function uses the above isJpgOrPngURL() to check if the URL is valid,
# and if so, returns "png" if the URL ends with .png or "jpg" if it ends with .jpg.
# Otherwise, it returns an empty string.
func getImageType(url: String) -> String:
	# Use our helper function to ensure the URL is valid.
	if not isImageURL(url):
		return ""
	
	# Convert to lowercase and remove any query or fragment parts.
	var lower_url = url.to_lower()
	var base_url = lower_url.split("?")[0].split("#")[0]
	
	if base_url.ends_with(".png"):
		return "png"
	elif base_url.ends_with(".jpg"):
		return "jpg"
	else:
		return ""

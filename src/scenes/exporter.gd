extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

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
	var tool_call = {}
	var image_detail_map = {
		0: "high",
		1: "low",
		2: "auto"
	}
	# Text message
	if message['type'] == 'Text':
		return {
			'role': message['role'],
			'content': message['textContent']
		}
	# Image message
	elif message['type'] == 'Image':
		return {
			'role': message['role'],
			'content': [
				{
					'type': 'image_url',
					'image_url': {
						'url': "data:image/jpeg;base64," + message['imageContent'],
						'detail': image_detail_map[message.get("imageDetail", 0)]
					}
				}
			]
		}
	# Function Call message
	elif message['type'] == 'Function Call':
		# Prepare function call
		var function_name = message['functionName']
		var function_parameters = {}
		
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
	return null

func convert_conversation_to_openai_format(conversation, function_map=null):
	# Convert an entire conversation to OpenAI format.
	# :param conversation: List of messages in source format
	# :param function_map: Optional map of function definitions
	# :return: List of converted messages with optional system message
	var converted_messages = []
	for message in conversation:
		var converted = convert_message_to_openai_format(message, function_map)
		
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
		processed_conversation += convert_conversation_to_openai_format(conversation, function_map)
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
			output_entry['tools'] = tools
		elif function_handle_setting == 1:
			# Only include ones used in the conversation
			tools = convert_functions_to_openai_format(ftdata.get('functions', []), get_all_functions_used_in_conversation(conversation_key))
			output_entry['tools'] = tools
		elif function_handle_setting == 2:
			tools = convert_functions_to_openai_format(ftdata.get('functions', []), get_all_functions_used_globally())
			output_entry['tools'] = tools
		elif function_handle_setting == 3: 
			for msg in processed_conversation:
				if msg.get('tool_calls', false):
					output_entry['tools'] = tools
		else:
			tools = convert_functions_to_openai_format(ftdata.get('functions', []))
			output_entry['tools'] = tools
		jsonl_file_string += JSON.stringify(output_entry) + "\n"
	return jsonl_file_string

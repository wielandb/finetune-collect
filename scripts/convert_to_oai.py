import os, sys, json, re, argparse

def convert_to_oai(input_file, output_file):
	# Converts my proprietary JSON format to OpenAI-fine tuning format
	with open(input_file, 'r') as f:
		data = json.load(f)
	
	# First convert all functions
	## How one function should look in the final format
	"""
        {
            "type": "function",
            "function": {
                "name": "get_current_weather",
                "description": "Get the current weather",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "location": {
                            "type": "string",
                            "description": "The city and country, eg. San Francisco, USA"
                        },
                        "format": { "type": "string", "enum": ["celsius", "fahrenheit"] }
                    },
                    "required": ["location", "format"]
                }
            }
        }
	"""
	## How a function looks in my format
	"""
		{
			"description": "Gets the weather at a certain location",
			"name": "get_weather",
			"parameters": [
				{
					"description": "The location the weather is asked for",
					"enumOptions": "",
					"isEnum": false,
					"isRequired": true,
					"maximum": 0,
					"minimum": 0,
					"name": "location",
					"type": "String"
				},
				{
					"description": "The unit the temperature should be provided in",
					"enumOptions": "celsius,fahrenheit",
					"isEnum": true,
					"isRequired": false,
					"maximum": 0,
					"minimum": 0,
					"name": "unit",
					"type": "String"
				}
			]
		}
	"""
	functions = []
	for function in data['functions']:
		parameters = {}
		for parameter in function['parameters']:
			parameters[parameter['name']] = {
				"type": parameter['type'],
				"description": parameter['description']
			}
			if parameter['isEnum']:
				parameters[parameter['name']]['enum'] = parameter['enumOptions'].split(',')
		functions.append({
			"type": "function",
			"function": {
				"name": function['name'],
				"description": function['description'],
				"parameters": {
					"type": "object",
					"properties": parameters,
					"required": [parameter['name'] for parameter in function['parameters'] if parameter['isRequired']]
				}
			}
		})
	# Convert all conversations into messages
	# Iterate over all conversations
	for conversation in data['conversations']:
		# Convert the messages into the required format
		# How one message should look in the final format
		## Normally: (3 examples)
		"""
		{"role": "system", "content": "Marv is a factual chatbot that is also sarcastic."}, 
		{"role": "user", "content": "What's the capital of France?"}
		{"role": "assistant", "content": "Paris, as if everyone doesn't know that already."}]}
		"""
		## A message consisting of an image:
		"""
		   { "role": "user", "content": [
        {
          "type": "image_url",
          "image_url": {
            "url": "data:image/jpeg;base64,{and here the base64 encoded image}"
          }
        }
    	  ]
    	}
		"""
		## A message consisting of a tool call:
		# Which is one message element in my format but needs to be split into two in the final format
		"""
			{"role": "assistant", "tool_calls": [{"id": "call_id", "type": "function", "function": {"name": "get_current_weather", "arguments": "{\"location\": \"San Francisco, USA\", \"format\": \"celsius\"}"}}]}
			{"role": "tool", "tool_call_id": "call_id", "content": "21.0"},
		"""
		# How a message looks in my format
		## Normally (Text):
		"""
			{
				"functionName": "",
				"functionParameters": [],
				"functionResults": [],
				"imageContent": "",
				"role": "user",
				"textContent": "What traffic sign is this?",
				"type": "Text"
			},
		"""
		## Image:
		"""
			{
				"functionName": "",
				"functionParameters": [],
				"functionResults": [],
				"imageContent": "data:image/jpeg;base64,{base64 encoded image}",
				"role": "user",
				"textContent": "",
				"type": "Image"
			},
		"""
		## Tool call:
		"""
					{
				"functionName": "get_weather",
				"functionParameters": [
					{
						"isUsed": false,
						"name": "unit",
						"parameterValueChoice": "",
						"parameterValueText": ""
					},
					{
						"isUsed": true,
						"name": "location",
						"parameterValueChoice": "",
						"parameterValueText": ""
					}
				],
				"functionResults": [
					{
						"key": "temperature",
						"value": "28.0"
					}
				],
				"imageContent": "",
				"role": "assistant",
				"textContent": "",
				"type": "Function Call"
			}
		"""
		# Iterate over all messages in the conversation
		messages = []
		for message in conversation['messages']:


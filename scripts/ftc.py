import json
import copy

def convert_parameter_to_openai_format(param):
    """
    Convert a parameter from the source format to OpenAI function parameter format.
    """
    param_type_map = {
        'String': 'string',
        'Integer': 'integer',
        'Number': 'number',
        'Boolean': 'boolean'
    }
    
    converted_param = {
        'type': param_type_map.get(param['type'], 'string'),
        'description': param.get('description', '')
    }
    
    # Handle enum options
    if param.get('isEnum', False) and param.get('enumOptions'):
        converted_param['enum'] = param['enumOptions'].split(',')
    
    return converted_param

def convert_function_to_openai_format(func):
    """
    Convert a function from the source format to OpenAI function format.
    """
    converted_function = {
        'type': 'function',
        'function': {
            'name': func['name'],
            'description': func.get('description', ''),
            'parameters': {
                'type': 'object',
                'properties': {},
                'required': []
            }
        }
    }
    
    for param in func['parameters']:
        param_name = param['name']
        converted_param = convert_parameter_to_openai_format(param)
        
        converted_function['function']['parameters']['properties'][param_name] = converted_param
        
        # Add to required parameters if isRequired is True
        if param.get('isRequired', False):
            converted_function['function']['parameters']['required'].append(param_name)
    
    return converted_function

def convert_message_to_openai_format(message, function_map=None):
    """
    Convert a message from the source format to OpenAI message format.
    Handles text, image, and function call messages.
    """
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
                        'url': "data:image/jpeg;base64," + message['imageContent']
                    }
                }
            ]
        }
    
    # Function Call message
    elif message['type'] == 'Function Call':
        # Prepare function call
        function_name = message['functionName']
        function_parameters = {}
        
        # Convert parameters
        for param in message['functionParameters']:
            if param['isUsed']:
                # Use choice if available, otherwise text
                value = param['parameterValueChoice'] or param['parameterValueText']
                function_parameters[param['name']] = value
        
        # Prepare tool call
        tool_call = {
            'role': 'assistant',
            'tool_calls': [{
                'id': 'call_id',  # You might want to generate a unique ID
                'type': 'function',
                'function': {
                    'name': function_name,
                    'arguments': json.dumps(function_parameters)
                }
            }]
        }
        
        # If function result exists, add tool response
        if message['functionResults']:
            tool_response = {
                'role': 'tool',
                'tool_call_id': 'call_id',
                'content': message['functionResults'][0]['value']
            }
            return [tool_call, tool_response]
        
        return tool_call
    
    return None

def convert_conversation_to_openai_format(conversation, function_map=None):
    """
    Convert an entire conversation to OpenAI format.
    
    :param conversation: List of messages in source format
    :param function_map: Optional map of function definitions
    :return: List of converted messages with optional system message
    """
    converted_messages = []
    
    for message in conversation:
        converted = convert_message_to_openai_format(message, function_map)
        
        # Handle cases where a single function message might return multiple messages
        if isinstance(converted, list):
            converted_messages.extend(converted)
        elif converted:
            converted_messages.append(converted)
    
    return converted_messages

def convert_functions_to_openai_format(functions):
    """
    Convert list of functions to OpenAI tools format.
    """
    return [convert_function_to_openai_format(func) for func in functions]

def convert_fine_tuning_data(input_file, output_file):
    """
    Convert entire fine-tuning data from source format to OpenAI JSONL.
    
    :param input_file: Path to input JSON file
    :param output_file: Path to output JSONL file
    """
    # Read input file
    with open(input_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Prepare function map and tools for global use
    function_map = {func['name']: func for func in data.get('functions', [])}
    tools = convert_functions_to_openai_format(data.get('functions', []))
    
    # Optional global system message
    system_message = None
    if data['settings'].get('useGlobalSystemMessage', False):
        system_message = data['settings'].get('globalSystemMessage', '')
    
    # Write output JSONL
    with open(output_file, 'w', encoding='utf-8') as out_f:
        for conversation_key, conversation in data['conversations'].items():
            # Add global system message if applicable
            processed_conversation = []
            if system_message:
                processed_conversation.append({
                    'role': 'system', 
                    'content': system_message
                })
            
            # Convert conversation
            processed_conversation.extend(
                convert_conversation_to_openai_format(conversation, function_map)
            )
            
            # Write to JSONL, optionally including tools
            output_entry = {
                'messages': processed_conversation
            }
            
            # Only add tools if there are function calls in the conversation
            if any(msg.get('tool_calls') for msg in processed_conversation):
                output_entry['tools'] = tools
            
            out_f.write(json.dumps(output_entry) + '\n')

def main():
    if sys.argv[0]:
        filename = sys.argv[0]
    else:
        filename = "data.json"
    convert_fine_tuning_data(filename, 'output_finetune.jsonl')

if __name__ == '__main__':
    main()
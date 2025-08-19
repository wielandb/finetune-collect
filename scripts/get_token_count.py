import tiktoken, sys, json
encoding = tiktoken.encoding_for_model("gpt-4o")


#!/usr/bin/env python3

"""
Example script to calculate token usage for fine-tuning data (text + optional images + optional functions).
Usage:
    python calculate_token_usage.py /path/to/your_finetuning_project.json

Output:
    Prints a dictionary of conversation_id -> token_count
    Example: {'FtC1': 1, 'd4yI': 1, 'duJa': 398, 'PP60': 208226, '4bGq': 3595636, 'I9Pt': 707, 'QiTc': 577039, 'BSLs': 658948, '9ZHo': 157}
"""

import sys
import json
import base64
import math
import requests
from io import BytesIO

try:
    from PIL import Image
except ImportError:
    #print("Please install Pillow (pip install Pillow) to handle images.")
    Image = None

import tiktoken

# -----------------------------------------------------------------------------
# 1. Image token calculation (based on example from OpenAI Vision pricing doc)
# -----------------------------------------------------------------------------

def image_token_count(image_data, low_res=False):
    """
    Calculate how many tokens an image will consume, based on:
      - base tokens = 85
      - tile tokens = 170 per 512x512 tile
      - number of tiles = ceil(width/512) * ceil(height/512)
      - optional resizing if low_res is True (example logic; adjust as needed)

    image_data can be:
      - a URL (if from_base64=False)
      - base64-encoded bytes (if from_base64=True)
    """
    """
    if Image is None:
        # If PIL not installed, return 0 to avoid errors
        return 0

    # 1) Obtain the image and check whether it's base64 or a URL
    from_base64 = True
    if image_data.startswith("http"):
        from_base64 = False
    if from_base64:
        # decode base64, "data:image/jpeg;base64," or "data:image/png;base64," +
        if "," in image_data:
            image_data = image_data.split(",")[1]
        img_bytes = base64.b64decode(image_data)
        img = Image.open(BytesIO(img_bytes))
    else:
        # assume it's a URL and download
        response = requests.get(image_data)
        response.raise_for_status()
        img = Image.open(BytesIO(response.content))

    width, height = img.size
    #print(f"Image size: {width}x{height}")
    # 2) Possibly do some resizing if low_res is True
    #    (Below is just a sample approach. Adjust your resize logic if needed.)
    if low_res:
        # For example, scale down so that max dimension is 768 if bigger
        max_dim = 768
        if width > max_dim or height > max_dim:
            scale = min(max_dim / width, max_dim / height)
            new_w = int(width * scale)
            new_h = int(height * scale)
            img = img.resize((new_w, new_h))
            width, height = new_w, new_h

    # 3) Calculate how many 512x512 tiles
    tiles_x = math.ceil(width / 512)
    tiles_y = math.ceil(height / 512)
    tile_count = tiles_x * tiles_y
    #print(f"Number of 512x512 tiles: {tile_count}")
    base_tokens = 85
    tile_token_cost = 170

    total_image_tokens = base_tokens + tile_count * tile_token_cost
    #print(f"Total image tokens: {total_image_tokens}")
    return total_image_tokens
    """
    # Thats not idea and should be revisited
    if low_res:
        return 85
    else:
        return 1105

def get_token_count_for_string(s):
    return len(encoding.encode(str(s)))

def get_setting(setting_key):
    global SAVE_DATA
    return SAVE_DATA["settings"].get(setting_key, None)

def get_functions():
    global SAVE_DATA
    return SAVE_DATA["functions"]

def get_token_count_for_text_message(message_dict):
    # Get the fine tuning type from the settings
    finetune_type = get_setting("finetuneType")
    if finetune_type == 0:
        return get_token_count_for_string(message_dict["textContent"])
    elif finetune_type == 1:
        return get_token_count_for_string(message_dict["preferredTextContent"] + message_dict["unpreferredTextContent"])
    elif finetune_type == 2:
        return 0

def get_token_count_for_json_schema_message(message_dict):
    return get_token_count_for_string(message_dict["jsonSchemaValue"])

def get_token_count_for_image_message(message_dict):
    # image_detail: 0 = high detail, 1 = low detail, (consider 2 to be also high detail)
    image_detail = message_dict["imageDetail"]
    if image_detail == 0:
        return image_token_count(message_dict["imageContent"])
    elif image_detail == 1:
        return image_token_count(message_dict["imageContent"], low_res=True)
    else:
        return 0


def get_token_count_for_function_call_message(message_dict):
    # A function call message is in reality a function call followed by a text message
    # The text message is the result of the function call
    # Return the combined token count of both
    tokens = 0
    tokens += get_token_count_for_string(message_dict["functionName"])
    for param in message_dict["functionParameters"]:
        tokens += get_token_count_for_string(param["name"])
        tokens += get_token_count_for_string(param["parameterValueText"] + param["parameterValueChoice"] + str(param["parameterValueNumber"]))
    tokens += get_token_count_for_string(message_dict["functionResults"])
    #print("tokens for function call message: " + str(tokens))
    return tokens


def get_token_count_for_available_function(fname):
    function = next((f for f in get_functions() if f["name"] == fname), None)
    if function is None:
        return 0
    #print("Calculating tokens for function " + fname)
    tokens = 10 # func_init, according to OpenAi Cookbook
    tokens += get_token_count_for_string(function["name"] + ":" + function["description"]) # According to OpenAi Cookbook
    #print("Tokens for function " + fname + " after name and description: " + str(tokens))
    tokens += 3 # prop_Init
    for param in function["parameters"]:
        tokens += 3 #prop_key
        tokens += get_token_count_for_string(param["name"] + ":" + param["type"] + ":" + param["description"])
        #print("Tokens for function " + fname + " after parameter " + param["name"] + ": " + str(tokens))
        # Chek if the parameter is an enum
        if param["isEnum"]:
            tokens += -3 # enum_init
            for option in param["enumOptions"].split(","):
                tokens += 3 # enum_item
                tokens += get_token_count_for_string(option)
    #print("Additional tokens for single available function " + fname + ": " + str(tokens))
    return tokens

def token_count_for_available_functions(conversationIx):
    global SAVE_DATA
    # Calculate how many tokens (for which functions to include in every message) are needed for each message cause the settings say so
    # The different "includeFunctions" settings are:
    # 0 - Always include all functions
    # 1 - Include all functions used anywhere in the current conversation
    # 2 - Include all functions used at least once in ANY conversation
    # 3 - Include all functions if any function is used in the current conversation

    # Get the current conversation
    conversation = SAVE_DATA["conversations"][conversationIx]
    # Get the current setting
    include_functions = get_setting("includeFunctions")
    # Get the functions
    functions = get_functions()
    # Get the function names used in the current conversation
    function_names = []
    for message in conversation:
        if message["type"] == "Function Call":
            function_names.append(message["functionName"])
    # Get the function names used in any conversation
    function_names_all = []
    for convokey in SAVE_DATA["conversations"]:
        for message in SAVE_DATA["conversations"][convokey]:
            if message["type"] == "Function Call":
                function_names_all.append(message["functionName"])
    # Get the unique function names
    function_names = list(set(function_names))
    function_names_all = list(set(function_names_all))
    # Get the tokens depending on the setting for all functions that we will include
    tokens = 0
    if include_functions == 0:
        for fname in function_names_all:
            tokens += get_token_count_for_available_function(fname)
    elif include_functions == 1:
        for fname in function_names:
            tokens += get_token_count_for_available_function(fname)
    elif include_functions == 2:
        for fname in function_names_all:
            tokens += get_token_count_for_available_function(fname)
    elif include_functions == 3:
        if len(function_names) > 0:
            for fname in function_names_all:
                tokens += get_token_count_for_available_function(fname)
    #print("Additional tokens for available functions: " + str(tokens))
    return tokens

def get_token_count_for_function_return_value(message_dict):
    return get_token_count_for_string(message_dict["functionResults"])

def get_token_count_for_conversation(convoIx):
    global SAVE_DATA
    conversation = SAVE_DATA["conversations"][convoIx]
    tokens = {"total": 0, "input": 0, "output": 0}
    for message in conversation:
        if message["type"] == "meta":
            this_message_tokens = 0
        if message["type"] == "Text":
            this_message_tokens = get_token_count_for_text_message(message)
        if message["type"] == "Image":
            this_message_tokens = get_token_count_for_image_message(message)
        if message["type"] == "Function Call":
            this_message_tokens = get_token_count_for_function_call_message(message)
        if message["type"] == "JSON":
            this_message_tokens = get_token_count_for_json_schema_message(message)
        # If its a user message or function call, we need to add the token count for the available functions
        if message["role"] == "user" or message["type"] == "Function Call":
            this_message_tokens += token_count_for_available_functions(convoIx)
        # Add to the total and input/output as appropriate
        tokens["total"] += this_message_tokens
        if message["role"] == "user" or message["role"] == "system":
            tokens["input"] += this_message_tokens
        elif message["role"] == "assistant":
            if message["type"] == "Function Call":
                tmp_output_tokens = this_message_tokens - get_token_count_for_function_return_value(message)
                tokens["output"] += tmp_output_tokens
                tokens["input"] += get_token_count_for_function_return_value(message)
            else:
                tokens["output"] += this_message_tokens
    return tokens

# Get the save file path from the command line
save_file = sys.argv[1]

# Load the save file 
with open(save_file, "r", encoding="UTF-8") as f:
    SAVE_DATA = json.loads(f.read())

token_count_for_convoix = {}

conversations = SAVE_DATA["conversations"]
for conversationKey in conversations:
    conversation = conversations[conversationKey]
    token_counts = get_token_count_for_conversation(conversationKey)
    token_count_for_convoix[conversationKey] = {}
    token_count_for_convoix[conversationKey]["total"] = token_counts["total"]
    token_count_for_convoix[conversationKey]["input"] = token_counts["input"]
    token_count_for_convoix[conversationKey]["output"] = token_counts["output"]
    #print(f"Conversation {conversationKey} has {token_count} tokens")

print(str(token_count_for_convoix).replace("'", "\""))
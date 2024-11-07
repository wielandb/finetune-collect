extends ScrollContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func estimate_tokens(somed):
	# Performs a very basic calculation of tokens
	return len(str(somed)) * 0.25
	
func estimate_token_cost(tokens, pricepermillion):
	return tokens * (pricepermillion / 1000000)



func analyze_functions(CONVD, FUNCD, SETTINGSD):
	var error_list = []
	# Checks all functions for errors
	## Check if two functions have the same name
	var knownFnames = []
	for f in FUNCD:
		if f["name"] in knownFnames:
			error_list.append("Mehr als eine Funktion hat folgenden namen: " + f["name"])
		else:
			knownFnames.append(f["name"])
	## Check if no function has an empty name
	for f in FUNCD:
		if f["name"] == "":
			error_list.append("Eine Funktion hat einen leeren Namen!")
	## 


func _on_run_analysis_button_pressed() -> void:
	## get all the dicts
	var FUNCTIONS = get_node("/root/FineTune").FUNCTIONS
	var CONVERSATIONS = get_node("/root/FineTune").CONVERSATIONS
	var SETTINGS = get_node("/root/FineTune").SETTINGS
	## Calculate token cost
	var message_tokens = estimate_tokens(CONVERSATIONS)
	var function_tokens = estimate_tokens(FUNCTIONS)
	var message_token_cost = estimate_token_cost(message_tokens, 25.00)
	var function_token_cost = estimate_token_cost(function_tokens, 25.00)
	print("Current token costs:")
	print(str(message_tokens) + " message tokens, " + str(message_token_cost) + "€")
	print(str(function_tokens) + " function tokens, " + str(function_token_cost) + "€")

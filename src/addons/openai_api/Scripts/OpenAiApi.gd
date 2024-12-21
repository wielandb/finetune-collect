@icon("res://addons/openai_api/Icons/openico.png")
extends Node

var chatgpt_inst = preload("res://addons/openai_api/Scenes/ChatGpt.tscn")
var dalle_inst = preload("res://addons/openai_api/Scenes/Dalle.tscn")
var models_inst = preload("res://addons/openai_api/Scenes/Models.tscn")

@export var dalle :Dalle = null
@export var chatgpt :ChatGpt = null
@export var models: Models = null

@export var openai_api_key = ""

signal gpt_response_completed(message:Message, response:Dictionary)
signal dalle_response_completed(texture:ImageTexture)
signal models_received(models: Array[String])

##Makes an api call to open ai chatgpt, and returns a class `Message` that contains `{"role":role,"content":content}`
func prompt_gpt(ListOfMessages:Array[Message], model: String = "gpt-4o-mini", url:String="https://api.openai.com/v1/chat/completions", tools:Array = []):
	
	while !chatgpt:
		await get_tree().create_timer(0.2).timeout
		
	chatgpt.prompt_gpt(ListOfMessages,model,url,tools)

##Makes an api call to open ai dalle, and returns the generated Texture
func prompt_dalle(prompt:String, resolution:String = "1024x1024", model: String = "dall-e-2", url:String="https://api.openai.com/v1/images/generations"):
	
	while !dalle:
		await get_tree().create_timer(0.2).timeout
		
	dalle.prompt_dalle(prompt,resolution,model,url)

func get_api() -> String:
	if openai_api_key.is_empty():
		push_error("Insert your OpenAi api key!")
	return openai_api_key
	
func set_api(api:String) -> void:
	openai_api_key = api

func get_models() -> void:
	while !models:
		await get_tree().create_timer(0.2).timeout
		
	models.get_available_models()

func _ready():
	if chatgpt and dalle and models:
		return
		
	call_deferred("add_child", chatgpt_inst.instantiate())
	call_deferred("add_child", dalle_inst.instantiate())
	call_deferred("add_child", models_inst.instantiate())
	
func _process(delta):
	if dalle and chatgpt and models:
		set_process(false)
	if get_children() == []:
		return
		
	chatgpt = get_children()[0]
	dalle = get_children()[1]
	models = get_children()[2]

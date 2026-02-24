@icon("res://addons/openai_api/Icons/openico.png")
extends Node

var chatgpt_inst = preload("res://addons/openai_api/Scenes/ChatGpt.tscn")
var dalle_inst = preload("res://addons/openai_api/Scenes/Dalle.tscn")
var models_inst = preload("res://addons/openai_api/Scenes/Models.tscn")
var grader_inst = preload("res://addons/openai_api/Scenes/Grader.tscn")

@export var dalle :Dalle = null
@export var chatgpt :ChatGpt = null
@export var models: Models = null
@export var grader: Grader = null

const DEFAULT_API_BASE_URL = "https://api.openai.com/v1"

@export var openai_api_key = ""
@export var api_base_url = DEFAULT_API_BASE_URL

signal gpt_response_completed(message:Message, response:Dictionary)
signal gpt_response_failed(response: Dictionary)
signal dalle_response_completed(texture:ImageTexture)
signal models_received(models: Array[String])
signal grader_run_completed(response: Dictionary)
signal grader_validation_completed(response: Dictionary)

func _normalize_api_base_url(url: String) -> String:
	var normalized = url.strip_edges()
	while normalized.ends_with("/"):
		normalized = normalized.substr(0, normalized.length() - 1)
	if normalized == "":
		return DEFAULT_API_BASE_URL
	return normalized

func get_api_base_url() -> String:
	api_base_url = _normalize_api_base_url(api_base_url)
	return api_base_url

func set_api_base_url(url: String) -> void:
	api_base_url = _normalize_api_base_url(url)

func build_api_url(path: String) -> String:
	var normalized_path = path.strip_edges()
	if normalized_path == "":
		return get_api_base_url()
	if not normalized_path.begins_with("/"):
		normalized_path = "/" + normalized_path
	return get_api_base_url() + normalized_path

##Makes an api call to open ai chatgpt, and returns a class `Message` that contains `{"role":role,"content":content}`
func prompt_gpt(ListOfMessages:Array[Message], model: String = "gpt-4o-mini", url:String = "", tools:Array = [], response_format: Dictionary = {}):
	
	while !chatgpt:
		await get_tree().create_timer(0.2).timeout
	
	var request_url = url.strip_edges()
	if request_url == "":
		request_url = build_api_url("/chat/completions")
	chatgpt.prompt_gpt(ListOfMessages, model, request_url, tools, response_format)

##Makes an api call to open ai dalle, and returns the generated Texture
func prompt_dalle(prompt:String, resolution:String = "1024x1024", model: String = "dall-e-2", url:String = ""):
	
	while !dalle:
		await get_tree().create_timer(0.2).timeout
	
	var request_url = url.strip_edges()
	if request_url == "":
		request_url = build_api_url("/images/generations")
	dalle.prompt_dalle(prompt, resolution, model, request_url)

func run_grader(grader_obj: Dictionary, model_sample, item = null, url: String = ""):
	while !grader:
		await get_tree().create_timer(0.2).timeout
	var request_url = url.strip_edges()
	if request_url == "":
		request_url = build_api_url("/fine_tuning/alpha/graders/run")
	grader.run_grader(grader_obj, model_sample, item, request_url)

func validate_grader(grader_obj: Dictionary, url: String = ""):

	while !grader:
		await get_tree().create_timer(0.2).timeout

	var request_url = url.strip_edges()
	if request_url == "":
		request_url = build_api_url("/fine_tuning/alpha/graders/validate")
	grader.validate_grader(grader_obj, request_url)

func create_grader() -> Grader:
	var g: Grader = grader_inst.instantiate()
	add_child(g)
	return g

func get_api() -> String:
	if openai_api_key.is_empty():
		push_error("Insert your OpenAi api key!")
	return openai_api_key

func set_api(api:String) -> void:
	openai_api_key = api

func get_models() -> void:
	while !models:
		await get_tree().create_timer(0.2).timeout
	
	models.get_available_models(build_api_url("/models"))

func _ready():
	if chatgpt and dalle and models and grader:
		return

	call_deferred("add_child", chatgpt_inst.instantiate())
	call_deferred("add_child", dalle_inst.instantiate())
	call_deferred("add_child", models_inst.instantiate())
	call_deferred("add_child", grader_inst.instantiate())
	
func _process(delta):
	if chatgpt and dalle and models and grader:
		set_process(false)
		return
	for child in get_children():
		if !chatgpt and child is ChatGpt:
			chatgpt = child
		elif !dalle and child is Dalle:
			dalle = child
		elif !models and child is Models:
			models = child
		elif !grader and child is Grader:
			grader = child

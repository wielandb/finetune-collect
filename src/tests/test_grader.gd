extends SceneTree

var run_called := false
var validate_called := false
var parent_run_called := false
var parent_validate_called := false

func _init():
	var parent = Node.new()
	parent.add_user_signal('grader_run_completed')
	parent.add_user_signal('grader_validation_completed')
	get_root().add_child(parent)
	var Grader = load('res://addons/openai_api/Scripts/Grader.gd')
	var g = Grader.new()
	parent.add_child(g)
	await create_timer(0).timeout
	g.connect('run_completed', _on_run)
	g.connect('validation_completed', _on_validate)
	parent.connect('grader_run_completed', _on_parent_run)
	parent.connect('grader_validation_completed', _on_parent_validate)
	var body = JSON.stringify({'ok': true}).to_utf8_buffer()
	g._run_request_completed(HTTPRequest.RESULT_SUCCESS, 200, [], body)
	g._validate_request_completed(HTTPRequest.RESULT_SUCCESS, 200, [], body)
	assert(run_called)
	assert(validate_called)
	assert(parent_run_called)
	assert(parent_validate_called)
	print('Grader signals propagated')
	quit(0)

func _on_run(response):
	run_called = true

func _on_validate(response):
	validate_called = true

func _on_parent_run(response):
	parent_run_called = true

func _on_parent_validate(response):
	parent_validate_called = true

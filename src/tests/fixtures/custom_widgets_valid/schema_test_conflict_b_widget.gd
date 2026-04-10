extends SchemaCustomWidgetBase

var match_schema: Dictionary = {
	"type": "object",
	"required": ["conflict_key"],
	"properties": {
		"conflict_key": {"type": "string"}
	},
	"additionalProperties": false
}

func bind_context(context: SchemaCustomWidgetContext) -> void:
	var value = context.get_value()
	if not (value is Dictionary):
		context.set_value({"conflict_key": ""}, false)
	$ConflictBFlagLabel.text = "Conflict Widget B"
